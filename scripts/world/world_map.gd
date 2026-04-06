## @fileoverview 월드맵 메인 스크립트. 6개 지역의 노드 배치, 연결선 표시,
## 카메라 이동, 노드 선택/진입 등 월드맵의 모든 상호작용을 관리한다.
extends Node2D

## MapNode 스크립트 (class_name 글로벌 등록 실패 시 대비)
const MapNodeClass = preload("res://scripts/world/map_node.gd")

# ── 지역 중심 좌표 (1920x1080 기반) ──
# 스펙에 따른 대략적 배치: 이르헨(좌상) - 실바렌(우상) - 크로우펠(중앙) -
# 하르벤(중우) - 벨마르(좌하) - 아스칼론(우하) - 재의 바다(하단)

## 지역별 중심 좌표
const REGION_CENTERS := {
	"irhen": Vector2(350, 200),
	"silvaren": Vector2(900, 180),
	"crowfel": Vector2(620, 450),
	"harben": Vector2(1100, 420),
	"belmar": Vector2(250, 500),
	"ascalon": Vector2(1350, 550),
	"ashen_sea": Vector2(960, 800),
}

## 지역별 한국어 이름
const REGION_NAMES := {
	"irhen": "이르헨",
	"silvaren": "실바렌",
	"crowfel": "크로우펠",
	"harben": "하르벤",
	"belmar": "벨마르",
	"ascalon": "아스칼론",
	"ashen_sea": "재의 바다",
}

## 지역별 노드 오프셋 (같은 지역 내 노드를 분산 배치하기 위한 오프셋 맵)
## node_id -> 중심으로부터의 오프셋
const NODE_OFFSETS := {
	# 이르헨
	"irhen_village": Vector2(0, 0),
	"irhen_road": Vector2(80, 60),
	"irhen_rebuild": Vector2(-60, 70),
	# 벨마르
	"belmar_port": Vector2(0, 0),
	"belmar_alley": Vector2(-70, 60),
	"belmar_guild": Vector2(70, 50),
	"belmar_dock_pilgrimage": Vector2(0, 90),
	# 실바렌
	"silvaren_entrance": Vector2(0, 0),
	"silvaren_assembly": Vector2(-80, 60),
	"silvaren_temple": Vector2(80, 50),
	"silvaren_barrier_stone": Vector2(0, 100),
	"silvaren_pilgrimage": Vector2(-60, -50),
	"silvaren_beasts": Vector2(90, -40),
	# 하르벤
	"harben_granary": Vector2(0, 0),
	"harben_fields": Vector2(70, 50),
	"harben_pilgrimage": Vector2(-60, 60),
	# 크로우펠
	"crowfel_mountain_pass": Vector2(0, 0),
	"crowfel_fortress": Vector2(-80, 50),
	"crowfel_foothills": Vector2(-80, 110),
	"crowfel_pilgrimage": Vector2(-140, 80),
	"crowfel_bandits": Vector2(80, 50),
	"crowfel_ashen": Vector2(80, -40),
	# 아스칼론
	"ascalon_outskirts": Vector2(-120, -80),
	"ascalon_city": Vector2(0, -40),
	"ascalon_banquet": Vector2(80, -100),
	"ascalon_voldt_prison": Vector2(-80, 20),
	"ascalon_elmira": Vector2(100, 0),
	"ascalon_linen_room": Vector2(0, 60),
	"ascalon_throne_room": Vector2(-80, 100),
	"ascalon_temple_underground": Vector2(80, 80),
	"ascalon_outskirts_assault": Vector2(-140, 140),
	"ascalon_secret_police": Vector2(-60, 170),
	"ascalon_eris_prison": Vector2(20, 200),
	"ascalon_morgan_basement": Vector2(80, 170),
	"ascalon_throne": Vector2(0, 240),
	# 재의 바다
	"ashen_sea_entrance": Vector2(0, 0),
	"ashen_sea_lord": Vector2(-80, 70),
	"ashen_sea_frontier": Vector2(80, 60),
}

## 연결선 색상 (일반)
const LINE_COLOR_DEFAULT := Color(0.5, 0.45, 0.35, 0.4)
## 연결선 색상 (활성)
const LINE_COLOR_ACTIVE := Color(0.8, 0.7, 0.4, 0.7)
## 연결선 두께
const LINE_WIDTH := 2.0

## 카메라 이동 속도 (키보드)
const CAMERA_SPEED := 400.0
## 카메라 팬 최소/최대 범위
const CAMERA_MIN := Vector2(0, 0)
const CAMERA_MAX := Vector2(1920, 1080)

# ── 내부 참조 ──

## 카메라 노드
var _camera: Camera2D = null
## 연결선 컨테이너
var _connections_layer: Node2D = null
## 노드 컨테이너
var _nodes_layer: Node2D = null
## 플레이어 마커
var _player_marker: Node2D = null
## 정보 패널
var _info_panel: Control = null
## 정보 패널 내부 라벨
var _info_name: Label = null
var _info_type: Label = null
var _info_desc: RichTextLabel = null
var _info_enter_btn: Button = null

## 생성된 MapNodeClass 인스턴스 맵 {node_id: MapNodeClass}
var _map_nodes: Dictionary = {}

## 현재 선택된 노드 ID
var _selected_node_id: String = ""

## 배경 색상 (양피지 톤)
const BG_COLOR := Color(0.15, 0.12, 0.1)

# ── 라이프사이클 ──

func _ready() -> void:
	_get_scene_nodes()
	_build_world_map()
	_connect_signals()

	# 플레이어 마커를 현재 노드 또는 첫 available 노드 위치로 이동
	var pm: Node = get_node("/root/ProgressionManager")
	if pm.current_node_id != "" and _map_nodes.has(pm.current_node_id):
		_move_player_marker(_map_nodes[pm.current_node_id].position)
		_camera.position = _map_nodes[pm.current_node_id].position
	else:
		for nid: String in _map_nodes:
			if pm.get_node_state(nid) == "available":
				_camera.position = _map_nodes[nid].position
				_move_player_marker(_map_nodes[nid].position)
				break
	print("[WorldMap] 월드맵 로드 완료 (노드: %d개)" % _map_nodes.size())

func _process(delta: float) -> void:
	_handle_camera_input(delta)

func _unhandled_input(event: InputEvent) -> void:
	# ESC로 정보 패널 닫기
	if event.is_action_pressed("ui_cancel"):
		_hide_info_panel()
		get_viewport().set_input_as_handled()

# ── 씬 노드 참조 획득 ──

## tscn에 정의된 노드 참조를 가져온다.
func _get_scene_nodes() -> void:
	_camera = $Camera2D
	_connections_layer = $Connections
	_nodes_layer = $Nodes
	_player_marker = $PlayerMarker
	_info_panel = $InfoPanel
	_info_name = $InfoPanel/NodeName
	_info_type = $InfoPanel/NodeType
	_info_desc = $InfoPanel/NodeDescription
	_info_enter_btn = $InfoPanel/EnterButton
	# 초기 상태: 정보 패널 숨김
	_info_panel.visible = false
	# 카메라 초기 위치 (맵 중앙)
	_camera.position = Vector2(960, 540)

# ── 월드맵 빌드 ──

## DataManager의 world_nodes 데이터를 기반으로 전체 맵을 구축한다.
func _build_world_map() -> void:
	var dm: Node = get_node("/root/DataManager")
	var pm: Node = get_node("/root/ProgressionManager")

	# 1) 지역 라벨 생성
	_create_region_labels()

	# 2) 노드 생성
	for nid: String in dm.world_nodes:
		var node_data: Dictionary = dm.world_nodes[nid]
		var pos := _calculate_node_position(nid, node_data)
		var map_node := MapNodeClass.new()
		map_node.setup(node_data, pos)
		map_node.set_state(pm.get_node_state(nid))
		map_node.node_clicked.connect(_on_node_clicked)
		_nodes_layer.add_child(map_node)
		_map_nodes[nid] = map_node

	# 3) 연결선 생성
	_create_connections(dm)

	# 디버그 카운터
	var available_count := 0
	var locked_count := 0
	for nid2: String in _map_nodes:
		if pm.get_node_state(nid2) == "available":
			available_count += 1
		elif pm.get_node_state(nid2) == "locked":
			locked_count += 1
	print("[WorldMap] 월드맵 구축 완료: 노드 %d개 (available: %d, locked: %d)" % [
		_map_nodes.size(), available_count, locked_count
	])

## 노드의 월드맵 배치 좌표를 계산한다.
## @param nid 노드 ID
## @param node_data 노드 데이터
## @returns 배치 좌표
func _calculate_node_position(nid: String, node_data: Dictionary) -> Vector2:
	var region_name: String = node_data.get("region", "irhen")
	var center: Vector2 = REGION_CENTERS.get(region_name, Vector2(500, 500))
	var offset: Vector2 = NODE_OFFSETS.get(nid, Vector2.ZERO)
	return center + offset

## 디버그 오버레이를 생성한다 (진단 로그 표시).
## CanvasLayer 200으로 설정 — FadeRect(layer 100) 위에 표시.
## @param log_text 화면에 표시할 진단 로그
## 지역 이름 라벨을 생성한다.
func _create_region_labels() -> void:
	for region_id: String in REGION_CENTERS:
		var center: Vector2 = REGION_CENTERS[region_id]
		var label := Label.new()
		label.text = REGION_NAMES.get(region_id, region_id)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = center + Vector2(-80, -90)
		label.size = Vector2(160, 28)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.5, 0.85))
		_nodes_layer.add_child(label)

## 노드 간 연결선(Line2D)을 생성한다.
## @param dm DataManager 참조
func _create_connections(dm: Node) -> void:
	# 중복 연결 방지용 Set
	var drawn: Dictionary = {}
	for nid: String in dm.world_nodes:
		var node_data: Dictionary = dm.world_nodes[nid]
		var conns: Array = node_data.get("connections", [])
		for connected_id: String in conns:
			# 정렬된 키로 중복 방지
			var key: String
			if nid < connected_id:
				key = nid + "-" + connected_id
			else:
				key = connected_id + "-" + nid
			if drawn.has(key):
				continue
			drawn[key] = true
			# 양쪽 노드가 모두 존재하는 경우에만 선 생성
			if not _map_nodes.has(nid) or not _map_nodes.has(connected_id):
				continue
			var line := Line2D.new()
			line.name = "Line_%s" % key
			line.add_point(_map_nodes[nid].position)
			line.add_point(_map_nodes[connected_id].position)
			line.width = LINE_WIDTH
			line.default_color = LINE_COLOR_DEFAULT
			_connections_layer.add_child(line)

# ── 시그널 연결 ──

## EventBus, UI 시그널을 연결한다.
func _connect_signals() -> void:
	_info_enter_btn.pressed.connect(_on_enter_button_pressed)
	var eb: Node = get_node("/root/EventBus")
	eb.node_unlocked.connect(_on_node_unlocked)

# ── 노드 선택/정보 표시 ──

## 노드 클릭 시 정보 패널을 표시한다.
## @param node_id 클릭된 노드 ID
func _on_node_clicked(node_id: String) -> void:
	_selected_node_id = node_id
	_show_info_panel(node_id)
	# 플레이어 마커를 해당 노드로 이동 (Tween)
	if _map_nodes.has(node_id):
		_move_player_marker(_map_nodes[node_id].position)

## 정보 패널을 표시한다.
## @param node_id 표시할 노드 ID
func _show_info_panel(node_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	var node_data: Dictionary = dm.world_nodes.get(node_id, {})
	if node_data.is_empty():
		return
	_info_name.text = node_data.get("name_ko", "")
	_info_type.text = _get_type_display_name(node_data.get("type", ""))
	_info_desc.text = node_data.get("description_ko", "")
	# 완료된 노드 중 재진입 불가 타입이면 버튼 비활성화
	var pm: Node = get_node("/root/ProgressionManager")
	var node_state: String = pm.get_node_state(node_id)
	var ntype: String = node_data.get("type", "")
	if node_state == "completed" and ntype not in ["shop", "outpost", "wandering_battle"]:
		_info_enter_btn.text = "완료됨"
		_info_enter_btn.disabled = true
	else:
		_info_enter_btn.text = "진입하기"
		_info_enter_btn.disabled = false
	_info_panel.visible = true

## 정보 패널을 숨긴다.
func _hide_info_panel() -> void:
	_info_panel.visible = false
	_selected_node_id = ""

## 노드 타입의 표시용 한국어 이름을 반환한다.
## @param ntype 노드 타입 문자열
## @returns 표시용 한국어 문자열
func _get_type_display_name(ntype: String) -> String:
	match ntype:
		"story_battle": return "스토리 전투"
		"wandering_battle": return "유랑 전투"
		"story_event": return "스토리 이벤트"
		"shop": return "상점"
		"outpost": return "거점"
		"travel": return "이동 경로"
		_: return ntype

# ── 노드 진입 ──

## 진입 버튼 클릭 시 선택된 노드 타입에 따라 전환 처리.
func _on_enter_button_pressed() -> void:
	if _selected_node_id == "":
		return
	var dm: Node = get_node("/root/DataManager")
	var node_data: Dictionary = dm.world_nodes.get(_selected_node_id, {})
	if node_data.is_empty():
		return
	var ntype: String = node_data.get("type", "")
	var bid: String = node_data.get("battle_id", "")
	var sid: String = node_data.get("scene_id", "")
	var gm: Node = get_node("/root/GameManager")

	# 자동 세이브 (노드 진입 전)
	var sm: Node = get_node("/root/SaveManager")
	sm.auto_save()

	match ntype:
		"story_battle", "wandering_battle":
			# 전투 씬으로 전환
			if bid != "":
				gm.current_battle_id = bid
				gm.current_scene_id = sid
				# 전투 씬 경로 (Phase 9에서 구현)
				var battle_scene := "res://scenes/battle/battle_scene.tscn"
				gm.transition_to_scene(battle_scene, 0.5, gm.GameState.DEPLOYMENT)
				print("[WorldMap] 전투 진입: %s (battle: %s)" % [_selected_node_id, bid])
			else:
				push_warning("[WorldMap] 전투 ID 없음: %s" % _selected_node_id)
		"story_event":
			# 대화/이벤트 씬으로 전환
			if sid != "":
				gm.current_scene_id = sid
				var dialogue_scene := "res://scenes/dialogue/dialogue_scene.tscn"
				gm.transition_to_scene(dialogue_scene, 0.5, gm.GameState.DIALOGUE)
				print("[WorldMap] 이벤트 진입: %s (scene: %s)" % [_selected_node_id, sid])
		"shop":
			# 상점 화면으로 전환
			gm.transition_to_scene("res://scenes/ui/shop_screen.tscn", 0.5, gm.GameState.MENU)
			print("[WorldMap] 상점 진입: %s" % _selected_node_id)
		"outpost":
			# 편성/장비 메뉴
			gm.transition_to_scene("res://scenes/ui/outpost_screen.tscn", 0.5, gm.GameState.MENU)
			print("[WorldMap] 거점 진입: %s" % _selected_node_id)
		"travel":
			# 이동 경로는 바로 완료 처리
			var pm: Node = get_node("/root/ProgressionManager")
			pm.complete_node(_selected_node_id)
			_refresh_node_states()
			_hide_info_panel()
			print("[WorldMap] 이동 경로 통과: %s" % _selected_node_id)

# ── 플레이어 마커 ──

## 플레이어 마커를 대상 위치로 Tween 이동시킨다.
## @param target_pos 목표 좌표
func _move_player_marker(target_pos: Vector2) -> void:
	var tween := create_tween()
	tween.tween_property(_player_marker, "position", target_pos, 0.3) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

# ── 카메라 제어 ──

## 키보드 입력에 따라 카메라를 이동시킨다.
## @param delta 프레임 시간
func _handle_camera_input(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed("camera_up"):
		dir.y -= 1
	if Input.is_action_pressed("camera_down"):
		dir.y += 1
	if Input.is_action_pressed("camera_left"):
		dir.x -= 1
	if Input.is_action_pressed("camera_right"):
		dir.x += 1

	if dir != Vector2.ZERO:
		_camera.position += dir.normalized() * CAMERA_SPEED * delta
		_camera.position = _camera.position.clamp(CAMERA_MIN, CAMERA_MAX)

## 특정 지역으로 카메라를 팬 이동시킨다.
## @param region_id 지역 ID
func pan_to_region(region_id: String) -> void:
	var center: Vector2 = REGION_CENTERS.get(region_id, _camera.position)
	var tween := create_tween()
	tween.tween_property(_camera, "position", center, 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

## 특정 노드로 카메라를 팬 이동시킨다.
## @param node_id 노드 ID
func pan_to_node(node_id: String) -> void:
	if _map_nodes.has(node_id):
		var tween := create_tween()
		tween.tween_property(_camera, "position", _map_nodes[node_id].position, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

# ── 상태 갱신 ──

## 모든 노드의 상태를 ProgressionManager에서 다시 읽어와 갱신한다.
func _refresh_node_states() -> void:
	var pm: Node = get_node("/root/ProgressionManager")
	for nid: String in _map_nodes:
		var map_node: MapNodeClass = _map_nodes[nid]
		map_node.set_state(pm.get_node_state(nid))
	# 연결선 색상 갱신
	_refresh_connection_colors()

## 연결선 색상을 노드 상태에 따라 갱신한다.
func _refresh_connection_colors() -> void:
	var pm: Node = get_node("/root/ProgressionManager")
	for child: Node in _connections_layer.get_children():
		if child is Line2D:
			var line: Line2D = child
			# 라인 이름에서 노드 ID 추출: "Line_nodeA-nodeB"
			var parts: PackedStringArray = line.name.substr(5).split("-", true, 1)
			if parts.size() == 2:
				var a_state: String = pm.get_node_state(parts[0])
				var b_state: String = pm.get_node_state(parts[1])
				if a_state != "locked" and b_state != "locked":
					line.default_color = LINE_COLOR_ACTIVE
				else:
					line.default_color = LINE_COLOR_DEFAULT

## 노드 해금 시 상태를 갱신하고 연출을 수행한다.
## @param node_id 해금된 노드 ID
func _on_node_unlocked(node_id: String) -> void:
	if _map_nodes.has(node_id):
		_map_nodes[node_id].set_state("available")
		_refresh_connection_colors()

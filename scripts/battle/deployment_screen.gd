## @fileoverview 전투 전 배치 화면. 파티 캐릭터를 배치 가능 셀에 드래그&드롭/클릭으로 배치한다.
class_name DeploymentScreen
extends CanvasLayer

# ── 상수 ──

## 최대 배치 인원 수
const MAX_DEPLOY_COUNT: int = 8

## 카엘 캐릭터 ID (고정 배치)
const KAEL_ID: String = "kael"

# ── 시그널 ──

## 배치 확정 시 발생
signal deployment_finished(deployed_units: Array)

## 배치 취소 시 발생
signal deployment_cancelled()

# ── 멤버 변수 ──

## BattleMap 참조
var _battle_map: Node2D = null

## 배치 가능 셀 좌표 배열
var _deploy_cells: Array[Vector2i] = []

## 파티 캐릭터 목록 [{id, name_ko, level, ...}]
var _party_characters: Array[Dictionary] = []

## 배치된 캐릭터: {cell: Vector2i → character_data: Dictionary}
var _deployed: Dictionary = {}

## 현재 선택 중인 캐릭터 데이터
var _selected_character: Dictionary = {}

## 배치 제한 인원
var _deploy_limit: int = MAX_DEPLOY_COUNT

## UI 노드 참조
var _character_list: VBoxContainer = null
var _start_button: Button = null
var _info_label: Label = null
var _panel: Panel = null

# ── 초기화 ──

## 배치 화면 초기화
## @param battle_map BattleMap 노드 참조
## @param deploy_cells 배치 가능 셀 좌표 배열
## @param party 파티 캐릭터 데이터 배열
## @param deploy_limit 배치 제한 인원 (맵 데이터의 deploy_count)
func setup(battle_map: Node2D, deploy_cells: Array[Vector2i], party: Array[Dictionary], deploy_limit: int = MAX_DEPLOY_COUNT) -> void:
	_battle_map = battle_map
	_deploy_cells = deploy_cells
	_party_characters = party
	_deploy_limit = mini(deploy_limit, MAX_DEPLOY_COUNT)
	_deployed.clear()
	_selected_character = {}

	_build_ui()

	# 배치 가능 셀 하이라이트
	if _battle_map and _battle_map.has_method("show_deploy_range"):
		_battle_map.show_deploy_range(deploy_cells)

	# 카엘 자동 배치 (첫 번째 배치 셀에)
	_auto_deploy_kael()

	# 셀 클릭 시그널 연결
	if _battle_map and _battle_map.has_signal("cell_clicked"):
		if not _battle_map.cell_clicked.is_connected(_on_cell_clicked):
			_battle_map.cell_clicked.connect(_on_cell_clicked)
	if _battle_map and _battle_map.has_signal("unit_clicked"):
		if not _battle_map.unit_clicked.is_connected(_on_unit_clicked):
			_battle_map.unit_clicked.connect(_on_unit_clicked)

	_update_ui()

## GUI 라우팅 우회: _input에서 직접 rect 비교로 버튼 클릭 처리
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT: return
	var pos := mb.position

	# 패널 영역 외 클릭은 무시
	if _panel == null or not _panel.get_global_rect().has_point(pos): return

	# 전투 시작 버튼 수동 클릭 감지
	if _start_button and not _start_button.disabled:
		if _start_button.get_global_rect().has_point(pos):
			_on_start_pressed()
			get_viewport().set_input_as_handled()
			return

	# 캐릭터 버튼 수동 클릭 감지
	if _character_list == null: return
	for char_data: Dictionary in _party_characters:
		var char_id: String = char_data.get("id", "")
		var btn_name := "Char_" + char_id
		if not _character_list.has_node(btn_name): continue
		var btn := _character_list.get_node(btn_name) as Button
		if btn == null or btn.disabled: continue
		if btn.get_global_rect().has_point(pos):
			_on_character_button_pressed(char_data)
			get_viewport().set_input_as_handled()
			return

## UI 구성
func _build_ui() -> void:
	layer = 10

	var vp_size: Vector2 = get_viewport().get_visible_rect().size

	# 왼쪽 패널 (캐릭터 목록)
	_panel = Panel.new()
	_panel.name = "DeployPanel"
	_panel.position = Vector2(0, 0)
	_panel.size = Vector2(280, vp_size.y)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# 타이틀
	var title := Label.new()
	title.text = "유닛 배치"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 정보 라벨
	_info_label = Label.new()
	_info_label.text = "배치: 0/%d" % _deploy_limit
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_info_label)

	var separator := HSeparator.new()
	vbox.add_child(separator)

	# 스크롤 가능한 캐릭터 목록
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 400)
	vbox.add_child(scroll)

	_character_list = VBoxContainer.new()
	_character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_character_list)

	# 전투 시작 버튼
	_start_button = Button.new()
	_start_button.text = "전투 시작"
	_start_button.custom_minimum_size = Vector2(0, 50)
	_start_button.pressed.connect(_on_start_pressed)
	vbox.add_child(_start_button)

	# 캐릭터 버튼 생성
	_populate_character_list()

## 캐릭터 목록 버튼 생성
func _populate_character_list() -> void:
	for child: Node in _character_list.get_children():
		child.queue_free()

	var dm: Node = get_node("/root/DataManager")
	for char_data: Dictionary in _party_characters:
		var char_id: String = char_data.get("id", "")
		# 파티 데이터에 name_ko가 없으면 DataManager에서 풀 데이터 조회
		var display_name: String = char_data.get("name_ko", "")
		if display_name.is_empty() and dm and dm.has_method("get_character"):
			var full: Dictionary = dm.get_character(char_id)
			display_name = full.get("name_ko", "???")
		if display_name.is_empty():
			display_name = "???"
		var btn := Button.new()
		btn.text = "%s (Lv.%d)" % [display_name, char_data.get("level", 1)]
		btn.custom_minimum_size = Vector2(0, 40)
		btn.toggle_mode = true
		btn.pressed.connect(_on_character_button_pressed.bind(char_data))
		btn.name = "Char_" + char_id
		_character_list.add_child(btn)

# ── 카엘 자동 배치 ──

## 카엘을 첫 번째 배치 셀에 자동 배치
func _auto_deploy_kael() -> void:
	if _deploy_cells.is_empty():
		return

	# 파티에서 카엘 찾기
	var kael_data: Dictionary = {}
	for char_data: Dictionary in _party_characters:
		if char_data.get("id", "") == KAEL_ID:
			kael_data = char_data
			break

	if kael_data.is_empty():
		return

	# 첫 번째 빈 배치 셀에 배치
	for cell: Vector2i in _deploy_cells:
		if not _deployed.has(cell):
			_place_unit(kael_data, cell)
			break

# ── 배치 조작 ──

## 유닛을 셀에 배치
## @param char_data 캐릭터 데이터
## @param cell 배치할 셀 좌표
func _place_unit(char_data: Dictionary, cell: Vector2i) -> void:
	# 이미 배치된 캐릭터인지 확인 → 기존 위치에서 제거
	var char_id: String = char_data.get("id", "")
	for existing_cell: Vector2i in _deployed.keys():
		var existing_data: Dictionary = _deployed[existing_cell]
		if existing_data.get("id", "") == char_id:
			_remove_unit_at(existing_cell)
			break

	# 해당 셀에 이미 다른 유닛이 있으면 제거
	if _deployed.has(cell):
		_remove_unit_at(cell)

	# 배치
	_deployed[cell] = char_data

	# BattleMap에 유닛 스폰
	if _battle_map and _battle_map.has_method("spawn_unit"):
		var dm: Node = _battle_map.get_node("/root/DataManager")
		var full_data: Dictionary = dm.get_character(char_id)
		if full_data.is_empty():
			full_data = char_data
		var unit_level: int = char_data.get("level", 1)
		_battle_map.spawn_unit(full_data, cell, "player", char_id, unit_level)

	_selected_character = {}
	_update_ui()

## 셀의 유닛 제거
## @param cell 셀 좌표
func _remove_unit_at(cell: Vector2i) -> void:
	if not _deployed.has(cell):
		return

	var char_data: Dictionary = _deployed[cell]
	var char_id: String = char_data.get("id", "")

	# 카엘은 제거 불가
	if char_id == KAEL_ID:
		return

	_deployed.erase(cell)

	# BattleMap에서 유닛 제거
	if _battle_map and _battle_map.has_method("remove_unit"):
		_battle_map.remove_unit(cell)

	_update_ui()

# ── 이벤트 핸들러 ──

## 캐릭터 버튼 클릭
## @param char_data 클릭된 캐릭터 데이터
func _on_character_button_pressed(char_data: Dictionary) -> void:
	var char_id: String = char_data.get("id", "")

	# 이미 배치된 캐릭터 선택 시 → 해당 유닛으로 카메라 이동 (또는 제거 모드)
	for cell: Vector2i in _deployed.keys():
		var d: Dictionary = _deployed[cell]
		if d.get("id", "") == char_id:
			# 이미 배치됨 — 선택 상태 해제
			_selected_character = {}
			_update_ui()
			return

	# 배치 제한 확인
	if _deployed.size() >= _deploy_limit:
		return

	_selected_character = char_data
	_update_ui()

## 빈 셀 클릭 (배치 셀에 캐릭터 배치)
## @param cell 클릭된 셀
func _on_cell_clicked(cell: Vector2i) -> void:
	# 배치 가능 셀인지 확인
	if cell not in _deploy_cells:
		return

	# 선택된 캐릭터가 없으면 무시
	if _selected_character.is_empty():
		# 해당 셀에 유닛이 있으면 제거
		if _deployed.has(cell):
			_remove_unit_at(cell)
		return

	_place_unit(_selected_character, cell)

## 유닛 클릭 (배치된 유닛 선택/제거)
## @param unit 클릭된 BattleUnit
func _on_unit_clicked(unit: BattleUnit) -> void:
	if unit.team != "player":
		return
	# 플레이어 유닛 클릭 → 제거 (카엘 제외)
	if unit.unit_id != KAEL_ID:
		_remove_unit_at(unit.cell)

## 전투 시작 버튼 클릭
func _on_start_pressed() -> void:
	# 최소 1명 배치 필요 (카엘은 자동이므로 항상 1명 이상)
	if _deployed.is_empty():
		return

	# 하이라이트 해제
	if _battle_map and _battle_map.has_method("clear_highlights"):
		_battle_map.clear_highlights()

	# 시그널 연결 해제
	if _battle_map:
		if _battle_map.has_signal("cell_clicked") and _battle_map.cell_clicked.is_connected(_on_cell_clicked):
			_battle_map.cell_clicked.disconnect(_on_cell_clicked)
		if _battle_map.has_signal("unit_clicked") and _battle_map.unit_clicked.is_connected(_on_unit_clicked):
			_battle_map.unit_clicked.disconnect(_on_unit_clicked)

	# 배치 결과 구성
	var result: Array = []
	for cell: Vector2i in _deployed:
		result.append({"cell": cell, "character": _deployed[cell]})

	deployment_finished.emit(result)

	# UI 정리
	queue_free()

# ── UI 갱신 ──

## UI 상태 갱신
func _update_ui() -> void:
	# 배치 카운트 갱신
	if _info_label:
		_info_label.text = "배치: %d/%d" % [_deployed.size(), _deploy_limit]

	# 시작 버튼 활성화 조건
	if _start_button:
		_start_button.disabled = _deployed.is_empty()

	# 캐릭터 버튼 상태 갱신
	_update_character_buttons()

## 캐릭터 버튼 상태 갱신 (배치됨/선택됨/사용가능)
func _update_character_buttons() -> void:
	if _character_list == null:
		return

	var dm: Node = get_node("/root/DataManager")
	for i: int in range(_party_characters.size()):
		var char_data: Dictionary = _party_characters[i]
		var char_id: String = char_data.get("id", "")
		var btn_name := "Char_" + char_id
		if not _character_list.has_node(btn_name):
			continue
		var btn: Button = _character_list.get_node(btn_name) as Button

		# DataManager에서 표시 이름 조회
		var display_name: String = char_data.get("name_ko", "")
		if display_name.is_empty() and dm and dm.has_method("get_character"):
			var full: Dictionary = dm.get_character(char_id)
			display_name = full.get("name_ko", "???")
		if display_name.is_empty():
			display_name = "???"

		# 배치 여부 확인
		var is_deployed := false
		for cell: Vector2i in _deployed.keys():
			var d: Dictionary = _deployed[cell]
			if d.get("id", "") == char_id:
				is_deployed = true
				break

		# 선택 여부
		var is_selected: bool = _selected_character.get("id", "") == char_id

		if is_deployed:
			btn.text = "%s (Lv.%d) [배치됨]" % [display_name, char_data.get("level", 1)]
			btn.button_pressed = true
			btn.disabled = (char_id == KAEL_ID)  # 카엘은 비활성화
		elif is_selected:
			btn.text = "%s (Lv.%d) [선택]" % [display_name, char_data.get("level", 1)]
			btn.button_pressed = true
			btn.disabled = false
		else:
			btn.text = "%s (Lv.%d)" % [display_name, char_data.get("level", 1)]
			btn.button_pressed = false
			btn.disabled = (_deployed.size() >= _deploy_limit)

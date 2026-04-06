## @fileoverview 전투 맵 매니저. 맵 로드, 유닛 관리, 하이라이트 표시, 카메라 제어를 담당한다.
extends Node2D

# ── 상수 ──

## 카메라 스크롤 속도 (픽셀/초)
const CAMERA_SCROLL_SPEED: float = 300.0

## 하이라이트 색상
const COLOR_MOVE: Color = Color(0.2, 0.4, 0.9, 0.35)       # 이동 범위 (파란색 반투명)
const COLOR_ATTACK: Color = Color(0.9, 0.2, 0.2, 0.35)      # 공격 범위 (빨간색 반투명)
const COLOR_DEPLOY: Color = Color(0.2, 0.9, 0.3, 0.35)      # 배치 가능 (초록색 반투명)
const COLOR_GRID_LINE: Color = Color(1.0, 1.0, 1.0, 0.15)   # 그리드 선

# ── 시그널 ──

## 유닛 클릭 시 발생
signal unit_clicked(unit: BattleUnit)
## 빈 셀 클릭 시 발생
signal cell_clicked(cell: Vector2i)
## 배치 완료 시 발생
signal deployment_confirmed(deployed_units: Array)

# ── 멤버 변수 ──

## 그리드 시스템
var grid: GridSystem = GridSystem.new()

## 현재 로드된 맵 데이터
var _map_data: Dictionary = {}

## 유닛 매핑: {Vector2i: BattleUnit}
var units: Dictionary = {}

## 유닛 ID → BattleUnit 매핑 (빠른 조회용)
var _units_by_id: Dictionary = {}

## 그리드 오버레이 표시 여부
var _grid_visible: bool = false

## 현재 하이라이트 중인 셀 목록 (타입별)
var _highlighted_cells: Dictionary = {
	"move": [],
	"attack": [],
	"deploy": [],
}

# ── 노드 참조 ──

## 카메라
var _camera: Camera2D = null

## 지형 레이어 (추후 TileMapLayer로 교체 예정, 현재 Node2D placeholder)
var _terrain_layer: Node2D = null

## 장식 레이어 (추후 TileMapLayer로 교체 예정, 현재 Node2D placeholder)
var _deco_layer: Node2D = null

## 하이라이트 레이어 (Node2D로 draw 기반)
var _highlight_layer: Node2D = null

## 유닛 컨테이너
var _units_container: Node2D = null

## 그리드 오버레이 (Node2D로 draw 기반)
var _grid_overlay: Node2D = null

## 전투 UI (CanvasLayer, placeholder)
var _battle_ui: CanvasLayer = null

# ── 초기화 ──

func _ready() -> void:
	_find_child_nodes()
	# 그리드 시스템에 유닛 정보 콜백 연결
	grid.set_unit_info_callback(_get_unit_info_at)

## 자식 노드 참조 취득
func _find_child_nodes() -> void:
	if has_node("Camera2D"):
		_camera = get_node("Camera2D") as Camera2D
	if has_node("TerrainLayer"):
		_terrain_layer = get_node("TerrainLayer") as Node2D
	if has_node("DecoLayer"):
		_deco_layer = get_node("DecoLayer") as Node2D
	if has_node("HighlightLayer"):
		_highlight_layer = get_node("HighlightLayer") as Node2D
	if has_node("Units"):
		_units_container = get_node("Units") as Node2D
	if has_node("GridOverlay"):
		_grid_overlay = get_node("GridOverlay") as Node2D
	if has_node("BattleUI"):
		_battle_ui = get_node("BattleUI") as CanvasLayer

func _process(delta: float) -> void:
	_handle_camera_input(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mb.global_position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_handle_mouse_hover(mm.global_position)
	elif event.is_action_pressed("toggle_grid"):
		_toggle_grid()

# ── 맵 로드 ──

## 맵 데이터를 로드하고 지형을 구성한다
## @param battle_id 전투 ID (예: "battle_01")
func load_map(battle_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	_map_data = dm.get_map(battle_id)
	if _map_data.is_empty():
		push_error("[BattleMap] 맵 데이터 없음: %s" % battle_id)
		return

	var size_data: Dictionary = _map_data.get("map_size", {})
	var map_w: int = size_data.get("width", 20)
	var map_h: int = size_data.get("height", 16)

	# 타일 데이터 구성 (terrain_layout 기반)
	# 현재 맵 JSON에는 tiles 2D 배열이 없으므로 기본 "plains"로 채운다
	# 추후 맵 에디터에서 실제 타일 배열을 포함하면 그것을 사용
	var tiles: Array = _build_tiles_array(map_w, map_h)

	grid.setup_map(tiles, Vector2i(map_w, map_h))

	# 카메라 제한 설정
	_setup_camera_limits(map_w, map_h)

	# 지형 시각화 (ColorRect 기반 — 타일셋이 없는 동안 placeholder)
	_render_terrain(tiles, map_w, map_h)

	# 적 유닛 배치
	_spawn_enemies()

	print("[BattleMap] 맵 로드 완료: %s (%dx%d)" % [battle_id, map_w, map_h])

## 타일 2D 배열 구성. 맵 데이터에 tiles가 있으면 사용, 없으면 기본값 생성
## @param w 맵 너비
## @param h 맵 높이
## @returns tiles[y][x] = terrain_type 형태의 2D 배열
func _build_tiles_array(w: int, h: int) -> Array:
	# 맵 데이터에 tiles 필드가 있으면 직접 사용
	if _map_data.has("tiles"):
		return _map_data["tiles"]

	# 없으면 기본 plains로 채움
	var tiles: Array = []
	for y: int in range(h):
		var row: Array = []
		for x: int in range(w):
			row.append("plains")
		tiles.append(row)
	return tiles

## 카메라 제한 설정
## @param map_w 맵 너비 (타일 단위)
## @param map_h 맵 높이 (타일 단위)
func _setup_camera_limits(map_w: int, map_h: int) -> void:
	if _camera == null:
		return
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map_w * GridSystem.TILE_SIZE
	_camera.limit_bottom = map_h * GridSystem.TILE_SIZE
	# 카메라 초기 위치: 맵 중앙
	_camera.position = Vector2(
		map_w * GridSystem.TILE_SIZE / 2.0,
		map_h * GridSystem.TILE_SIZE / 2.0
	)

## 지형 렌더링 (placeholder — 타일셋 없는 동안 ColorRect로 표시)
## @param tiles 타일 2D 배열
## @param w 너비
## @param h 높이
func _render_terrain(tiles: Array, w: int, h: int) -> void:
	# 기존 지형 시각화 정리
	if _terrain_layer:
		for child: Node in _terrain_layer.get_children():
			child.queue_free()

	# 타일셋이 아직 없으므로 ColorRect placeholder로 각 셀 표시
	var terrain_node: Node2D = _terrain_layer if _terrain_layer else self
	for y: int in range(h):
		for x: int in range(w):
			var terrain_type: String = tiles[y][x] if y < tiles.size() and x < tiles[y].size() else "plains"
			var rect := ColorRect.new()
			rect.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
			rect.position = Vector2(x * GridSystem.TILE_SIZE, y * GridSystem.TILE_SIZE)
			rect.color = _get_terrain_color(terrain_type)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			terrain_node.add_child(rect)

## 지형 타입별 placeholder 색상 반환
## @param terrain_type 지형 타입
## @returns 색상
func _get_terrain_color(terrain_type: String) -> Color:
	match terrain_type:
		"plains":       return Color(0.45, 0.65, 0.30)
		"forest":       return Color(0.20, 0.45, 0.15)
		"mountain":     return Color(0.55, 0.50, 0.45)
		"shallow_water":return Color(0.30, 0.55, 0.80)
		"deep_water":   return Color(0.15, 0.30, 0.65)
		"bridge":       return Color(0.55, 0.45, 0.30)
		"road":         return Color(0.60, 0.55, 0.45)
		"ruins":        return Color(0.50, 0.50, 0.45)
		"sand":         return Color(0.80, 0.75, 0.55)
		"lava":         return Color(0.85, 0.25, 0.10)
		"barrier_stone":return Color(0.50, 0.60, 0.70)
		"ashen_land":   return Color(0.40, 0.38, 0.35)
		"wall":         return Color(0.35, 0.35, 0.35)
		"fortress":     return Color(0.55, 0.55, 0.60)
		"village":      return Color(0.60, 0.50, 0.35)
		"throne":       return Color(0.70, 0.55, 0.25)
		_:              return Color(0.45, 0.65, 0.30)

# ── 적 유닛 배치 ──

## 맵 데이터의 enemy_placements를 기반으로 적 유닛 스폰
func _spawn_enemies() -> void:
	var dm: Node = get_node("/root/DataManager")
	var placements: Array = _map_data.get("enemy_placements", [])

	for i: int in range(placements.size()):
		var placement: Dictionary = placements[i]
		var enemy_id: String = placement.get("enemy_id", "")
		var enemy_level: int = placement.get("level", 1)
		var pos: Array = placement.get("position", [0, 0])
		var spawn_cell := Vector2i(pos[0] as int, pos[1] as int)

		var enemy_data: Dictionary = dm.get_enemy(enemy_id)
		if enemy_data.is_empty():
			push_warning("[BattleMap] 적 데이터 없음: %s" % enemy_id)
			continue

		# 고유 유닛 ID 생성 (같은 적 다수 배치 지원)
		var uid: String = "%s_%d" % [enemy_id, i]
		spawn_unit(enemy_data, spawn_cell, "enemy", uid, enemy_level)

# ── 유닛 관리 ──

## 유닛을 스폰한다
## @param unit_data 캐릭터 또는 적 데이터 Dictionary
## @param spawn_cell 배치할 셀 좌표
## @param unit_team 팀 ("player" 또는 "enemy")
## @param uid 고유 유닛 ID (없으면 데이터의 id 사용)
## @param unit_level 유닛 레벨
## @returns 생성된 BattleUnit
func spawn_unit(unit_data: Dictionary, spawn_cell: Vector2i, unit_team: String, uid: String = "", unit_level: int = 1) -> BattleUnit:
	var unit := _create_battle_unit_instance()
	if uid.is_empty():
		uid = unit_data.get("id", "unit_%d" % units.size())
	unit.unit_id = uid

	if unit_team == "player":
		unit.init_from_character(unit_data, unit_level)
	else:
		unit.init_from_enemy(unit_data, unit_level)

	unit.cell = spawn_cell
	unit.position = GridSystem.cell_to_world(spawn_cell)

	if _units_container:
		_units_container.add_child(unit)
	else:
		add_child(unit)

	units[spawn_cell] = unit
	_units_by_id[uid] = unit

	return unit

## BattleUnit 인스턴스 생성. 씬 파일이 있으면 인스턴스, 없으면 코드로 구성
## @returns BattleUnit 노드
func _create_battle_unit_instance() -> BattleUnit:
	var scene_path := "res://scenes/battle/battle_unit.tscn"
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		return scene.instantiate() as BattleUnit
	else:
		# 씬 파일 없이 코드로 구성 (fallback)
		return _build_battle_unit_manually()

## BattleUnit을 코드로 수동 구성 (씬 파일 없을 때 fallback)
## @returns 구성된 BattleUnit
func _build_battle_unit_manually() -> BattleUnit:
	var unit := BattleUnit.new()

	# AnimatedSprite2D (placeholder)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	unit.add_child(sprite)

	# HP바
	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(28, 4)
	health_bar.position = Vector2(-14, -20)
	health_bar.size = Vector2(28, 4)
	health_bar.show_percentage = false
	unit.add_child(health_bar)

	# 상태이상 아이콘 컨테이너
	var status_icons := HBoxContainer.new()
	status_icons.name = "StatusIcons"
	status_icons.position = Vector2(-14, -28)
	unit.add_child(status_icons)

	# 선택 표시
	var selection := Sprite2D.new()
	selection.name = "SelectionIndicator"
	selection.visible = false
	unit.add_child(selection)

	return unit

## 지정 셀의 유닛 조회
## @param cell 셀 좌표
## @returns BattleUnit 또는 null
func get_unit_at(cell: Vector2i) -> BattleUnit:
	return units.get(cell, null)

## ID로 유닛 조회
## @param uid 유닛 ID
## @returns BattleUnit 또는 null
func get_unit_by_id(uid: String) -> BattleUnit:
	return _units_by_id.get(uid, null)

## 셀에 유닛이 있는지 확인
## @param cell 셀 좌표
## @returns 점유되어 있으면 true
func is_cell_occupied(cell: Vector2i) -> bool:
	return units.has(cell)

## 유닛 제거
## @param cell 셀 좌표
func remove_unit(cell: Vector2i) -> void:
	if units.has(cell):
		var unit: BattleUnit = units[cell]
		_units_by_id.erase(unit.unit_id)
		units.erase(cell)
		unit.queue_free()

## 유닛 이동 (셀 매핑 갱신)
## @param from_cell 이전 셀
## @param to_cell 이동 후 셀
func move_unit(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not units.has(from_cell):
		return
	var unit: BattleUnit = units[from_cell]
	units.erase(from_cell)
	units[to_cell] = unit

## 유닛 정보 콜백 (GridSystem에서 사용)
## @param cell 셀 좌표
## @returns {team: String} 또는 null
func _get_unit_info_at(cell: Vector2i) -> Variant:
	if units.has(cell):
		var unit: BattleUnit = units[cell]
		return {"team": unit.team}
	return null

# ── 하이라이트 표시 ──

## 이동 범위 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_movement_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["move"] = cells
	_redraw_highlights()

## 공격 범위 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_attack_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["attack"] = cells
	_redraw_highlights()

## 배치 가능 셀 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_deploy_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["deploy"] = cells
	_redraw_highlights()

## 모든 하이라이트 제거
func clear_highlights() -> void:
	_highlighted_cells["move"] = []
	_highlighted_cells["attack"] = []
	_highlighted_cells["deploy"] = []
	_redraw_highlights()

## 하이라이트 레이어 다시 그리기
func _redraw_highlights() -> void:
	if _highlight_layer == null:
		return
	# 기존 하이라이트 제거
	for child: Node in _highlight_layer.get_children():
		child.queue_free()

	# 이동 범위
	var move_cells: Array = _highlighted_cells.get("move", [])
	for cell_pos: Vector2i in move_cells:
		_add_highlight_rect(cell_pos, COLOR_MOVE)

	# 공격 범위
	var atk_cells: Array = _highlighted_cells.get("attack", [])
	for cell_pos: Vector2i in atk_cells:
		_add_highlight_rect(cell_pos, COLOR_ATTACK)

	# 배치 가능
	var dep_cells: Array = _highlighted_cells.get("deploy", [])
	for cell_pos: Vector2i in dep_cells:
		_add_highlight_rect(cell_pos, COLOR_DEPLOY)

## 하이라이트 셀 ColorRect 추가
## @param cell_pos 셀 좌표
## @param color 하이라이트 색상
func _add_highlight_rect(cell_pos: Vector2i, color: Color) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
	rect.position = Vector2(cell_pos.x * GridSystem.TILE_SIZE, cell_pos.y * GridSystem.TILE_SIZE)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_layer.add_child(rect)

# ── 그리드 오버레이 ──

## 그리드 표시 토글 (G키)
func _toggle_grid() -> void:
	_grid_visible = not _grid_visible
	if _grid_overlay:
		_grid_overlay.visible = _grid_visible
		if _grid_visible:
			_draw_grid_lines()
		else:
			for child: Node in _grid_overlay.get_children():
				child.queue_free()

## 그리드 선 그리기
func _draw_grid_lines() -> void:
	if _grid_overlay == null:
		return
	# 기존 선 제거
	for child: Node in _grid_overlay.get_children():
		child.queue_free()

	var ts: int = GridSystem.TILE_SIZE
	var w: int = grid.map_size.x * ts
	var h: int = grid.map_size.y * ts

	# 수직선
	for x: int in range(0, grid.map_size.x + 1):
		var line := _create_line(Vector2(x * ts, 0), Vector2(x * ts, h))
		_grid_overlay.add_child(line)

	# 수평선
	for y: int in range(0, grid.map_size.y + 1):
		var line := _create_line(Vector2(0, y * ts), Vector2(w, y * ts))
		_grid_overlay.add_child(line)

## Line2D 노드 생성
## @param from_pos 시작 좌표
## @param to_pos 끝 좌표
## @returns Line2D 노드
func _create_line(from_pos: Vector2, to_pos: Vector2) -> Line2D:
	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 1.0
	line.default_color = COLOR_GRID_LINE
	return line

# ── 카메라 제어 ──

## 카메라 입력 처리 (WASD / 방향키)
## @param delta 프레임 시간
func _handle_camera_input(delta: float) -> void:
	if _camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("camera_up"):
		direction.y -= 1
	if Input.is_action_pressed("camera_down"):
		direction.y += 1
	if Input.is_action_pressed("camera_left"):
		direction.x -= 1
	if Input.is_action_pressed("camera_right"):
		direction.x += 1

	if direction != Vector2.ZERO:
		_camera.position += direction.normalized() * CAMERA_SCROLL_SPEED * delta

# ── 입력 처리 ──

## 좌클릭 처리
## @param screen_pos 화면 좌표
func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var clicked_cell := GridSystem.world_to_cell(world_pos)

	if not grid.is_within_bounds(clicked_cell):
		return

	# 유닛이 있는 셀 클릭
	if units.has(clicked_cell):
		unit_clicked.emit(units[clicked_cell])
		EventBus.unit_selected.emit(units[clicked_cell].unit_id)
	else:
		cell_clicked.emit(clicked_cell)

## 마우스 호버 처리
## @param screen_pos 화면 좌표
func _handle_mouse_hover(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var hovered_cell := GridSystem.world_to_cell(world_pos)

	if grid.is_within_bounds(hovered_cell):
		EventBus.cell_hovered.emit(hovered_cell)

## 화면 좌표 → 월드 좌표 변환 (카메라 고려)
## @param screen_pos 화면 좌표
## @returns 월드 좌표
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if _camera:
		var viewport := get_viewport()
		if viewport:
			return get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos

# ── 유틸리티 ──

## 팀별 유닛 목록 조회
## @param team_name 팀 이름
## @returns BattleUnit 배열
func get_units_by_team(team_name: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit: BattleUnit in units.values():
		if unit.team == team_name:
			result.append(unit)
	return result

## 모든 유닛의 턴 리셋
## @param team_name 리셋할 팀 (빈 문자열이면 전체)
func reset_units_turn(team_name: String = "") -> void:
	for unit: BattleUnit in units.values():
		if team_name.is_empty() or unit.team == team_name:
			unit.reset_turn()
			unit.clear_acted_visual()

## 전투 종료 판정 (한쪽이 전멸했는지)
## @returns "player_win" / "enemy_win" / "" (진행 중)
func check_battle_end() -> String:
	var player_alive := false
	var enemy_alive := false
	for unit: BattleUnit in units.values():
		if unit.is_alive():
			if unit.team == "player":
				player_alive = true
			elif unit.team == "enemy":
				enemy_alive = true
	if not enemy_alive:
		return "player_win"
	if not player_alive:
		return "enemy_win"
	return ""

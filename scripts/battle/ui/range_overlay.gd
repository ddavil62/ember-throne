## @fileoverview 범위 오버레이 & 경로 화살표. 이동/공격/스킬 범위 하이라이트와
## 마우스 호버 시 실시간 이동 경로 화살표를 표시한다. BattleMap의 기존
## 하이라이트 시스템을 보완한다.
class_name RangeOverlay
extends Node2D

# ── 상수 ──

## 오버레이 색상
const COLOR_MOVE := Color(0.2, 0.4, 0.9, 0.35)
const COLOR_ATTACK := Color(0.9, 0.2, 0.2, 0.35)
const COLOR_SKILL := Color(0.2, 0.9, 0.3, 0.35)
const COLOR_SKILL_AREA := Color(0.2, 0.9, 0.3, 0.55)
const COLOR_PATH := Color(1.0, 1.0, 0.2, 0.6)
const COLOR_PATH_ARROW := Color(1.0, 1.0, 0.2, 0.8)
const COLOR_DESTINATION := Color(1.0, 1.0, 0.2, 0.9)
const COLOR_DANGER := Color(0.9, 0.15, 0.15, 0.25)

## 화살표 크기 비율 (타일 대비)
const ARROW_SIZE_RATIO: float = 0.4

## 도착 마커 크기 비율
const DEST_MARKER_RATIO: float = 0.3

# ── 멤버 변수 ──

## 현재 이동 경로 셀 배열
var _current_path: Array[Vector2i] = []

## 현재 스킬 범위 셀 배열
var _skill_range_cells: Array[Vector2i] = []

## 현재 스킬 효과 범위 셀 배열
var _skill_area_cells: Array[Vector2i] = []

## 경로 표시 노드 컨테이너
var _path_container: Node2D = null

## 스킬 범위 표시 노드 컨테이너
var _skill_container: Node2D = null

## 스킬 효과 범위 표시 노드 컨테이너
var _skill_area_container: Node2D = null

## 위험 범위 표시 노드 컨테이너
var _danger_container: Node2D = null

## 위험 범위 표시 상태
var _danger_visible: bool = false

## 위험 범위 셀 목록
var _danger_cells: Array[Vector2i] = []

# ── 초기화 ──

func _ready() -> void:
	_path_container = Node2D.new()
	_path_container.name = "PathContainer"
	add_child(_path_container)

	_skill_container = Node2D.new()
	_skill_container.name = "SkillRangeContainer"
	add_child(_skill_container)

	_skill_area_container = Node2D.new()
	_skill_area_container.name = "SkillAreaContainer"
	add_child(_skill_area_container)

	_danger_container = Node2D.new()
	_danger_container.name = "DangerZoneContainer"
	add_child(_danger_container)

# ── 이동 경로 표시 ──

## 이동 경로를 표시한다 (마우스 호버 시 실시간 갱신).
## @param path 경로 셀 배열 (시작 셀 포함)
func show_move_path(path: Array[Vector2i]) -> void:
	# 경로가 같으면 다시 그리지 않음
	if _paths_equal(path, _current_path):
		return

	clear_path()
	_current_path = path.duplicate()

	if path.size() < 2:
		return

	# 경로 셀 하이라이트 + 화살표 방향
	for i: int in range(path.size()):
		var cell: Vector2i = path[i]
		var world_pos: Vector2 = GridSystem.cell_to_world(cell)

		if i == path.size() - 1:
			# 마지막 셀: 도착 마커
			_draw_destination_marker(world_pos)
		else:
			# 경로 셀: 방향 화살표
			var next_cell: Vector2i = path[i + 1]
			_draw_path_cell(world_pos)
			_draw_arrow(world_pos, cell, next_cell)

## 이동 경로 표시를 제거한다.
func clear_path() -> void:
	_current_path.clear()
	if _path_container:
		for child: Node in _path_container.get_children():
			child.queue_free()

# ── 스킬 범위 표시 ──

## 스킬 사용 가능 범위를 하이라이트한다.
## @param cells 스킬 범위 셀 배열
func show_skill_range(cells: Array[Vector2i]) -> void:
	clear_skill_range()
	_skill_range_cells = cells.duplicate()

	for cell: Vector2i in cells:
		var world_pos: Vector2 = GridSystem.cell_to_world(cell)
		_draw_range_cell(world_pos, COLOR_SKILL, _skill_container)

## 스킬 효과 범위를 하이라이트한다 (더 진한 초록).
## @param cells 스킬 효과 범위 셀 배열
func show_skill_area(cells: Array[Vector2i]) -> void:
	clear_skill_area()
	_skill_area_cells = cells.duplicate()

	for cell: Vector2i in cells:
		var world_pos: Vector2 = GridSystem.cell_to_world(cell)
		_draw_range_cell(world_pos, COLOR_SKILL_AREA, _skill_area_container)

## 스킬 범위 하이라이트를 제거한다.
func clear_skill_range() -> void:
	_skill_range_cells.clear()
	if _skill_container:
		for child: Node in _skill_container.get_children():
			child.queue_free()

## 스킬 효과 범위 하이라이트를 제거한다.
func clear_skill_area() -> void:
	_skill_area_cells.clear()
	if _skill_area_container:
		for child: Node in _skill_area_container.get_children():
			child.queue_free()

## 모든 오버레이를 제거한다.
func clear_all() -> void:
	clear_path()
	clear_skill_range()
	clear_skill_area()
	clear_danger_zone()

# ── 적 위험 범위 표시 (2-4) ──

## 적 위험 범위를 표시한다. 모든 적의 이동+공격 범위를 합산한 빨간 반투명 오버레이.
## @param cells 위험 범위 셀 배열 (외부에서 합산 후 전달)
func show_danger_zone(cells: Array[Vector2i]) -> void:
	clear_danger_zone()
	_danger_cells = cells.duplicate()
	_danger_visible = true

	for cell: Vector2i in cells:
		var world_pos: Vector2 = GridSystem.cell_to_world(cell)
		_draw_range_cell(world_pos, COLOR_DANGER, _danger_container)

## 적 위험 범위를 제거한다.
func clear_danger_zone() -> void:
	_danger_cells.clear()
	_danger_visible = false
	if _danger_container:
		for child: Node in _danger_container.get_children():
			child.queue_free()

## 위험 범위 표시 상태를 반환한다.
## @returns 표시 중이면 true
func is_danger_visible() -> bool:
	return _danger_visible

# ── 그리기 유틸 ──

## 경로 셀 배경을 그린다 (노란색 반투명).
## @param center 셀 중앙 월드 좌표
func _draw_path_cell(center: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = COLOR_PATH
	rect.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
	rect.position = center - Vector2(GridSystem.TILE_SIZE / 2.0, GridSystem.TILE_SIZE / 2.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_path_container.add_child(rect)

## 범위 셀 배경을 그린다 (지정 색상).
## @param center 셀 중앙 월드 좌표
## @param color 하이라이트 색상
## @param container 부모 Node2D
func _draw_range_cell(center: Vector2, color: Color, container: Node2D) -> void:
	var rect := ColorRect.new()
	rect.color = color
	rect.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
	rect.position = center - Vector2(GridSystem.TILE_SIZE / 2.0, GridSystem.TILE_SIZE / 2.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(rect)

## 방향 화살표를 그린다 (Polygon2D 삼각형).
## @param center 셀 중앙 월드 좌표
## @param from_cell 현재 셀
## @param to_cell 다음 셀
func _draw_arrow(center: Vector2, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var diff: Vector2i = to_cell - from_cell
	var arrow_size: float = GridSystem.TILE_SIZE * ARROW_SIZE_RATIO
	var half: float = arrow_size / 2.0

	# 방향별 삼각형 꼭짓점 (중앙 기준)
	var points: PackedVector2Array = PackedVector2Array()

	if diff.x == 1 and diff.y == 0:
		# 오른쪽
		points.append(Vector2(half, 0))
		points.append(Vector2(-half, -half))
		points.append(Vector2(-half, half))
	elif diff.x == -1 and diff.y == 0:
		# 왼쪽
		points.append(Vector2(-half, 0))
		points.append(Vector2(half, -half))
		points.append(Vector2(half, half))
	elif diff.x == 0 and diff.y == 1:
		# 아래
		points.append(Vector2(0, half))
		points.append(Vector2(-half, -half))
		points.append(Vector2(half, -half))
	elif diff.x == 0 and diff.y == -1:
		# 위
		points.append(Vector2(0, -half))
		points.append(Vector2(-half, half))
		points.append(Vector2(half, half))
	else:
		return  # 대각선은 4방향 그리드에서 미지원

	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = COLOR_PATH_ARROW
	polygon.position = center
	_path_container.add_child(polygon)

## 도착 마커를 그린다 (다이아몬드 모양).
## @param center 셀 중앙 월드 좌표
func _draw_destination_marker(center: Vector2) -> void:
	# 배경 셀
	_draw_path_cell(center)

	# 다이아몬드 마커
	var size: float = GridSystem.TILE_SIZE * DEST_MARKER_RATIO
	var points := PackedVector2Array()
	points.append(Vector2(0, -size))      # 상
	points.append(Vector2(size, 0))       # 우
	points.append(Vector2(0, size))       # 하
	points.append(Vector2(-size, 0))      # 좌

	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = COLOR_DESTINATION
	polygon.position = center
	_path_container.add_child(polygon)

	# 외곽선 (Line2D)
	var outline := Line2D.new()
	for point: Vector2 in points:
		outline.add_point(point)
	outline.add_point(points[0])  # 닫기
	outline.width = 1.5
	outline.default_color = Color(1.0, 1.0, 1.0, 0.9)
	outline.position = center
	_path_container.add_child(outline)

# ── 내부 유틸 ──

## 두 경로가 동일한지 비교한다.
## @param a 경로 A
## @param b 경로 B
## @returns 동일하면 true
func _paths_equal(a: Array[Vector2i], b: Array[Vector2i]) -> bool:
	if a.size() != b.size():
		return false
	for i: int in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

## @fileoverview 그리드 핵심 로직. 셀/월드 좌표 변환, BFS 이동 범위, A* 경로 탐색을 담당한다.
class_name GridSystem
extends RefCounted

# ── 상수 ──

## 타일 크기 (픽셀)
const TILE_SIZE: int = 32

## 8방향 이름 배열 (atan2 기반 인덱스 매핑용)
const DIRECTIONS: Array[String] = [
	"south", "south_west", "west", "north_west",
	"north", "north_east", "east", "south_east"
]

## BFS/A*용 4방향 이웃 오프셋
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(0, -1),  # 상
	Vector2i(0, 1),   # 하
	Vector2i(-1, 0),  # 좌
	Vector2i(1, 0),   # 우
]

# ── 멤버 변수 ──

## 맵 크기 (타일 단위)
var map_size: Vector2i = Vector2i.ZERO

## 유닛 점유 정보 조회 콜백 — BattleMap에서 주입
## (cell: Vector2i) -> Dictionary|null  {team: String} 또는 null
var _get_unit_info_callback: Callable = Callable()

# ── 좌표 변환 ──

## 셀 좌표 → 월드 좌표 (셀 중앙 지점)
## @param cell 그리드 좌표
## @returns 월드 좌표 (셀 중앙)
static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * TILE_SIZE + TILE_SIZE / 2, cell.y * TILE_SIZE + TILE_SIZE / 2)

## 월드 좌표 → 셀 좌표
## @param world_pos 월드 좌표
## @returns 그리드 좌표
static func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(world_pos.x) / TILE_SIZE, int(world_pos.y) / TILE_SIZE)

## 셀 좌표가 맵 범위 안인지 확인
## @param cell 확인할 셀 좌표
## @returns 범위 안이면 true
func is_within_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < map_size.x and cell.y >= 0 and cell.y < map_size.y

## 두 셀 사이의 방향 계산 (8방향)
## @param from 출발 셀
## @param to 대상 셀
## @returns 방향 문자열 ("south", "north_east" 등)
static func get_direction(from: Vector2i, to: Vector2i) -> String:
	var diff := Vector2(to - from)
	if diff == Vector2.ZERO:
		return "south"
	var angle := atan2(diff.y, diff.x)
	# atan2: 오른쪽=0, 아래=PI/2, 왼쪽=PI/-PI, 위=-PI/2
	# 45도 간격으로 양자화, 인덱스 매핑:
	# east=0, south_east=1, south=2, south_west=3, west=4, north_west=5, north=6, north_east=7
	var index := int(round(angle / (PI / 4.0)))
	if index < 0:
		index += 8
	# 내부 배열 순서와 매핑: east(0)→6, se(1)→7, s(2)→0, sw(3)→1, w(4)→2, nw(5)→3, n(6)→4, ne(7)→5
	var remap: Array[int] = [6, 7, 0, 1, 2, 3, 4, 5]
	return DIRECTIONS[remap[index % 8]]

# ── 지형 조회 ──

## 지정 셀의 지형 타입 조회
## @param cell 셀 좌표
## @returns 지형 타입 문자열 (예: "plains", "forest"). 범위 밖이면 빈 문자열
func get_tile_at(cell: Vector2i) -> String:
	if not is_within_bounds(cell):
		return ""
	return _get_tile_type_at(cell)

## 타일 타입 조회 (내부). BattleMap에서 tiles 2D 배열을 주입받음
var _tiles: Array = []

## 내부 타일 타입 조회
## @param cell 셀 좌표
## @returns 지형 타입 문자열
func _get_tile_type_at(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= _tiles.size():
		return ""
	var row: Variant = _tiles[cell.y]
	if row is Array:
		if cell.x < 0 or cell.x >= row.size():
			return ""
		return row[cell.x] as String
	return ""

## 지형의 이동 코스트 조회
## @param terrain_type 지형 타입 문자열
## @returns 이동 코스트 (impassable이면 -1)
func _get_move_cost(terrain_type: String) -> int:
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1
	var terrain_data: Dictionary = dm.get_terrain(terrain_type)
	if terrain_data.is_empty():
		return 1
	return terrain_data.get("move_cost", 1) as int

## 지형이 통과 가능한지 확인
## @param terrain_type 지형 타입 문자열
## @returns 통과 가능하면 true
func _is_terrain_passable(terrain_type: String) -> bool:
	var cost := _get_move_cost(terrain_type)
	return cost > 0

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

# ── 콜백 설정 ──

## 유닛 정보 조회 콜백 설정. BattleMap에서 호출한다.
## @param callback (cell: Vector2i) -> Dictionary|null 형식의 Callable
func set_unit_info_callback(callback: Callable) -> void:
	_get_unit_info_callback = callback

## 타일 데이터 설정. BattleMap에서 맵 로드 시 호출한다.
## @param tiles 2D 배열 (tiles[y][x] = terrain_type)
## @param size 맵 크기 Vector2i
func setup_map(tiles: Array, size: Vector2i) -> void:
	_tiles = tiles
	map_size = size

# ── BFS 이동 범위 계산 ──

## BFS 기반 이동 범위 계산
## @param start 유닛 현재 셀 좌표
## @param mov 유닛 이동력
## @param unit_team 유닛 팀 ("player" 또는 "enemy")
## @returns 이동 가능한 셀 좌표 배열
func get_movement_range(start: Vector2i, mov: int, unit_team: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	# BFS용 비용 맵: {Vector2i: int} — 해당 셀까지의 최소 비용
	var cost_map: Dictionary = {}
	cost_map[start] = 0

	# BFS 큐: [cell, accumulated_cost]
	var queue: Array = [[start, 0]]

	while queue.size() > 0:
		var current: Array = queue.pop_front()
		var cell: Vector2i = current[0]
		var accumulated: int = current[1]

		for offset: Vector2i in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = cell + offset
			if not is_within_bounds(neighbor):
				continue

			# 지형 통과 가능 여부
			var terrain_type := _get_tile_type_at(neighbor)
			if not _is_terrain_passable(terrain_type):
				continue

			# 이동 코스트
			var move_cost := _get_move_cost(terrain_type)
			var new_cost: int = accumulated + move_cost
			if new_cost > mov:
				continue

			# 유닛 점유 확인
			if _get_unit_info_callback.is_valid():
				var unit_info: Variant = _get_unit_info_callback.call(neighbor)
				if unit_info != null and unit_info is Dictionary:
					var occupant_team: String = unit_info.get("team", "")
					if occupant_team != unit_team:
						# 적 유닛이 있는 셀은 통과 불가
						continue
					# 아군 유닛은 통과 가능 (하지만 최종 목적지로는 불가)

			# 이미 더 적은 비용으로 도달한 적이 있으면 건너뛰기
			if cost_map.has(neighbor) and cost_map[neighbor] <= new_cost:
				continue
			cost_map[neighbor] = new_cost
			queue.append([neighbor, new_cost])

	# 결과 구성: 시작 셀 제외, 아군이 점유하지 않은 셀만
	for cell: Vector2i in cost_map:
		if cell == start:
			continue
		# 아군 유닛이 있는 셀은 최종 도착지에서 제외
		if _get_unit_info_callback.is_valid():
			var unit_info: Variant = _get_unit_info_callback.call(cell)
			if unit_info != null:
				continue
		result.append(cell)

	return result

# ── 공격 범위 계산 ──

## 공격 범위 계산 (맨해튼 거리 기반)
## @param center 공격 기준 셀 좌표
## @param range_min 최소 사거리
## @param range_max 최대 사거리
## @returns 공격 가능한 셀 좌표 배열
func get_attack_range(center: Vector2i, range_min: int, range_max: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dx: int in range(-range_max, range_max + 1):
		for dy: int in range(-range_max, range_max + 1):
			var dist := absi(dx) + absi(dy)
			if dist < range_min or dist > range_max:
				continue
			var cell := center + Vector2i(dx, dy)
			if is_within_bounds(cell) and cell != center:
				result.append(cell)
	return result

# ── A* 경로 탐색 ──

## A* 경로 탐색. 시작 셀에서 목표 셀까지의 최단 경로를 반환한다.
## @param from_cell 시작 셀 좌표
## @param to_cell 목표 셀 좌표
## @param mov 유닛 이동력 (-1이면 무제한)
## @param unit_team 유닛 팀
## @returns 경로 셀 배열 (시작 셀 포함, 경로 없으면 빈 배열)
func find_path(from_cell: Vector2i, to_cell: Vector2i, mov: int, unit_team: String) -> Array[Vector2i]:
	if from_cell == to_cell:
		return [from_cell]
	if not is_within_bounds(to_cell):
		return []

	# 오픈 리스트: [[priority, cell, cost, parent_cell]]
	# 간단한 우선순위 큐 (배열 정렬 기반)
	var open_list: Array = []
	var closed_set: Dictionary = {}  # {Vector2i: true}
	var came_from: Dictionary = {}   # {Vector2i: Vector2i}
	var g_score: Dictionary = {}     # {Vector2i: int}

	g_score[from_cell] = 0
	var h := _heuristic(from_cell, to_cell)
	open_list.append([h, from_cell])

	while open_list.size() > 0:
		# 최소 우선순위 추출 (정렬 후 pop_front)
		open_list.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var current_entry: Array = open_list.pop_front()
		var current: Vector2i = current_entry[1]

		if current == to_cell:
			# 경로 역추적
			return _reconstruct_path(came_from, to_cell)

		if closed_set.has(current):
			continue
		closed_set[current] = true

		for offset: Vector2i in NEIGHBOR_OFFSETS:
			var neighbor: Vector2i = current + offset
			if not is_within_bounds(neighbor):
				continue
			if closed_set.has(neighbor):
				continue

			var terrain_type := _get_tile_type_at(neighbor)
			if not _is_terrain_passable(terrain_type):
				continue

			# 적 유닛 차단 확인 (목표 셀은 예외)
			if neighbor != to_cell and _get_unit_info_callback.is_valid():
				var unit_info: Variant = _get_unit_info_callback.call(neighbor)
				if unit_info != null and unit_info is Dictionary:
					var occupant_team: String = unit_info.get("team", "")
					if occupant_team != unit_team:
						continue

			var move_cost := _get_move_cost(terrain_type)
			var tentative_g: int = g_score[current] + move_cost

			# 이동력 제한 확인
			if mov >= 0 and tentative_g > mov:
				continue

			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				g_score[neighbor] = tentative_g
				came_from[neighbor] = current
				var f: int = tentative_g + _heuristic(neighbor, to_cell)
				open_list.append([f, neighbor])

	# 경로 없음
	return []

## A* 휴리스틱 (맨해튼 거리)
## @param a 셀 A
## @param b 셀 B
## @returns 맨해튼 거리
func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 경로 역추적
## @param came_from 부모 맵
## @param current 목표 셀
## @returns 시작 → 목표 순서의 경로 배열
func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path

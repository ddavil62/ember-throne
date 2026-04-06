## @fileoverview 스킬 데이터 조회 및 유효성 검증 시스템.
## DataManager로부터 스킬 데이터를 조회하고, 사용 가능 여부 판정, 사거리/범위 계산,
## 유효 대상 셀 산출, MP/사용횟수 소비를 담당한다.
class_name SkillSystem
extends RefCounted

# ── 멤버 변수 ──

## 스킬 사용횟수 트래킹: {"유닛ID_스킬ID": 사용한 횟수}
var _skill_uses: Dictionary = {}

# ── 스킬 데이터 조회 ──

## 스킬 ID로 스킬 데이터를 조회한다.
## @param skill_id 스킬 ID
## @returns 스킬 데이터 Dictionary (없으면 빈 Dictionary)
func get_skill(skill_id: String) -> Dictionary:
	var dm: Node = _get_data_manager()
	if dm == null:
		return {}
	return dm.get_skill(skill_id)

# ── 사용 가능 여부 판정 ──

## 유닛이 해당 스킬을 사용할 수 있는지 판정한다.
## MP 충분 여부, 사용횟수 남음 여부, 침묵 상태 여부를 확인한다.
## @param unit 사용할 유닛
## @param skill_id 스킬 ID
## @returns 사용 가능하면 true
func can_use_skill(unit: BattleUnit, skill_id: String) -> bool:
	if unit == null or not unit.is_alive():
		return false

	var skill_data: Dictionary = get_skill(skill_id)
	if skill_data.is_empty():
		return false

	# 침묵 체크 — 침묵 상태이면 스킬 사용 불가
	for effect: Dictionary in unit.status_effects:
		if effect.get("status_id", "") == "silence":
			return false

	# MP 체크
	var mp_cost: int = skill_data.get("mp_cost", 0)
	if unit.current_mp < mp_cost:
		return false

	# 사용횟수 체크 (-1이면 무제한)
	var uses_per_battle: int = skill_data.get("uses_per_battle", -1)
	if uses_per_battle > 0:
		var use_key: String = unit.unit_id + "_" + skill_id
		var used_count: int = _skill_uses.get(use_key, 0)
		if used_count >= uses_per_battle:
			return false

	return true

# ── 사거리 조회 ──

## 스킬의 사거리 정보를 반환한다.
## @param skill_id 스킬 ID
## @returns {"range_min": int, "range_max": int}
func get_skill_range(skill_id: String) -> Dictionary:
	var skill_data: Dictionary = get_skill(skill_id)
	return {
		"range_min": skill_data.get("range_min", 1),
		"range_max": skill_data.get("range_max", 1),
	}

# ── 유효 대상 셀 산출 ──

## 스킬 범위 내 유효 대상 셀 목록을 반환한다.
## 스킬의 target 유형에 따라 적/아군 필터링을 수행한다.
## @param caster 시전 유닛
## @param skill_id 스킬 ID
## @param grid GridSystem
## @param units_map {Vector2i: BattleUnit} 유닛 맵
## @returns 유효 대상 셀 좌표 배열
func get_skill_targets(caster: BattleUnit, skill_id: String, grid: GridSystem, units_map: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	var skill_data: Dictionary = get_skill(skill_id)
	if skill_data.is_empty():
		return result

	var target_type: String = skill_data.get("target", "single_enemy")
	var range_min: int = skill_data.get("range_min", 1)
	var range_max: int = skill_data.get("range_max", 1)

	# 자기 자신 대상 스킬
	if target_type == "self":
		result.append(caster.cell)
		return result

	# 아군 전체 / 적 전체
	if target_type == "all_allies":
		for cell_pos: Vector2i in units_map:
			var unit: BattleUnit = units_map[cell_pos]
			if unit.is_alive() and unit.team == caster.team:
				result.append(cell_pos)
		return result

	if target_type == "all_enemies":
		for cell_pos: Vector2i in units_map:
			var unit: BattleUnit = units_map[cell_pos]
			if unit.is_alive() and unit.team != caster.team:
				result.append(cell_pos)
		return result

	# 사거리 범위 내 셀 계산 (맨해튼 거리)
	var range_cells: Array[Vector2i] = grid.get_attack_range(caster.cell, range_min, range_max)

	# range_min이 0이면 시전자 셀도 포함
	if range_min == 0:
		range_cells.append(caster.cell)

	# target 유형에 따른 필터링
	match target_type:
		"single_enemy":
			# 적 유닛이 있는 셀만
			for cell_pos: Vector2i in range_cells:
				if units_map.has(cell_pos):
					var unit: BattleUnit = units_map[cell_pos]
					if unit.is_alive() and unit.team != caster.team:
						result.append(cell_pos)

		"single_ally":
			# 아군 유닛이 있는 셀만 (자신 제외)
			for cell_pos: Vector2i in range_cells:
				if units_map.has(cell_pos):
					var unit: BattleUnit = units_map[cell_pos]
					if unit.is_alive() and unit.team == caster.team and cell_pos != caster.cell:
						result.append(cell_pos)

		"area":
			# 범위 공격 — 사거리 내 모든 셀이 대상 가능
			for cell_pos: Vector2i in range_cells:
				result.append(cell_pos)

		_:
			# 기본: 사거리 내 유닛 있는 셀
			for cell_pos: Vector2i in range_cells:
				if units_map.has(cell_pos):
					result.append(cell_pos)

	return result

# ── 범위(area) 패턴 계산 ──

## 중심 셀 기준으로 area 패턴에 해당하는 셀 목록을 반환한다.
## @param center 중심 셀 좌표
## @param area_type area 유형 ("single", "cross", "diamond_2", "line_3", "square_2", "all_enemies", "all_allies")
## @param facing 시전 방향 ("south", "north", "east", "west" 등) — line_3에서 사용
## @returns 영향받는 셀 좌표 배열
func get_area_cells(center: Vector2i, area_type: String, facing: String = "south") -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	match area_type:
		"single":
			result.append(center)

		"cross":
			# 십자형: 중심 + 상하좌우 1칸
			result.append(center)
			result.append(center + Vector2i(0, -1))  # 상
			result.append(center + Vector2i(0, 1))   # 하
			result.append(center + Vector2i(-1, 0))  # 좌
			result.append(center + Vector2i(1, 0))   # 우

		"diamond_2":
			# 다이아몬드 2칸 반경: 맨해튼 거리 <= 2
			for dx: int in range(-2, 3):
				for dy: int in range(-2, 3):
					if absi(dx) + absi(dy) <= 2:
						result.append(center + Vector2i(dx, dy))

		"line_3":
			# 직선 3칸: facing 방향으로 3칸
			var dir_offset: Vector2i = _facing_to_offset(facing)
			for i: int in range(1, 4):  # 1, 2, 3칸
				result.append(center + dir_offset * i)

		"square_2":
			# 2x2 영역
			result.append(center)
			result.append(center + Vector2i(1, 0))
			result.append(center + Vector2i(0, 1))
			result.append(center + Vector2i(1, 1))

		"all_enemies", "all_allies", "all":
			# 전체 대상 — 별도 처리 필요 (호출 측에서 유닛 목록 기반으로 처리)
			result.append(center)

		_:
			# 알 수 없는 유형은 단일 대상으로 처리
			result.append(center)

	return result

# ── MP/사용횟수 소비 ──

## 스킬 사용에 필요한 자원(MP, 사용횟수)을 차감한다.
## @param unit 시전 유닛
## @param skill_id 스킬 ID
func consume_skill_cost(unit: BattleUnit, skill_id: String) -> void:
	var skill_data: Dictionary = get_skill(skill_id)
	if skill_data.is_empty():
		return

	# MP 차감
	var mp_cost: int = skill_data.get("mp_cost", 0)
	unit.current_mp = maxi(unit.current_mp - mp_cost, 0)

	# 사용횟수 기록
	var uses_per_battle: int = skill_data.get("uses_per_battle", -1)
	if uses_per_battle > 0:
		var use_key: String = unit.unit_id + "_" + skill_id
		_skill_uses[use_key] = _skill_uses.get(use_key, 0) + 1

# ── 전투 리셋 ──

## 전투 시작 시 사용횟수 트래킹을 초기화한다.
func reset_battle() -> void:
	_skill_uses.clear()

# ── 내부 유틸 ──

## facing 문자열을 오프셋 Vector2i로 변환한다.
## @param facing_str 방향 문자열
## @returns Vector2i 오프셋
func _facing_to_offset(facing_str: String) -> Vector2i:
	match facing_str:
		"north", "north_west", "north_east":
			return Vector2i(0, -1)
		"south", "south_west", "south_east":
			return Vector2i(0, 1)
		"east":
			return Vector2i(1, 0)
		"west":
			return Vector2i(-1, 0)
		_:
			return Vector2i(0, 1)  # 기본: 남쪽

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

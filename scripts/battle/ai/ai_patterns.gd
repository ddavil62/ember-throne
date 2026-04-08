## @fileoverview AI 행동 패턴 6종 구현.
## aggressive, defensive, support, ambush, flee, boss 패턴을 통해
## 적 유닛의 전투 행동을 결정한다.
class_name AIPatterns
extends RefCounted

# ── 상수 ──

## 도주 패턴 HP 임계값 (30% 이하에서 도주)
const FLEE_HP_THRESHOLD: float = 0.30

## 앰부시 감지 범위 (맨해튼 거리)
const AMBUSH_TRIGGER_RANGE: int = 2

# ── 멤버 변수 ──

## 앰부시 전환 트래킹 {unit_id: bool}
var _ambush_triggered: Dictionary = {}

# ── aggressive 패턴 ──

## 가장 가까운 적에게 돌진. 공격 가능하면 공격, 아니면 가장 가까운 셀로 이동.
## @param unit 행동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조 (데미지 추정 등)
## @returns 행동 Dictionary {"type", "move_to", "target", "skill_id"}
func aggressive(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	if targets.is_empty():
		return _wait_action(unit)

	# 최적 타겟 선택 (controller의 우선순위 로직 사용)
	var target: BattleUnit = controller.get_best_target(unit, targets, battle_map)
	if target == null:
		return _wait_action(unit)

	# 최적 이동 셀 결정
	var best_cell: Vector2i = controller.get_best_move_cell(unit, target, battle_map)

	# 이동 후 공격 가능 여부 확인
	var range_max: int = _get_weapon_range_max(unit)
	var range_min: int = _get_weapon_range_min(unit)
	var dist_after_move: int = _manhattan_distance(best_cell, target.cell)

	if dist_after_move >= range_min and dist_after_move <= range_max:
		return {
			"type": "move_attack",
			"move_to": best_cell,
			"target": target,
			"skill_id": ""
		}
	else:
		# 공격 불가 — 가장 가까운 위치로 이동만
		return {
			"type": "move",
			"move_to": best_cell,
			"target": null,
			"skill_id": ""
		}

# ── defensive 패턴 ──

## 현재 위치에서 공격 범위 내 적만 공격. 범위 내 적이 없으면 대기 (이동하지 않음).
## 지형 보너스가 높은 셀에서 대기 선호.
## @param unit 행동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조
## @returns 행동 Dictionary
func defensive(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	var range_max: int = _get_weapon_range_max(unit)
	var range_min: int = _get_weapon_range_min(unit)

	# 현재 위치에서 공격 가능한 적 검색
	var attackable: Array[BattleUnit] = []
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		var dist: int = _manhattan_distance(unit.cell, t.cell)
		if dist >= range_min and dist <= range_max:
			attackable.append(t)

	if not attackable.is_empty():
		# 공격 가능한 적 중 최적 타겟 선택
		var best_target: BattleUnit = controller.get_best_target(unit, attackable, battle_map)
		if best_target != null:
			return {
				"type": "move_attack",
				"move_to": unit.cell,
				"target": best_target,
				"skill_id": ""
			}

	# 범위 내 적이 없음 — 지형 활용 AI가 켜져 있으면 지형 보너스 셀로 이동, 아니면 대기
	var diff_mgr: DifficultyManager = DifficultyManager.get_instance()
	var best_cell: Vector2i = unit.cell
	if diff_mgr.is_terrain_ai():
		best_cell = _find_best_terrain_cell(unit, move_cells, battle_map)
	if best_cell != unit.cell:
		return {
			"type": "move",
			"move_to": best_cell,
			"target": null,
			"skill_id": ""
		}

	# 이동할 곳도 없으면 현재 위치에서 대기
	return _wait_action(unit)

# ── support 패턴 ──

## 아군 HP 확인 -> 가장 낮은 아군에게 힐/버프.
## 위협(근접 적) 시 후퇴. 스킬 사용 가능하면 heal 타입 우선.
## @param unit 행동 유닛
## @param targets 적 유닛 배열 (플레이어 팀)
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조
## @returns 행동 Dictionary
func support(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	# 아군 (같은 팀) 유닛 목록 조회
	var allies: Array[BattleUnit] = _get_allies(unit, battle_map)

	# 근접 적 위협 확인 — 2칸 이내에 적이 있는지
	var threatened: bool = _is_threatened(unit, targets, 2)

	# 위협받는 경우 후퇴 우선
	if threatened:
		var farthest: Vector2i = _find_farthest_cell_from_targets(unit, targets, move_cells)
		return {
			"type": "move",
			"move_to": farthest,
			"target": null,
			"skill_id": ""
		}

	# 힐 스킬 보유 여부 확인
	var heal_skill: Dictionary = _find_heal_skill(unit)
	if not heal_skill.is_empty():
		# HP가 가장 낮은 아군 찾기 (자기 자신 포함)
		var lowest_ally: BattleUnit = _find_lowest_hp_ally(unit, allies)
		if lowest_ally != null:
			# 아군의 HP가 70% 이하면 힐 시도
			var ally_hp_ratio: float = float(lowest_ally.current_hp) / float(maxi(lowest_ally.stats.get("hp", 1), 1))
			if ally_hp_ratio <= 0.70:
				var skill_range: int = heal_skill.get("range_max", heal_skill.get("range", 3))
				var dist: int = _manhattan_distance(unit.cell, lowest_ally.cell)
				if dist <= skill_range:
					return {
						"type": "skill",
						"skill_id": heal_skill.get("id", ""),
						"move_to": unit.cell,
						"target": lowest_ally,
					}
				# 사거리 밖이면 아군에게 접근
				var approach_cell: Vector2i = _find_cell_closer_to(unit, lowest_ally.cell, move_cells)
				return {
					"type": "move",
					"move_to": approach_cell,
					"target": null,
					"skill_id": ""
				}

	# 힐 불필요하면 대기 (support 유닛은 공격을 기피)
	return _wait_action(unit)

# ── ambush 패턴 ──

## 초기: 이동하지 않고 대기. 적이 범위 2칸 이내로 접근하면 aggressive로 전환.
## 전환 후에는 계속 aggressive.
## @param unit 행동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조
## @returns 행동 Dictionary
func ambush(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	var uid: String = unit.unit_id

	# 이미 전환된 유닛이면 aggressive 동작
	if _ambush_triggered.get(uid, false):
		return aggressive(unit, targets, move_cells, battle_map, controller)

	# 적이 2칸 이내에 있는지 확인
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		var dist: int = _manhattan_distance(unit.cell, t.cell)
		if dist <= AMBUSH_TRIGGER_RANGE:
			# 전환! 이후 계속 aggressive
			_ambush_triggered[uid] = true
			return aggressive(unit, targets, move_cells, battle_map, controller)

	# 아직 미감지 — 대기
	return _wait_action(unit)

# ── flee 패턴 ──

## HP 30% 이하: 적으로부터 가장 먼 셀로 도주.
## HP 30% 초과: aggressive와 동일.
## @param unit 행동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조
## @returns 행동 Dictionary
func flee(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	var hp_ratio: float = float(unit.current_hp) / float(maxi(unit.stats.get("hp", 1), 1))

	if hp_ratio <= FLEE_HP_THRESHOLD:
		# HP 30% 이하 — 도주
		var farthest: Vector2i = _find_farthest_cell_from_targets(unit, targets, move_cells)
		return {
			"type": "flee",
			"move_to": farthest,
			"target": null,
			"skill_id": ""
		}
	else:
		# HP 30% 초과 — aggressive 동작
		return aggressive(unit, targets, move_cells, battle_map, controller)

# ── boss 패턴 ──

## BossAI로 위임한다. AIController에서 분기되므로 여기서는 fallback만 제공.
## @param unit 행동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @param controller AIController 참조
## @returns 행동 Dictionary
func boss(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D, controller: RefCounted) -> Dictionary:
	# AIController에서 BossAI를 직접 호출하므로 여기로 오는 경우는 예외
	# 기본 aggressive로 폴백
	return aggressive(unit, targets, move_cells, battle_map, controller)

# ── 유틸리티 함수 ──

## 맨해튼 거리 계산
## @param a 셀 A
## @param b 셀 B
## @returns 맨해튼 거리
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 유닛의 무기 최대 사거리 조회
## @param unit 대상 유닛
## @returns 최대 사거리 (기본 1)
func _get_weapon_range_max(unit: BattleUnit) -> int:
	# _source_data에서 직접 조회 (적 데이터의 range_max)
	var range_max: int = unit._source_data.get("range_max", -1)
	if range_max > 0:
		return range_max
	# 무기에서 조회
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return 1
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("range_max", 1) as int

## 유닛의 무기 최소 사거리 조회
## @param unit 대상 유닛
## @returns 최소 사거리 (기본 1)
func _get_weapon_range_min(unit: BattleUnit) -> int:
	var range_min: int = unit._source_data.get("range_min", -1)
	if range_min >= 0:
		return range_min
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return 1
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("range_min", 1) as int

## 지형 방어 보너스가 가장 높은 이동 셀을 찾는다.
## @param unit 기준 유닛
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 최적 셀 좌표
func _find_best_terrain_cell(unit: BattleUnit, move_cells: Array[Vector2i], battle_map: Node2D) -> Vector2i:
	if move_cells.is_empty():
		return unit.cell

	var best_cell: Vector2i = unit.cell
	var best_bonus: int = _get_terrain_def_bonus_at(unit.cell, battle_map)

	for cell: Vector2i in move_cells:
		var bonus: int = _get_terrain_def_bonus_at(cell, battle_map)
		if bonus > best_bonus:
			best_bonus = bonus
			best_cell = cell

	return best_cell

## 지정 셀의 지형 방어 보너스를 조회한다.
## @param cell 셀 좌표
## @param battle_map 전투 맵 참조
## @returns 방어 보너스 값 (정수, %)
func _get_terrain_def_bonus_at(cell: Vector2i, battle_map: Node2D) -> int:
	if battle_map == null:
		return 0
	var grid: GridSystem = battle_map.grid
	if grid == null:
		return 0
	var terrain_type: String = grid.get_tile_at(cell)
	if terrain_type.is_empty():
		return 0
	var dm: Node = _get_data_manager()
	if dm == null:
		return 0
	var terrain_data: Dictionary = dm.get_terrain(terrain_type)
	return terrain_data.get("def_bonus", 0) as int

## 적으로부터 가장 먼 이동 셀을 찾는다. (후퇴/도주용)
## @param unit 이동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @returns 가장 먼 셀 좌표
func _find_farthest_cell_from_targets(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i]) -> Vector2i:
	if move_cells.is_empty():
		return unit.cell

	var best_cell: Vector2i = unit.cell
	var max_min_dist: int = 0

	# 현재 위치도 후보에 포함
	var candidates: Array[Vector2i] = move_cells.duplicate()
	candidates.append(unit.cell)

	for cell: Vector2i in candidates:
		var min_dist_to_enemy: int = 999
		for t: BattleUnit in targets:
			if not t.is_alive():
				continue
			var dist: int = _manhattan_distance(cell, t.cell)
			if dist < min_dist_to_enemy:
				min_dist_to_enemy = dist
		if min_dist_to_enemy > max_min_dist:
			max_min_dist = min_dist_to_enemy
			best_cell = cell

	return best_cell

## 유닛 주변에 적이 있는지 확인한다 (위협 판정).
## @param unit 기준 유닛
## @param targets 적 유닛 배열
## @param threat_range 위협 범위 (맨해튼 거리)
## @returns 위협받으면 true
func _is_threatened(unit: BattleUnit, targets: Array[BattleUnit], threat_range: int) -> bool:
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		if _manhattan_distance(unit.cell, t.cell) <= threat_range:
			return true
	return false

## 같은 팀 아군 유닛 목록을 조회한다.
## @param unit 기준 유닛
## @param battle_map 전투 맵 참조
## @returns 아군 유닛 배열
func _get_allies(unit: BattleUnit, battle_map: Node2D) -> Array[BattleUnit]:
	if battle_map == null:
		return []
	return battle_map.get_units_by_team(unit.team)

## HP가 가장 낮은 아군 유닛을 찾는다.
## @param unit 기준 유닛 (자기 자신도 포함)
## @param allies 아군 유닛 배열
## @returns HP 최저 아군 또는 null
func _find_lowest_hp_ally(unit: BattleUnit, allies: Array[BattleUnit]) -> BattleUnit:
	var lowest: BattleUnit = null
	var min_ratio: float = 1.0
	for ally: BattleUnit in allies:
		if not ally.is_alive():
			continue
		var ratio: float = float(ally.current_hp) / float(maxi(ally.stats.get("hp", 1), 1))
		if ratio < min_ratio:
			min_ratio = ratio
			lowest = ally
	return lowest

## 유닛이 보유한 힐 스킬을 찾는다.
## @param unit 대상 유닛
## @returns 힐 스킬 데이터 Dictionary (없으면 빈 Dictionary)
func _find_heal_skill(unit: BattleUnit) -> Dictionary:
	var dm: Node = _get_data_manager()
	if dm == null:
		return {}

	# 유닛 스킬 목록에서 heal 타입 검색
	for skill_id: String in unit.skills:
		var skill_data: Dictionary = dm.get_skill(skill_id)
		if skill_data.is_empty():
			continue
		var skill_type: String = skill_data.get("type", "")
		var target_type: String = skill_data.get("target", "")
		# heal, buff 타입이면서 아군 대상이면 힐 스킬로 간주
		if skill_type in ["heal", "support", "buff"] or target_type in ["single_ally", "all_allies"]:
			return skill_data

	# _source_data의 skills (적 데이터 — 인라인 스킬 배열)에서도 검색
	var source_skills: Array = unit._source_data.get("skills", [])
	for skill_entry: Variant in source_skills:
		if skill_entry is Dictionary:
			var skill_type: String = skill_entry.get("type", "")
			if skill_type in ["heal", "support", "buff"]:
				return skill_entry

	return {}

## 특정 셀에 가까워지는 이동 셀을 찾는다.
## @param unit 이동 유닛
## @param target_cell 목표 셀
## @param move_cells 이동 가능 셀 배열
## @returns 가장 가까운 이동 셀
func _find_cell_closer_to(unit: BattleUnit, target_cell: Vector2i, move_cells: Array[Vector2i]) -> Vector2i:
	var best_cell: Vector2i = unit.cell
	var best_dist: int = _manhattan_distance(unit.cell, target_cell)

	for cell: Vector2i in move_cells:
		var dist: int = _manhattan_distance(cell, target_cell)
		if dist < best_dist:
			best_dist = dist
			best_cell = cell

	return best_cell

## 대기 행동을 반환한다.
## @param unit 유닛
## @returns 대기 행동 Dictionary
func _wait_action(unit: BattleUnit) -> Dictionary:
	return {
		"type": "wait",
		"move_to": unit.cell,
		"target": null,
		"skill_id": ""
	}

## 앰부시 전환 상태를 초기화한다. 전투 시작 시 호출.
func reset() -> void:
	_ambush_triggered.clear()

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

## @fileoverview AI 전체 컨트롤러. 유닛의 ai_pattern에 따라 적절한 패턴을 선택하고
## 행동을 결정한다. TurnManager에서 AI 유닛 행동 시 호출된다.
class_name AIController
extends RefCounted

# ── 멤버 변수 ──

## AI 행동 패턴 모듈
var _patterns: AIPatterns = AIPatterns.new()

## 보스 전용 AI 모듈
var _boss_ai: BossAI = BossAI.new()

## 전투 데미지 계산기
var _combat_calc: CombatCalculator = CombatCalculator.new()

## 집중 공격 — 직전 턴에 공격받은 타겟 (턴 간 유지)
var _last_attacked_target: BattleUnit = null

## 집중 공격 — 현재 턴에서 AI 유닛들이 공격한 타겟 목록
var _current_turn_targets: Array[BattleUnit] = []

# ── 메인 행동 결정 ──

## 유닛의 AI 행동을 결정한다.
## @param unit 행동할 AI 유닛
## @param battle_map 전투 맵 참조 (Node2D — BattleMap)
## @returns {"type": "move_attack"/"move"/"wait"/"skill"/"flee"/"summon"/"clone",
##           "move_to": Vector2i, "target": BattleUnit|null, "skill_id": String}
func decide_action(unit: BattleUnit, battle_map: Node2D) -> Dictionary:
	# ai_pattern 조회 (없으면 기본 "aggressive")
	var ai_pattern: String = unit._source_data.get("ai_pattern", "aggressive")

	# 적 팀 유닛 목록 (AI 유닛의 공격 대상)
	var target_team: String = "player" if unit.team == "enemy" else "enemy"
	var targets: Array[BattleUnit] = _get_alive_units_by_team(target_team, battle_map)

	if targets.is_empty():
		return _wait_action(unit)

	# 이동 가능 셀 계산
	var move_cells: Array[Vector2i] = []
	if battle_map and battle_map.grid:
		move_cells = battle_map.grid.get_movement_range(
			unit.cell, unit.stats.get("mov", 0), unit.team
		)

	# 보스 패턴은 BossAI에 직접 위임
	if ai_pattern == "boss":
		var action: Dictionary = _boss_ai.decide(unit, targets, move_cells, battle_map)
		_track_focus_fire(action)
		return action

	# 일반 패턴 분기
	var action: Dictionary = {}
	match ai_pattern:
		"aggressive":
			action = _patterns.aggressive(unit, targets, move_cells, battle_map, self)
		"defensive":
			action = _patterns.defensive(unit, targets, move_cells, battle_map, self)
		"support":
			action = _patterns.support(unit, targets, move_cells, battle_map, self)
		"ambush":
			action = _patterns.ambush(unit, targets, move_cells, battle_map, self)
		"flee":
			if _is_hard_difficulty():
				# Hard 모드에서는 도주 대신 공격적으로 행동
				if targets.is_empty():
					action = _patterns.defensive(unit, targets, move_cells, battle_map, self)
				else:
					action = _patterns.aggressive(unit, targets, move_cells, battle_map, self)
			else:
				action = _patterns.flee(unit, targets, move_cells, battle_map, self)
		_:
			# 알 수 없는 패턴 — aggressive로 폴백
			action = _patterns.aggressive(unit, targets, move_cells, battle_map, self)

	# 집중 공격 추적 — 공격 행동이면 타겟을 기록
	_track_focus_fire(action)
	return action

# ── 타겟 선택 ──

## 최적 공격 대상을 선택한다. 우선순위:
## 1. 킬 가능 유닛 (예상 데미지 >= 잔여 HP)
## 2. Hard 난이도: 힐러 우선
## 3. 낮은 HP 유닛
## 4. 무기 상성 유리 대상
## 5. 가장 가까운 유닛
## @param unit 공격 유닛
## @param targets 공격 대상 후보 배열
## @param battle_map 전투 맵 참조
## @returns 최적 타겟 BattleUnit 또는 null
func get_best_target(unit: BattleUnit, targets: Array[BattleUnit], battle_map: Node2D) -> BattleUnit:
	if targets.is_empty():
		return null

	# 생존 유닛만 필터
	var alive_targets: Array[BattleUnit] = []
	for t: BattleUnit in targets:
		if t.is_alive():
			alive_targets.append(t)
	if alive_targets.is_empty():
		return null

	# 난이도 매니저에서 AI 설정 조회
	var diff_mgr: DifficultyManager = DifficultyManager.get_instance()
	var target_selection: String = diff_mgr.get_target_selection()
	var focus_fire: bool = diff_mgr.is_focus_fire()

	# 후보 점수 계산
	var best_target: BattleUnit = null
	var best_score: float = -999.0

	for t: BattleUnit in alive_targets:
		var score: float = 0.0
		var dist: int = _manhattan_distance(unit.cell, t.cell)

		# 1. 킬 가능 유닛 — 최고 우선순위
		var est_damage: int = estimate_damage(unit, t, battle_map)
		if est_damage >= t.current_hp:
			score += 100.0

		# 2. 위협 기반 타겟 선택 (threat_based): 힐러/서포터 우선
		if target_selection == "threat_based":
			var target_class: String = t._source_data.get("class", "")
			var target_role: String = t._source_data.get("role", "")
			if target_class in ["healer", "support", "cleric", "priest"] or target_role in ["healer", "support"]:
				score += 50.0

		# 3. 낮은 HP 유닛 선호 (HP 비율이 낮을수록 높은 점수)
		var hp_ratio: float = float(t.current_hp) / float(maxi(t.stats.get("hp", 1), 1))
		score += (1.0 - hp_ratio) * 30.0

		# 4. 무기 상성 유리
		var advantage: int = _get_weapon_advantage(unit, t)
		score += float(advantage) * 15.0

		# 5. 가까운 유닛 선호 (거리 패널티)
		score -= float(dist) * 2.0

		# 6. 집중 공격 보너스 — 이전 턴/현재 턴에 공격받은 타겟에 가산
		if focus_fire:
			if _last_attacked_target != null and t == _last_attacked_target and t.is_alive():
				score += 30.0
			if t in _current_turn_targets:
				score += 30.0

		if score > best_score:
			best_score = score
			best_target = t

	return best_target

# ── 이동 셀 결정 ──

## 이동 후 공격 가능한 최적 위치를 찾는다. 공격 불가하면 가장 가까운 위치.
## @param unit 이동 유닛
## @param target 공격 대상
## @param battle_map 전투 맵 참조
## @returns 최적 이동 셀 좌표
func get_best_move_cell(unit: BattleUnit, target: BattleUnit, battle_map: Node2D) -> Vector2i:
	if battle_map == null or battle_map.grid == null:
		return unit.cell

	# 이동 가능 셀 조회
	var move_cells: Array[Vector2i] = battle_map.grid.get_movement_range(
		unit.cell, unit.stats.get("mov", 0), unit.team
	)

	# 무기 사거리
	var range_max: int = _get_range_max(unit)
	var range_min: int = _get_range_min(unit)

	# 현재 위치에서 공격 가능한지 확인
	var current_dist: int = _manhattan_distance(unit.cell, target.cell)
	if current_dist >= range_min and current_dist <= range_max:
		return unit.cell

	var best_attack_cell: Vector2i = unit.cell
	var found_attack_cell: bool = false
	var best_attack_dist_to_unit: int = 999

	var best_approach_cell: Vector2i = unit.cell
	var best_approach_dist: int = current_dist

	for cell: Vector2i in move_cells:
		var dist_to_target: int = _manhattan_distance(cell, target.cell)

		# 공격 가능 셀인가?
		if dist_to_target >= range_min and dist_to_target <= range_max:
			var dist_from_unit: int = _manhattan_distance(unit.cell, cell)
			if not found_attack_cell or dist_from_unit < best_attack_dist_to_unit:
				found_attack_cell = true
				best_attack_cell = cell
				best_attack_dist_to_unit = dist_from_unit

		# 접근 셀 (공격은 못하지만 가장 가까운)
		if dist_to_target < best_approach_dist:
			best_approach_dist = dist_to_target
			best_approach_cell = cell

	if found_attack_cell:
		return best_attack_cell
	return best_approach_cell

# ── 데미지 추정 ──

## 예상 데미지를 산출한다 (랜덤 없이 기대값).
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param battle_map 전투 맵 참조
## @returns 예상 데미지 (int)
func estimate_damage(attacker: BattleUnit, defender: BattleUnit, battle_map: Node2D) -> int:
	if battle_map == null or battle_map.grid == null:
		return 0

	var grid: GridSystem = battle_map.grid

	# 물리 vs 마법 판별 — 적 데이터의 type 또는 weapon_type으로 판별
	var unit_type: String = attacker._source_data.get("type", "melee")
	var weapon_type: String = attacker._source_data.get("weapon_type", "")

	if unit_type == "magic" or weapon_type == "magic":
		return _estimate_magic_damage(attacker, defender, grid)
	else:
		return _estimate_physical_damage(attacker, defender, grid)

## 물리 예상 데미지 (크리티컬/명중 확률 반영한 기대값)
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param grid GridSystem
## @returns 기대 데미지
func _estimate_physical_damage(attacker: BattleUnit, defender: BattleUnit, grid: GridSystem) -> int:
	var atk: float = float(attacker.stats.get("atk", 0))
	var def: float = float(defender.stats.get("def", 0))

	# 난이도 보정
	if attacker.team == "enemy":
		atk *= _get_difficulty_multiplier("enemy_atk_multiplier")
	if defender.team == "enemy":
		def *= _get_difficulty_multiplier("enemy_def_multiplier")

	# 기본 데미지: ATK - DEF / 2
	var base: float = atk - def / 2.0

	# 지형 방어 보정
	var terrain_mod: float = _combat_calc.get_terrain_def_bonus(defender.cell, grid)

	# 무기 상성 보정
	var weapon_mod: float = _get_weapon_damage_mod(attacker, defender)

	# 명중률 기대값
	var hit_rate: float = float(_combat_calc.calc_hit_rate(attacker, defender, grid)) / 100.0

	# 크리티컬 기대 배율
	var crit_rate: float = float(_combat_calc.calc_crit_rate(attacker, defender)) / 100.0
	var crit_mod: float = 1.0 + crit_rate * (CombatCalculator.CRIT_MULTIPLIER - 1.0)

	var damage: float = base * terrain_mod * weapon_mod * crit_mod * hit_rate
	return maxi(int(damage), 0)

## 마법 예상 데미지
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param grid GridSystem
## @returns 기대 데미지
func _estimate_magic_damage(attacker: BattleUnit, defender: BattleUnit, grid: GridSystem) -> int:
	var matk: float = float(attacker.stats.get("matk", 0))
	var mdef: float = float(defender.stats.get("mdef", 0))

	if attacker.team == "enemy":
		matk *= _get_difficulty_multiplier("enemy_atk_multiplier")
	if defender.team == "enemy":
		mdef *= _get_difficulty_multiplier("enemy_def_multiplier")

	var base: float = matk - mdef / 2.0

	var terrain_mod: float = _combat_calc.get_terrain_def_bonus(defender.cell, grid)

	var hit_rate: float = float(_combat_calc.calc_hit_rate(attacker, defender, grid)) / 100.0

	var crit_rate: float = float(_combat_calc.calc_crit_rate(attacker, defender)) / 100.0
	var crit_mod: float = 1.0 + crit_rate * (CombatCalculator.CRIT_MULTIPLIER - 1.0)

	var damage: float = base * terrain_mod * crit_mod * hit_rate
	return maxi(int(damage), 0)

# ── 유틸리티 ──

## 맨해튼 거리 계산
## @param a 셀 A
## @param b 셀 B
## @returns 맨해튼 거리
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 지정 팀의 생존 유닛 목록을 조회한다.
## @param team_name 팀 이름
## @param battle_map 전투 맵 참조
## @returns 생존 유닛 배열
func _get_alive_units_by_team(team_name: String, battle_map: Node2D) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	if battle_map == null:
		return result
	var all_units: Array[BattleUnit] = battle_map.get_units_by_team(team_name)
	for u: BattleUnit in all_units:
		if u.is_alive():
			result.append(u)
	return result

## 무기 상성 우열 판정
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @returns +1(유리), -1(불리), 0(중립)
func _get_weapon_advantage(attacker: BattleUnit, defender: BattleUnit) -> int:
	var attacker_type: String = _get_unit_weapon_type(attacker)
	var defender_type: String = _get_unit_weapon_type(defender)
	return WeaponTriangle.get_weapon_advantage(attacker_type, defender_type)

## 무기 상성 데미지 배율 조회
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @returns 데미지 배율 (1.15/0.85/1.0)
func _get_weapon_damage_mod(attacker: BattleUnit, defender: BattleUnit) -> float:
	var attacker_type: String = _get_unit_weapon_type(attacker)
	var defender_type: String = _get_unit_weapon_type(defender)
	return WeaponTriangle.get_weapon_damage_mod(attacker_type, defender_type)

## 유닛의 무기 타입을 조회한다.
## @param unit 대상 유닛
## @returns 무기 타입 문자열
func _get_unit_weapon_type(unit: BattleUnit) -> String:
	# 적 데이터에 weapon_type이 있으면 직접 사용
	var wt: String = unit._source_data.get("weapon_type", "")
	if not wt.is_empty():
		return wt
	# 장비에서 조회
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return ""
	var dm: Node = _get_data_manager()
	if dm == null:
		return ""
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("type", "")

## 유닛의 최대 사거리를 조회한다.
## @param unit 대상 유닛
## @returns 최대 사거리
func _get_range_max(unit: BattleUnit) -> int:
	var range_max: int = unit._source_data.get("range_max", -1)
	if range_max > 0:
		return range_max
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return 1
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("range_max", 1) as int

## 유닛의 최소 사거리를 조회한다.
## @param unit 대상 유닛
## @returns 최소 사거리
func _get_range_min(unit: BattleUnit) -> int:
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

## Hard 난이도인지 확인한다.
## @returns Hard 난이도이면 true
func _is_hard_difficulty() -> bool:
	var gm: Node = _get_game_manager()
	if gm == null:
		return false
	return gm.difficulty == "hard"

## 난이도 멀티플라이어 조회
## @param key 멀티플라이어 키
## @returns 배율 값 (기본 1.0)
func _get_difficulty_multiplier(key: String) -> float:
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1.0
	var gm: Node = _get_game_manager()
	if gm == null:
		return 1.0
	var current_difficulty: String = gm.difficulty
	var diff_data: Dictionary = dm.difficulty_data.get(current_difficulty, {})
	return diff_data.get(key, 1.0) as float

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

# ── 집중 공격 추적 ──

## 행동 결과에서 공격 타겟을 추출하여 집중 공격 추적에 기록한다.
## @param action 행동 Dictionary
func _track_focus_fire(action: Dictionary) -> void:
	if action.get("type", "") == "move_attack" or action.get("type", "") == "skill":
		var target: Variant = action.get("target", null)
		if target is BattleUnit:
			record_attack_target(target)

## 공격 실행 후 호출하여 타겟을 기록한다. (TurnManager 등에서 호출)
## @param target 공격받은 유닛
func record_attack_target(target: BattleUnit) -> void:
	if target != null and not _current_turn_targets.has(target):
		_current_turn_targets.append(target)

## 턴 종료 시 호출하여 집중 공격 추적 상태를 갱신한다.
## 현재 턴 타겟 목록의 마지막 타겟을 _last_attacked_target으로 보관하고 초기화한다.
func on_turn_end() -> void:
	if not _current_turn_targets.is_empty():
		_last_attacked_target = _current_turn_targets[-1]
	_current_turn_targets.clear()

## 전투 시작 시 호출하여 집중 공격 상태를 초기화한다.
func reset_focus_fire() -> void:
	_last_attacked_target = null
	_current_turn_targets.clear()

## 전투 시작 시 AI 전체 상태를 초기화한다. 패턴/보스 내부 상태 + 집중 공격 추적 초기화.
func reset() -> void:
	_patterns.reset()
	_boss_ai.reset()
	reset_focus_fire()

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

## GameManager 싱글톤 참조 취득
## @returns GameManager 노드 또는 null
func _get_game_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

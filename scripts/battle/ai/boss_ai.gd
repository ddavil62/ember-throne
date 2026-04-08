## @fileoverview 보스 전용 AI. 재의 군주, 루시드, 타락한 모르간 3종 보스의
## 페이즈별 행동 결정 로직을 관리한다.
class_name BossAI
extends RefCounted

# ── 멤버 변수 ──

## 보스별 현재 페이즈 {boss_id: int}
var _phase_tracker: Dictionary = {}

## 보스별 소환 횟수 {boss_id: int}
var _summon_count: Dictionary = {}

## 보스별 경과 턴 수 (소환 쿨타임용) {boss_id: int}
var _turn_counter: Dictionary = {}

## 보스별 분신 생성 여부 {boss_id: bool}
var _clone_spawned: Dictionary = {}

## 전투 계산기 (예상 데미지 산출용)
var _combat_calc: CombatCalculator = CombatCalculator.new()

# ── 상수 ──

## 재의 군주: 소환 쿨타임 (턴)
const ASH_LORD_SUMMON_INTERVAL: int = 3

## 재의 군주: 최대 소환 횟수
const ASH_LORD_MAX_SUMMONS: int = 3

## 재의 군주: 2페이즈 전환 HP 비율
const ASH_LORD_PHASE2_THRESHOLD: float = 0.50

## 루시드: 2페이즈 전환 HP 비율
const LUCID_PHASE2_THRESHOLD: float = 0.60

## 루시드: 3페이즈 전환 HP 비율 (본체 노출)
const LUCID_PHASE3_THRESHOLD: float = 0.30

## 타락한 모르간: 2페이즈 전환 HP 비율
const MORGAN_PHASE2_THRESHOLD: float = 0.60

## 타락한 모르간: 3페이즈 전환 HP 비율
const MORGAN_PHASE3_THRESHOLD: float = 0.30

## 승천 모르간: 소환 쿨타임 (턴)
const ASCENDED_MORGAN_SUMMON_INTERVAL: int = 4

## 승천 모르간: 최대 소환 횟수
const ASCENDED_MORGAN_MAX_SUMMONS: int = 2

## 승천 모르간: 궁극기 HP 비율 임계값 (barrier_collapse 사용 조건)
const ASCENDED_MORGAN_ULTIMATE_THRESHOLD: float = 0.15

# ── 메인 분기 ──

## 보스 유닛의 행동을 결정한다. unit._source_data.id로 보스를 분기한다.
## @param unit 보스 유닛
## @param targets 적 유닛 배열 (플레이어 팀)
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary {"type": ..., "move_to": ..., "target": ..., "skill_id": ...}
func decide(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var boss_id: String = unit._source_data.get("id", "")

	# 턴 카운터 증가
	_turn_counter[boss_id] = _turn_counter.get(boss_id, 0) + 1

	# HP 비율로 페이즈 갱신
	_update_phase(unit)

	match boss_id:
		"ashen_lord_vanguard":
			return decide_ash_lord(unit, targets, move_cells, battle_map)
		"lucid":
			return decide_lucid(unit, targets, move_cells, battle_map)
		"corrupted_morgan":
			return decide_corrupted_morgan(unit, targets, move_cells, battle_map)
		"ascended_morgan":
			return decide_ascended_morgan(unit, targets, move_cells, battle_map)
		_:
			# 알 수 없는 보스 — aggressive 기본 동작
			return _default_aggressive(unit, targets, move_cells, battle_map)

## 보스의 HP 비율에 따라 페이즈를 갱신한다.
## @param unit 보스 유닛
func _update_phase(unit: BattleUnit) -> void:
	var boss_id: String = unit._source_data.get("id", "")
	var hp_ratio: float = float(unit.current_hp) / float(maxi(unit.stats.get("hp", 1), 1))
	var current_phase: int = _phase_tracker.get(boss_id, 1)

	match boss_id:
		"ashen_lord_vanguard":
			if hp_ratio <= ASH_LORD_PHASE2_THRESHOLD and current_phase < 2:
				_phase_tracker[boss_id] = 2
		"lucid":
			if hp_ratio <= LUCID_PHASE3_THRESHOLD and current_phase < 3:
				_phase_tracker[boss_id] = 3
			elif hp_ratio <= LUCID_PHASE2_THRESHOLD and current_phase < 2:
				_phase_tracker[boss_id] = 2
		"corrupted_morgan":
			if hp_ratio <= MORGAN_PHASE3_THRESHOLD and current_phase < 3:
				_phase_tracker[boss_id] = 3
			elif hp_ratio <= MORGAN_PHASE2_THRESHOLD and current_phase < 2:
				_phase_tracker[boss_id] = 2

# ── 재의 군주 (ash_lord / ashen_lord_vanguard) ──

## 재의 군주 AI 행동 결정.
## Phase 1 (HP 100~51%): 부하 소환 (3턴마다, 최대 3회) + 근접 공격
## Phase 2 (HP 50% 이하): 재의 폭풍 (광역 마법) + 근접 공격
## @param unit 보스 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func decide_ash_lord(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var boss_id: String = unit._source_data.get("id", "")
	var phase: int = _phase_tracker.get(boss_id, 1)
	var turn: int = _turn_counter.get(boss_id, 0)
	var summons: int = _summon_count.get(boss_id, 0)

	if phase == 1:
		# Phase 1: 소환 + 근접 공격
		# 3턴마다 소환 시도 (최대 3회)
		if turn % ASH_LORD_SUMMON_INTERVAL == 0 and summons < ASH_LORD_MAX_SUMMONS:
			_summon_count[boss_id] = summons + 1
			return {
				"type": "summon",
				"summon_id": "ash_flame",
				"count": 2,
				"move_to": unit.cell,
				"target": null,
				"skill_id": "ash_summon"
			}

		# 소환하지 않는 턴에는 근접 공격
		return _melee_attack_or_approach(unit, targets, move_cells, battle_map)

	else:
		# Phase 2: 광역 마법 + 근접 공격
		# 범위 내에 2명 이상의 적이 있으면 재의 포효 사용
		var nearby_count: int = _count_targets_in_range(unit, targets, 3)
		if nearby_count >= 2:
			return {
				"type": "skill",
				"skill_id": "ash_roar",
				"move_to": unit.cell,
				"target": null,
			}

		# 그 외 근접 공격
		return _melee_attack_or_approach(unit, targets, move_cells, battle_map)

# ── 루시드 (lucid) ──

## 루시드 AI 행동 결정.
## Phase 1 (HP 100~61%): 일반 공격 + 분신 생성 (1회)
## Phase 2 (HP 60~31%): 본체 은닉 (stealth) + 분신이 공격
## Phase 3 (HP 30% 이하): 본체 노출 + 전력 공격
## @param unit 보스 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func decide_lucid(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var boss_id: String = unit._source_data.get("id", "")
	var phase: int = _phase_tracker.get(boss_id, 1)
	var has_cloned: bool = _clone_spawned.get(boss_id, false)

	if phase == 1:
		# Phase 1: 일반 공격 + 분신 생성 (1회)
		if not has_cloned:
			_clone_spawned[boss_id] = true
			return {
				"type": "clone",
				"count": 2,
				"move_to": unit.cell,
				"target": null,
				"skill_id": "clone"
			}
		# 가장 HP 낮은 적을 우선 공격 (냉혹한 판단 패시브)
		return _attack_lowest_hp_target(unit, targets, move_cells, battle_map)

	elif phase == 2:
		# Phase 2: 본체 은닉 + 후방 이동
		# stealth 상태 부여 (분신이 공격을 대행한다고 가정)
		# 적으로부터 가장 먼 셀로 이동하고 대기
		var farthest_cell: Vector2i = _find_farthest_cell_from_targets(unit, targets, move_cells)
		return {
			"type": "move",
			"move_to": farthest_cell,
			"target": null,
			"skill_id": ""
		}

	else:
		# Phase 3: 본체 노출 + 전력 공격
		# 가장 HP 낮은 적을 물리 공격 + 스킬 사용
		var lowest_target: BattleUnit = _find_lowest_hp_target(targets)
		if lowest_target == null:
			return _wait_action(unit)

		# 스킬 사용 가능하면 assassination_blade 사용
		var attack_cell: Vector2i = _find_attack_cell(unit, lowest_target, move_cells, battle_map)
		var dist_to_target: int = _manhattan_distance(attack_cell, lowest_target.cell)
		if dist_to_target <= 1:
			return {
				"type": "skill",
				"skill_id": "assassination_blade",
				"move_to": attack_cell,
				"target": lowest_target,
			}
		# 접근 불가시 가장 가까운 셀로 이동
		return {
			"type": "move_attack",
			"move_to": attack_cell,
			"target": lowest_target,
			"skill_id": ""
		}

# ── 타락한 모르간 (corrupted_morgan) ──

## 타락한 모르간 AI 행동 결정.
## Phase 1 (HP 100~61%): 마법 위주 + 버프
## Phase 2 (HP 60~31%): 물리+마법 혼합 + 광역기 사용
## Phase 3 (HP 30% 이하): 최강 스킬 사용 + 전체 디버프
## @param unit 보스 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func decide_corrupted_morgan(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var boss_id: String = unit._source_data.get("id", "")
	var phase: int = _phase_tracker.get(boss_id, 1)

	if phase == 1:
		# Phase 1: 마법 위주 — barrier_dominion으로 고위협 대상 공격
		var high_threat: BattleUnit = _find_highest_threat_target(targets)
		if high_threat == null:
			return _wait_action(unit)

		# 사거리 4 내에 있으면 barrier_dominion 사용
		var dist: int = _manhattan_distance(unit.cell, high_threat.cell)
		if dist <= 4:
			return {
				"type": "skill",
				"skill_id": "barrier_dominion",
				"move_to": unit.cell,
				"target": high_threat,
			}

		# 사거리 밖이면 가까운 셀로 이동 후 공격 시도
		var best_cell: Vector2i = _find_cell_within_range(unit, high_threat, move_cells, 4)
		return {
			"type": "move_attack",
			"move_to": best_cell,
			"target": high_threat,
			"skill_id": "barrier_dominion"
		}

	elif phase == 2:
		# Phase 2: 혼합 — 광역기 + 결계의 사슬
		# 범위 내 2명 이상이면 barrier_storm (광역)
		var nearby_count: int = _count_targets_in_range(unit, targets, 4)
		if nearby_count >= 2:
			return {
				"type": "skill",
				"skill_id": "barrier_storm",
				"move_to": unit.cell,
				"target": null,
			}

		# 힐러/고위협 대상에게 barrier_chain (이동 불가)
		var priority_target: BattleUnit = _find_healer_or_threat(targets)
		if priority_target != null:
			var dist: int = _manhattan_distance(unit.cell, priority_target.cell)
			if dist <= 3:
				return {
					"type": "skill",
					"skill_id": "barrier_chain",
					"move_to": unit.cell,
					"target": priority_target,
				}

		# 기본 마법 공격
		return _magic_attack_or_approach(unit, targets, move_cells, battle_map)

	else:
		# Phase 3: 최강 스킬 — primal_bombardment + barrier_collapse
		# HP가 매우 낮을 때 barrier_collapse (맵 전체 고정 데미지) 사용
		var hp_ratio: float = float(unit.current_hp) / float(maxi(unit.stats.get("hp", 1), 1))
		if hp_ratio <= 0.15:
			return {
				"type": "skill",
				"skill_id": "barrier_collapse",
				"move_to": unit.cell,
				"target": null,
			}

		# primal_bombardment 사용 — 사거리 5, 직선 관통
		var best_target: BattleUnit = _find_highest_threat_target(targets)
		if best_target != null:
			var dist: int = _manhattan_distance(unit.cell, best_target.cell)
			if dist <= 5:
				return {
					"type": "skill",
					"skill_id": "primal_bombardment",
					"move_to": unit.cell,
					"target": best_target,
				}

		# 접근 후 공격
		return _magic_attack_or_approach(unit, targets, move_cells, battle_map)

# ── 승천 모르간 (ascended_morgan) — battle_34 3페이즈 최종 보스 ──

## 승천 모르간 AI 행동 결정. corrupted_morgan의 Phase 3 스킬셋을 전용 보스로 분리한 것.
## 궁극기(barrier_collapse) + AoE(primal_bombardment, barrier_storm) + 주기적 미니언 소환
## @param unit 보스 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func decide_ascended_morgan(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var boss_id: String = unit._source_data.get("id", "")
	var turn: int = _turn_counter.get(boss_id, 0)
	var summons: int = _summon_count.get(boss_id, 0)
	var hp_ratio: float = float(unit.current_hp) / float(maxi(unit.stats.get("hp", 1), 1))

	# 1. 궁극기 — HP가 매우 낮을 때 barrier_collapse (맵 전체 고정 데미지)
	if hp_ratio <= ASCENDED_MORGAN_ULTIMATE_THRESHOLD:
		return {
			"type": "skill",
			"skill_id": "barrier_collapse",
			"move_to": unit.cell,
			"target": null,
		}

	# 2. 주기적 미니언 소환 (ash_phantom_enhanced, 4턴마다, 최대 2회, 첫 턴 제외)
	if turn > 0 and turn % ASCENDED_MORGAN_SUMMON_INTERVAL == 0 and summons < ASCENDED_MORGAN_MAX_SUMMONS:
		_summon_count[boss_id] = summons + 1
		return {
			"type": "summon",
			"summon_id": "ash_phantom_enhanced",
			"count": 1,
			"move_to": unit.cell,
			"target": null,
			"skill_id": "ash_summon"
		}

	# 3. AoE — 범위 내 2명 이상이면 barrier_storm 사용
	var nearby_count: int = _count_targets_in_range(unit, targets, 4)
	if nearby_count >= 2:
		return {
			"type": "skill",
			"skill_id": "barrier_storm",
			"move_to": unit.cell,
			"target": null,
		}

	# 4. 메인 공격 — primal_bombardment (사거리 5, 직선 관통)
	var best_target: BattleUnit = _find_highest_threat_target(targets)
	if best_target != null:
		var dist: int = _manhattan_distance(unit.cell, best_target.cell)
		if dist <= 5:
			return {
				"type": "skill",
				"skill_id": "primal_bombardment",
				"move_to": unit.cell,
				"target": best_target,
			}

	# 5. 접근 후 공격
	return _magic_attack_or_approach(unit, targets, move_cells, battle_map)

# ── 유틸리티 함수 ──

## 맨해튼 거리 계산
## @param a 셀 A
## @param b 셀 B
## @returns 맨해튼 거리
func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

## 근접 공격 또는 접근 행동을 반환한다.
## @param unit 공격 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func _melee_attack_or_approach(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var closest: BattleUnit = _find_closest_target(unit, targets)
	if closest == null:
		return _wait_action(unit)

	var attack_cell: Vector2i = _find_attack_cell(unit, closest, move_cells, battle_map)
	var dist: int = _manhattan_distance(attack_cell, closest.cell)

	# 무기 사거리 조회
	var range_max: int = unit._source_data.get("range_max", 1)
	var range_min: int = unit._source_data.get("range_min", 1)

	if dist >= range_min and dist <= range_max:
		return {
			"type": "move_attack",
			"move_to": attack_cell,
			"target": closest,
			"skill_id": ""
		}
	else:
		return {
			"type": "move",
			"move_to": attack_cell,
			"target": null,
			"skill_id": ""
		}

## 마법 공격 또는 접근 행동을 반환한다.
## @param unit 공격 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func _magic_attack_or_approach(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var best_target: BattleUnit = _find_highest_threat_target(targets)
	if best_target == null:
		best_target = _find_closest_target(unit, targets)
	if best_target == null:
		return _wait_action(unit)

	var range_max: int = unit._source_data.get("range_max", 4)
	var best_cell: Vector2i = _find_cell_within_range(unit, best_target, move_cells, range_max)
	var dist: int = _manhattan_distance(best_cell, best_target.cell)

	if dist <= range_max:
		return {
			"type": "move_attack",
			"move_to": best_cell,
			"target": best_target,
			"skill_id": ""
		}
	else:
		return {
			"type": "move",
			"move_to": best_cell,
			"target": null,
			"skill_id": ""
		}

## 가장 HP 낮은 적을 공격하는 행동을 반환한다. (루시드 — 냉혹한 판단)
## @param unit 공격 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func _attack_lowest_hp_target(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	var lowest: BattleUnit = _find_lowest_hp_target(targets)
	if lowest == null:
		return _wait_action(unit)

	var attack_cell: Vector2i = _find_attack_cell(unit, lowest, move_cells, battle_map)
	var range_max: int = unit._source_data.get("range_max", 1)
	var dist: int = _manhattan_distance(attack_cell, lowest.cell)

	if dist <= range_max:
		return {
			"type": "move_attack",
			"move_to": attack_cell,
			"target": lowest,
			"skill_id": ""
		}
	else:
		return {
			"type": "move",
			"move_to": attack_cell,
			"target": null,
			"skill_id": ""
		}

## 가장 가까운 적을 찾는다.
## @param unit 기준 유닛
## @param targets 대상 배열
## @returns 가장 가까운 유닛 또는 null
func _find_closest_target(unit: BattleUnit, targets: Array[BattleUnit]) -> BattleUnit:
	var closest: BattleUnit = null
	var min_dist: int = 999
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		var dist: int = _manhattan_distance(unit.cell, t.cell)
		if dist < min_dist:
			min_dist = dist
			closest = t
	return closest

## HP가 가장 낮은 적을 찾는다.
## @param targets 대상 배열
## @returns HP 최저 유닛 또는 null
func _find_lowest_hp_target(targets: Array[BattleUnit]) -> BattleUnit:
	var lowest: BattleUnit = null
	var min_hp: int = 99999
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		if t.current_hp < min_hp:
			min_hp = t.current_hp
			lowest = t
	return lowest

## 고위협 대상을 찾는다. MATK 또는 ATK가 높은 유닛을 우선 타겟으로 한다.
## @param targets 대상 배열
## @returns 고위협 유닛 또는 null
func _find_highest_threat_target(targets: Array[BattleUnit]) -> BattleUnit:
	var best: BattleUnit = null
	var max_threat: int = -1
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		# 위협도 = max(ATK, MATK)
		var threat: int = maxi(t.stats.get("atk", 0), t.stats.get("matk", 0))
		if threat > max_threat:
			max_threat = threat
			best = t
	return best

## 힐러 또는 고위협 대상을 찾는다. support 클래스 유닛을 우선한다.
## @param targets 대상 배열
## @returns 우선 대상 유닛 또는 null
func _find_healer_or_threat(targets: Array[BattleUnit]) -> BattleUnit:
	# 힐러(support/healer 역할) 우선
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		var class_name_str: String = t._source_data.get("class", "")
		var role: String = t._source_data.get("role", "")
		if class_name_str in ["healer", "support", "cleric", "priest"] or role in ["healer", "support"]:
			return t

	# 힐러 없으면 고위협 대상
	return _find_highest_threat_target(targets)

## 대상에게 공격 가능한 최적 이동 셀을 찾는다.
## @param unit 공격 유닛
## @param target 공격 대상
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 최적 셀 좌표
func _find_attack_cell(unit: BattleUnit, target: BattleUnit, move_cells: Array[Vector2i], _battle_map: Node2D) -> Vector2i:
	var range_max: int = unit._source_data.get("range_max", 1)
	var range_min: int = unit._source_data.get("range_min", 1)
	var best_cell: Vector2i = unit.cell
	var best_dist: int = _manhattan_distance(unit.cell, target.cell)

	# 현재 위치에서 공격 가능한지 먼저 확인
	if best_dist >= range_min and best_dist <= range_max:
		return unit.cell

	# 이동 가능 셀 중 공격 범위 내이면서 대상에 가장 가까운 셀 선택
	for cell: Vector2i in move_cells:
		var dist: int = _manhattan_distance(cell, target.cell)
		if dist >= range_min and dist <= range_max:
			# 공격 가능 셀 — 유닛으로부터 가장 가까운 것 선호
			var dist_from_unit: int = _manhattan_distance(unit.cell, cell)
			var cur_best_dist_from_unit: int = _manhattan_distance(unit.cell, best_cell)
			if best_dist < range_min or best_dist > range_max or dist_from_unit < cur_best_dist_from_unit:
				best_cell = cell
				best_dist = dist
		elif dist < best_dist and (best_dist < range_min or best_dist > range_max):
			# 아직 공격 가능 셀을 못 찾았으면 가장 가까운 셀
			best_cell = cell
			best_dist = dist

	return best_cell

## 대상까지 특정 사거리 이내로 접근할 수 있는 이동 셀을 찾는다.
## @param unit 이동 유닛
## @param target 접근 대상
## @param move_cells 이동 가능 셀 배열
## @param max_range 목표 사거리
## @returns 최적 셀 좌표
func _find_cell_within_range(unit: BattleUnit, target: BattleUnit, move_cells: Array[Vector2i], max_range: int) -> Vector2i:
	var best_cell: Vector2i = unit.cell
	var best_dist: int = _manhattan_distance(unit.cell, target.cell)

	# 현재 위치가 이미 사거리 내면 그대로
	if best_dist <= max_range:
		return unit.cell

	for cell: Vector2i in move_cells:
		var dist: int = _manhattan_distance(cell, target.cell)
		if dist <= max_range:
			# 사거리 내 셀 — 가능한 먼 곳 (안전 거리 유지)
			if best_dist > max_range or dist > _manhattan_distance(best_cell, target.cell):
				best_cell = cell
				best_dist = dist
		elif dist < best_dist and best_dist > max_range:
			# 사거리 밖이지만 가장 가까운 셀
			best_cell = cell
			best_dist = dist

	return best_cell

## 적으로부터 가장 먼 이동 셀을 찾는다. (후퇴/은닉용)
## @param unit 이동 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @returns 가장 먼 셀 좌표
func _find_farthest_cell_from_targets(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i]) -> Vector2i:
	if move_cells.is_empty():
		return unit.cell

	var best_cell: Vector2i = unit.cell
	var max_min_dist: int = 0

	for cell: Vector2i in move_cells:
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

## 유닛 주변 특정 범위 내 적 수를 센다.
## @param unit 기준 유닛
## @param targets 적 유닛 배열
## @param range_val 범위 (맨해튼 거리)
## @returns 범위 내 적 수
func _count_targets_in_range(unit: BattleUnit, targets: Array[BattleUnit], range_val: int) -> int:
	var count: int = 0
	for t: BattleUnit in targets:
		if not t.is_alive():
			continue
		if _manhattan_distance(unit.cell, t.cell) <= range_val:
			count += 1
	return count

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

## 보스 AI 내부 상태를 초기화한다. 전투 시작 시 호출.
func reset() -> void:
	_phase_tracker.clear()
	_summon_count.clear()
	_turn_counter.clear()
	_clone_spawned.clear()

## 알 수 없는 보스용 기본 aggressive 행동을 반환한다.
## @param unit 유닛
## @param targets 적 유닛 배열
## @param move_cells 이동 가능 셀 배열
## @param battle_map 전투 맵 참조
## @returns 행동 Dictionary
func _default_aggressive(unit: BattleUnit, targets: Array[BattleUnit], move_cells: Array[Vector2i], battle_map: Node2D) -> Dictionary:
	return _melee_attack_or_approach(unit, targets, move_cells, battle_map)

## @fileoverview 경험치 & 레벨업 시스템. 행동별 EXP 산출, 레벨 차이 보정, 레벨업 스탯 성장을 처리한다.
class_name ExperienceSystem
extends RefCounted

# ── 상수 ──

## 최대 레벨
const MAX_LEVEL: int = 30

## 행동별 기본 EXP
const BASE_EXP: Dictionary = {
	"attack": 10,
	"heal": 10,
	"buff": 8,
	"item": 3,
}

## 킬 보너스 EXP
const KILL_BONUS_EXP: int = 30

## 레벨 차이 보정 최소값 (diff = -5일 때)
const LEVEL_DIFF_MIN_MULT: float = 0.25

## 레벨 차이 보정 최대값 (diff = +5일 때)
const LEVEL_DIFF_MAX_MULT: float = 2.0

## 레벨 차이 보정 범위
const LEVEL_DIFF_RANGE: int = 5

## 벤치 유닛 EXP 비율
const BENCH_EXP_RATIO: float = 0.5

# ── 멤버 변수 ──

## 유닛별 현재 누적 EXP 트래킹 {unit_id: int}
## BattleUnit에 current_exp / exp_to_next 필드가 추가되기 전까지 내부 관리
var _unit_exp: Dictionary = {}

# ── 경험치 계산 ──

## 행동 EXP를 계산한다
## @param action_type 행동 타입 ("attack", "heal", "buff", "item")
## @param unit_level 유닛 레벨
## @param target_level 대상 레벨
## @returns 획득 EXP
func calc_action_exp(action_type: String, unit_level: int, target_level: int) -> int:
	var base_exp: int = BASE_EXP.get(action_type, 0)
	if base_exp <= 0:
		return 0

	# 레벨 차이 보정
	var level_mult: float = _calc_level_diff_multiplier(unit_level, target_level)

	# 난이도 보정
	var diff_mult: float = _get_exp_difficulty_multiplier()

	var exp: int = maxi(int(float(base_exp) * level_mult * diff_mult), 1)
	return exp

## 킬 EXP를 계산한다
## @param unit_level 유닛 레벨
## @param target_level 처치 대상 레벨
## @returns 킬 보너스 EXP
func calc_kill_exp(unit_level: int, target_level: int) -> int:
	var level_mult: float = _calc_level_diff_multiplier(unit_level, target_level)
	var diff_mult: float = _get_exp_difficulty_multiplier()
	return maxi(int(float(KILL_BONUS_EXP) * level_mult * diff_mult), 1)

## 벤치(비참전) 유닛의 EXP를 계산한다
## @param active_units_exp_gained 참전 유닛들이 이번 전투에서 얻은 EXP 배열
## @returns 벤치 유닛이 받을 EXP
func calc_bench_exp(active_units_exp_gained: Array[int]) -> int:
	if active_units_exp_gained.is_empty():
		return 0
	var total: int = 0
	for exp: int in active_units_exp_gained:
		total += exp
	var avg: float = float(total) / float(active_units_exp_gained.size())
	return maxi(int(avg * BENCH_EXP_RATIO), 1)

# ── 경험치 적용 & 레벨업 ──

## 유닛에 경험치를 적용하고, 레벨업 시 스탯을 증가시킨다
## @param unit 대상 BattleUnit
## @param exp_amount 적용할 EXP 양
## @returns {"leveled_up": bool, "new_level": int, "stat_gains": Dictionary}
func apply_exp(unit: BattleUnit, exp_amount: int) -> Dictionary:
	var result: Dictionary = {
		"leveled_up": false,
		"new_level": unit.level,
		"stat_gains": {},
	}

	# 레벨 캡 도달 시 EXP 적용 안 함
	if unit.level >= MAX_LEVEL:
		return result

	# 현재 EXP 조회/초기화 (내부 트래킹)
	if not _unit_exp.has(unit.unit_id):
		_unit_exp[unit.unit_id] = 0
	_unit_exp[unit.unit_id] += exp_amount

	# 레벨업 경험치 확인
	var exp_to_next: int = get_exp_to_next_level(unit.level)

	# 연속 레벨업 가능
	while _unit_exp[unit.unit_id] >= exp_to_next and unit.level < MAX_LEVEL:
		_unit_exp[unit.unit_id] -= exp_to_next
		unit.level += 1
		result["leveled_up"] = true
		result["new_level"] = unit.level

		# 성장률 기반 스탯 증가
		var gains: Dictionary = _calc_level_up_stats(unit)
		_merge_stat_gains(result["stat_gains"], gains)

		# 유닛 스탯에 적용
		for stat_key: String in gains:
			unit.stats[stat_key] = unit.stats.get(stat_key, 0) + gains[stat_key]

		# HP/MP 전회복
		unit.current_hp = unit.stats.get("hp", 0)
		unit.current_mp = unit.stats.get("mp", 0)

		# 다음 레벨 필요 EXP 갱신
		exp_to_next = get_exp_to_next_level(unit.level)

	# EventBus 시그널
	var event_bus: Node = _get_event_bus()
	if event_bus:
		event_bus.exp_gained.emit(unit.unit_id, exp_amount)
		if result["leveled_up"]:
			event_bus.level_up.emit(unit.unit_id, result["new_level"], result["stat_gains"])

	return result

## 다음 레벨까지 필요한 EXP를 반환한다
## @param current_level 현재 레벨
## @returns 필요 EXP (level * 100)
func get_exp_to_next_level(current_level: int) -> int:
	return current_level * 100

# ── 내부 유틸 ──

## 레벨 차이에 따른 EXP 배율 계산 (선형 보간)
## @param unit_level 유닛 레벨
## @param target_level 대상 레벨
## @returns 배율 (0.25 ~ 2.0)
func _calc_level_diff_multiplier(unit_level: int, target_level: int) -> float:
	var diff: int = clampi(target_level - unit_level, -LEVEL_DIFF_RANGE, LEVEL_DIFF_RANGE)
	# diff = -5 → 0.25, diff = 0 → 1.0 (근사), diff = +5 → 2.0
	# 선형 보간: t = (diff + 5) / 10 → lerp(0.25, 2.0, t)
	var t: float = float(diff + LEVEL_DIFF_RANGE) / float(LEVEL_DIFF_RANGE * 2)
	return lerpf(LEVEL_DIFF_MIN_MULT, LEVEL_DIFF_MAX_MULT, t)

## 레벨업 시 성장률 기반 스탯 증가 계산
## 성장률의 정수 부분은 확정, 소수 부분은 확률로 +1
## @param unit 대상 유닛
## @returns {stat_key: gain_amount} Dictionary
func _calc_level_up_stats(unit: BattleUnit) -> Dictionary:
	var gains: Dictionary = {}
	var char_data: Dictionary = _get_character_data(unit.unit_id)
	var growth: Dictionary = char_data.get("growth", {})

	for stat_key: String in ["hp", "mp", "atk", "def", "matk", "mdef", "spd"]:
		var growth_val: float = float(growth.get(stat_key, 0.0))
		if growth_val <= 0.0:
			continue
		# 정수 부분은 확정 증가
		var guaranteed: int = int(growth_val)
		# 소수 부분은 확률로 +1
		var fraction: float = growth_val - float(guaranteed)
		var bonus: int = 1 if randf() < fraction else 0
		var total_gain: int = guaranteed + bonus
		if total_gain > 0:
			gains[stat_key] = total_gain

	return gains

## 스탯 증가분을 누적 병합한다
## @param target 누적 대상 Dictionary
## @param source 추가할 증가분 Dictionary
func _merge_stat_gains(target: Dictionary, source: Dictionary) -> void:
	for key: String in source:
		target[key] = target.get(key, 0) + source[key]

## 캐릭터 원본 데이터 조회 (성장률 참조용)
## @param unit_id 유닛 ID
## @returns 캐릭터 데이터 Dictionary
func _get_character_data(unit_id: String) -> Dictionary:
	var dm: Node = _get_data_manager()
	if dm == null:
		return {}
	# 플레이어 캐릭터 데이터 조회
	var char_data: Dictionary = dm.get_character(unit_id)
	if not char_data.is_empty():
		return char_data
	# 적 데이터에서도 조회 (적 유닛의 경우)
	return dm.get_enemy(unit_id)

## 난이도 EXP 배율 조회
## @returns EXP 배율 (기본 1.0)
func _get_exp_difficulty_multiplier() -> float:
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1.0
	var gm: Node = _get_game_manager()
	if gm == null:
		return 1.0
	var current_difficulty: String = gm.difficulty
	var diff_data: Dictionary = dm.difficulty_data.get(current_difficulty, {})
	return diff_data.get("exp_multiplier", 1.0) as float

## DataManager 싱글톤 참조 취득
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

## GameManager 싱글톤 참조 취득
func _get_game_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

## EventBus 싱글톤 참조 취득
func _get_event_bus() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("EventBus"):
		return tree.root.get_node("EventBus")
	return null

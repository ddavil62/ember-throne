## @fileoverview 상태이상/버프 관리 매니저. 7종 상태이상과 7종 버프의 적용, 해제,
## 턴 시작 효과 처리, 스탯 보정 배율 계산을 담당한다.
class_name StatusEffectManager
extends RefCounted

# ── 상수: 상태이상 ──

## 독 — 턴 시작 HP 10% 감소
const POISON_DAMAGE_RATIO: float = 0.10
const POISON_DEFAULT_DURATION: int = 3

## 화상 — 턴 시작 HP 5% 감소
const BURN_DAMAGE_RATIO: float = 0.05
const BURN_DEFAULT_DURATION: int = 2

## 빙결 — 행동 불가 (자동 스킵)
const FREEZE_DEFAULT_DURATION: int = 1

## 마비 — 50% 확률 행동 불가
const PARALYZE_CHANCE: float = 0.50
const PARALYZE_DEFAULT_DURATION: int = 2

## 침묵 — 스킬 사용 불가 (기본 공격만)
const SILENCE_DEFAULT_DURATION: int = 2

## 수면 — 행동 불가 + 피격 시 해제
const SLEEP_DEFAULT_DURATION: int = 3

## 재화 — 턴 시작 HP 8% 감소 + DEF -10%
const ASH_BURN_DAMAGE_RATIO: float = 0.08
const ASH_BURN_DEF_PENALTY: float = 0.10
const ASH_BURN_DEFAULT_DURATION: int = 3

# ── 상수: 디버프/상태이상 목록 ──

## 행동 불가 상태 ID 목록
const INCAPACITATE_STATUSES: Array[String] = ["freeze", "sleep"]

## 해로운 상태이상 ID 목록
const HARMFUL_STATUSES: Array[String] = [
	"poison", "burn", "freeze", "paralyze", "silence", "sleep", "ash_burn"
]

## 버프 ID 목록
const BUFF_STATUSES: Array[String] = [
	"atk_up", "def_up", "matk_up", "mdef_up", "spd_up", "regen", "oath_buff"
]

# ── 멤버 변수 ──

## 유닛별 상태이상 저장: {unit_id: Array[{status_id, duration, value}]}
var _effects: Dictionary = {}

# ── 상태이상 적용/제거 ──

## 유닛에 상태이상을 적용한다.
## 동일 상태가 이미 있으면 duration을 갱신(더 긴 쪽)한다.
## @param unit 대상 유닛
## @param status_id 상태이상 ID ("poison", "atk_up" 등)
## @param duration 지속 턴 수
## @param value 수치 값 (버프 퍼센트 등, 상태이상은 0.0)
## @returns 적용 성공 여부
func apply_status(unit: BattleUnit, status_id: String, duration: int, value: float = 0.0) -> bool:
	if unit == null or not unit.is_alive():
		return false

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		_effects[uid] = []

	# 기존 동일 상태 확인 — 있으면 duration 갱신
	var effects_list: Array = _effects[uid]
	for effect: Dictionary in effects_list:
		if effect.get("status_id", "") == status_id:
			# 더 긴 duration으로 갱신
			if duration > effect.get("duration", 0):
				effect["duration"] = duration
			# value도 더 높은 쪽으로 갱신
			if value > effect.get("value", 0.0):
				effect["value"] = value
			# BattleUnit에도 동기화
			unit.apply_status(status_id, effect["duration"])
			return true

	# 새 상태 추가
	var new_effect: Dictionary = {
		"status_id": status_id,
		"duration": duration,
		"value": value,
	}
	effects_list.append(new_effect)

	# BattleUnit 동기화
	unit.apply_status(status_id, duration)

	# EventBus 시그널
	EventBus.status_applied.emit(uid, status_id, duration)
	print("[StatusEffectManager] %s에 %s 적용 (%d턴, 값: %.2f)" % [uid, status_id, duration, value])

	return true

## 유닛의 특정 상태이상을 제거한다.
## @param unit 대상 유닛
## @param status_id 제거할 상태이상 ID
func remove_status(unit: BattleUnit, status_id: String) -> void:
	if unit == null:
		return

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return

	var effects_list: Array = _effects[uid]
	for i: int in range(effects_list.size() - 1, -1, -1):
		if effects_list[i].get("status_id", "") == status_id:
			effects_list.remove_at(i)
			break

	# BattleUnit 동기화
	unit.remove_status(status_id)

	# EventBus 시그널
	EventBus.status_removed.emit(uid, status_id)

## 유닛이 특정 상태이상을 가지고 있는지 확인한다.
## @param unit 대상 유닛
## @param status_id 확인할 상태이상 ID
## @returns 보유 시 true
func has_status(unit: BattleUnit, status_id: String) -> bool:
	if unit == null:
		return false

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return false

	for effect: Dictionary in _effects[uid]:
		if effect.get("status_id", "") == status_id:
			return true
	return false

# ── 행동 가능 여부 판정 ──

## 유닛이 이번 턴에 행동할 수 있는지 판정한다.
## freeze/sleep이면 무조건 불가, paralyze는 50% 확률.
## @param unit 대상 유닛
## @returns 행동 가능하면 true
func can_act(unit: BattleUnit) -> bool:
	if unit == null or not unit.is_alive():
		return false

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return true

	for effect: Dictionary in _effects[uid]:
		var sid: String = effect.get("status_id", "")

		# 빙결 — 행동 불가
		if sid == "freeze":
			print("[StatusEffectManager] %s 빙결 — 행동 불가" % uid)
			return false

		# 수면 — 행동 불가
		if sid == "sleep":
			print("[StatusEffectManager] %s 수면 — 행동 불가" % uid)
			return false

		# 마비 — 50% 확률 행동 불가
		if sid == "paralyze":
			if randf() < PARALYZE_CHANCE:
				print("[StatusEffectManager] %s 마비 — 행동 불가 (50%% 실패)" % uid)
				return false

	return true

# ── 턴 시작 효과 처리 ──

## 턴 시작 시 상태이상 효과를 적용하고 duration을 차감한다.
## 만료된 상태이상은 자동 제거한다.
## @param unit 대상 유닛
## @returns 이번 턴에 발생한 효과 결과 배열 [{type, status_id, amount, ...}]
func process_turn_start(unit: BattleUnit) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if unit == null or not unit.is_alive():
		return results

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return results

	var expired: Array[String] = []
	var effects_list: Array = _effects[uid]

	for effect: Dictionary in effects_list:
		var sid: String = effect.get("status_id", "")

		# 도트 데미지 처리
		match sid:
			"poison":
				var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * POISON_DAMAGE_RATIO), 1)
				unit.take_damage(damage)
				results.append({"type": "damage", "status_id": sid, "amount": damage})
				print("[StatusEffectManager] %s 독 데미지: %d" % [uid, damage])

			"burn":
				var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * BURN_DAMAGE_RATIO), 1)
				unit.take_damage(damage)
				results.append({"type": "damage", "status_id": sid, "amount": damage})
				print("[StatusEffectManager] %s 화상 데미지: %d" % [uid, damage])

			"ash_burn":
				var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * ASH_BURN_DAMAGE_RATIO), 1)
				unit.take_damage(damage)
				results.append({"type": "damage", "status_id": sid, "amount": damage})
				print("[StatusEffectManager] %s 재화 데미지: %d" % [uid, damage])

			"regen":
				var heal: int = maxi(int(float(unit.stats.get("hp", 0)) * 0.05), 1)
				unit.heal(heal)
				results.append({"type": "heal", "status_id": sid, "amount": heal})
				print("[StatusEffectManager] %s 재생 회복: %d" % [uid, heal])

		# duration 차감
		effect["duration"] = effect.get("duration", 0) - 1
		if effect["duration"] <= 0:
			expired.append(sid)

	# 만료 상태 제거
	for sid: String in expired:
		remove_status(unit, sid)
		results.append({"type": "expired", "status_id": sid})

	return results

# ── 스탯 보정 배율 ──

## 버프/디버프에 의한 스탯 배율을 계산한다.
## 기본값 1.0에 각 버프의 value를 가감한다.
## @param unit 대상 유닛
## @param stat 스탯 이름 ("atk", "def", "matk", "mdef", "spd")
## @returns 배율 (1.0 기반, 예: ATK +15%이면 1.15)
func get_stat_modifier(unit: BattleUnit, stat: String) -> float:
	if unit == null:
		return 1.0

	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return 1.0

	var modifier: float = 1.0

	for effect: Dictionary in _effects[uid]:
		var sid: String = effect.get("status_id", "")
		var value: float = effect.get("value", 0.0)

		match sid:
			"atk_up":
				if stat == "atk":
					modifier += value
			"def_up":
				if stat == "def":
					modifier += value
			"matk_up":
				if stat == "matk":
					modifier += value
			"mdef_up":
				if stat == "mdef":
					modifier += value
			"spd_up":
				if stat == "spd":
					modifier += value
			"oath_buff":
				# ATK/DEF 동시 상승
				if stat == "atk" or stat == "def":
					modifier += value
			"ash_burn":
				# DEF -10%
				if stat == "def":
					modifier -= ASH_BURN_DEF_PENALTY

	return maxf(modifier, 0.0)

# ── 피격 시 처리 ──

## 유닛이 피격당했을 때 호출한다. 수면 상태이면 해제한다.
## @param unit 피격당한 유닛
func on_hit(unit: BattleUnit) -> void:
	if unit == null:
		return
	if has_status(unit, "sleep"):
		remove_status(unit, "sleep")
		print("[StatusEffectManager] %s 피격 — 수면 해제" % unit.unit_id)

# ── 유틸 ──

## 유닛의 활성 상태이상 목록을 반환한다.
## @param unit 대상 유닛
## @returns 상태이상 Dictionary 배열
func get_active_effects(unit: BattleUnit) -> Array[Dictionary]:
	if unit == null:
		return []
	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return []
	var result: Array[Dictionary] = []
	for effect: Dictionary in _effects[uid]:
		result.append(effect.duplicate())
	return result

## 유닛의 모든 상태이상을 제거한다. (전투 종료 시 등)
## @param unit 대상 유닛
func clear_all(unit: BattleUnit) -> void:
	if unit == null:
		return
	var uid: String = unit.unit_id
	if not _effects.has(uid):
		return
	var to_remove: Array[String] = []
	for effect: Dictionary in _effects[uid]:
		to_remove.append(effect.get("status_id", ""))
	for sid: String in to_remove:
		remove_status(unit, sid)

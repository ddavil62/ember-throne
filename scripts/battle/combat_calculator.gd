## @fileoverview 전투 데미지, 명중률, 크리티컬 공식 계산기.
## 물리/마법 데미지, 치유량, 명중률, 크리티컬율을 산출한다.
class_name CombatCalculator
extends RefCounted

# ── 상수 ──

## 크리티컬 데미지 배율
const CRIT_MULTIPLIER: float = 2.5

## 최소 데미지 (0 이하 방지)
const MIN_DAMAGE: int = 1

## 최소 명중률 (%)
const MIN_HIT_RATE: int = 10

## 최대 명중률 (%)
const MAX_HIT_RATE: int = 100

## 최소 크리티컬율 (%)
const MIN_CRIT_RATE: int = 0

## 최대 크리티컬율 (%)
const MAX_CRIT_RATE: int = 50

# ── 물리 데미지 ──

## 물리 데미지를 계산한다
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param skill_mult 스킬 배율 (기본 공격 시 1.0)
## @param grid GridSystem (지형 조회용)
## @returns {"damage": int, "is_crit": bool, "hit": bool}
func calc_physical_damage(attacker: BattleUnit, defender: BattleUnit, skill_mult: float, grid: GridSystem) -> Dictionary:
	var result: Dictionary = {"damage": 0, "is_crit": false, "hit": false}

	# 명중 판정
	var hit_rate: int = calc_hit_rate(attacker, defender, grid)
	var hit_roll: int = randi() % 100
	if hit_roll >= hit_rate:
		return result  # 빗나감

	result["hit"] = true

	# 기본 데미지: ATK * skill_mult - DEF / 2
	var atk: float = float(attacker.stats.get("atk", 0))
	var def: float = float(defender.stats.get("def", 0))

	# 난이도 보정 (적 공격자인 경우)
	if attacker.team == "enemy":
		atk *= _get_difficulty_multiplier("enemy_atk_multiplier")
	if defender.team == "enemy":
		def *= _get_difficulty_multiplier("enemy_def_multiplier")

	var base: float = atk * skill_mult - def / 2.0

	# 지형 방어 보정 (방어자 위치 기준)
	var terrain_mod: float = get_terrain_def_bonus(defender.cell, grid)

	# 무기 상성 보정
	var attacker_weapon_type: String = _get_unit_weapon_type(attacker)
	var defender_weapon_type: String = _get_unit_weapon_type(defender)
	var weapon_mod: float = WeaponTriangle.get_weapon_damage_mod(attacker_weapon_type, defender_weapon_type)

	# 크리티컬 판정
	var crit_rate: int = calc_crit_rate(attacker, defender)
	var crit_roll: int = randi() % 100
	var crit_mod: float = 1.0
	if crit_roll < crit_rate:
		crit_mod = CRIT_MULTIPLIER
		result["is_crit"] = true

	# 최종 데미지 계산
	var damage: float = base * terrain_mod * weapon_mod * crit_mod
	result["damage"] = maxi(int(damage), MIN_DAMAGE)

	return result

# ── 마법 데미지 ──

## 마법 데미지를 계산한다
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param skill_mult 스킬 배율
## @param element 마법 속성 ("fire", "wind", "thunder" 등)
## @param grid GridSystem (지형 조회용)
## @returns {"damage": int, "is_crit": bool, "hit": bool}
func calc_magic_damage(attacker: BattleUnit, defender: BattleUnit, skill_mult: float, element: String, grid: GridSystem) -> Dictionary:
	var result: Dictionary = {"damage": 0, "is_crit": false, "hit": false}

	# 명중 판정
	var hit_rate: int = calc_hit_rate(attacker, defender, grid)
	result["hit"] = (randi() % 100) < hit_rate
	if not result["hit"]:
		return result

	# 기본 데미지: MATK * skill_mult - MDEF / 2
	var matk: float = float(attacker.stats.get("matk", 0))
	var mdef: float = float(defender.stats.get("mdef", 0))

	# 난이도 보정
	if attacker.team == "enemy":
		matk *= _get_difficulty_multiplier("enemy_atk_multiplier")
	if defender.team == "enemy":
		mdef *= _get_difficulty_multiplier("enemy_def_multiplier")

	var base: float = matk * skill_mult - mdef / 2.0

	# 마법 상성 보정
	var magic_mod: float = WeaponTriangle.get_magic_damage_mod(element, _get_defender_element(defender))

	# 지형 방어 보정
	var terrain_mod: float = get_terrain_def_bonus(defender.cell, grid)

	# 크리티컬 판정
	var crit_rate: int = calc_crit_rate(attacker, defender)
	var crit_mod: float = 1.0
	if (randi() % 100) < crit_rate:
		crit_mod = CRIT_MULTIPLIER
		result["is_crit"] = true

	# 최종 데미지
	var damage: float = base * terrain_mod * magic_mod * crit_mod
	result["damage"] = maxi(int(damage), MIN_DAMAGE)

	return result

# ── 치유량 ──

## 치유량을 계산한다
## @param healer 힐러 유닛
## @param target 대상 유닛
## @param skill_mult 스킬 배율
## @returns 치유량 (int)
func calc_heal_amount(healer: BattleUnit, target: BattleUnit, skill_mult: float) -> int:
	var matk: float = float(healer.stats.get("matk", 0))
	var base_heal: float = matk * skill_mult
	# 최대 HP를 넘지 않도록 제한
	var max_heal: int = target.stats.get("hp", 0) - target.current_hp
	return mini(maxi(int(base_heal), 1), maxi(max_heal, 0))

# ── 명중률 ──

## 명중률을 계산한다
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param grid GridSystem (지형 조회용)
## @returns 명중률 (10~100)
func calc_hit_rate(attacker: BattleUnit, defender: BattleUnit, grid: GridSystem) -> int:
	# 무기 기본 명중 (무기가 없으면 100)
	var accuracy: int = _get_weapon_hit(attacker)

	# 지형 회피 보정 (방어자 위치)
	var terrain_evade: int = get_terrain_evade_bonus(defender.cell, grid)

	# 무기 상성 명중 보정
	var attacker_weapon_type: String = _get_unit_weapon_type(attacker)
	var defender_weapon_type: String = _get_unit_weapon_type(defender)
	var weapon_hit_mod: float = WeaponTriangle.get_weapon_hit_mod(attacker_weapon_type, defender_weapon_type)

	# 명중률 = 기본 명중 * 무기 상성 보정 - 지형 회피
	var hit_rate: int = int(float(accuracy) * weapon_hit_mod) - terrain_evade

	return clampi(hit_rate, MIN_HIT_RATE, MAX_HIT_RATE)

# ── 크리티컬율 ──

## 크리티컬율을 계산한다
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @returns 크리티컬율 (0~50)
func calc_crit_rate(attacker: BattleUnit, defender: BattleUnit) -> int:
	# 무기 기본 크리티컬
	var weapon_crit: int = _get_weapon_crit(attacker)

	# SPD 차이 보정
	var attacker_spd: float = float(attacker.stats.get("spd", 0))
	var defender_spd: float = float(defender.stats.get("spd", 0))
	var spd_bonus: float = (attacker_spd - defender_spd) / 4.0

	var crit_rate: int = int(float(weapon_crit) + spd_bonus)
	return clampi(crit_rate, MIN_CRIT_RATE, MAX_CRIT_RATE)

# ── 지형 보정 조회 ──

## 방어자 위치의 지형 방어 보정을 반환한다
## @param cell 셀 좌표
## @param grid GridSystem
## @returns 방어 보정 배율 (예: 지형 def_bonus=10이면 0.9 = 10% 데미지 감소)
func get_terrain_def_bonus(cell: Vector2i, grid: GridSystem) -> float:
	var terrain_type: String = grid.get_tile_at(cell)
	if terrain_type.is_empty():
		return 1.0
	var dm: Node = _get_data_manager()
	if dm == null:
		return 1.0
	var terrain_data: Dictionary = dm.get_terrain(terrain_type)
	var def_bonus: int = terrain_data.get("def_bonus", 0)
	# def_bonus는 퍼센트 값 (예: 10 → 10% 데미지 감소)
	return 1.0 - float(def_bonus) / 100.0

## 방어자 위치의 지형 회피 보정을 반환한다
## @param cell 셀 좌표
## @param grid GridSystem
## @returns 회피 보정 값 (퍼센트)
func get_terrain_evade_bonus(cell: Vector2i, grid: GridSystem) -> int:
	var terrain_type: String = grid.get_tile_at(cell)
	if terrain_type.is_empty():
		return 0
	var dm: Node = _get_data_manager()
	if dm == null:
		return 0
	var terrain_data: Dictionary = dm.get_terrain(terrain_type)
	return terrain_data.get("evade_bonus", 0) as int

# ── 내부 유틸 ──

## 유닛의 장비 무기 타입 조회
## @param unit 대상 유닛
## @returns 무기 타입 문자열 (예: "sword", "lance")
func _get_unit_weapon_type(unit: BattleUnit) -> String:
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return ""
	var dm: Node = _get_data_manager()
	if dm == null:
		return ""
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("type", "")

## 유닛의 무기 명중값 조회
## @param unit 대상 유닛
## @returns 명중값 (무기 없으면 100)
func _get_weapon_hit(unit: BattleUnit) -> int:
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return 100
	var dm: Node = _get_data_manager()
	if dm == null:
		return 100
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("hit", 100) as int

## 유닛의 무기 크리티컬값 조회
## @param unit 대상 유닛
## @returns 크리티컬 기본값 (무기 없으면 0)
func _get_weapon_crit(unit: BattleUnit) -> int:
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return 0
	var dm: Node = _get_data_manager()
	if dm == null:
		return 0
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("crit", 0) as int

## 방어자의 마법 속성 추론 (스킬 기반, 현재는 빈 문자열 반환)
## @param defender 방어 유닛
## @returns 마법 속성 문자열
func _get_defender_element(_defender: BattleUnit) -> String:
	# 현재 유닛에 고유 속성 필드가 없으므로 빈 문자열 반환
	# 추후 유닛 속성 시스템 추가 시 확장
	return ""

## 난이도 멀티플라이어 조회
## @param key 멀티플라이어 키 (예: "enemy_atk_multiplier")
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

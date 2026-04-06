## @fileoverview 유대 관계 시스템. 13쌍의 유대 레벨 관리, 인접 배치 패시브 효과 적용,
## 유대 대화 열람 가능 여부를 담당한다.
class_name BondSystem
extends RefCounted

# ── 상수 ──

## 유대 레벨 초기값 (합류 시 자동 부여)
const DEFAULT_BOND_LEVEL: int = 1

## 인접 전투 카운트 조건 임계값
const ADJACENT_COUNT_THRESHOLD: int = 5

## 에리스 사망 플래그 키
const ERIS_DEATH_FLAG: String = "eris_death"

## 에리스 사망 후 볼트에게 적용되는 상시 방어 보정
const ERIS_SHIELD_DEF_PERCENT: int = 15

# ── 내부 변수 ──

## DataManager에서 로드한 유대 데이터 캐시
var _bonds_cache: Array = []

# ── 초기화 ──

func _init() -> void:
	_load_bonds()

## DataManager로부터 유대 데이터를 로드한다.
func _load_bonds() -> void:
	var dm: Node = _get_data_manager()
	if dm:
		_bonds_cache = dm.bonds

## EventBus의 scene_ended 시그널에 연결한다.
## RefCounted이므로 외부에서 명시적으로 호출해야 한다.
## @param scene_id 종료된 씬 ID
func on_scene_ended(scene_id: String) -> void:
	var triggered: Array = check_bond_triggers(scene_id)
	for entry in triggered:
		print("[BondSystem] 유대 레벨업: %s (%s) Lv.%d -> Lv.%d" % [
			entry.get("name_ko", ""),
			str(entry.get("pair", [])),
			entry.get("old_level", 0),
			entry.get("new_level", 0),
		])

# ── 유대 레벨 관리 ──

## 유대 쌍의 현재 레벨을 조회한다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @returns 현재 유대 레벨 (관계 없으면 0)
func get_bond_level(char_a: String, char_b: String) -> int:
	var bond: Dictionary = get_bond_data(char_a, char_b)
	if bond.is_empty():
		return 0
	var pair_key: String = _make_pair_key(char_a, char_b)
	var flag_key: String = "bond_lv_%s" % pair_key
	var gm: Node = _get_game_manager()
	if gm == null:
		return DEFAULT_BOND_LEVEL
	return gm.get_flag(flag_key, DEFAULT_BOND_LEVEL)

## 유대 쌍의 레벨을 설정한다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @param level 설정할 레벨
func set_bond_level(char_a: String, char_b: String, level: int) -> void:
	var bond: Dictionary = get_bond_data(char_a, char_b)
	if bond.is_empty():
		push_warning("[BondSystem] 유대 관계 없음: %s - %s" % [char_a, char_b])
		return
	# max_level 초과 방지
	var max_lv: int = bond.get("max_level", 1)
	level = clampi(level, DEFAULT_BOND_LEVEL, max_lv)

	var pair_key: String = _make_pair_key(char_a, char_b)
	var flag_key: String = "bond_lv_%s" % pair_key
	var gm: Node = _get_game_manager()
	if gm == null:
		push_error("[BondSystem] GameManager 접근 불가")
		return
	gm.set_flag(flag_key, level)

# ── 유대 레벨업 트리거 확인 ──

## 특정 씬 종료 시 레벨업 조건을 확인하고 해당하는 유대를 승급시킨다.
## @param scene_id 종료된 씬 ID (예: "2-7")
## @returns 레벨업된 유대 정보 배열 [{pair, old_level, new_level, name_ko}]
func check_bond_triggers(scene_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for bond in _bonds_cache:
		var pair: Array = bond.get("pair", [])
		if pair.size() < 2:
			continue
		var char_a: String = pair[0]
		var char_b: String = pair[1]
		var current_lv: int = get_bond_level(char_a, char_b)
		var max_lv: int = bond.get("max_level", 1)

		# Lv1 -> Lv2 승급 확인
		if current_lv == 1 and max_lv >= 2:
			var trigger: Variant = bond.get("lv2_trigger")
			if trigger is Dictionary and trigger.get("scene", "") == scene_id:
				if _check_manual_condition(char_a, char_b, trigger):
					set_bond_level(char_a, char_b, 2)
					results.append({
						"pair": pair,
						"old_level": 1,
						"new_level": 2,
						"name_ko": bond.get("name_ko", ""),
					})

		# Lv2 -> Lv3 승급 확인
		elif current_lv == 2 and max_lv >= 3:
			var trigger: Variant = bond.get("lv3_trigger")
			if trigger is Dictionary and trigger.get("scene", "") == scene_id:
				if _check_manual_condition(char_a, char_b, trigger):
					set_bond_level(char_a, char_b, 3)
					results.append({
						"pair": pair,
						"old_level": 2,
						"new_level": 3,
						"name_ko": bond.get("name_ko", ""),
					})
	return results

## 수동 조건(manual_condition)을 확인한다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @param trigger 트리거 Dictionary
## @returns 조건 충족 여부
func _check_manual_condition(char_a: String, char_b: String, trigger: Dictionary) -> bool:
	var condition: String = trigger.get("manual_condition", "")
	if condition == "":
		return true
	var gm: Node = _get_game_manager()
	if gm == null:
		return false

	# "adjacent_battle_count_5" 조건: 인접 전투 카운트 5 이상
	if condition == "adjacent_battle_count_5":
		var pair_key: String = _make_pair_key(char_a, char_b)
		var count_key: String = "bond_adjacent_%s_count" % pair_key
		var count: int = gm.get_flag(count_key, 0)
		return count >= ADJACENT_COUNT_THRESHOLD

	# 그 외 조건은 GameManager 플래그 존재 여부로 판단
	return gm.has_flag(condition)

# ── 인접 효과 계산 ──

## 전투에서 유닛이 인접 유닛들과의 유대로 받는 스탯 보정을 계산한다.
## 여러 유대 효과가 중첩될 경우 합산한다.
## @param unit_id 대상 유닛 ID
## @param adjacent_unit_ids 인접한 유닛 ID 배열
## @returns 합산된 스탯 보정 Dictionary (예: {"atk_percent": 10, "def_percent": 5})
func calc_adjacency_bonus(unit_id: String, adjacent_unit_ids: Array[String]) -> Dictionary:
	var bonus: Dictionary = {}

	# 에리스 사망 후 볼트 특수 처리: 인접 효과 대신 상시 패시브
	if unit_id == "voldt" and _is_eris_dead():
		var voldt_eris_bond: Dictionary = get_bond_data("voldt", "eris")
		if not voldt_eris_bond.is_empty():
			var bond_lv: int = get_bond_level("voldt", "eris")
			if bond_lv >= 2:
				bonus["def_percent"] = bonus.get("def_percent", 0) + ERIS_SHIELD_DEF_PERCENT
				return bonus

	for adj_id in adjacent_unit_ids:
		var bond: Dictionary = get_bond_data(unit_id, adj_id)
		if bond.is_empty():
			continue

		# 에리스 사망 후에는 voldt-eris 인접 효과를 적용하지 않는다
		var pair: Array = bond.get("pair", [])
		if _is_eris_dead() and pair.has("voldt") and pair.has("eris"):
			continue

		var bond_lv: int = get_bond_level(unit_id, adj_id)
		if bond_lv < 1:
			continue

		var effects: Dictionary = bond.get("effects", {})
		var lv_key: String = "lv%d" % bond_lv
		var lv_effects: Dictionary = effects.get(lv_key, {})

		# "both" 효과: 양쪽 모두 적용 (원본 데이터 보호를 위해 복사)
		var unit_bonus: Dictionary = lv_effects.get("both", {}).duplicate()

		# 특정 캐릭터 대상 효과: unit_id와 일치할 때만 적용
		if lv_effects.has(unit_id):
			var specific: Dictionary = lv_effects.get(unit_id, {})
			for stat_key in specific:
				unit_bonus[stat_key] = unit_bonus.get(stat_key, 0) + specific[stat_key]

		# 합산
		for stat_key in unit_bonus:
			bonus[stat_key] = bonus.get(stat_key, 0) + unit_bonus[stat_key]

	return bonus

## 에리스 사망 여부를 확인한다.
## @returns 사망 여부
func _is_eris_dead() -> bool:
	var gm: Node = _get_game_manager()
	if gm == null:
		return false
	return gm.has_flag(ERIS_DEATH_FLAG)

# ── 인접 전투 카운트 추적 ──

## 전투에서 두 유닛이 인접 배치되었을 때 카운트를 증가시킨다.
## 유대 관계가 있는 쌍만 추적한다.
## @param unit_a 첫 번째 유닛 ID
## @param unit_b 두 번째 유닛 ID
func track_adjacency(unit_a: String, unit_b: String) -> void:
	var bond: Dictionary = get_bond_data(unit_a, unit_b)
	if bond.is_empty():
		return

	var gm: Node = _get_game_manager()
	if gm == null:
		return

	var pair_key: String = _make_pair_key(unit_a, unit_b)
	var count_key: String = "bond_adjacent_%s_count" % pair_key
	var current_count: int = gm.get_flag(count_key, 0)
	gm.set_flag(count_key, current_count + 1)

# ── 유대 정보 조회 ──

## 캐릭터의 모든 유대 관계를 조회한다.
## 각 항목에 현재 레벨, 효과, 파트너 ID를 포함한다.
## @param char_id 캐릭터 ID
## @returns 유대 정보 배열
func get_character_bonds(char_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for bond in _bonds_cache:
		var pair: Array = bond.get("pair", [])
		if pair.size() < 2:
			continue
		if not pair.has(char_id):
			continue

		var partner_id: String = pair[0] if pair[1] == char_id else pair[1]
		var bond_lv: int = get_bond_level(pair[0], pair[1])
		var effects: Dictionary = bond.get("effects", {})
		var lv_key: String = "lv%d" % bond_lv
		var current_effects: Dictionary = effects.get(lv_key, {})

		results.append({
			"pair": pair,
			"partner_id": partner_id,
			"name_ko": bond.get("name_ko", ""),
			"name_en": bond.get("name_en", ""),
			"type": bond.get("type", ""),
			"level": bond_lv,
			"max_level": bond.get("max_level", 1),
			"effects": current_effects,
			"lore_ko": bond.get("lore_ko", ""),
		})
	return results

## 모든 유대 관계의 현재 상태를 반환한다.
## @returns 13쌍 전체의 현재 레벨, 효과 정보 배열
func get_all_bonds_status() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for bond in _bonds_cache:
		var pair: Array = bond.get("pair", [])
		if pair.size() < 2:
			continue

		var bond_lv: int = get_bond_level(pair[0], pair[1])
		var effects: Dictionary = bond.get("effects", {})
		var lv_key: String = "lv%d" % bond_lv
		var current_effects: Dictionary = effects.get(lv_key, {})

		results.append({
			"pair": pair,
			"name_ko": bond.get("name_ko", ""),
			"name_en": bond.get("name_en", ""),
			"type": bond.get("type", ""),
			"level": bond_lv,
			"max_level": bond.get("max_level", 1),
			"effects": current_effects,
			"lore_ko": bond.get("lore_ko", ""),
		})
	return results

# ── 유대 대화 열람 ──

## 유대 대화를 열람할 수 있는지 확인한다.
## 유대 레벨이 1 이상이면 거점에서 유대 대화를 열람할 수 있다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @returns 열람 가능 여부
func is_bond_conversation_available(char_a: String, char_b: String) -> bool:
	var bond: Dictionary = get_bond_data(char_a, char_b)
	if bond.is_empty():
		return false
	return get_bond_level(char_a, char_b) >= DEFAULT_BOND_LEVEL

# ── 유대 데이터 조회 ──

## bonds_data에서 두 캐릭터가 포함된 유대 엔트리를 반환한다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @returns 유대 데이터 Dictionary (없으면 빈 Dictionary)
func get_bond_data(char_a: String, char_b: String) -> Dictionary:
	for bond in _bonds_cache:
		var pair: Array = bond.get("pair", [])
		if pair.size() < 2:
			continue
		if pair.has(char_a) and pair.has(char_b):
			return bond
	return {}

# ── 볼트-에리스 특수 패시브 ──

## 에리스 사망 후 볼트에게 적용되는 "에리스의 방패" 상시 패시브를 계산한다.
## 인접 효과와 별개로, 에리스 사망 + 유대 Lv2일 때 상시 적용된다.
## @param unit_id 대상 유닛 ID
## @returns 패시브 보정 Dictionary (해당 없으면 빈 Dictionary)
func get_eris_shield_passive(unit_id: String) -> Dictionary:
	if unit_id != "voldt":
		return {}
	if not _is_eris_dead():
		return {}
	var bond_lv: int = get_bond_level("voldt", "eris")
	if bond_lv < 2:
		return {}
	return {"def_percent": ERIS_SHIELD_DEF_PERCENT}

# ── 유틸리티 ──

## 두 캐릭터 ID를 알파벳순으로 정렬하여 유니크 키를 생성한다.
## @param char_a 첫 번째 캐릭터 ID
## @param char_b 두 번째 캐릭터 ID
## @returns 정렬된 쌍 키 (예: "kael_seria")
func _make_pair_key(char_a: String, char_b: String) -> String:
	if char_a < char_b:
		return char_a + "_" + char_b
	return char_b + "_" + char_a

# ── 싱글톤 헬퍼 ──

## EventBus 싱글톤을 반환한다.
## @returns EventBus 노드 또는 null
func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EventBus")

## GameManager 싱글톤을 반환한다.
## @returns GameManager 노드 또는 null
func _get_game_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameManager")

## DataManager 싱글톤을 반환한다.
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("DataManager")

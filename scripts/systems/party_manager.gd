## @fileoverview 파티 관리 시스템. 파티원 합류/이탈, 출격 편성, 레벨업, 장비 착탈을 담당한다.
class_name PartyManagerClass
extends Node

# ── 상수 ──

## 최대 파티 인원
const MAX_PARTY_SIZE := 12
## 최대 출격 인원
const MAX_ACTIVE_SIZE := 8
## 고정 출격 캐릭터 (카엘은 항상 출격)
const MANDATORY_CHAR := "kael"
## 스탯 목록 (합산 계산용)
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "matk", "mdef", "spd", "mov"]

# ── 파티 데이터 ──

## 현재 파티원 정보 배열 (최대 12명)
## 각 원소: {id, level, exp, current_hp, current_mp, equipment: {weapon, armor, accessory}, skills, status}
var party: Array[Dictionary] = []

## 출격 파티 ID 배열 (최대 8명, kael 항상 포함)
var active_party: Array[String] = []

# ── 초기화 ──

func _ready() -> void:
	pass

## 1막 시작 시 초기 파티를 구성한다. (kael, seria, rinen 기본 합류)
func init_default_party() -> void:
	add_character("kael", 1)
	add_character("seria", 1)
	add_character("rinen", 2)
	set_active(["kael", "seria", "rinen"])

# ── 파티원 관리 ──

## 캐릭터를 파티에 합류시킨다.
## @param char_id 캐릭터 ID
## @param level 초기 레벨 (기본 1)
func add_character(char_id: String, level: int = 1) -> void:
	# 이미 파티에 있으면 무시
	if get_party_member(char_id).size() > 0:
		push_warning("[PartyManager] 이미 파티에 존재: %s" % char_id)
		return
	# 최대 인원 확인
	if party.size() >= MAX_PARTY_SIZE:
		push_warning("[PartyManager] 파티 인원 초과: %s" % char_id)
		return

	var dm: Node = get_node("/root/DataManager")
	var char_data: Dictionary = dm.get_character(char_id)
	if char_data.is_empty():
		push_error("[PartyManager] 캐릭터 데이터 없음: %s" % char_id)
		return

	var base_stats: Dictionary = char_data.get("stats_lv1", {})
	var growth: Dictionary = char_data.get("growth", {})

	# 레벨에 따른 기본 스탯 계산
	var stats: Dictionary = _calc_base_stats(base_stats, growth, level)

	var member: Dictionary = {
		"id": char_id,
		"level": level,
		"exp": 0,
		"current_hp": stats.get("hp", 1),
		"current_mp": stats.get("mp", 0),
		"equipment": {
			"weapon": "",
			"armor": "",
			"accessory": "",
		},
		"skills": char_data.get("skills", []).duplicate(),
		"status": [],
	}
	party.append(member)

	# 이벤트 발행
	var eb: Node = get_node("/root/EventBus")
	eb.character_joined.emit(char_id)
	print("[PartyManager] 합류: %s (Lv.%d)" % [char_id, level])

## 캐릭터를 파티에서 이탈시킨다.
## @param char_id 캐릭터 ID
func remove_character(char_id: String) -> void:
	# 카엘은 제거 불가
	if char_id == MANDATORY_CHAR:
		push_warning("[PartyManager] 카엘은 파티에서 제거할 수 없다")
		return
	for i in range(party.size()):
		if party[i]["id"] == char_id:
			# 장비 해제 → 인벤토리 반환
			_return_equipment(char_id)
			party.remove_at(i)
			# 출격 파티에서도 제거
			var idx := active_party.find(char_id)
			if idx >= 0:
				active_party.remove_at(idx)
			print("[PartyManager] 이탈: %s" % char_id)
			return
	push_warning("[PartyManager] 파티에 없는 캐릭터: %s" % char_id)

## 출격 파티를 설정한다.
## @param char_ids 출격 캐릭터 ID 배열
func set_active(char_ids: Array[String]) -> void:
	# 카엘이 포함되어 있는지 확인
	if not char_ids.has(MANDATORY_CHAR):
		char_ids.insert(0, MANDATORY_CHAR)

	# 최대 인원 제한
	if char_ids.size() > MAX_ACTIVE_SIZE:
		char_ids.resize(MAX_ACTIVE_SIZE)

	# 유효한 캐릭터만 필터
	var valid: Array[String] = []
	for cid in char_ids:
		if get_party_member(cid).size() > 0:
			valid.append(cid)
	active_party = valid
	print("[PartyManager] 출격 파티 설정: %s" % str(active_party))

## 파티원 정보를 조회한다.
## @param char_id 캐릭터 ID
## @returns 파티원 Dictionary 또는 빈 Dictionary
func get_party_member(char_id: String) -> Dictionary:
	for member in party:
		if member["id"] == char_id:
			return member
	return {}

## 출격 파티 정보를 배열로 반환한다.
## @returns 출격 파티원 Dictionary 배열
func get_active_party() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for cid in active_party:
		var member := get_party_member(cid)
		if member.size() > 0:
			result.append(member)
	return result

# ── 레벨/경험치 ──

## 경험치를 획득한다. 레벨업 조건 충족 시 자동 레벨업한다.
## @param char_id 캐릭터 ID
## @param amount 획득 경험치
func gain_exp(char_id: String, amount: int) -> void:
	var member := get_party_member(char_id)
	if member.is_empty():
		return
	member["exp"] += amount
	var eb: Node = get_node("/root/EventBus")
	eb.exp_gained.emit(char_id, amount)

	# 레벨업 확인 (100 EXP 당 1 레벨)
	while member["exp"] >= _exp_to_next_level(member["level"]):
		member["exp"] -= _exp_to_next_level(member["level"])
		level_up(char_id)

## 레벨업 처리. 성장률 기반 스탯 증가를 적용한다.
## @param char_id 캐릭터 ID
func level_up(char_id: String) -> void:
	var member := get_party_member(char_id)
	if member.is_empty():
		return

	var dm: Node = get_node("/root/DataManager")
	var char_data: Dictionary = dm.get_character(char_id)
	var growth: Dictionary = char_data.get("growth", {})

	member["level"] += 1

	# 성장률에 따른 스탯 증가 계산
	var stat_gains: Dictionary = {}
	for key in STAT_KEYS:
		var growth_val: float = growth.get(key, 0.0)
		# 정수부는 확정, 소수부는 확률
		var guaranteed: int = int(growth_val)
		var chance: float = growth_val - guaranteed
		var gain: int = guaranteed
		if randf() < chance:
			gain += 1
		stat_gains[key] = gain

	# HP/MP 최대치 증가 시 현재값도 같이 증가
	var stats_before := calc_stats(char_id)
	member["current_hp"] += stat_gains.get("hp", 0)
	member["current_mp"] += stat_gains.get("mp", 0)

	# 최대치 초과 방지
	var stats_after := calc_stats(char_id)
	member["current_hp"] = mini(member["current_hp"], stats_after.get("hp", member["current_hp"]))
	member["current_mp"] = mini(member["current_mp"], stats_after.get("mp", member["current_mp"]))

	var eb: Node = get_node("/root/EventBus")
	eb.level_up.emit(char_id, member["level"], stat_gains)
	print("[PartyManager] 레벨업: %s → Lv.%d (HP+%d ATK+%d DEF+%d)" % [
		char_id, member["level"],
		stat_gains.get("hp", 0), stat_gains.get("atk", 0), stat_gains.get("def", 0)
	])

## 다음 레벨까지 필요한 경험치를 반환한다.
## @param current_level 현재 레벨
## @returns 필요 경험치
func _exp_to_next_level(current_level: int) -> int:
	# experience_system.gd와 동일한 공식: level * 100
	return current_level * 100

# ── 스탯 계산 ──

## 기본 스탯 + 장비 보정을 합산하여 최종 스탯을 반환한다.
## @param char_id 캐릭터 ID
## @returns 합산 스탯 Dictionary {hp, mp, atk, def, matk, mdef, spd, mov}
func calc_stats(char_id: String) -> Dictionary:
	var dm: Node = get_node("/root/DataManager")
	var char_data: Dictionary = dm.get_character(char_id)
	var member := get_party_member(char_id)

	if char_data.is_empty() or member.is_empty():
		return {}

	var base: Dictionary = char_data.get("stats_lv1", {})
	var growth: Dictionary = char_data.get("growth", {})
	var level: int = member.get("level", 1)

	# 기본 스탯 (레벨 기반)
	var stats: Dictionary = _calc_base_stats(base, growth, level)

	# 전직 보너스 확인
	var gm: Node = get_node("/root/GameManager")
	var class_change_scene: String = char_data.get("class_change_scene", "")
	if class_change_scene != "" and gm.has_flag("class_changed_%s" % char_id):
		var bonus: Dictionary = char_data.get("class_change_bonus", {})
		for key in STAT_KEYS:
			stats[key] = stats.get(key, 0) + bonus.get(key, 0)

	# 장비 보정 추가
	if has_node("/root/InventoryManager"):
		var em_script = load("res://scripts/systems/equipment_manager.gd")
		if em_script:
			var equip_bonus: Dictionary = em_script.calc_equipment_bonus(char_id)
			for key in STAT_KEYS:
				stats[key] = stats.get(key, 0) + equip_bonus.get(key, 0)

	return stats

## 레벨 기반 기본 스탯을 계산한다.
## @param base_stats 레벨 1 기본 스탯
## @param growth 성장률
## @param level 레벨
## @returns 해당 레벨의 기본 스탯
func _calc_base_stats(base_stats: Dictionary, growth: Dictionary, level: int) -> Dictionary:
	var stats: Dictionary = {}
	for key in STAT_KEYS:
		var base_val: int = base_stats.get(key, 0)
		var growth_val: float = growth.get(key, 0.0)
		# 레벨 1에서는 base 그대로, 이후 성장률 * (level-1) 적용
		stats[key] = base_val + int(growth_val * (level - 1))
	return stats

# ── 장비 관리 ──

## 장비를 교체한다. 이전 장비 ID를 반환한다.
## @param char_id 캐릭터 ID
## @param slot 슬롯 ("weapon" | "armor" | "accessory")
## @param item_id 장착할 아이템 ID
## @returns 이전에 장착되어 있던 아이템 ID (없으면 빈 문자열)
func equip(char_id: String, slot: String, item_id: String) -> String:
	var member := get_party_member(char_id)
	if member.is_empty():
		return ""
	if not can_equip(char_id, item_id, slot):
		push_warning("[PartyManager] 장비 불가: %s → %s (%s)" % [char_id, item_id, slot])
		return ""

	var equipment: Dictionary = member["equipment"]
	var prev_id: String = equipment.get(slot, "")

	# 이전 장비를 인벤토리에 반환
	if prev_id != "":
		var im: Node = get_node("/root/InventoryManager")
		im.add_item(prev_id, 1)

	# 새 장비 장착 (인벤토리에서 제거)
	var im: Node = get_node("/root/InventoryManager")
	im.remove_item(item_id, 1)
	equipment[slot] = item_id

	print("[PartyManager] 장비: %s의 %s → %s (이전: %s)" % [char_id, slot, item_id, prev_id])
	return prev_id

## 장비를 해제한다.
## @param char_id 캐릭터 ID
## @param slot 슬롯 ("weapon" | "armor" | "accessory")
## @returns 해제된 아이템 ID (없으면 빈 문자열)
func unequip(char_id: String, slot: String) -> String:
	var member := get_party_member(char_id)
	if member.is_empty():
		return ""

	var equipment: Dictionary = member["equipment"]
	var item_id: String = equipment.get(slot, "")
	if item_id == "":
		return ""

	# 인벤토리에 반환
	var im: Node = get_node("/root/InventoryManager")
	im.add_item(item_id, 1)
	equipment[slot] = ""

	print("[PartyManager] 장비 해제: %s의 %s (%s)" % [char_id, slot, item_id])
	return item_id

## 해당 캐릭터가 아이템을 해당 슬롯에 장비할 수 있는지 확인한다.
## @param char_id 캐릭터 ID
## @param item_id 아이템 ID
## @param slot 슬롯 ("weapon" | "armor" | "accessory")
## @returns 장비 가능 여부
func can_equip(char_id: String, item_id: String, slot: String) -> bool:
	var dm: Node = get_node("/root/DataManager")
	var char_data: Dictionary = dm.get_character(char_id)
	if char_data.is_empty():
		return false

	# 슬롯별 장비 타입 확인
	match slot:
		"weapon":
			var weapon_data: Dictionary = dm.get_weapon(item_id)
			if weapon_data.is_empty():
				return false
			var weapon_types: Array = char_data.get("weapon_types", [])
			if not weapon_types.has(weapon_data.get("type", "")):
				return false
			# equippable_by 확인
			var equippable: Array = weapon_data.get("equippable_by", [])
			if equippable.size() > 0 and not equippable.has(char_id):
				return false
			# 유니크 장비의 owner 확인
			if weapon_data.get("unique", false):
				var owner: String = weapon_data.get("owner", "")
				if owner != "" and owner != char_id:
					return false
			return true

		"armor":
			var armor_data: Dictionary = dm.get_armor(item_id)
			if armor_data.is_empty():
				return false
			var armor_types: Array = char_data.get("armor_types", [])
			# 전직 후 추가 방어구 타입 처리 (예: heavy_post_class)
			var gm: Node = get_node("/root/GameManager")
			var effective_types: Array = []
			for atype in armor_types:
				if atype.ends_with("_post_class"):
					if gm.has_flag("class_changed_%s" % char_id):
						effective_types.append(atype.replace("_post_class", ""))
				else:
					effective_types.append(atype)
			if not effective_types.has(armor_data.get("type", "")):
				return false
			# equippable_by 확인
			var equippable: Array = armor_data.get("equippable_by", [])
			if equippable.size() > 0 and not equippable.has(char_id):
				return false
			return true

		"accessory":
			var acc_data: Dictionary = dm.get_accessory(item_id)
			if acc_data.is_empty():
				return false
			# 악세서리는 기본적으로 누구나 장비 가능
			# 유니크 owner 확인만
			if acc_data.get("unique", false):
				var owner: String = acc_data.get("owner", "")
				if owner != "" and owner != char_id:
					return false
			return true

	return false

## 파티 이탈 시 모든 장비를 인벤토리에 반환한다.
## @param char_id 캐릭터 ID
func _return_equipment(char_id: String) -> void:
	var member := get_party_member(char_id)
	if member.is_empty():
		return
	var equipment: Dictionary = member.get("equipment", {})
	var im: Node = get_node("/root/InventoryManager")
	for slot in ["weapon", "armor", "accessory"]:
		var item_id: String = equipment.get(slot, "")
		if item_id != "":
			im.add_item(item_id, 1)
			equipment[slot] = ""

# ── 직렬화 ──

## 세이브용 직렬화. 파티 전체 데이터를 배열로 반환한다.
## @returns 직렬화된 파티 데이터 배열
func serialize() -> Array:
	var result: Array = []
	for member in party:
		result.append({
			"id": member["id"],
			"level": member["level"],
			"exp": member["exp"],
			"current_hp": member["current_hp"],
			"current_mp": member["current_mp"],
			"equipment": member["equipment"].duplicate(),
			"skills": member["skills"].duplicate(),
			"status": member["status"].duplicate(),
		})
	return result

## 로드용 역직렬화. 직렬화된 데이터로 파티를 복원한다.
## @param data 직렬화된 파티 데이터 배열
func deserialize(data: Array) -> void:
	party.clear()
	active_party.clear()
	for entry in data:
		var member: Dictionary = {
			"id": entry.get("id", ""),
			"level": entry.get("level", 1),
			"exp": entry.get("exp", 0),
			"current_hp": entry.get("current_hp", 1),
			"current_mp": entry.get("current_mp", 0),
			"equipment": entry.get("equipment", {"weapon": "", "armor": "", "accessory": ""}).duplicate(),
			"skills": entry.get("skills", []).duplicate(),
			"status": entry.get("status", []).duplicate(),
		}
		party.append(member)
	# 출격 파티는 별도 필드에서 복원 (save_manager에서 처리)

## 출격 파티 직렬화
## @returns 출격 파티 ID 배열
func serialize_active() -> Array:
	return active_party.duplicate()

## 출격 파티 역직렬화
## @param data 출격 파티 ID 배열
func deserialize_active(data: Array) -> void:
	active_party.clear()
	for cid in data:
		if cid is String and get_party_member(cid).size() > 0:
			active_party.append(cid)
	# 카엘이 빠져있으면 추가
	if not active_party.has(MANDATORY_CHAR) and get_party_member(MANDATORY_CHAR).size() > 0:
		active_party.insert(0, MANDATORY_CHAR)

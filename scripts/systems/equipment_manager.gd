## @fileoverview 장비 시스템 로직. 장비 스탯 합산, 스탯 차이 계산, 장비 가능 아이템 필터링을 담당한다.
## 오토로드가 아닌 유틸리티 클래스. 정적 함수로 구성한다.
class_name EquipmentManager
extends RefCounted

## 스탯 키 목록
const STAT_KEYS: Array[String] = ["hp", "mp", "atk", "def", "matk", "mdef", "spd", "mov"]

# ── 장비 스탯 계산 ──

## 캐릭터가 장착 중인 장비의 스탯 합산을 반환한다.
## @param char_id 캐릭터 ID
## @returns 장비 보너스 스탯 Dictionary
static func calc_equipment_bonus(char_id: String) -> Dictionary:
	var bonus: Dictionary = {}
	for key in STAT_KEYS:
		bonus[key] = 0

	var pm_node: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	if pm_node == null:
		return bonus
	var member: Dictionary = pm_node.get_party_member(char_id)
	if member.is_empty():
		return bonus

	var dm: Node = Engine.get_main_loop().root.get_node("DataManager")
	var equipment: Dictionary = member.get("equipment", {})

	# 무기 보너스
	var weapon_id: String = equipment.get("weapon", "")
	if weapon_id != "":
		var weapon_data: Dictionary = dm.get_weapon(weapon_id)
		bonus["atk"] += weapon_data.get("atk", 0)
		# 무기의 추가 효과 스탯
		for effect in weapon_data.get("effects", []):
			_apply_effect_bonus(bonus, effect)

	# 방어구 보너스
	var armor_id: String = equipment.get("armor", "")
	if armor_id != "":
		var armor_data: Dictionary = dm.get_armor(armor_id)
		bonus["def"] += armor_data.get("def", 0)
		bonus["mdef"] += armor_data.get("mdef", 0)
		bonus["hp"] += armor_data.get("hp", 0)
		# 속도 패널티
		bonus["spd"] -= armor_data.get("spd_penalty", 0)
		# 방어구 추가 효과
		for effect in armor_data.get("effects", []):
			_apply_effect_bonus(bonus, effect)

	# 악세서리 보너스
	var acc_id: String = equipment.get("accessory", "")
	if acc_id != "":
		var acc_data: Dictionary = dm.get_accessory(acc_id)
		var stat_bonus: Dictionary = acc_data.get("stat_bonus", {})
		for key in STAT_KEYS:
			bonus[key] += stat_bonus.get(key, 0)
		# 악세서리 추가 효과
		for effect in acc_data.get("effects", []):
			_apply_effect_bonus(bonus, effect)

	return bonus

## 이펙트에서 스탯 보너스를 추출하여 적용한다.
## @param bonus 누적 보너스 Dictionary
## @param effect 이펙트 Dictionary
static func _apply_effect_bonus(bonus: Dictionary, effect: Dictionary) -> void:
	var effect_type: String = effect.get("type", "")
	# 직접적인 스탯 보너스 이펙트 처리
	match effect_type:
		"stat_bonus":
			var stat: String = effect.get("stat", "")
			var value: int = effect.get("value", 0)
			if stat in STAT_KEYS:
				bonus[stat] += value
		"spd_bonus":
			bonus["spd"] += effect.get("value", 0)
		"hp_bonus":
			bonus["hp"] += effect.get("value", 0)
		"mp_bonus":
			bonus["mp"] += effect.get("value", 0)

# ── 스탯 차이 계산 ──

## 장비 변경 시 스탯 차이를 계산한다. (새 장비 - 현재 장비)
## @param char_id 캐릭터 ID
## @param slot 슬롯 ("weapon" | "armor" | "accessory")
## @param new_item_id 새로 장착할 아이템 ID
## @returns 스탯 차이 Dictionary {stat_key: diff_value}
static func get_stat_diff(char_id: String, slot: String, new_item_id: String) -> Dictionary:
	var diff: Dictionary = {}
	for key in STAT_KEYS:
		diff[key] = 0

	var pm_node: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	if pm_node == null:
		return diff

	# 현재 장비의 보너스
	var current_bonus: Dictionary = calc_equipment_bonus(char_id)

	# 새 장비 교체 시 보너스 시뮬레이션
	var member: Dictionary = pm_node.get_party_member(char_id)
	if member.is_empty():
		return diff

	var equipment: Dictionary = member.get("equipment", {})
	var old_item_id: String = equipment.get(slot, "")

	# 임시로 장비 교체
	equipment[slot] = new_item_id
	var new_bonus: Dictionary = calc_equipment_bonus(char_id)
	# 원래 장비 복원
	equipment[slot] = old_item_id

	# 차이 계산
	for key in STAT_KEYS:
		diff[key] = new_bonus.get(key, 0) - current_bonus.get(key, 0)

	return diff

# ── 장비 가능 아이템 필터 ──

## 캐릭터가 해당 슬롯에 장비 가능한 아이템을 인벤토리에서 필터링한다.
## @param char_id 캐릭터 ID
## @param slot 슬롯 ("weapon" | "armor" | "accessory")
## @returns 장비 가능 아이템 배열 [{id, data, count, stat_diff}]
static func get_equippable_items(char_id: String, slot: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var pm_node: Node = Engine.get_main_loop().root.get_node_or_null("PartyManager")
	var im_node: Node = Engine.get_main_loop().root.get_node_or_null("InventoryManager")
	if pm_node == null or im_node == null:
		return result

	var all_items: Dictionary = im_node.get_all_items()
	for item_id in all_items.keys():
		var count: int = all_items[item_id]
		if count <= 0:
			continue

		# 슬롯에 맞는 아이템인지 확인
		var item_data: Dictionary = im_node.get_item_data(item_id)
		if item_data.is_empty():
			continue

		var category: String = item_data.get("category", "")
		var slot_match: bool = false
		match slot:
			"weapon":
				slot_match = (category == "weapon")
			"armor":
				slot_match = (category == "armor")
			"accessory":
				slot_match = (category == "accessory")

		if not slot_match:
			continue

		# 캐릭터가 장비 가능한지 확인
		if not pm_node.can_equip(char_id, item_id, slot):
			continue

		# 스탯 차이 계산
		var stat_diff: Dictionary = get_stat_diff(char_id, slot, item_id)

		result.append({
			"id": item_id,
			"data": item_data,
			"count": count,
			"stat_diff": stat_diff,
		})

	return result

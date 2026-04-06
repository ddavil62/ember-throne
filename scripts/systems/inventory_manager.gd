## @fileoverview 인벤토리 관리 시스템. 아이템 추가/제거, 골드 관리, 아이템 데이터 조회를 담당한다.
class_name InventoryManagerClass
extends Node

# ── 인벤토리 데이터 ──

## 보유 아이템 {item_id: count}
var items: Dictionary = {}

## 보유 골드
var gold: int = 0

# ── 아이템 관리 ──

## 아이템을 추가한다.
## @param item_id 아이템 ID
## @param count 수량 (기본 1)
func add_item(item_id: String, count: int = 1) -> void:
	if item_id == "":
		return
	if items.has(item_id):
		items[item_id] += count
	else:
		items[item_id] = count
	print("[InventoryManager] 아이템 추가: %s x%d (보유: %d)" % [item_id, count, items[item_id]])

## 아이템을 제거한다.
## @param item_id 아이템 ID
## @param count 수량 (기본 1)
## @returns 제거 성공 여부
func remove_item(item_id: String, count: int = 1) -> bool:
	if not has_item(item_id, count):
		push_warning("[InventoryManager] 아이템 부족: %s (필요: %d, 보유: %d)" % [
			item_id, count, get_count(item_id)
		])
		return false
	items[item_id] -= count
	if items[item_id] <= 0:
		items.erase(item_id)
	print("[InventoryManager] 아이템 제거: %s x%d" % [item_id, count])
	return true

## 아이템 보유 여부를 확인한다.
## @param item_id 아이템 ID
## @param count 확인할 최소 수량 (기본 1)
## @returns 보유 여부
func has_item(item_id: String, count: int = 1) -> bool:
	return items.get(item_id, 0) >= count

## 아이템 보유 수량을 반환한다.
## @param item_id 아이템 ID
## @returns 보유 수량
func get_count(item_id: String) -> int:
	return items.get(item_id, 0)

## 전체 아이템 목록을 반환한다.
## @returns {item_id: count} 형태의 Dictionary
func get_all_items() -> Dictionary:
	return items.duplicate()

# ── 골드 관리 ──

## 골드를 추가한다.
## @param amount 추가할 골드 양
func add_gold(amount: int) -> void:
	gold += amount
	print("[InventoryManager] 골드 획득: +%d (잔액: %d)" % [amount, gold])

## 골드를 소비한다.
## @param amount 소비할 골드 양
## @returns 소비 성공 여부
func spend_gold(amount: int) -> bool:
	if gold < amount:
		push_warning("[InventoryManager] 골드 부족: 필요 %d, 보유 %d" % [amount, gold])
		return false
	gold -= amount
	print("[InventoryManager] 골드 소비: -%d (잔액: %d)" % [amount, gold])
	return true

# ── 아이템 데이터 조회 ──

## DataManager에서 아이템 데이터를 조회한다. 모든 아이템 종류를 검색한다.
## @param item_id 아이템 ID
## @returns 아이템 데이터 Dictionary (카테고리 키 "category" 포함)
func get_item_data(item_id: String) -> Dictionary:
	var dm: Node = get_node("/root/DataManager")

	# 무기 검색
	var weapon: Dictionary = dm.get_weapon(item_id)
	if not weapon.is_empty():
		var result: Dictionary = weapon.duplicate()
		result["category"] = "weapon"
		return result

	# 방어구 검색
	var armor: Dictionary = dm.get_armor(item_id)
	if not armor.is_empty():
		var result: Dictionary = armor.duplicate()
		result["category"] = "armor"
		return result

	# 악세서리 검색
	var acc: Dictionary = dm.get_accessory(item_id)
	if not acc.is_empty():
		var result: Dictionary = acc.duplicate()
		result["category"] = "accessory"
		return result

	# 소비 아이템 검색
	var cons: Dictionary = dm.get_consumable(item_id)
	if not cons.is_empty():
		var result: Dictionary = cons.duplicate()
		result["category"] = "consumable"
		return result

	return {}

# ── 직렬화 ──

## 세이브용 직렬화.
## @returns {items: {...}, gold: int} 형태의 Dictionary
func serialize() -> Dictionary:
	return {
		"items": items.duplicate(),
		"gold": gold,
	}

## 로드용 역직렬화.
## @param data 직렬화된 인벤토리 데이터
func deserialize(data: Dictionary) -> void:
	items = data.get("items", {}).duplicate()
	gold = data.get("gold", 0)
	print("[InventoryManager] 로드 완료: 아이템 %d종, 골드 %d" % [items.size(), gold])

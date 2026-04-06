## @fileoverview JSON 기반 게임 데이터 로딩 및 캐시 관리.
## characters, enemies, skills, items, maps, terrain 등 모든 정적 데이터를 로드한다.
class_name DataManagerClass
extends Node

# ── 데이터 캐시 ──

## 캐릭터 데이터 {id: Dictionary}
var characters: Dictionary = {}
## 적 데이터 {id: Dictionary}
var enemies: Dictionary = {}
## 스킬 데이터 {id: Dictionary}
var skills: Dictionary = {}
## 무기 데이터 {id: Dictionary}
var weapons: Dictionary = {}
## 방어구 데이터 {id: Dictionary}
var armor: Dictionary = {}
## 악세서리 데이터 {id: Dictionary}
var accessories: Dictionary = {}
## 소비 아이템 데이터 {id: Dictionary}
var consumables: Dictionary = {}
## 맵 데이터 {battle_id: Dictionary}
var maps: Dictionary = {}
## 지형 데이터 {terrain_type: Dictionary}
var terrain: Dictionary = {}
## 상점 데이터 {act: Array[item_id]}
var shops: Dictionary = {}
## 난이도 데이터 {difficulty_name: Dictionary}
var difficulty_data: Dictionary = {}
## 월드 노드 데이터 {node_id: Dictionary}
var world_nodes: Dictionary = {}
## 유대 관계 데이터
var bonds: Array = []
## 전직 조건 데이터
var class_changes: Array = []

## 로딩 완료 여부
var _loaded: bool = false

func _ready() -> void:
	load_all_data()

## 모든 데이터 파일을 로드한다.
func load_all_data() -> void:
	if _loaded:
		return
	_load_characters()
	_load_enemies()
	_load_skills()
	_load_items()
	_load_maps()
	_load_misc()
	_loaded = true
	print("[DataManager] 전체 데이터 로드 완료")

## JSON 파일을 Dictionary로 로드한다.
## @param path 리소스 경로 (res://...)
## @returns 파싱된 Dictionary 또는 빈 Dictionary
func _load_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_warning("[DataManager] 파일 없음: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataManager] 파일 열기 실패: %s" % path)
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[DataManager] JSON 파싱 실패: %s (line %d)" % [path, json.get_error_line()])
		return {}
	return json.data

## 디렉토리 내 모든 JSON 파일을 로드하여 id 기반 Dictionary로 반환한다.
## @param dir_path 디렉토리 경로
## @param id_field ID 필드명
## @returns {id: data} 형태의 Dictionary
func _load_json_dir(dir_path: String, id_field: String = "id") -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("[DataManager] 디렉토리 없음: %s" % dir_path)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var data: Variant = _load_json(dir_path + "/" + file_name)
			if data is Dictionary and data.has(id_field):
				result[data[id_field]] = data
			elif data is Array:
				# 배열 형태의 JSON (skills.json 등)
				for item: Dictionary in data:
					if item.has(id_field):
						result[item[id_field]] = item
		file_name = dir.get_next()
	dir.list_dir_end()
	return result

## 캐릭터 데이터 로드
func _load_characters() -> void:
	characters = _load_json_dir("res://data/characters")
	print("[DataManager] 캐릭터 %d명 로드" % characters.size())

## 적 데이터 로드
func _load_enemies() -> void:
	enemies = _load_json_dir("res://data/enemies")
	print("[DataManager] 적 %d종 로드" % enemies.size())

## 스킬 데이터 로드
func _load_skills() -> void:
	var data: Variant = _load_json("res://data/skills/skills.json")
	if data is Array:
		for skill: Dictionary in data:
			if skill.has("id"):
				skills[skill["id"]] = skill
	elif data is Dictionary:
		skills = data
	print("[DataManager] 스킬 %d개 로드" % skills.size())

## 아이템 데이터 로드
func _load_items() -> void:
	var weapons_data: Variant = _load_json("res://data/items/weapons.json")
	if weapons_data is Array:
		for item: Dictionary in weapons_data:
			weapons[item.get("id", "")] = item
	var armor_data: Variant = _load_json("res://data/items/armor.json")
	if armor_data is Array:
		for item: Dictionary in armor_data:
			armor[item.get("id", "")] = item
	var acc_data: Variant = _load_json("res://data/items/accessories.json")
	if acc_data is Array:
		for item: Dictionary in acc_data:
			accessories[item.get("id", "")] = item
	var cons_data: Variant = _load_json("res://data/items/consumables.json")
	if cons_data is Array:
		for item: Dictionary in cons_data:
			consumables[item.get("id", "")] = item
	print("[DataManager] 아이템 로드: 무기 %d / 방어구 %d / 악세 %d / 소비 %d" % [
		weapons.size(), armor.size(), accessories.size(), consumables.size()
	])

## 맵 데이터 로드
func _load_maps() -> void:
	maps = _load_json_dir("res://data/maps", "battle_id")
	print("[DataManager] 맵 %d개 로드" % maps.size())

## 기타 데이터 로드 (지형, 상점, 난이도)
func _load_misc() -> void:
	var terrain_data: Variant = _load_json("res://data/terrain.json")
	if terrain_data is Array:
		for t: Dictionary in terrain_data:
			terrain[t.get("type", "")] = t
	elif terrain_data is Dictionary:
		terrain = terrain_data
	var shops_data: Variant = _load_json("res://data/shops.json")
	if shops_data is Dictionary:
		shops = shops_data
	difficulty_data = _load_json("res://data/difficulty.json")

# ── 조회 헬퍼 ──

## 캐릭터 데이터 조회
func get_character(id: String) -> Dictionary:
	return characters.get(id, {})

## 적 데이터 조회
func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

## 스킬 데이터 조회
func get_skill(id: String) -> Dictionary:
	return skills.get(id, {})

## 무기 데이터 조회
func get_weapon(id: String) -> Dictionary:
	return weapons.get(id, {})

## 방어구 데이터 조회
func get_armor(id: String) -> Dictionary:
	return armor.get(id, {})

## 악세서리 데이터 조회
func get_accessory(id: String) -> Dictionary:
	return accessories.get(id, {})

## 소비 아이템 데이터 조회
func get_consumable(id: String) -> Dictionary:
	return consumables.get(id, {})

## 맵 데이터 조회
func get_map(battle_id: String) -> Dictionary:
	return maps.get(battle_id, {})

## 지형 데이터 조회
func get_terrain(terrain_type: String) -> Dictionary:
	return terrain.get(terrain_type, {})

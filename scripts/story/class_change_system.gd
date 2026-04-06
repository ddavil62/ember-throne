## @fileoverview 12캐릭터의 스토리 전직 시스템.
## 전직 조건 확인, 스탯 보너스 적용, 스킬/패시브 해금, 장비 타입 확장을 처리한다.
class_name ClassChangeSystem
extends RefCounted

# ── 상수 ──

## 전직 데이터 JSON 경로
const CLASS_CHANGES_PATH := "res://data/class_changes.json"
## 전직 플래그 접두사
const FLAG_CLASS_CHANGED := "class_changed_"
## 전직 클래스명 플래그 접두사
const FLAG_CLASS_NAME := "class_name_"
## 무기 타입 추가 플래그 접두사
const FLAG_WEAPON_TYPE := "weapon_type_added_"
## 방어구 타입 추가 플래그 접두사
const FLAG_ARMOR_TYPE := "armor_type_added_"
## 전직 효과음 ID
const SFX_CLASS_CHANGE := "class_change"
## 전체 전직 대상 캐릭터 수
const TOTAL_CLASS_CHANGES := 12

# ── 내부 변수 ──

## DataManager에서 로드한 전직 데이터 캐시
var _class_changes_cache: Array = []

# ── 초기화 ──

func _init() -> void:
	_load_class_changes()

## 전직 데이터를 로드한다. DataManager에 데이터가 있으면 그것을 사용하고,
## 없으면 JSON 파일에서 직접 로드한다.
func _load_class_changes() -> void:
	var dm: Node = _get_data_manager()
	if dm and dm.class_changes.size() > 0:
		_class_changes_cache = dm.class_changes
		return
	# DataManager에 로드되어 있지 않으면 직접 JSON에서 로드
	if not FileAccess.file_exists(CLASS_CHANGES_PATH):
		push_warning("[ClassChangeSystem] 전직 데이터 파일 없음: %s" % CLASS_CHANGES_PATH)
		return
	var file := FileAccess.open(CLASS_CHANGES_PATH, FileAccess.READ)
	if file == null:
		push_error("[ClassChangeSystem] 전직 데이터 파일 열기 실패: %s" % CLASS_CHANGES_PATH)
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[ClassChangeSystem] JSON 파싱 실패: %s (line %d)" % [CLASS_CHANGES_PATH, json.get_error_line()])
		return
	if json.data is Array:
		_class_changes_cache = json.data
		# DataManager에도 캐시 동기화
		if dm:
			dm.class_changes = _class_changes_cache
	print("[ClassChangeSystem] 전직 데이터 %d건 로드" % _class_changes_cache.size())

# ── 전직 가능 여부 확인 ──

## 해당 캐릭터가 지정된 씬에서 전직할 수 있는지 확인한다.
## @param character_id 캐릭터 ID
## @param scene_id 현재 씬 ID (예: "3-7")
## @returns 전직 가능 여부
func can_class_change(character_id: String, scene_id: String) -> bool:
	# 이미 전직한 캐릭터인지 확인
	var gm: Node = _get_game_manager()
	if gm and gm.has_flag(FLAG_CLASS_CHANGED + character_id):
		return false

	# 파티에 존재하는지 확인
	var pm: Node = _get_party_manager()
	if pm:
		var member: Dictionary = pm.get_party_member(character_id)
		if member.is_empty():
			return false

	# 전직 데이터에서 조건 일치 확인
	var data: Dictionary = get_class_change_data(character_id)
	if data.is_empty():
		return false
	if data.get("trigger_scene", "") != scene_id:
		return false

	return true

# ── 전직 실행 ──

## 전직을 실행하고 결과를 반환한다.
## 스탯 보너스는 플래그로 기록하여 PartyManager.calc_stats()에서 반영한다.
## @param character_id 캐릭터 ID
## @returns 전직 결과 Dictionary (success, character_id, old_class, new_class, stat_bonus, new_skills)
func execute_class_change(character_id: String) -> Dictionary:
	var data: Dictionary = get_class_change_data(character_id)
	if data.is_empty():
		push_warning("[ClassChangeSystem] 전직 데이터 없음: %s" % character_id)
		return {"success": false}

	var pm: Node = _get_party_manager()
	var gm: Node = _get_game_manager()
	var eb: Node = _get_event_bus()

	if not pm or not gm:
		push_error("[ClassChangeSystem] 싱글톤 접근 실패")
		return {"success": false}

	var member: Dictionary = pm.get_party_member(character_id)
	if member.is_empty():
		push_warning("[ClassChangeSystem] 파티에 없는 캐릭터: %s" % character_id)
		return {"success": false}

	# 새 스킬 추가
	var new_skills: Array = data.get("new_skills", [])
	var current_skills: Array = member.get("skills", [])
	for skill_id: String in new_skills:
		if not current_skills.has(skill_id):
			current_skills.append(skill_id)
	member["skills"] = current_skills

	# 새 패시브 추가
	var new_passives: Array = data.get("new_passives", [])
	if new_passives.size() > 0:
		if not member.has("passives"):
			member["passives"] = []
		var current_passives: Array = member["passives"]
		for passive_id: String in new_passives:
			if not current_passives.has(passive_id):
				current_passives.append(passive_id)

	# 장비 타입 확장 (플래그 기반)
	_apply_equipment_type_expansion(character_id, data)

	# 전직 완료 플래그 설정
	var new_class_ko: String = data.get("new_class_ko", "")
	var new_class_en: String = data.get("new_class_en", "")
	gm.set_flag(FLAG_CLASS_CHANGED + character_id, true)
	gm.set_flag(FLAG_CLASS_NAME + character_id, new_class_ko)

	# 시그널 발행
	if eb:
		eb.class_changed.emit(character_id, new_class_en)
		eb.sfx_play_requested.emit(SFX_CLASS_CHANGE)

	var old_class_ko: String = data.get("old_class_ko", "")
	var stat_bonus: Dictionary = data.get("stat_bonus", {})

	print("[ClassChangeSystem] 전직 완료: %s (%s → %s)" % [character_id, old_class_ko, new_class_ko])

	return {
		"success": true,
		"character_id": character_id,
		"old_class": old_class_ko,
		"new_class": new_class_ko,
		"stat_bonus": stat_bonus,
		"new_skills": new_skills,
	}

# ── 씬 기반 전직 트리거 ──

## 해당 씬에서 전직 가능한 모든 캐릭터를 순회하여 전직을 실행한다.
## 여러 캐릭터가 동시에 전직할 수 있다 (예: 3-12에서 grid + hazel).
## @param scene_id 현재 씬 ID
## @returns 전직 결과 배열 (각 원소는 execute_class_change의 반환값)
func check_and_execute(scene_id: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for entry: Dictionary in _class_changes_cache:
		var char_id: String = entry.get("character_id", "")
		if char_id == "" or entry.get("trigger_scene", "") != scene_id:
			continue
		if can_class_change(char_id, scene_id):
			var result: Dictionary = execute_class_change(char_id)
			if result.get("success", false):
				results.append(result)

	if results.size() > 0:
		print("[ClassChangeSystem] 씬 %s에서 %d명 전직" % [scene_id, results.size()])

	return results

# ── 데이터 조회 ──

## 특정 캐릭터의 전직 데이터를 조회한다.
## @param character_id 캐릭터 ID
## @returns 전직 데이터 Dictionary 또는 빈 Dictionary
func get_class_change_data(character_id: String) -> Dictionary:
	for entry: Dictionary in _class_changes_cache:
		if entry.get("character_id", "") == character_id:
			return entry
	return {}

## 특정 캐릭터가 이미 전직했는지 확인한다.
## @param character_id 캐릭터 ID
## @returns 전직 완료 여부
func is_class_changed(character_id: String) -> bool:
	var gm: Node = _get_game_manager()
	if not gm:
		return false
	return gm.has_flag(FLAG_CLASS_CHANGED + character_id)

# ── 전직 진행률 ──

## 전체 12명 중 전직 완료/미완료 현황을 반환한다.
## @returns {total: int, changed: int, changed_list: Array[String], remaining: Array[String]}
func get_class_change_progress() -> Dictionary:
	var changed_list: Array[String] = []
	var remaining: Array[String] = []

	for entry: Dictionary in _class_changes_cache:
		var char_id: String = entry.get("character_id", "")
		if char_id == "":
			continue
		if is_class_changed(char_id):
			changed_list.append(char_id)
		else:
			remaining.append(char_id)

	return {
		"total": TOTAL_CLASS_CHANGES,
		"changed": changed_list.size(),
		"changed_list": changed_list,
		"remaining": remaining,
	}

# ── 장비 타입 확장 ──

## 전직 시 new_weapon_types / new_armor_types를 플래그로 저장한다.
## 실제 적용은 PartyManager.can_equip()에서 플래그 확인으로 처리한다.
## @param character_id 캐릭터 ID
## @param data 전직 데이터 Dictionary
func _apply_equipment_type_expansion(character_id: String, data: Dictionary) -> void:
	var gm: Node = _get_game_manager()
	if not gm:
		return

	var new_weapon_types: Array = data.get("new_weapon_types", [])
	for wtype: String in new_weapon_types:
		var flag_key: String = FLAG_WEAPON_TYPE + character_id + "_" + wtype
		gm.set_flag(flag_key, true)
		print("[ClassChangeSystem] 무기 타입 해금: %s → %s" % [character_id, wtype])

	var new_armor_types: Array = data.get("new_armor_types", [])
	for atype: String in new_armor_types:
		var flag_key: String = FLAG_ARMOR_TYPE + character_id + "_" + atype
		gm.set_flag(flag_key, true)
		print("[ClassChangeSystem] 방어구 타입 해금: %s → %s" % [character_id, atype])

# ── 싱글톤 헬퍼 ──

## EventBus 싱글톤을 반환한다. RefCounted에서는 get_node를 사용할 수 없으므로
## Engine.get_main_loop()을 통해 SceneTree에 접근한다.
## @returns EventBus 노드 또는 null
func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("EventBus"):
		return tree.root.get_node("EventBus")
	return null

## GameManager 싱글톤을 반환한다.
## @returns GameManager 노드 또는 null
func _get_game_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

## PartyManager 싱글톤을 반환한다.
## @returns PartyManager 노드 또는 null
func _get_party_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("PartyManager"):
		return tree.root.get_node("PartyManager")
	return null

## DataManager 싱글톤을 반환한다.
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

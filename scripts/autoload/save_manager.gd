## @fileoverview 세이브/로드 시스템. 수동 3슬롯 + 자동 1슬롯.
class_name SaveManagerClass
extends Node

## 세이브 디렉토리 경로
const SAVE_DIR := "user://saves/"
## 최대 수동 세이브 슬롯 수
const MAX_MANUAL_SLOTS := 3
## 자동 세이브 슬롯 인덱스
const AUTO_SLOT := 0

func _ready() -> void:
	_ensure_save_dir()

## 세이브 디렉토리 존재 확인/생성
func _ensure_save_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

## 세이브 파일 경로 반환
## @param slot 슬롯 번호 (0=자동, 1~3=수동)
func _get_save_path(slot: int) -> String:
	if slot == AUTO_SLOT:
		return SAVE_DIR + "autosave.json"
	return SAVE_DIR + "save_%d.json" % slot

## 현재 게임 상태를 직렬화하여 Dictionary로 반환
func _serialize_game_state() -> Dictionary:
	var gm: Node = get_node("/root/GameManager")
	var pm: Node = get_node("/root/PartyManager")
	return {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(),
		"play_time": gm.play_time,
		"difficulty": gm.difficulty,
		"current_scene_id": gm.current_scene_id,
		"current_battle_id": gm.current_battle_id,
		"flags": gm.flags.duplicate(true),
		"party": _serialize_party(),
		"active_party": pm.serialize_active(),
		"gold": pm.gold,
		"inventory": _serialize_inventory(),
	}

## 파티 상태 직렬화. PartyManager에 위임한다.
func _serialize_party() -> Array:
	var pm: Node = get_node("/root/PartyManager")
	return pm.serialize()

## 인벤토리 직렬화. InventoryManager에 위임한다.
func _serialize_inventory() -> Dictionary:
	var im: Node = get_node("/root/InventoryManager")
	return im.serialize()

## 게임 저장
## @param slot 슬롯 번호 (0=자동, 1~3=수동)
## @returns 성공 여부
func save_game(slot: int) -> bool:
	_ensure_save_dir()
	var data := _serialize_game_state()
	var json_text := JSON.stringify(data, "\t")
	var path := _get_save_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[SaveManager] 세이브 실패: %s" % path)
		return false
	file.store_string(json_text)
	file.close()
	_mirror_to_steam_cloud(slot, json_text)
	print("[SaveManager] 저장 완료: 슬롯 %d" % slot)
	var eb: Node = get_node("/root/EventBus")
	eb.game_saved.emit(slot)
	return true

## 게임 로드
## @param slot 슬롯 번호
## @returns 성공 여부
func load_game(slot: int) -> bool:
	_sync_from_steam_cloud(slot)
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] 세이브 파일 없음: %s" % path)
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[SaveManager] 파일 열기 실패: %s" % path)
		return false
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		push_error("[SaveManager] JSON 파싱 실패: %s" % path)
		return false
	var data: Dictionary = json.data
	_apply_save_data(data)
	print("[SaveManager] 로드 완료: 슬롯 %d" % slot)
	var eb: Node = get_node("/root/EventBus")
	eb.game_loaded.emit(slot)
	return true

## 세이브 데이터를 게임 상태에 적용
func _apply_save_data(data: Dictionary) -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.play_time = data.get("play_time", 0.0)
	gm.difficulty = data.get("difficulty", "normal")
	gm.current_scene_id = data.get("current_scene_id", "")
	gm.current_battle_id = data.get("current_battle_id", "")
	gm.flags = data.get("flags", {})

	# 파티 데이터 복원
	var pm: Node = get_node("/root/PartyManager")
	var party_data: Array = data.get("party", [])
	if party_data.size() > 0:
		pm.deserialize(party_data)
		var active_data: Array = data.get("active_party", [])
		if active_data.size() > 0:
			pm.deserialize_active(active_data)
	pm.gold = int(data.get("gold", 0))

	# 인벤토리 데이터 복원
	var im: Node = get_node("/root/InventoryManager")
	var inv_data: Dictionary = data.get("inventory", {})
	if not inv_data.is_empty():
		im.deserialize(inv_data)

## 자동 세이브
func auto_save() -> bool:
	return save_game(AUTO_SLOT)

## 슬롯별 세이브 정보 조회 (미리보기용)
## @param slot 슬롯 번호
## @returns 세이브 메타데이터 또는 빈 Dictionary
func get_save_info(slot: int) -> Dictionary:
	var path := _get_save_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	var data: Dictionary = json.data
	return {
		"slot": slot,
		"timestamp": data.get("timestamp", ""),
		"play_time": data.get("play_time", 0.0),
		"scene_id": data.get("current_scene_id", ""),
		"difficulty": data.get("difficulty", ""),
	}

## 모든 슬롯의 세이브 정보 조회
func get_all_save_info() -> Array:
	var result: Array = []
	result.append(get_save_info(AUTO_SLOT))
	for i in range(1, MAX_MANUAL_SLOTS + 1):
		result.append(get_save_info(i))
	return result

## 세이브 파일 존재 여부
func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_get_save_path(slot))

## 세이브 파일 삭제
func delete_save(slot: int) -> bool:
	var path := _get_save_path(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false

# ── Steam Cloud 미러링 ──

## 세이브 파일명을 Steam Cloud용 파일명으로 변환
## @param slot 슬롯 번호
func _get_cloud_filename(slot: int) -> String:
	if slot == AUTO_SLOT:
		return "autosave.json"
	return "save_%d.json" % slot

## 세이브를 Steam Cloud에 미러링한다.
## @param slot 슬롯 번호
## @param json_text 세이브 JSON 문자열
func _mirror_to_steam_cloud(slot: int, json_text: String) -> void:
	var sm: Node = get_node_or_null("/root/SteamManager")
	if sm == null or not sm.steam_available:
		return
	var cloud_name := _get_cloud_filename(slot)
	sm.write_cloud_file(cloud_name, json_text)

## Steam Cloud에서 최신 세이브를 로컬에 동기화한다.
## 로컬 파일이 없거나 Cloud가 최신이면 Cloud 데이터로 덮어쓴다.
## @param slot 슬롯 번호
func _sync_from_steam_cloud(slot: int) -> void:
	var sm: Node = get_node_or_null("/root/SteamManager")
	if sm == null or not sm.steam_available:
		return
	var cloud_name := _get_cloud_filename(slot)
	if not sm.cloud_file_exists(cloud_name):
		return
	var cloud_text: String = sm.read_cloud_file(cloud_name)
	if cloud_text.is_empty():
		return
	# 로컬 파일이 없으면 Cloud에서 복원
	var local_path := _get_save_path(slot)
	if not FileAccess.file_exists(local_path):
		_ensure_save_dir()
		var file := FileAccess.open(local_path, FileAccess.WRITE)
		if file:
			file.store_string(cloud_text)
			file.close()
			print("[SaveManager] Cloud에서 로컬로 복원: 슬롯 %d" % slot)

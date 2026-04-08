## @fileoverview Steam 플랫폼 통합 매니저. GodotSteam 래퍼 + graceful fallback.
## GodotSteam 플러그인이 없어도 게임이 정상 작동하도록 보장한다.
class_name SteamManagerClass
extends Node

# ── 상수 ──

## Steam App ID (Spacewar 테스트용)
const APP_ID := 480

## 업적 ID 목록
const ACHIEVEMENTS := {
	"act1_clear": "ACT1_CLEAR",
	"act2_clear": "ACT2_CLEAR",
	"act3_clear": "ACT3_CLEAR",
	"ending_a": "ENDING_A",
	"ending_b": "ENDING_B",
	"full_party": "FULL_PARTY",
	"no_death_clear": "NO_DEATH_CLEAR",
	"hard_mode": "HARD_MODE",
	"all_cg": "ALL_CG",
	"bond_max": "BOND_MAX",
	"first_class_change": "FIRST_CLASS_CHANGE",
	"gold_hoarder": "GOLD_HOARDER",
	"skill_master": "SKILL_MASTER",
	"battle_veteran": "BATTLE_VETERAN",
	"speedrun": "SPEEDRUN",
}

# ── 상태 ──

## Steam 초기화 성공 여부
var steam_available: bool = false

## Steam 싱글톤 참조 (null이면 미사용)
var _steam = null

## 이미 해금된 업적 캐시
var _unlocked_achievements: Dictionary = {}

# ── 초기화 ──

func _ready() -> void:
	_init_steam()
	if steam_available:
		_cache_achievements()
		_connect_signals()

## Steam 초기화를 시도한다. 플러그인 미설치 시 graceful fallback.
func _init_steam() -> void:
	# GodotSteam 플러그인 존재 여부 확인
	if not ClassDB.class_exists(&"Steam"):
		print("[SteamManager] GodotSteam 플러그인 미설치, 오프라인 모드로 동작")
		steam_available = false
		return

	_steam = Engine.get_singleton("Steam")
	if _steam == null:
		print("[SteamManager] Steam 싱글톤을 찾을 수 없음, 오프라인 모드")
		steam_available = false
		return

	# Steam 초기화
	var init_result: Dictionary = _steam.steamInit(false, APP_ID)
	if init_result.get("status", -1) != 1:
		push_warning("[SteamManager] Steam 초기화 실패: %s" % str(init_result))
		steam_available = false
		_steam = null
		return

	steam_available = true
	print("[SteamManager] Steam 초기화 성공 (App ID: %d)" % APP_ID)

func _process(_delta: float) -> void:
	if steam_available and _steam != null:
		_steam.run_callbacks()

# ── 업적 ──

## 업적 해금 상태를 캐싱한다.
func _cache_achievements() -> void:
	if not steam_available:
		return
	for key in ACHIEVEMENTS:
		var api_name: String = ACHIEVEMENTS[key]
		var result: Dictionary = _steam.getAchievement(api_name)
		_unlocked_achievements[key] = result.get("achieved", false)

## EventBus 시그널에 업적 트리거를 연결한다.
func _connect_signals() -> void:
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb == null:
		return
	# 전직 → first_class_change
	if eb.has_signal("class_changed"):
		eb.class_changed.connect(_on_class_changed)
	# 캐릭터 합류 → full_party
	if eb.has_signal("character_joined"):
		eb.character_joined.connect(_on_character_joined)
	# 전투 승리 → battle_veteran
	if eb.has_signal("battle_won"):
		eb.battle_won.connect(_on_battle_won)
	# 골드 획득 → gold_hoarder
	if eb.has_signal("gold_gained"):
		eb.gold_gained.connect(_on_gold_gained)
	# 업적 해금 시그널
	if eb.has_signal("achievement_unlocked"):
		eb.achievement_unlocked.connect(_on_achievement_unlocked_external)

## 업적을 해금한다 (중복 해금 방지).
## @param achievement_key 내부 업적 키 (ACHIEVEMENTS 딕셔너리 키)
func unlock_achievement(achievement_key: String) -> void:
	if _unlocked_achievements.get(achievement_key, false):
		return  # 이미 해금됨

	_unlocked_achievements[achievement_key] = true

	if steam_available and _steam != null:
		var api_name: String = ACHIEVEMENTS.get(achievement_key, "")
		if api_name.is_empty():
			push_warning("[SteamManager] 알 수 없는 업적 키: %s" % achievement_key)
			return
		_steam.setAchievement(api_name)
		_steam.storeStats()
		print("[SteamManager] 업적 해금: %s (%s)" % [achievement_key, api_name])
	else:
		print("[SteamManager] 업적 해금 (오프라인): %s" % achievement_key)

	# EventBus로 알림
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("achievement_unlocked"):
		eb.achievement_unlocked.emit(achievement_key)

## 업적 해금 여부 확인
## @param achievement_key 내부 업적 키
## @returns 해금 여부
func is_achievement_unlocked(achievement_key: String) -> bool:
	return _unlocked_achievements.get(achievement_key, false)

## 모든 업적 초기화 (디버그용)
func reset_all_achievements() -> void:
	if steam_available and _steam != null:
		for key in ACHIEVEMENTS:
			_steam.clearAchievement(ACHIEVEMENTS[key])
		_steam.storeStats()
	_unlocked_achievements.clear()
	print("[SteamManager] 모든 업적 초기화")

# ── 업적 트리거 핸들러 ──

## 전직 발생 시 first_class_change 업적 해금
func _on_class_changed(_unit_id: String, _new_class: String) -> void:
	unlock_achievement("first_class_change")

## 캐릭터 합류 시 파티 12인 달성 확인
func _on_character_joined(_unit_id: String) -> void:
	var pm: Node = get_node_or_null("/root/PartyManager")
	if pm and pm.has_method("get_all_members"):
		var members: Array = pm.get_all_members()
		if members.size() >= 12:
			unlock_achievement("full_party")

## 전투 승리 시 battle_veteran 업적 (20승)
func _on_battle_won(_battle_id: String) -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var wins: int = gm.get_flag("total_battle_wins", 0) + 1
		gm.set_flag("total_battle_wins", wins)
		if wins >= 20:
			unlock_achievement("battle_veteran")

## 골드 획득 시 gold_hoarder 업적 (10000골드)
func _on_gold_gained(_amount: int) -> void:
	var pm: Node = get_node_or_null("/root/PartyManager")
	if pm and pm.gold >= 10000:
		unlock_achievement("gold_hoarder")

## 외부에서 EventBus를 통해 업적 해금 요청
func _on_achievement_unlocked_external(achievement_key: String) -> void:
	# 중복 방지는 unlock_achievement 내부에서 처리
	pass

# ── Steam Cloud ──

## Steam Cloud에 파일을 쓴다.
## @param filename 클라우드 파일명
## @param content 파일 내용 (String)
## @returns 성공 여부
func write_cloud_file(filename: String, content: String) -> bool:
	if not steam_available or _steam == null:
		return false
	var data := content.to_utf8_buffer()
	var result: bool = _steam.fileWrite(filename, data)
	if result:
		print("[SteamManager] Cloud 저장: %s" % filename)
	else:
		push_warning("[SteamManager] Cloud 저장 실패: %s" % filename)
	return result

## Steam Cloud에서 파일을 읽는다.
## @param filename 클라우드 파일명
## @returns 파일 내용 (String). 실패 시 빈 문자열.
func read_cloud_file(filename: String) -> String:
	if not steam_available or _steam == null:
		return ""
	var size: int = _steam.getFileSize(filename)
	if size <= 0:
		return ""
	var data: Dictionary = _steam.fileRead(filename, size)
	if data.get("ret", false):
		var buf: PackedByteArray = data.get("buf", PackedByteArray())
		return buf.get_string_from_utf8()
	return ""

## Steam Cloud 파일 존재 여부
## @param filename 클라우드 파일명
func cloud_file_exists(filename: String) -> bool:
	if not steam_available or _steam == null:
		return false
	return _steam.fileExists(filename)

# ── 막 클리어 / 엔딩 / 특수 업적 체크 ──

## 막 클리어 시 호출. 스토리 진행에 따라 업적을 해금한다.
## @param act 클리어한 막 번호 (1~3)
func on_act_cleared(act: int) -> void:
	match act:
		1: unlock_achievement("act1_clear")
		2: unlock_achievement("act2_clear")
		3: unlock_achievement("act3_clear")

## 엔딩 도달 시 호출.
## @param ending_id 엔딩 ID ("a" 또는 "b")
func on_ending_reached(ending_id: String) -> void:
	match ending_id:
		"a": unlock_achievement("ending_a")
		"b": unlock_achievement("ending_b")

	# 하드 모드 엔딩 체크
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm and gm.difficulty == "hard":
		unlock_achievement("hard_mode")

	# 사망 없이 클리어 체크
	if gm:
		var casualties: int = gm.get_flag("total_casualties", 0)
		if casualties == 0:
			unlock_achievement("no_death_clear")

	# 스피드런 체크 (4시간 = 14400초)
	if gm and gm.play_time <= 14400.0:
		unlock_achievement("speedrun")

## CG 전체 수집 시 호출
func on_all_cg_collected() -> void:
	unlock_achievement("all_cg")

## 본드 최대 달성 시 호출
func on_bond_max_reached() -> void:
	unlock_achievement("bond_max")

## 스킬 마스터 체크 (50종 이상 사용)
func check_skill_master() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var skills_used: int = gm.get_flag("unique_skills_used_count", 0)
		if skills_used >= 50:
			unlock_achievement("skill_master")

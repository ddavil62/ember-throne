## @fileoverview BGM/SFX 재생 관리. 크로스페이드, 볼륨 제어, EventBus 자동 SFX 배선을 담당한다.
class_name AudioManagerClass
extends Node

## BGM 리소스 경로 접두사
const BGM_PATH := "res://assets/audio/bgm/"
## SFX 리소스 경로 접두사
const SFX_PATH := "res://assets/audio/sfx/"

## BGM 시맨틱 ID → 실제 파일명 별칭 테이블
## 다수의 씬 전용 ID를 16개 파일에 매핑한다.
const BGM_ALIASES: Dictionary = {
	# ── 타이틀 ──
	"title_theme": "bgm_title",
	# ── 막별 기본 테마 ──
	"irhen_theme": "bgm_town1",
	"road_theme": "bgm_worldmap2",
	"war_theme": "bgm_battle2",
	"final_theme": "bgm_boss1",
	# ── 마을/거점 ──
	"village_peaceful": "bgm_town1",
	"harbor_lively": "bgm_town1",
	"port_revisit": "bgm_town2",
	"waltz_elegant": "bgm_town2",
	"quiet_morning": "bgm_sad2",
	"dawn_acoustic": "bgm_sad2",
	"new_morning_acoustic": "bgm_sad2",
	"starlight_duet": "bgm_sad2",
	# ── 탐험/이동 ──
	"forest_mystical": "bgm_worldmap2",
	"nature_majestic": "bgm_worldmap1",
	"mystical_strings": "bgm_worldmap2",
	"ancient_ruins": "bgm_worldmap2",
	"mountain_horn": "bgm_worldmap1",
	"ancient_ritual": "bgm_worldmap1",
	# ── 일반 전투 ──
	"battle_normal": "bgm_battle1",
	"battle_forest": "bgm_battle1",
	"battle_stealth": "bgm_battle1",
	"battle_dungeon": "bgm_battle1",
	"battle_tension": "bgm_tense1",
	"battle_chase": "bgm_tense2",
	"battle_intense": "bgm_battle2",
	"battle_epic": "bgm_battle2",
	"battle_orchestra": "bgm_battle2",
	"march_full_orchestra": "bgm_battle2",
	# ── 보스 전투 ──
	"battle_ash": "bgm_boss1",
	"battle_boss": "bgm_boss1",
	"battle_final": "bgm_boss2",
	"battle_final_ritual": "bgm_boss2",
	"ash_lord_theme": "bgm_boss1",
	"final_boss_orchestra": "bgm_boss2",
	"nightmare_distorted": "bgm_boss2",
	"confrontation_strings": "bgm_boss1",
	# ── 긴장/서스펜스 ──
	"tension_strings": "bgm_tense1",
	"drone_tension": "bgm_tense1",
	"stealth_tension": "bgm_tense1",
	"chase_theme": "bgm_tense2",
	"suspense_heartbeat": "bgm_tense2",
	"suspense_pizzicato": "bgm_tense2",
	"tension_low": "bgm_tense1",
	"heavy_strings": "bgm_tense1",
	"crisis_orchestra": "bgm_tense2",
	# ── 슬픔/감동 ──
	"lonely_piano": "bgm_sad1",
	"tragedy_cello": "bgm_sad1",
	"field_somber": "bgm_sad1",
	"cello_heavy_truth": "bgm_sad1",
	"ruin_wind_piano": "bgm_sad1",
	"kings_requiem": "bgm_sad1",
	"pipe_organ_solemn": "bgm_sad1",
	"choice_piano": "bgm_sad2",
	"march_bittersweet": "bgm_sad2",
	"disperse_piano_orchestra": "bgm_sad2",
	"atonement_choir": "bgm_sad2",
	# ── 성스러운/합창 ──
	"sacred_choral": "bgm_ending1",
	"rekindle_choral": "bgm_ending1",
	"resolve_sacred": "bgm_ending1",
	"boundary_choral": "bgm_ending1",
	# ── 엔딩 ──
	"victory_fanfare": "bgm_victory",
}

## SFX 시맨틱 ID → 실제 파일명 별칭 테이블
const SFX_ALIASES: Dictionary = {
	"ui_click": "sfx_ui_cursor",
	"ui_select": "sfx_ui_confirm",
	"class_change": "sfx_cutin_impact",
}

## BGM 플레이어 (현재 재생 중)
var _bgm_player: AudioStreamPlayer = null
## BGM 플레이어 (크로스페이드용 보조)
var _bgm_sub_player: AudioStreamPlayer = null
## SFX 플레이어 풀 (동시 재생 지원)
var _sfx_players: Array[AudioStreamPlayer] = []
## SFX 풀 크기
const SFX_POOL_SIZE := 8

## 현재 재생 중인 BGM 트랙 ID
var current_bgm: String = ""
## BGM 볼륨 (0.0 ~ 1.0)
var bgm_volume: float = 0.8:
	set(v):
		bgm_volume = clampf(v, 0.0, 1.0)
		if _bgm_player:
			_bgm_player.volume_db = linear_to_db(bgm_volume)
		if _bgm_sub_player:
			_bgm_sub_player.volume_db = linear_to_db(bgm_volume)
## SFX 볼륨 (0.0 ~ 1.0)
var sfx_volume: float = 0.8:
	set(v):
		sfx_volume = clampf(v, 0.0, 1.0)
		for p: AudioStreamPlayer in _sfx_players:
			p.volume_db = linear_to_db(sfx_volume)

func _ready() -> void:
	_setup_players()
	# EventBus 시그널 연결
	var eb: Node = get_node("/root/EventBus")
	eb.bgm_change_requested.connect(_on_bgm_change_requested)
	eb.sfx_play_requested.connect(_on_sfx_play_requested)
	# 전투 이벤트 자동 SFX
	eb.damage_dealt.connect(_on_damage_dealt)
	eb.heal_applied.connect(_on_heal_applied)
	eb.unit_died.connect(_on_unit_died)
	eb.level_up.connect(_on_level_up)
	eb.skill_used.connect(_on_skill_used)
	eb.gold_gained.connect(_on_gold_gained)
	eb.game_saved.connect(_on_game_saved)
	eb.game_loaded.connect(_on_game_loaded)
	eb.battle_won.connect(_on_battle_won)

## 오디오 플레이어 노드 생성
func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Music"
	_bgm_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_player)

	_bgm_sub_player = AudioStreamPlayer.new()
	_bgm_sub_player.bus = "Music"
	_bgm_sub_player.volume_db = linear_to_db(bgm_volume)
	add_child(_bgm_sub_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = linear_to_db(sfx_volume)
		add_child(player)
		_sfx_players.append(player)

## BGM 재생 (크로스페이드)
## @param track_id BGM 시맨틱 ID (BGM_ALIASES 또는 파일명)
## @param fade_duration 크로스페이드 시간 (초)
func play_bgm(track_id: String, fade_duration: float = 1.0) -> void:
	if track_id == current_bgm:
		return
	# 별칭 조회
	var file_id: String = BGM_ALIASES.get(track_id, track_id)
	# 확장자 순서로 탐색: .mp3 → .ogg → .wav
	var path := BGM_PATH + file_id + ".mp3"
	if not ResourceLoader.exists(path):
		path = BGM_PATH + file_id + ".ogg"
	if not ResourceLoader.exists(path):
		path = BGM_PATH + file_id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] BGM 없음: %s (→%s)" % [track_id, file_id])
		return

	var stream: AudioStream = load(path)
	current_bgm = track_id

	if _bgm_player.playing:
		# 크로스페이드: 현재 → 페이드아웃, 새 트랙 → 페이드인
		_bgm_sub_player.stream = stream
		_bgm_sub_player.volume_db = linear_to_db(0.0)
		_bgm_sub_player.play()

		var tween := create_tween().set_parallel(true)
		tween.tween_property(_bgm_player, "volume_db", linear_to_db(0.0), fade_duration)
		tween.tween_property(_bgm_sub_player, "volume_db", linear_to_db(bgm_volume), fade_duration)
		await tween.finished

		_bgm_player.stop()
		# 플레이어 스왑
		var tmp := _bgm_player
		_bgm_player = _bgm_sub_player
		_bgm_sub_player = tmp
	else:
		_bgm_player.stream = stream
		_bgm_player.volume_db = linear_to_db(bgm_volume)
		_bgm_player.play()

## BGM 정지
## @param fade_duration 페이드아웃 시간
func stop_bgm(fade_duration: float = 0.5) -> void:
	if not _bgm_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", linear_to_db(0.0), fade_duration)
	await tween.finished
	_bgm_player.stop()
	current_bgm = ""

## SFX 재생
## @param sfx_id SFX 시맨틱 ID (SFX_ALIASES 또는 파일명)
func play_sfx(sfx_id: String) -> void:
	# 별칭 조회
	var file_id: String = SFX_ALIASES.get(sfx_id, sfx_id)
	var path := SFX_PATH + file_id + ".ogg"
	if not ResourceLoader.exists(path):
		path = SFX_PATH + file_id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] SFX 없음: %s (→%s)" % [sfx_id, file_id])
		return

	var stream: AudioStream = load(path)
	# 풀에서 비어있는 플레이어 찾기
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = linear_to_db(sfx_volume)
			player.play()
			return
	# 풀이 가득 찬 경우 첫 번째 플레이어 재사용
	_sfx_players[0].stream = stream
	_sfx_players[0].play()

## EventBus 시그널 핸들러
func _on_bgm_change_requested(track_id: String) -> void:
	play_bgm(track_id)

func _on_sfx_play_requested(sfx_id: String) -> void:
	play_sfx(sfx_id)

## 피해 발생 시 타격/크리티컬 SFX
func _on_damage_dealt(_attacker_id: String, _defender_id: String, _amount: int, is_crit: bool) -> void:
	if is_crit:
		play_sfx("sfx_battle_critical")
	else:
		play_sfx("sfx_battle_hit")

## 힐 적용 시 회복 SFX
func _on_heal_applied(_healer_id: String, _target_id: String, _amount: int) -> void:
	play_sfx("sfx_skill_heal")

## 유닛 사망 SFX
func _on_unit_died(_unit_id: String, _killer_id: String) -> void:
	play_sfx("sfx_char_death")

## 레벨업 SFX
func _on_level_up(_unit_id: String, _new_level: int, _stat_gains: Dictionary) -> void:
	play_sfx("sfx_char_levelup")

## 스킬 사용 SFX (스킬 ID로 원소 구분)
func _on_skill_used(_caster_id: String, skill_id: String, _targets: Array) -> void:
	if "fire" in skill_id or "flame" in skill_id or "blaze" in skill_id:
		play_sfx("sfx_skill_fire")
	elif "ice" in skill_id or "frost" in skill_id or "blizzard" in skill_id:
		play_sfx("sfx_skill_ice")
	elif "thunder" in skill_id or "bolt" in skill_id or "lightning" in skill_id:
		play_sfx("sfx_skill_thunder")
	elif "wind" in skill_id or "gale" in skill_id or "breeze" in skill_id:
		play_sfx("sfx_skill_wind")
	elif "heal" in skill_id or "cure" in skill_id or "restore" in skill_id or "revival" in skill_id:
		play_sfx("sfx_skill_heal")
	elif "buff" in skill_id or "strengthen" in skill_id or "bless" in skill_id or "oath" in skill_id:
		play_sfx("sfx_skill_buff")
	else:
		play_sfx("sfx_battle_cast")

## 골드 획득 SFX
func _on_gold_gained(_amount: int) -> void:
	play_sfx("sfx_sys_gold")

## 세이브 SFX
func _on_game_saved(_slot: int) -> void:
	play_sfx("sfx_sys_save")

## 로드 SFX
func _on_game_loaded(_slot: int) -> void:
	play_sfx("sfx_sys_load")

## 전투 승리 시 승리 팡파레 BGM 전환
func _on_battle_won(_battle_id: String) -> void:
	play_bgm("victory_fanfare", 0.5)

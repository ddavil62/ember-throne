## @fileoverview BGM/SFX 재생 관리. 크로스페이드, 볼륨 제어를 담당한다.
class_name AudioManagerClass
extends Node

## BGM 리소스 경로 접두사
const BGM_PATH := "res://assets/audio/bgm/"
## SFX 리소스 경로 접두사
const SFX_PATH := "res://assets/audio/sfx/"

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
## @param track_id BGM 트랙 ID (파일명에서 확장자 제외)
## @param fade_duration 크로스페이드 시간 (초)
func play_bgm(track_id: String, fade_duration: float = 1.0) -> void:
	if track_id == current_bgm:
		return
	var path := BGM_PATH + track_id + ".ogg"
	if not ResourceLoader.exists(path):
		path = BGM_PATH + track_id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] BGM 없음: %s" % track_id)
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
## @param sfx_id SFX ID (파일명에서 확장자 제외)
func play_sfx(sfx_id: String) -> void:
	var path := SFX_PATH + sfx_id + ".ogg"
	if not ResourceLoader.exists(path):
		path = SFX_PATH + sfx_id + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("[AudioManager] SFX 없음: %s" % sfx_id)
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

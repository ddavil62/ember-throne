## @fileoverview 게임 상태 머신, 씬 전환, 글로벌 플래그를 관리한다.
class_name GameManagerClass
extends Node

# ── 게임 상태 ──

## 게임 상태 열거형
enum GameState {
	TITLE,         ## 타이틀 화면
	WORLD_MAP,     ## 월드맵
	DIALOGUE,      ## 대화/이벤트
	DEPLOYMENT,    ## 전투 전 배치
	BATTLE,        ## 전투 중
	BATTLE_RESULT, ## 전투 결과
	MENU,          ## 메뉴 (편성/장비/상점)
	LOADING,       ## 로딩
}

## 현재 게임 상태
var current_state: GameState = GameState.TITLE

## 이전 상태 (뒤로가기 등에 활용)
var _previous_state: GameState = GameState.TITLE

## 난이도 ("normal" | "hard")
var difficulty: String = "normal"

## 현재 스토리 진행 위치 (act-scene 형식, 예: "1-1")
var current_scene_id: String = ""

## 현재 전투 ID
var current_battle_id: String = ""

## 게임 플래그 (스토리 분기, 해금 상태 등)
var flags: Dictionary = {}

## 플레이타임 (초 단위)
var play_time: float = 0.0

## 플레이타임 카운트 활성화 여부
var _counting_time: bool = false

# ── 씬 전환 ──

## 씬 전환 오버레이 노드
var _transition_overlay: CanvasLayer = null

## 전환 진행 중 여부
var _transitioning: bool = false

func _ready() -> void:
	_setup_transition_overlay()
	_counting_time = false

func _process(delta: float) -> void:
	if _counting_time:
		play_time += delta

## 전환 오버레이 초기화
func _setup_transition_overlay() -> void:
	_transition_overlay = CanvasLayer.new()
	_transition_overlay.layer = 100
	var rect := ColorRect.new()
	rect.name = "FadeRect"
	rect.color = Color(0, 0, 0, 0)
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.add_child(rect)
	add_child(_transition_overlay)

## 상태 전환
## @param new_state 전환할 게임 상태
func change_state(new_state: GameState) -> void:
	_previous_state = current_state
	current_state = new_state
	# 전투/대화/월드맵에서만 플레이타임 카운트
	_counting_time = new_state in [
		GameState.WORLD_MAP, GameState.DIALOGUE, GameState.BATTLE,
		GameState.DEPLOYMENT, GameState.BATTLE_RESULT
	]

## 페이드 아웃 → 씬 전환 → 페이드 인
## @param scene_path 전환할 씬 리소스 경로
## @param duration 페이드 시간 (초)
## @param new_state 전환 후 게임 상태 (null이면 유지)
func transition_to_scene(scene_path: String, duration: float = 0.5, new_state = null) -> void:
	if _transitioning:
		return
	_transitioning = true

	var fade_rect: ColorRect = _transition_overlay.get_node("FadeRect")
	fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# 페이드 아웃
	var tween := create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished

	# 씬 변경
	get_tree().change_scene_to_file(scene_path)

	# 상태 전환
	if new_state != null:
		change_state(new_state)

	# 1프레임 대기 (씬 로드 완료)
	await get_tree().process_frame

	# 페이드 인
	var tween_in := create_tween()
	tween_in.tween_property(fade_rect, "color:a", 0.0, duration)
	await tween_in.finished

	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false

## 페이드 효과 없이 즉시 씬 전환
## @param scene_path 전환할 씬 리소스 경로
func change_scene_immediate(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

## 글로벌 플래그 설정
## @param key 플래그 키
## @param value 플래그 값
func set_flag(key: String, value: Variant) -> void:
	flags[key] = value

## 글로벌 플래그 조회
## @param key 플래그 키
## @param default 기본값
## @returns 플래그 값 또는 기본값
func get_flag(key: String, default: Variant = null) -> Variant:
	return flags.get(key, default)

## 플래그 존재 여부
## @param key 플래그 키
func has_flag(key: String) -> bool:
	return flags.has(key)

## 포맷된 플레이타임 문자열 반환 (HH:MM:SS)
func get_formatted_play_time() -> String:
	var hours := int(play_time) / 3600
	var minutes := (int(play_time) % 3600) / 60
	var seconds := int(play_time) % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]

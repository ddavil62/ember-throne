## @fileoverview 대화 진행 관리. JSON 기반 대화 스크립트를 로드하고
## segment 타입별 분기 처리를 담당한다.
class_name DialogueManagerClass
extends Node

# ── 상수 ──

## 대화 데이터 디렉토리 경로
const DIALOGUE_DATA_DIR := "res://data/dialogue/"

## 기본 언어 설정
const DEFAULT_LOCALE := "ko"

# ── 상태 변수 ──

## 현재 씬의 segments 배열
var current_script: Array = []

## 현재 segment 인덱스
var segment_index: int = -1

## 현재 진행 중인 scene_id
var current_scene_id: String = ""

## 언어 설정 ("ko" 또는 "en")
var locale: String = DEFAULT_LOCALE

## ACT 데이터 캐시 {act_number: Array}
var _act_cache: Dictionary = {}

## 대화 진행 중 여부
var _active: bool = false

# ── 노드 참조 ──

## 대화 박스 UI
var _dialogue_box: Node = null

## 선택지 패널 UI
var _choice_panel: Node = null

## CG 뷰어
var _cg_viewer: Node = null

# ── 초기화 ──

func _ready() -> void:
	pass

## 대화 박스/선택지 패널/CG 뷰어 노드를 등록한다.
## @param dialogue_box 대화 박스 노드
## @param choice_panel 선택지 패널 노드
## @param cg_viewer CG 뷰어 노드
func register_ui(dialogue_box: Node, choice_panel: Node, cg_viewer: Node) -> void:
	_dialogue_box = dialogue_box
	_choice_panel = choice_panel
	_cg_viewer = cg_viewer

# ── 씬 시작/종료 ──

## 지정된 scene_id로 대화를 시작한다.
## @param scene_id 씬 ID (예: "1-1", "2-3")
func start_scene(scene_id: String) -> void:
	if _active:
		push_warning("[DialogueManager] 이미 대화가 진행 중: %s" % current_scene_id)
		return

	# scene_id에서 act 번호 추출 (예: "1-1" → 1)
	var act := _extract_act(scene_id)
	if act <= 0:
		push_error("[DialogueManager] 잘못된 scene_id: %s" % scene_id)
		return

	# act 데이터 로드
	var act_data := _load_act_data(act)
	if act_data.is_empty():
		push_error("[DialogueManager] act%d 데이터 로드 실패" % act)
		return

	# scene_id에 해당하는 씬 찾기
	var scene_data := _find_scene(act_data, scene_id)
	if scene_data.is_empty():
		push_error("[DialogueManager] scene_id '%s' 를 찾을 수 없음" % scene_id)
		return

	# 상태 초기화
	current_scene_id = scene_id
	current_script = scene_data.get("segments", [])
	segment_index = -1
	_active = true

	# BGM 재생
	var bgm: String = scene_data.get("bgm", "")
	if bgm != "":
		var eb: Node = get_node("/root/EventBus")
		eb.bgm_change_requested.emit(bgm)

	# GameManager 상태 전환
	var gm: Node = get_node("/root/GameManager")
	gm.change_state(gm.GameState.DIALOGUE)
	gm.current_scene_id = scene_id

	# EventBus 시그널 발신
	var eb2: Node = get_node("/root/EventBus")
	eb2.scene_started.emit(scene_id)
	eb2.dialogue_started.emit(scene_id)

	# 대화 박스 표시
	if _dialogue_box:
		_dialogue_box.show()

	# 첫 segment 진행
	advance()

## 현재 대화 씬을 종료한다.
func end_scene() -> void:
	if not _active:
		return

	_active = false

	# 대화 박스 숨기기
	if _dialogue_box:
		_dialogue_box.hide()

	# 선택지 패널 숨기기
	if _choice_panel:
		_choice_panel.hide()

	# EventBus 시그널 발신
	var eb: Node = get_node("/root/EventBus")
	eb.dialogue_ended.emit(current_scene_id)
	eb.scene_ended.emit(current_scene_id)

	# 상태 초기화
	var finished_scene := current_scene_id
	current_scene_id = ""
	current_script = []
	segment_index = -1

	print("[DialogueManager] 씬 종료: %s" % finished_scene)

# ── 진행 ──

## 다음 segment로 진행한다.
func advance() -> void:
	if not _active:
		return

	segment_index += 1

	if segment_index >= current_script.size():
		# 모든 segment 완료 → 씬 종료
		end_scene()
		return

	var segment: Dictionary = current_script[segment_index]
	_process_segment(segment)

## segment 타입에 따라 적절한 처리를 수행한다.
## @param segment 현재 segment 데이터
func _process_segment(segment: Dictionary) -> void:
	var seg_type: String = segment.get("type", "")

	match seg_type:
		"dialogue":
			_handle_dialogue(segment)
		"narration":
			_handle_narration(segment)
		"cg":
			_handle_cg(segment)
		"choice":
			_handle_choice(segment)
		"battle_start":
			_handle_battle_start(segment)
		"bgm_change":
			_handle_bgm_change(segment)
		"portrait_change":
			_handle_portrait_change(segment)
		_:
			push_warning("[DialogueManager] 알 수 없는 segment 타입: %s" % seg_type)
			advance()

# ── segment 핸들러 ──

## "dialogue" 타입 — 대화 텍스트를 대화 박스에 표시한다.
## @param seg segment 데이터
func _handle_dialogue(seg: Dictionary) -> void:
	if not _dialogue_box:
		advance()
		return

	var speaker: String = seg.get("speaker", "")
	var emotion: String = seg.get("emotion", "default")
	var text: String = _get_localized_text(seg)

	_dialogue_box.show_dialogue(speaker, emotion, text)

## "narration" 타입 — 화자 없이 텍스트만 표시한다.
## @param seg segment 데이터
func _handle_narration(seg: Dictionary) -> void:
	if not _dialogue_box:
		advance()
		return

	var text: String = _get_localized_text(seg)
	_dialogue_box.show_narration(text)

## "cg" 타입 — CG 전체화면을 표시한다.
## @param seg segment 데이터
func _handle_cg(seg: Dictionary) -> void:
	if not _cg_viewer:
		advance()
		return

	var image: String = seg.get("image", "")
	_cg_viewer.show_cg(image)

## "choice" 타입 — 선택지를 표시한다.
## @param seg segment 데이터
func _handle_choice(seg: Dictionary) -> void:
	if not _choice_panel:
		advance()
		return

	# 선택지 프롬프트: prompt_ko/prompt_en 또는 text_ko/text_en 지원
	var prompt_key := "prompt_" + locale
	var prompt: String = seg.get(prompt_key, "")
	if prompt == "":
		prompt = seg.get("prompt_ko", seg.get("prompt_en", ""))
	if prompt == "":
		prompt = _get_localized_text(seg)

	var options: Array = seg.get("options", [])
	_choice_panel.show_choices(prompt, options, locale)

## 선택지 결과를 처리한다. choice_panel에서 호출된다.
## @param option 선택된 옵션 데이터
func on_choice_selected(option: Dictionary) -> void:
	# 플래그 설정
	var flag: String = option.get("flag", "")
	if flag != "":
		var gm: Node = get_node("/root/GameManager")
		gm.set_flag(flag, true)

	# next_scene이 있으면 현재 씬을 종료하고 해당 씬으로 전환
	var next_scene: String = option.get("next_scene", "")
	if next_scene != "":
		end_scene()
		start_scene(next_scene)
		return

	# next_index가 있으면 해당 인덱스로 점프
	var next_index: int = option.get("next_index", -1)
	if next_index >= 0 and next_index < current_script.size():
		segment_index = next_index - 1  # advance()에서 +1 하므로
	# next_index가 없으면 순차 진행

	advance()

## "battle_start" 타입 — 전투 씬으로 전환한다.
## @param seg segment 데이터
func _handle_battle_start(seg: Dictionary) -> void:
	var battle_id: String = seg.get("battle_id", "")
	if battle_id == "":
		push_warning("[DialogueManager] battle_id가 비어 있음")
		advance()
		return

	# 대화 일시 중단 (전투 후 재개될 수 있음)
	_active = false

	var gm: Node = get_node("/root/GameManager")
	gm.current_battle_id = battle_id
	# 전투 씬 전환은 외부에서 처리 (BattleManager 등)
	print("[DialogueManager] 전투 시작: %s" % battle_id)

## "bgm_change" 타입 — BGM을 변경한다.
## @param seg segment 데이터
func _handle_bgm_change(seg: Dictionary) -> void:
	var track: String = seg.get("track", "")
	if track != "":
		var eb: Node = get_node("/root/EventBus")
		eb.bgm_change_requested.emit(track)

	# BGM 변경 후 즉시 다음 segment로 진행
	advance()

## "portrait_change" 타입 — 대화 박스의 초상화를 변경한다.
## @param seg segment 데이터
func _handle_portrait_change(seg: Dictionary) -> void:
	if _dialogue_box:
		var speaker: String = seg.get("speaker", "")
		var emotion: String = seg.get("emotion", "default")
		_dialogue_box.update_portrait(speaker, emotion)

	# 초상화 변경 후 즉시 다음 segment로 진행
	advance()

# ── 데이터 로딩 ──

## ACT JSON 데이터를 로드하고 캐싱한다.
## @param act ACT 번호 (1~4)
## @returns 씬 배열 또는 빈 배열
func _load_act_data(act: int) -> Array:
	# 캐시 확인
	if _act_cache.has(act):
		return _act_cache[act]

	var path := DIALOGUE_DATA_DIR + "act%d.json" % act
	if not FileAccess.file_exists(path):
		push_warning("[DialogueManager] 파일 없음: %s" % path)
		return []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DialogueManager] 파일 열기 실패: %s" % path)
		return []

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[DialogueManager] JSON 파싱 실패: %s (line %d)" % [path, json.get_error_line()])
		return []

	var data: Variant = json.data
	if not data is Array:
		push_error("[DialogueManager] act%d 데이터가 배열이 아님" % act)
		return []

	# 캐시 저장
	_act_cache[act] = data
	print("[DialogueManager] act%d 로드 완료 (%d 씬)" % [act, data.size()])
	return data

# ── 유틸리티 ──

## scene_id에서 act 번호를 추출한다.
## @param scene_id 씬 ID (예: "1-1" → 1, "2-3" → 2)
## @returns act 번호 또는 -1
func _extract_act(scene_id: String) -> int:
	var parts := scene_id.split("-")
	if parts.size() < 2:
		return -1
	if not parts[0].is_valid_int():
		return -1
	return parts[0].to_int()

## act 데이터에서 특정 scene_id를 찾아 반환한다.
## @param act_data 씬 배열
## @param scene_id 찾을 scene_id
## @returns 씬 Dictionary 또는 빈 Dictionary
func _find_scene(act_data: Array, scene_id: String) -> Dictionary:
	for scene: Dictionary in act_data:
		if scene.get("scene_id", "") == scene_id:
			return scene
	return {}

## 현재 locale에 따라 텍스트를 반환한다.
## @param data segment 데이터
## @returns 로컬라이즈된 텍스트
func _get_localized_text(data: Dictionary) -> String:
	var key := "text_" + locale
	if data.has(key):
		return data[key]
	# fallback: ko → en
	if data.has("text_ko"):
		return data["text_ko"]
	if data.has("text_en"):
		return data["text_en"]
	return ""

## 대화 진행 중 여부를 반환한다.
func is_active() -> bool:
	return _active

## ACT 캐시를 초기화한다.
func clear_cache() -> void:
	_act_cache.clear()

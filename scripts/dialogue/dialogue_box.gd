## @fileoverview 대화 박스 UI. 타이핑 이펙트, 초상화 표시, 자동 진행,
## 스킵 기능을 제공한다. Control 기반으로 동적 구성된다.
class_name DialogueBoxClass
extends Control

# ── 상수 ──

## 타이핑 이펙트 간격 (초/글자)
const TYPING_SPEED := 0.03

## 자동 진행 대기 시간 (초)
const AUTO_ADVANCE_DELAY := 2.0

## 스킵 모드 타이핑 속도 (초/글자)
const SKIP_TYPING_SPEED := 0.005

## 초상화 이미지 경로 접두사
const PORTRAIT_PATH := "res://assets/portraits/"

## 초상화 크기
const PORTRAIT_SIZE := Vector2(256, 256)

## 대화 박스 높이
const BOX_HEIGHT := 200

## 좌우 마진 비율 (5%)
const MARGIN_RATIO := 0.05

## 하단 마진 (px)
const BOTTOM_MARGIN := 20

## 화자 이름 매핑 (id → 한국어 이름)
const SPEAKER_NAMES := {
	"kael": "카엘",
	"seria": "세리아",
	"linen": "리넨",
	"roc": "로크",
	"nael": "나엘",
	"grid": "그리드",
	"drana": "드라나",
	"voldt": "볼드",
	"irene": "이렌",
	"hazel": "헤이즐",
	"elmira": "엘미라",
	"cyr": "시르",
	"tom": "톰",
	"olga": "올가",
	"bartol": "바르톨",
	"pina": "피나",
	"caldric": "칼드릭",
	"lucid": "루시드",
	"morgan": "모르간",
	"annette": "아네트",
	"rendor": "렌도르",
	"karen": "카렌",
	"eris": "에리스",
	"marina": "마리나",
	"mother": "노모",
	"deputy": "부관",
	"soldier": "병사",
	"farmer": "농부",
	"elder": "원로장",
	"pro_elder": "찬성파 원로",
	"con_elder": "반대파 원로",
	"neutral_elder": "중립파 원로",
	"rebel_soldier": "저항군 병사",
	"secret_police": "비밀경찰",
	"sentry": "초병",
	"ash_lord": "재의 군주",
}

# ── 상태 변수 ──

## 현재 표시할 전체 텍스트
var _full_text: String = ""

## 현재까지 표시된 글자 수
var _visible_chars: int = 0

## 타이핑 진행 중 여부
var _typing: bool = false

## 타이핑 타이머
var _type_timer: float = 0.0

## 전체 텍스트 표시 완료 여부
var _text_complete: bool = false

## 자동 진행 모드
var _auto_mode: bool = false

## 자동 진행 타이머
var _auto_timer: float = 0.0

## 스킵 모드 (S키 누르는 동안)
var _skip_mode: bool = false

## 현재 화자 ID
var _current_speaker: String = ""

## 현재 감정
var _current_emotion: String = "default"

# ── UI 노드 참조 ──

## 대화 박스 배경
var _bg_panel: Panel = null

## 초상화 텍스처
var _portrait_rect: TextureRect = null

## 화자 이름 레이블
var _name_label: Label = null

## 대화 텍스트 레이블
var _text_label: RichTextLabel = null

## 다음 표시 아이콘
var _next_indicator: Label = null

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	hide()

## UI 노드를 동적으로 생성한다.
func _build_ui() -> void:
	# 자신의 앵커를 화면 하단에 배치
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -(BOX_HEIGHT + BOTTOM_MARGIN)
	offset_bottom = -BOTTOM_MARGIN

	# 좌우 마진 계산 (부모 너비의 5%)
	var margin_px := 96  # 1920 * 0.05 = 96, 기본값
	offset_left = margin_px
	offset_right = -margin_px

	# 배경 패널
	_bg_panel = Panel.new()
	_bg_panel.name = "BgPanel"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.85)
	style.border_color = Color(0.6, 0.5, 0.3, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	_bg_panel.add_theme_stylebox_override("panel", style)
	add_child(_bg_panel)
	_bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# HBoxContainer — 초상화 + 텍스트 영역
	var hbox := HBoxContainer.new()
	hbox.name = "HBox"
	hbox.set("theme_override_constants/separation", 16)
	_bg_panel.add_child(hbox)
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 초상화 TextureRect
	_portrait_rect = TextureRect.new()
	_portrait_rect.name = "Portrait"
	_portrait_rect.custom_minimum_size = PORTRAIT_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hbox.add_child(_portrait_rect)

	# VBoxContainer — 이름 + 텍스트
	var vbox := VBoxContainer.new()
	vbox.name = "TextArea"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.set("theme_override_constants/separation", 4)
	hbox.add_child(vbox)

	# 화자 이름 레이블
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_font_size_override("font_size", 20)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	vbox.add_child(_name_label)

	# 대화 텍스트 (RichTextLabel)
	_text_label = RichTextLabel.new()
	_text_label.name = "TextLabel"
	_text_label.bbcode_enabled = true
	_text_label.fit_content = false
	_text_label.scroll_active = false
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_font_size_override("normal_font_size", 18)
	_text_label.add_theme_color_override("default_color", Color(0.95, 0.95, 0.95))
	vbox.add_child(_text_label)

	# 다음 표시 아이콘 (우하단)
	_next_indicator = Label.new()
	_next_indicator.name = "NextIndicator"
	_next_indicator.text = "[V]"
	_next_indicator.add_theme_font_size_override("font_size", 14)
	_next_indicator.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	_next_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_indicator.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_next_indicator.anchor_left = 1.0
	_next_indicator.anchor_right = 1.0
	_next_indicator.anchor_top = 1.0
	_next_indicator.anchor_bottom = 1.0
	_next_indicator.offset_left = -40
	_next_indicator.offset_top = -24
	_next_indicator.visible = false
	_bg_panel.add_child(_next_indicator)

# ── 대화 표시 ──

## 대화 텍스트를 표시한다 (화자 + 초상화 포함).
## @param speaker 화자 ID
## @param emotion 감정 (default, determined, sad 등)
## @param text 표시할 텍스트
func show_dialogue(speaker: String, emotion: String, text: String) -> void:
	_current_speaker = speaker
	_current_emotion = emotion

	# 화자 이름 표시
	var display_name: String = SPEAKER_NAMES.get(speaker, speaker)
	_name_label.text = display_name
	_name_label.visible = true

	# 초상화 로드
	_load_portrait(speaker, emotion)
	_portrait_rect.visible = true

	# 텍스트 타이핑 시작
	_start_typing(text)

## 내레이션 텍스트를 표시한다 (화자 없음).
## @param text 표시할 텍스트
func show_narration(text: String) -> void:
	_current_speaker = ""
	_current_emotion = ""

	# 화자 이름 숨기기
	_name_label.text = ""
	_name_label.visible = false

	# 초상화 숨기기
	_portrait_rect.visible = false
	_portrait_rect.texture = null

	# 텍스트 타이핑 시작
	_start_typing(text)

## 초상화만 변경한다 (텍스트는 유지).
## @param speaker 화자 ID
## @param emotion 감정
func update_portrait(speaker: String, emotion: String) -> void:
	_current_speaker = speaker
	_current_emotion = emotion
	_load_portrait(speaker, emotion)

# ── 타이핑 이펙트 ──

## 타이핑 이펙트를 시작한다.
## @param text 표시할 전체 텍스트
func _start_typing(text: String) -> void:
	_full_text = text
	_visible_chars = 0
	_typing = true
	_text_complete = false
	_type_timer = 0.0
	_auto_timer = 0.0
	_next_indicator.visible = false

	_text_label.text = _full_text
	_text_label.visible_characters = 0

## 타이핑을 즉시 완료한다.
func _complete_typing() -> void:
	_typing = false
	_text_complete = true
	_visible_chars = _full_text.length()
	_text_label.visible_characters = -1  # 전체 표시
	_next_indicator.visible = true

func _process(delta: float) -> void:
	if not visible:
		return

	# 스킵 모드 확인 (S키 누르고 있는 동안)
	_skip_mode = Input.is_key_pressed(KEY_S)

	# 타이핑 중
	if _typing:
		var speed := SKIP_TYPING_SPEED if _skip_mode else TYPING_SPEED
		_type_timer += delta
		while _type_timer >= speed and _visible_chars < _full_text.length():
			_type_timer -= speed
			_visible_chars += 1
			_text_label.visible_characters = _visible_chars

		if _visible_chars >= _full_text.length():
			_complete_typing()

	# 스킵 모드 — 텍스트 완료 후 자동 진행
	if _skip_mode and _text_complete:
		_request_advance()
		return

	# 자동 진행 모드
	if _auto_mode and _text_complete:
		_auto_timer += delta
		if _auto_timer >= AUTO_ADVANCE_DELAY:
			_request_advance()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# 클릭 또는 Enter로 진행
	var accepted := false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accepted = true
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ENTER, KEY_SPACE:
					accepted = true
				KEY_A:
					# 자동 진행 토글
					_auto_mode = not _auto_mode
					_auto_timer = 0.0
					print("[DialogueBox] 자동 진행: %s" % ("ON" if _auto_mode else "OFF"))
					get_viewport().set_input_as_handled()
					return

	if accepted:
		get_viewport().set_input_as_handled()
		if _typing:
			# 타이핑 중이면 즉시 완료
			_complete_typing()
		elif _text_complete:
			# 텍스트 완료 상태면 다음으로 진행
			_request_advance()

## DialogueManager에게 진행을 요청한다.
func _request_advance() -> void:
	_text_complete = false
	_next_indicator.visible = false
	_auto_timer = 0.0

	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm:
		dm.advance()

# ── 초상화 로딩 ──

## 캐릭터 초상화 이미지를 로드한다.
## @param speaker 화자 ID
## @param emotion 감정
func _load_portrait(speaker: String, emotion: String) -> void:
	if speaker == "":
		_portrait_rect.texture = null
		return

	# 감정별 이미지 경로: {speaker}_{emotion}.png
	var path := PORTRAIT_PATH + "%s_%s.png" % [speaker, emotion]
	if ResourceLoader.exists(path):
		_portrait_rect.texture = load(path)
		return

	# fallback: 기본 감정
	var default_path := PORTRAIT_PATH + "%s_default.png" % speaker
	if ResourceLoader.exists(default_path):
		_portrait_rect.texture = load(default_path)
		return

	# fallback: 이름만
	var name_path := PORTRAIT_PATH + "%s.png" % speaker
	if ResourceLoader.exists(name_path):
		_portrait_rect.texture = load(name_path)
		return

	# 초상화 없음
	_portrait_rect.texture = null

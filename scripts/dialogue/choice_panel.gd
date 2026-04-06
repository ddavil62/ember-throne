## @fileoverview 선택지 UI 패널. 2~4개의 선택지 버튼을 세로로 나열하고
## 키보드/마우스 입력을 받아 결과를 DialogueManager에 전달한다.
class_name ChoicePanelClass
extends Control

# ── 상수 ──

## 버튼 최소 높이
const BUTTON_MIN_HEIGHT := 48

## 버튼 간격
const BUTTON_SPACING := 12

## 패널 최대 너비
const PANEL_MAX_WIDTH := 600

## 패널 배경 색상
const BG_COLOR := Color(0.08, 0.08, 0.15, 0.9)

## 버튼 기본 색상
const BUTTON_NORMAL_COLOR := Color(0.12, 0.12, 0.22, 0.9)

## 버튼 포커스/호버 색상
const BUTTON_FOCUS_COLOR := Color(0.25, 0.2, 0.1, 0.95)

## 버튼 텍스트 색상
const BUTTON_TEXT_COLOR := Color(0.95, 0.95, 0.95)

## 포커스 텍스트 색상
const BUTTON_FOCUS_TEXT_COLOR := Color(1.0, 0.85, 0.4)

# ── 상태 변수 ──

## 현재 표시 중인 옵션 배열
var _options: Array = []

## 현재 키보드 포커스 인덱스
var _focus_index: int = 0

## 생성된 버튼 노드 배열
var _buttons: Array[Button] = []

## 선택 가능 여부
var _accepting_input: bool = false

## 프롬프트 텍스트
var _prompt_text: String = ""

## 현재 locale
var _locale: String = "ko"

# ── UI 노드 참조 ──

## 배경 패널
var _bg_panel: Panel = null

## 프롬프트 레이블
var _prompt_label: Label = null

## 버튼 컨테이너
var _button_container: VBoxContainer = null

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	hide()

## UI 노드를 동적으로 생성한다.
func _build_ui() -> void:
	# 자신의 앵커를 화면 중앙에 배치
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -PANEL_MAX_WIDTH / 2
	offset_right = PANEL_MAX_WIDTH / 2
	offset_top = -150
	offset_bottom = 150

	# 배경 패널
	_bg_panel = Panel.new()
	_bg_panel.name = "BgPanel"
	_bg_panel.anchors_preset = Control.PRESET_FULL_RECT
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.border_color = Color(0.6, 0.5, 0.3, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	_bg_panel.add_theme_stylebox_override("panel", style)
	add_child(_bg_panel)

	# VBoxContainer — 프롬프트 + 버튼들
	var vbox := VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.set("theme_override_constants/separation", BUTTON_SPACING)
	_bg_panel.add_child(vbox)

	# 프롬프트 레이블
	_prompt_label = Label.new()
	_prompt_label.name = "PromptLabel"
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.6))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_prompt_label)

	# 간격
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# 버튼 컨테이너
	_button_container = VBoxContainer.new()
	_button_container.name = "ButtonContainer"
	_button_container.set("theme_override_constants/separation", BUTTON_SPACING)
	vbox.add_child(_button_container)

# ── 선택지 표시 ──

## 선택지를 표시한다.
## @param prompt 프롬프트 텍스트
## @param options 선택지 배열 [{text_ko, text_en, flag, next_index}, ...]
## @param locale 언어 설정
func show_choices(prompt: String, options: Array, locale: String = "ko") -> void:
	_prompt_text = prompt
	_options = options
	_locale = locale
	_focus_index = 0
	_accepting_input = true

	# 프롬프트 설정
	_prompt_label.text = prompt

	# 기존 버튼 제거
	_clear_buttons()

	# 새 버튼 생성
	_buttons.clear()
	for i in range(options.size()):
		var option: Dictionary = options[i]
		var btn := _create_choice_button(i, option)
		_button_container.add_child(btn)
		_buttons.append(btn)

	# 첫 번째 버튼에 포커스
	if _buttons.size() > 0:
		_update_focus()

	# 패널 크기 조정
	var total_height := 80 + (BUTTON_MIN_HEIGHT + BUTTON_SPACING) * options.size()
	offset_top = -total_height / 2
	offset_bottom = total_height / 2

	show()

## 선택지 버튼을 생성한다.
## @param index 버튼 인덱스
## @param option 옵션 데이터
## @returns 생성된 Button 노드
func _create_choice_button(index: int, option: Dictionary) -> Button:
	var btn := Button.new()
	btn.name = "Choice_%d" % index

	# 텍스트 설정
	var text_key := "text_" + _locale
	var text: String = option.get(text_key, option.get("text_ko", "???"))
	btn.text = text

	# 스타일
	btn.custom_minimum_size = Vector2(0, BUTTON_MIN_HEIGHT)
	btn.add_theme_font_size_override("font_size", 18)

	# 기본 스타일박스
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = BUTTON_NORMAL_COLOR
	normal_style.set_border_width_all(1)
	normal_style.border_color = Color(0.4, 0.35, 0.25, 0.6)
	normal_style.set_corner_radius_all(4)
	normal_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal_style)

	# 호버/포커스 스타일박스
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = BUTTON_FOCUS_COLOR
	hover_style.set_border_width_all(2)
	hover_style.border_color = Color(1.0, 0.85, 0.4, 0.8)
	hover_style.set_corner_radius_all(4)
	hover_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", hover_style)

	# 프레스 스타일박스
	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.3, 0.25, 0.1, 0.95)
	pressed_style.set_border_width_all(2)
	pressed_style.border_color = Color(1.0, 0.85, 0.4)
	pressed_style.set_corner_radius_all(4)
	pressed_style.set_content_margin_all(8)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	# 텍스트 색상
	btn.add_theme_color_override("font_color", BUTTON_TEXT_COLOR)
	btn.add_theme_color_override("font_hover_color", BUTTON_FOCUS_TEXT_COLOR)
	btn.add_theme_color_override("font_focus_color", BUTTON_FOCUS_TEXT_COLOR)

	# 클릭 시그널
	btn.pressed.connect(_on_button_pressed.bind(index))

	return btn

## 기존 버튼을 모두 제거한다.
func _clear_buttons() -> void:
	for child in _button_container.get_children():
		child.queue_free()
	_buttons.clear()

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _accepting_input:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				_focus_index = max(0, _focus_index - 1)
				_update_focus()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_focus_index = min(_buttons.size() - 1, _focus_index + 1)
				_update_focus()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_SPACE:
				_select_current()
				get_viewport().set_input_as_handled()

## 키보드 포커스를 갱신한다.
func _update_focus() -> void:
	for i in range(_buttons.size()):
		if i == _focus_index:
			_buttons[i].grab_focus()

## 현재 포커스된 선택지를 확정한다.
func _select_current() -> void:
	if _focus_index >= 0 and _focus_index < _options.size():
		_on_button_pressed(_focus_index)

## 버튼 클릭 핸들러.
## @param index 선택된 버튼 인덱스
func _on_button_pressed(index: int) -> void:
	if not _accepting_input:
		return

	_accepting_input = false

	# SFX 재생
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb:
		eb.sfx_play_requested.emit("ui_select")

	# 선택 결과를 DialogueManager에 전달
	var option: Dictionary = _options[index]
	hide()

	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm:
		dm.on_choice_selected(option)

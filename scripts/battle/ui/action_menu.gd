## @fileoverview 전투 행동 메뉴. 유닛 이동 후 공격/스킬/아이템/대기 선택 UI.
## TurnManager의 인라인 메뉴를 대체하는 독립 클래스. NinePatch 에셋 대응.
class_name ActionMenu
extends CanvasLayer

# ── 상수 ──

## 메뉴 렌더 레이어
const MENU_LAYER: int = 50

## 버튼 크기
const BUTTON_SIZE := Vector2(140, 40)

## 색상
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.92)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_HOVER := Color(0.25, 0.25, 0.35, 1.0)
const COLOR_NORMAL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_PRESSED := Color(0.35, 0.25, 0.15, 1.0)
const COLOR_DISABLED := Color(0.3, 0.3, 0.3, 1.0)

## 행동별 아이콘/라벨 매핑
const ACTION_LABELS: Dictionary = {
	"attack": "공격",
	"skill": "스킬",
	"item": "아이템",
	"wait": "대기",
}

## NinePatch 에셋 경로
const NINEPATCH_PANEL := "res://assets/ui/panel_dark.png"
const NINEPATCH_JSON := "res://assets/ui/ninepatch_data.json"

## 패널 여백
const PADDING: int = 8

# ── 시그널 ──

## 행동 메뉴 항목 선택 시
signal action_selected(action: String)

# ── 멤버 변수 ──

## 메뉴 컨테이너 (PanelContainer 또는 NinePatchRect)
var _menu_container: Control = null

## 버튼 컨테이너
var _button_container: VBoxContainer = null

## 버튼 참조 배열 (키보드 네비게이션용)
var _buttons: Array[Button] = []

## 현재 포커스 인덱스
var _focus_index: int = 0

## 메뉴 표시 여부
var _is_visible: bool = false

# ── 초기화 ──

func _ready() -> void:
	layer = MENU_LAYER
	visible = false

## 메뉴를 표시한다.
## @param actions 표시할 행동 ID 배열 (["attack","skill","item","wait"])
func show_menu(actions: Array[String]) -> void:
	# 기존 메뉴 정리
	_cleanup()

	# 메뉴 배경 생성 (NinePatch 또는 fallback)
	_menu_container = _create_menu_background()
	add_child(_menu_container)

	# 버튼 컨테이너
	_button_container = VBoxContainer.new()
	_button_container.add_theme_constant_override("separation", 4)

	if _menu_container is NinePatchRect:
		_button_container.position = Vector2(PADDING, PADDING)
		_menu_container.add_child(_button_container)
	else:
		_menu_container.add_child(_button_container)

	# 버튼 생성
	_buttons.clear()
	_focus_index = 0

	for action_id: String in actions:
		var label_text: String = ACTION_LABELS.get(action_id, action_id)
		var btn := _create_action_button(label_text, action_id)
		_button_container.add_child(btn)
		_buttons.append(btn)

	# 위치: 화면 중앙 우측
	var total_height: float = actions.size() * (BUTTON_SIZE.y + 4) + PADDING * 2
	if _menu_container is NinePatchRect:
		_menu_container.size = Vector2(BUTTON_SIZE.x + PADDING * 2, total_height)
		_menu_container.position = Vector2(960 + 100, 540 - total_height / 2)
	else:
		_menu_container.position = Vector2(960 + 100, 540 - total_height / 2)

	# 첫 번째 버튼에 포커스
	if _buttons.size() > 0:
		_buttons[0].grab_focus()

	visible = true
	_is_visible = true

## 메뉴를 숨긴다.
func hide_menu() -> void:
	visible = false
	_is_visible = false
	_cleanup()

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return

	# 키보드 네비게이션
	if event.is_action_pressed("ui_up"):
		_navigate(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_navigate(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		_select_current()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		hide_menu()
		get_viewport().set_input_as_handled()

## 포커스를 이동한다.
## @param direction -1(위) 또는 +1(아래)
func _navigate(direction: int) -> void:
	if _buttons.is_empty():
		return
	_focus_index = (_focus_index + direction) % _buttons.size()
	if _focus_index < 0:
		_focus_index = _buttons.size() - 1
	_buttons[_focus_index].grab_focus()

## 현재 포커스 버튼을 선택한다.
func _select_current() -> void:
	if _focus_index >= 0 and _focus_index < _buttons.size():
		_buttons[_focus_index].emit_signal("pressed")

# ── UI 생성 유틸 ──

## 메뉴 배경을 생성한다. NinePatch 에셋이 있으면 NinePatchRect, 없으면 PanelContainer.
## @returns Control 노드
func _create_menu_background() -> Control:
	# NinePatch 에셋 확인
	if ResourceLoader.exists(NINEPATCH_PANEL):
		var tex: Texture2D = load(NINEPATCH_PANEL)
		if tex:
			var nine := NinePatchRect.new()
			nine.texture = tex
			# 9slice 마진 로드
			var margins: Dictionary = _load_ninepatch_margins("panel_dark.png")
			nine.patch_margin_left = margins.get("left", 48)
			nine.patch_margin_right = margins.get("right", 48)
			nine.patch_margin_top = margins.get("top", 48)
			nine.patch_margin_bottom = margins.get("bottom", 48)
			return nine

	# Fallback: PanelContainer
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	panel.add_theme_stylebox_override("panel", style)
	return panel

## NinePatch 마진 데이터를 JSON에서 로드한다.
## @param asset_name 에셋 파일명 (예: "panel_dark.png")
## @returns {left, right, top, bottom} Dictionary
func _load_ninepatch_margins(asset_name: String) -> Dictionary:
	var default_margins := {"left": 48, "right": 48, "top": 48, "bottom": 48}
	if not ResourceLoader.exists(NINEPATCH_JSON):
		return default_margins

	var file := FileAccess.open("res://assets/ui/ninepatch_data.json", FileAccess.READ)
	if file == null:
		return default_margins

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(json_text)
	if err != OK:
		return default_margins

	var data: Variant = json.data
	if data is Array:
		for entry: Variant in data:
			if entry is Dictionary and entry.get("asset", "") == asset_name:
				return {
					"left": entry.get("patch_margin_left", 48),
					"right": entry.get("patch_margin_right", 48),
					"top": entry.get("patch_margin_top", 48),
					"bottom": entry.get("patch_margin_bottom", 48),
				}

	return default_margins

## 행동 버튼을 생성한다.
## @param label_text 버튼 라벨
## @param action_id 행동 ID
## @returns Button 노드
func _create_action_button(label_text: String, action_id: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = BUTTON_SIZE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 버튼 스타일
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_NORMAL
	normal_style.corner_radius_top_left = 4
	normal_style.corner_radius_top_right = 4
	normal_style.corner_radius_bottom_left = 4
	normal_style.corner_radius_bottom_right = 4
	normal_style.content_margin_left = 8
	normal_style.content_margin_right = 8
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_HOVER
	hover_style.corner_radius_top_left = 4
	hover_style.corner_radius_top_right = 4
	hover_style.corner_radius_bottom_left = 4
	hover_style.corner_radius_bottom_right = 4
	hover_style.content_margin_left = 8
	hover_style.content_margin_right = 8
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = COLOR_PRESSED
	pressed_style.corner_radius_top_left = 4
	pressed_style.corner_radius_top_right = 4
	pressed_style.corner_radius_bottom_left = 4
	pressed_style.corner_radius_bottom_right = 4
	pressed_style.content_margin_left = 8
	pressed_style.content_margin_right = 8
	btn.add_theme_stylebox_override("pressed", pressed_style)

	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = COLOR_HOVER
	focus_style.border_color = COLOR_ACCENT
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	focus_style.corner_radius_top_left = 4
	focus_style.corner_radius_top_right = 4
	focus_style.corner_radius_bottom_left = 4
	focus_style.corner_radius_bottom_right = 4
	focus_style.content_margin_left = 8
	focus_style.content_margin_right = 8
	btn.add_theme_stylebox_override("focus", focus_style)

	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_ACCENT)
	btn.add_theme_font_size_override("font_size", 16)

	btn.pressed.connect(_on_action_pressed.bind(action_id))
	return btn

## 행동 버튼 클릭 콜백
## @param action_id 선택된 행동 ID
func _on_action_pressed(action_id: String) -> void:
	hide_menu()
	action_selected.emit(action_id)

## 내부 노드를 정리한다.
func _cleanup() -> void:
	_buttons.clear()
	if _menu_container:
		_menu_container.queue_free()
		_menu_container = null
	_button_container = null

## @fileoverview 전투 결과 화면. 승리/패배 시 경험치, 레벨업, 획득 아이템을 표시한다.
## 승리 시 확인 버튼, 패배 시 재도전/월드맵 버튼을 제공한다.
class_name BattleResult
extends CanvasLayer

# ── 상수 ──

## 렌더 레이어 (최상위)
const RESULT_LAYER: int = 80

## 패널 크기
const PANEL_WIDTH: float = 600.0
const PANEL_MIN_HEIGHT: float = 400.0

## 색상
const COLOR_OVERLAY := Color(0.0, 0.0, 0.0, 0.6)
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_VICTORY := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_DEFEAT := Color(0.7, 0.3, 0.3, 1.0)
const COLOR_LEVEL_UP := Color(0.3, 0.9, 0.5, 1.0)
const COLOR_GOLD := Color(1.0, 0.85, 0.3, 1.0)
const COLOR_ITEM := Color(0.5, 0.7, 1.0, 1.0)
const COLOR_BTN_NORMAL := Color(0.15, 0.15, 0.22, 1.0)
const COLOR_BTN_HOVER := Color(0.25, 0.25, 0.35, 1.0)
const COLOR_BTN_ACCENT := Color(0.85, 0.55, 0.2, 0.3)

## 패널 여백
const PADDING: int = 24

# ── 시그널 ──

## 결과 확인 (승리 후)
signal result_confirmed
## 재도전 요청 (패배 후)
signal retry_requested
## 월드맵 복귀 요청 (패배 후)
signal return_to_map

# ── 멤버 변수 ──

## 오버레이 배경
var _overlay: ColorRect = null

## 결과 패널
var _panel: Control = null

# ── 초기화 ──

func _ready() -> void:
	layer = RESULT_LAYER
	visible = false

# ── 결과 표시 ──

## 전투 결과를 표시한다.
## @param result_data 결과 데이터 Dictionary
## result_data = {
##   "victory": bool,
##   "exp_results": [{unit_id, exp_gained, leveled_up, old_level, new_level, stat_gains}],
##   "gold_earned": int,
##   "items_earned": [{item_id, name_ko, count}],
## }
func show_result(result_data: Dictionary) -> void:
	_cleanup()

	var is_victory: bool = result_data.get("victory", false)

	# 오버레이 배경
	_overlay = ColorRect.new()
	_overlay.color = COLOR_OVERLAY
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# 결과 패널
	if is_victory:
		_panel = _build_victory_panel(result_data)
	else:
		_panel = _build_defeat_panel()
	add_child(_panel)

	visible = true

# ── 승리 패널 ──

## 승리 결과 패널을 구성한다.
## @param result_data 결과 데이터
## @returns Control 패널 노드
func _build_victory_panel(result_data: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_MIN_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	style.border_color = COLOR_VICTORY.darkened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 타이틀
	var title := Label.new()
	title.text = "전투 승리!"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_VICTORY)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 경험치 결과
	var exp_results: Array = result_data.get("exp_results", [])
	if not exp_results.is_empty():
		var exp_scroll := ScrollContainer.new()
		exp_scroll.custom_minimum_size = Vector2(0, 150)
		exp_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(exp_scroll)

		var exp_list := VBoxContainer.new()
		exp_list.add_theme_constant_override("separation", 6)
		exp_scroll.add_child(exp_list)

		for exp_entry: Variant in exp_results:
			if not exp_entry is Dictionary:
				continue
			var entry: Dictionary = exp_entry as Dictionary
			var row := _build_exp_row(entry)
			exp_list.add_child(row)

	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# 획득 골드
	var gold_earned: int = result_data.get("gold_earned", 0)
	if gold_earned > 0:
		var gold_label := Label.new()
		gold_label.text = "획득 골드: %dG" % gold_earned
		gold_label.add_theme_font_size_override("font_size", 16)
		gold_label.add_theme_color_override("font_color", COLOR_GOLD)
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gold_label)

	# 획득 아이템
	var items_earned: Array = result_data.get("items_earned", [])
	if not items_earned.is_empty():
		var items_label := Label.new()
		var item_names: Array[String] = []
		for item_entry: Variant in items_earned:
			if item_entry is Dictionary:
				var idata: Dictionary = item_entry as Dictionary
				var iname: String = idata.get("name_ko", idata.get("item_id", ""))
				var icount: int = idata.get("count", 1)
				if icount > 1:
					item_names.append("%s x%d" % [iname, icount])
				else:
					item_names.append(iname)
		items_label.text = "획득 아이템: %s" % ", ".join(item_names)
		items_label.add_theme_font_size_override("font_size", 14)
		items_label.add_theme_color_override("font_color", COLOR_ITEM)
		items_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		items_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(items_label)

	# 확인 버튼
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var confirm_btn := _create_button("확인", true)
	confirm_btn.pressed.connect(_on_confirm)
	btn_container.add_child(confirm_btn)

	# 패널 위치: 화면 중앙
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-PANEL_WIDTH / 2, -PANEL_MIN_HEIGHT / 2)

	return panel

## 경험치 행을 구성한다.
## @param entry {unit_id, exp_gained, leveled_up, old_level, new_level, stat_gains}
## @returns HBoxContainer 행
func _build_exp_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# 유닛 이름 (DataManager에서 조회 시도)
	var unit_id: String = entry.get("unit_id", "")
	var display_name: String = _get_unit_display_name(unit_id)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_label)

	# EXP
	var exp_gained: int = entry.get("exp_gained", 0)
	var exp_label := Label.new()
	exp_label.text = "+%d EXP" % exp_gained
	exp_label.add_theme_font_size_override("font_size", 14)
	exp_label.add_theme_color_override("font_color", COLOR_ACCENT)
	exp_label.custom_minimum_size = Vector2(100, 0)
	row.add_child(exp_label)

	# 레벨업 표시
	var leveled_up: bool = entry.get("leveled_up", false)
	if leveled_up:
		var old_level: int = entry.get("old_level", 1)
		var new_level: int = entry.get("new_level", 1)
		var levelup_label := Label.new()
		levelup_label.text = "Lv.%d -> Lv.%d!" % [old_level, new_level]
		levelup_label.add_theme_font_size_override("font_size", 14)
		levelup_label.add_theme_color_override("font_color", COLOR_LEVEL_UP)
		row.add_child(levelup_label)

		# 스탯 증가 표시
		var stat_gains: Dictionary = entry.get("stat_gains", {})
		if not stat_gains.is_empty():
			var gains_parts: Array[String] = []
			for key: String in stat_gains:
				var gain_val: int = stat_gains[key]
				if gain_val > 0:
					gains_parts.append("%s+%d" % [key.to_upper(), gain_val])
			if not gains_parts.is_empty():
				var gains_label := Label.new()
				gains_label.text = "(%s)" % " ".join(gains_parts)
				gains_label.add_theme_font_size_override("font_size", 12)
				gains_label.add_theme_color_override("font_color", COLOR_LEVEL_UP.darkened(0.2))
				row.add_child(gains_label)

	return row

# ── 패배 패널 ──

## 패배 결과 패널을 구성한다.
## @returns Control 패널 노드
func _build_defeat_panel() -> Control:
	var panel := PanelContainer.new()
	var defeat_height: float = 200.0
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, defeat_height)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	style.border_color = COLOR_DEFEAT.darkened(0.3)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 타이틀
	var title := Label.new()
	title.text = "전투 패배..."
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_DEFEAT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# 여백
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# 버튼 행
	var btn_container := HBoxContainer.new()
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_container)

	var retry_btn := _create_button("재도전", true)
	retry_btn.pressed.connect(_on_retry)
	btn_container.add_child(retry_btn)

	var map_btn := _create_button("월드맵으로", false)
	map_btn.pressed.connect(_on_return_to_map)
	btn_container.add_child(map_btn)

	# 패널 위치: 화면 중앙
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-PANEL_WIDTH / 2, -defeat_height / 2)

	return panel

# ── 버튼 생성 ──

## 스타일 적용된 버튼을 생성한다.
## @param text 버튼 텍스트
## @param is_primary 주요 버튼 여부 (accent 색상 적용)
## @returns Button 노드
func _create_button(text: String, is_primary: bool) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 44)

	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = COLOR_BTN_ACCENT if is_primary else COLOR_BTN_NORMAL
	normal_style.corner_radius_top_left = 6
	normal_style.corner_radius_top_right = 6
	normal_style.corner_radius_bottom_left = 6
	normal_style.corner_radius_bottom_right = 6
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = COLOR_BTN_HOVER
	hover_style.corner_radius_top_left = 6
	hover_style.corner_radius_top_right = 6
	hover_style.corner_radius_bottom_left = 6
	hover_style.corner_radius_bottom_right = 6
	hover_style.border_color = COLOR_ACCENT if is_primary else COLOR_TEXT_DIM
	hover_style.border_width_left = 1
	hover_style.border_width_right = 1
	hover_style.border_width_top = 1
	hover_style.border_width_bottom = 1
	hover_style.content_margin_left = 12
	hover_style.content_margin_right = 12
	btn.add_theme_stylebox_override("hover", hover_style)

	var focus_style := hover_style.duplicate() as StyleBoxFlat
	focus_style.border_color = COLOR_ACCENT
	focus_style.border_width_left = 2
	focus_style.border_width_right = 2
	focus_style.border_width_top = 2
	focus_style.border_width_bottom = 2
	btn.add_theme_stylebox_override("focus", focus_style)

	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COLOR_TEXT)
	btn.add_theme_color_override("font_hover_color", COLOR_ACCENT)

	return btn

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	# Enter로 확인 (승리 시)
	if event.is_action_pressed("ui_accept"):
		if _panel:
			_on_confirm()
		get_viewport().set_input_as_handled()

# ── 이벤트 핸들러 ──

## 확인 버튼 클릭
func _on_confirm() -> void:
	_cleanup()
	visible = false
	result_confirmed.emit()

## 재도전 버튼 클릭
func _on_retry() -> void:
	_cleanup()
	visible = false
	retry_requested.emit()

## 월드맵 복귀 버튼 클릭
func _on_return_to_map() -> void:
	_cleanup()
	visible = false
	return_to_map.emit()

# ── 내부 유틸 ──

## 유닛 표시 이름을 조회한다 (DataManager에서 한국어 이름 검색).
## @param unit_id 유닛 ID
## @returns 표시 이름
func _get_unit_display_name(unit_id: String) -> String:
	var dm: Node = _get_data_manager()
	if dm:
		var char_data: Dictionary = dm.get_character(unit_id)
		if not char_data.is_empty():
			return char_data.get("name_ko", unit_id)
	return unit_id

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

## 내부 노드를 정리한다.
func _cleanup() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if _panel:
		_panel.queue_free()
		_panel = null

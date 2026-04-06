## @fileoverview 편성 화면. 좌측에 전체 파티, 우측에 출격 슬롯 8개를 표시한다.
## 캐릭터를 클릭하여 출격 슬롯에 추가/제거한다. 카엘은 고정 출격.
extends Control

# ── 상수 ──

## 슬롯 크기
const SLOT_SIZE := Vector2(160, 48)
## 패널 패딩
const PADDING := 16
## 색상 테마
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_SLOT_EMPTY := Color(0.15, 0.15, 0.22, 1.0)
const COLOR_SLOT_FILLED := Color(0.18, 0.22, 0.28, 1.0)
const COLOR_SLOT_KAEL := Color(0.25, 0.18, 0.12, 1.0)
const COLOR_SLOT_HOVER := Color(0.25, 0.28, 0.35, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)

# ── 노드 참조 ──

## 좌측 파티원 리스트 컨테이너
var _party_list: VBoxContainer
## 우측 출격 슬롯 그리드
var _active_grid: GridContainer
## 확인 버튼
var _confirm_btn: Button
## 제목 라벨
var _title_label: Label
## 출격 인원 라벨
var _count_label: Label

## 현재 선택된 캐릭터 ID
var _selected_char: String = ""
## 임시 출격 파티 (확인 전까지 적용하지 않음)
var _temp_active: Array[String] = []

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	_refresh()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	# 풀스크린 배경
	anchors_preset = Control.PRESET_FULL_RECT
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 메인 패널 (중앙 정렬, 고정 크기)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1200, 700)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-600, -350)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = COLOR_PANEL
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = PADDING
	panel_style.content_margin_right = PADDING
	panel_style.content_margin_top = PADDING
	panel_style.content_margin_bottom = PADDING
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# 헤더
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "편성"
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title_label)

	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", COLOR_TEXT)
	header.add_child(_count_label)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 구분선
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 메인 콘텐츠 (좌: 전체 파티, 우: 출격 슬롯)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# 좌측: 전체 파티원 목록
	var left_panel := VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.add_theme_constant_override("separation", 8)
	content.add_child(left_panel)

	var left_title := Label.new()
	left_title.text = "전체 파티원"
	left_title.add_theme_font_size_override("font_size", 18)
	left_title.add_theme_color_override("font_color", COLOR_TEXT)
	left_panel.add_child(left_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(scroll)

	_party_list = VBoxContainer.new()
	_party_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_party_list)

	# 우측: 출격 슬롯
	var right_panel := VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.add_theme_constant_override("separation", 8)
	content.add_child(right_panel)

	var right_title := Label.new()
	right_title.text = "출격 파티 (최대 8명)"
	right_title.add_theme_font_size_override("font_size", 18)
	right_title.add_theme_color_override("font_color", COLOR_TEXT)
	right_panel.add_child(right_title)

	_active_grid = GridContainer.new()
	_active_grid.columns = 4
	_active_grid.add_theme_constant_override("h_separation", 8)
	_active_grid.add_theme_constant_override("v_separation", 8)
	right_panel.add_child(_active_grid)

	# 하단: 확인 버튼
	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	vbox.add_child(footer)

	_confirm_btn = Button.new()
	_confirm_btn.text = "확인"
	_confirm_btn.custom_minimum_size = Vector2(120, 40)
	_confirm_btn.pressed.connect(_on_confirm)
	footer.add_child(_confirm_btn)

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

# ── 데이터 갱신 ──

## 화면을 갱신한다.
func _refresh() -> void:
	var pm: Node = get_node("/root/PartyManager")
	_temp_active = pm.active_party.duplicate()
	_refresh_party_list()
	_refresh_active_grid()
	_update_count_label()

## 파티원 목록을 갱신한다.
func _refresh_party_list() -> void:
	# 기존 자식 제거
	for child in _party_list.get_children():
		child.queue_free()

	var pm: Node = get_node("/root/PartyManager")
	var dm: Node = get_node("/root/DataManager")

	for member in pm.party:
		var char_id: String = member["id"]
		var char_data: Dictionary = dm.get_character(char_id)
		var is_active: bool = _temp_active.has(char_id)

		var row := _create_party_row(char_id, char_data, member, is_active)
		_party_list.add_child(row)

## 파티원 행을 생성한다.
func _create_party_row(char_id: String, char_data: Dictionary, member: Dictionary, is_active: bool) -> Control:
	var btn := Button.new()
	var name_ko: String = char_data.get("name_ko", char_id)
	var class_ko: String = char_data.get("class_ko", "")
	var level: int = member.get("level", 1)
	var active_mark: String = " [출격]" if is_active else ""
	var kael_mark: String = " *" if char_id == "kael" else ""

	btn.text = "%s%s  %s  Lv.%d%s" % [name_ko, kael_mark, class_ko, level, active_mark]
	btn.custom_minimum_size = Vector2(400, 36)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	if is_active:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_SLOT_FILLED
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		btn.add_theme_stylebox_override("normal", style)

	btn.pressed.connect(_on_party_member_clicked.bind(char_id))
	return btn

## 출격 슬롯 그리드를 갱신한다.
func _refresh_active_grid() -> void:
	for child in _active_grid.get_children():
		child.queue_free()

	var pm: Node = get_node("/root/PartyManager")
	var dm: Node = get_node("/root/DataManager")

	for i in range(8):
		var slot := Button.new()
		slot.custom_minimum_size = SLOT_SIZE

		if i < _temp_active.size():
			var char_id: String = _temp_active[i]
			var char_data: Dictionary = dm.get_character(char_id)
			var member: Dictionary = pm.get_party_member(char_id)
			var name_ko: String = char_data.get("name_ko", char_id)
			var level: int = member.get("level", 1)

			slot.text = "%s\nLv.%d" % [name_ko, level]

			var style := StyleBoxFlat.new()
			if char_id == "kael":
				style.bg_color = COLOR_SLOT_KAEL
			else:
				style.bg_color = COLOR_SLOT_FILLED
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			slot.add_theme_stylebox_override("normal", style)
			slot.pressed.connect(_on_active_slot_clicked.bind(i))
		else:
			slot.text = "(빈 슬롯)"
			var style := StyleBoxFlat.new()
			style.bg_color = COLOR_SLOT_EMPTY
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			slot.add_theme_stylebox_override("normal", style)

		_active_grid.add_child(slot)

## 출격 인원 라벨을 갱신한다.
func _update_count_label() -> void:
	_count_label.text = "출격: %d / %d" % [_temp_active.size(), 8]

# ── 이벤트 핸들러 ──

## 파티원 클릭 시 출격 파티에 추가/제거한다.
func _on_party_member_clicked(char_id: String) -> void:
	if _temp_active.has(char_id):
		# 이미 출격 중이면 제거 (카엘 제외)
		if char_id == "kael":
			return
		_temp_active.erase(char_id)
	else:
		# 출격 추가 (최대 8명)
		if _temp_active.size() >= 8:
			return
		_temp_active.append(char_id)

	_refresh_party_list()
	_refresh_active_grid()
	_update_count_label()

## 출격 슬롯 클릭 시 해당 캐릭터를 제거한다.
func _on_active_slot_clicked(slot_idx: int) -> void:
	if slot_idx >= _temp_active.size():
		return
	var char_id: String = _temp_active[slot_idx]
	# 카엘은 제거 불가
	if char_id == "kael":
		return
	_temp_active.remove_at(slot_idx)

	_refresh_party_list()
	_refresh_active_grid()
	_update_count_label()

## 확인 버튼 → active_party를 갱신하고 닫는다.
func _on_confirm() -> void:
	var pm: Node = get_node("/root/PartyManager")
	var typed_active: Array[String] = []
	for cid in _temp_active:
		typed_active.append(cid)
	pm.set_active(typed_active)
	_on_close()

## 닫기 처리.
func _on_close() -> void:
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.emit("party")
	queue_free()

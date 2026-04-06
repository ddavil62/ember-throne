## @fileoverview 장비 화면. 캐릭터 선택, 장비 슬롯, 스탯 표시, 장비 교체를 담당한다.
## 좌측: 캐릭터 선택, 중앙: 캐릭터 정보/스탯, 우측: 장비 슬롯 및 교체 팝업.
extends Control

# ── 상수 ──

const PADDING := 16
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_SLOT := Color(0.15, 0.15, 0.22, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_STAT_UP := Color(0.3, 0.8, 0.3, 1.0)
const COLOR_STAT_DOWN := Color(0.8, 0.3, 0.3, 1.0)
const COLOR_POPUP_BG := Color(0.1, 0.1, 0.15, 0.98)

## 스탯 표시 이름 매핑
const STAT_NAMES := {
	"hp": "HP", "mp": "MP", "atk": "ATK", "def": "DEF",
	"matk": "MATK", "mdef": "MDEF", "spd": "SPD", "mov": "MOV"
}

# ── 노드 참조 ──

## 캐릭터 선택 리스트
var _char_list: VBoxContainer
## 캐릭터 정보 컨테이너
var _info_container: VBoxContainer
## 장비 슬롯 컨테이너
var _equip_container: VBoxContainer
## 장비 교체 팝업
var _equip_popup: Control = null

## 현재 선택된 캐릭터 ID
var _selected_char: String = ""

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	# 첫 번째 출격 캐릭터를 기본 선택
	var pm: Node = get_node("/root/PartyManager")
	if pm.active_party.size() > 0:
		_selected_char = pm.active_party[0]
	_refresh()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 메인 패널
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1300, 720)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-650, -360)
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
	vbox.add_child(header)

	var title := Label.new()
	title.text = "장비"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 메인 콘텐츠 (3열)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# 좌측: 캐릭터 선택
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(200, 0)
	left.add_theme_constant_override("separation", 4)
	content.add_child(left)

	var left_title := Label.new()
	left_title.text = "캐릭터"
	left_title.add_theme_font_size_override("font_size", 16)
	left_title.add_theme_color_override("font_color", COLOR_TEXT)
	left.add_child(left_title)

	var char_scroll := ScrollContainer.new()
	char_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(char_scroll)

	_char_list = VBoxContainer.new()
	_char_list.add_theme_constant_override("separation", 2)
	char_scroll.add_child(_char_list)

	# 중앙: 캐릭터 정보/스탯
	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(400, 0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)
	content.add_child(center)

	_info_container = VBoxContainer.new()
	_info_container.add_theme_constant_override("separation", 8)
	center.add_child(_info_container)

	# 우측: 장비 슬롯
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(350, 0)
	right.add_theme_constant_override("separation", 8)
	content.add_child(right)

	var right_title := Label.new()
	right_title.text = "장비 슬롯"
	right_title.add_theme_font_size_override("font_size", 16)
	right_title.add_theme_color_override("font_color", COLOR_TEXT)
	right.add_child(right_title)

	_equip_container = VBoxContainer.new()
	_equip_container.add_theme_constant_override("separation", 8)
	right.add_child(_equip_container)

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _equip_popup != null:
			_close_equip_popup()
		else:
			_on_close()
		get_viewport().set_input_as_handled()

# ── 데이터 갱신 ──

## 전체 화면을 갱신한다.
func _refresh() -> void:
	_refresh_char_list()
	_refresh_info()
	_refresh_equip_slots()

## 캐릭터 목록을 갱신한다.
func _refresh_char_list() -> void:
	for child in _char_list.get_children():
		child.queue_free()

	var pm: Node = get_node("/root/PartyManager")
	var dm: Node = get_node("/root/DataManager")

	for cid in pm.active_party:
		var char_data: Dictionary = dm.get_character(cid)
		var member: Dictionary = pm.get_party_member(cid)
		var name_ko: String = char_data.get("name_ko", cid)
		var level: int = member.get("level", 1)

		var btn := Button.new()
		btn.text = "%s Lv.%d" % [name_ko, level]
		btn.custom_minimum_size = Vector2(180, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if cid == _selected_char:
			var style := StyleBoxFlat.new()
			style.bg_color = COLOR_ACCENT.darkened(0.3)
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(_on_char_selected.bind(cid))
		_char_list.add_child(btn)

## 캐릭터 정보/스탯을 갱신한다.
func _refresh_info() -> void:
	for child in _info_container.get_children():
		child.queue_free()

	if _selected_char == "":
		return

	var pm: Node = get_node("/root/PartyManager")
	var dm: Node = get_node("/root/DataManager")
	var char_data: Dictionary = dm.get_character(_selected_char)
	var member: Dictionary = pm.get_party_member(_selected_char)

	if char_data.is_empty() or member.is_empty():
		return

	# 이름 + 클래스 + 레벨
	var name_label := Label.new()
	name_label.text = "%s  |  %s  |  Lv.%d" % [
		char_data.get("name_ko", ""), char_data.get("class_ko", ""), member.get("level", 1)
	]
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_info_container.add_child(name_label)

	var sep := HSeparator.new()
	_info_container.add_child(sep)

	# 스탯 표시
	var stats: Dictionary = pm.calc_stats(_selected_char)
	var stat_title := Label.new()
	stat_title.text = "현재 스탯"
	stat_title.add_theme_font_size_override("font_size", 16)
	stat_title.add_theme_color_override("font_color", COLOR_ACCENT)
	_info_container.add_child(stat_title)

	# 2열 그리드로 스탯 배치
	var stat_grid := GridContainer.new()
	stat_grid.columns = 4
	stat_grid.add_theme_constant_override("h_separation", 16)
	stat_grid.add_theme_constant_override("v_separation", 6)
	_info_container.add_child(stat_grid)

	for key in ["hp", "mp", "atk", "def", "matk", "mdef", "spd", "mov"]:
		var label := Label.new()
		label.text = "%s:" % STAT_NAMES.get(key, key)
		label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		label.add_theme_font_size_override("font_size", 15)
		stat_grid.add_child(label)

		var val := Label.new()
		val.text = str(stats.get(key, 0))
		val.add_theme_color_override("font_color", COLOR_TEXT)
		val.add_theme_font_size_override("font_size", 15)
		val.custom_minimum_size = Vector2(50, 0)
		stat_grid.add_child(val)

	# HP/MP 현재치
	var hp_mp := Label.new()
	hp_mp.text = "HP: %d / %d  |  MP: %d / %d" % [
		member.get("current_hp", 0), stats.get("hp", 0),
		member.get("current_mp", 0), stats.get("mp", 0),
	]
	hp_mp.add_theme_font_size_override("font_size", 14)
	hp_mp.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_info_container.add_child(hp_mp)

## 장비 슬롯을 갱신한다.
func _refresh_equip_slots() -> void:
	for child in _equip_container.get_children():
		child.queue_free()

	if _selected_char == "":
		return

	var pm: Node = get_node("/root/PartyManager")
	var im: Node = get_node("/root/InventoryManager")
	var member: Dictionary = pm.get_party_member(_selected_char)
	if member.is_empty():
		return

	var equipment: Dictionary = member.get("equipment", {})
	var slots := [
		{"key": "weapon", "name": "무기"},
		{"key": "armor", "name": "방어구"},
		{"key": "accessory", "name": "악세서리"},
	]

	for slot_info in slots:
		var slot_key: String = slot_info["key"]
		var slot_name: String = slot_info["name"]
		var item_id: String = equipment.get(slot_key, "")

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_equip_container.add_child(row)

		# 슬롯 이름
		var name_label := Label.new()
		name_label.text = "%s:" % slot_name
		name_label.custom_minimum_size = Vector2(80, 0)
		name_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		row.add_child(name_label)

		# 현재 장착 아이템
		var item_label := Label.new()
		if item_id != "":
			var item_data: Dictionary = im.get_item_data(item_id)
			item_label.text = item_data.get("name_ko", item_id)
		else:
			item_label.text = "(없음)"
			item_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_label.add_theme_color_override("font_color", COLOR_TEXT)
		row.add_child(item_label)

		# 변경 버튼
		var change_btn := Button.new()
		change_btn.text = "변경"
		change_btn.custom_minimum_size = Vector2(60, 28)
		change_btn.pressed.connect(_on_equip_change.bind(slot_key))
		row.add_child(change_btn)

		# 해제 버튼
		if item_id != "":
			var unequip_btn := Button.new()
			unequip_btn.text = "해제"
			unequip_btn.custom_minimum_size = Vector2(60, 28)
			unequip_btn.pressed.connect(_on_unequip.bind(slot_key))
			row.add_child(unequip_btn)

# ── 장비 교체 팝업 ──

## 장비 변경 버튼 클릭 시 교체 가능한 아이템 목록 팝업을 표시한다.
func _on_equip_change(slot: String) -> void:
	if _equip_popup != null:
		_close_equip_popup()

	var equippable: Array[Dictionary] = EquipmentManager.get_equippable_items(_selected_char, slot)

	_equip_popup = Control.new()
	_equip_popup.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_equip_popup)

	# 반투명 배경 (클릭 시 닫기)
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.gui_input.connect(_on_popup_overlay_input)
	_equip_popup.add_child(overlay)

	# 팝업 패널
	var popup_panel := PanelContainer.new()
	popup_panel.custom_minimum_size = Vector2(700, 500)
	popup_panel.anchors_preset = Control.PRESET_CENTER
	popup_panel.position = Vector2(-350, -250)
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = COLOR_POPUP_BG
	popup_style.corner_radius_top_left = 8
	popup_style.corner_radius_top_right = 8
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup_style.content_margin_left = PADDING
	popup_style.content_margin_right = PADDING
	popup_style.content_margin_top = PADDING
	popup_style.content_margin_bottom = PADDING
	popup_panel.add_theme_stylebox_override("panel", popup_style)
	_equip_popup.add_child(popup_panel)

	var pvbox := VBoxContainer.new()
	pvbox.add_theme_constant_override("separation", 8)
	popup_panel.add_child(pvbox)

	# 팝업 헤더
	var slot_names := {"weapon": "무기", "armor": "방어구", "accessory": "악세서리"}
	var popup_header := HBoxContainer.new()
	pvbox.add_child(popup_header)

	var popup_title := Label.new()
	popup_title.text = "%s 변경" % slot_names.get(slot, slot)
	popup_title.add_theme_font_size_override("font_size", 20)
	popup_title.add_theme_color_override("font_color", COLOR_ACCENT)
	popup_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	popup_header.add_child(popup_title)

	var popup_close := Button.new()
	popup_close.text = "닫기"
	popup_close.pressed.connect(_close_equip_popup)
	popup_header.add_child(popup_close)

	var psep := HSeparator.new()
	pvbox.add_child(psep)

	# 아이템 목록
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pvbox.add_child(scroll)

	var item_list := VBoxContainer.new()
	item_list.add_theme_constant_override("separation", 4)
	scroll.add_child(item_list)

	if equippable.is_empty():
		var empty_label := Label.new()
		empty_label.text = "장비 가능한 아이템이 없습니다."
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		item_list.add_child(empty_label)
	else:
		for item_info in equippable:
			var row := _create_equip_item_row(item_info, slot)
			item_list.add_child(row)

## 장비 가능 아이템 행을 생성한다.
func _create_equip_item_row(item_info: Dictionary, slot: String) -> Control:
	var data: Dictionary = item_info["data"]
	var stat_diff: Dictionary = item_info["stat_diff"]
	var item_id: String = item_info["id"]
	var count: int = item_info["count"]

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 아이템 이름 + 수량
	var name_label := Label.new()
	name_label.text = "%s (x%d)" % [data.get("name_ko", item_id), count]
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	hbox.add_child(name_label)

	# 주요 스탯 (슬롯별)
	var stat_text: String = ""
	match slot:
		"weapon":
			stat_text = "ATK+%d" % data.get("atk", 0)
		"armor":
			stat_text = "DEF+%d  MDEF+%d" % [data.get("def", 0), data.get("mdef", 0)]
		"accessory":
			var bonuses: Array = []
			var stat_bonus: Dictionary = data.get("stat_bonus", {})
			for key in stat_bonus.keys():
				var v: int = stat_bonus[key]
				if v != 0:
					bonuses.append("%s+%d" % [STAT_NAMES.get(key, key), v])
			stat_text = "  ".join(bonuses) if bonuses.size() > 0 else "-"

	var stat_label := Label.new()
	stat_label.text = stat_text
	stat_label.custom_minimum_size = Vector2(150, 0)
	stat_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	hbox.add_child(stat_label)

	# 스탯 차이 표시
	var diff_label := Label.new()
	var diff_parts: Array = []
	for key in ["atk", "def", "matk", "mdef", "spd", "hp", "mp"]:
		var d: int = stat_diff.get(key, 0)
		if d != 0:
			var arrow: String = "+" if d > 0 else ""
			diff_parts.append("%s%s%d" % [STAT_NAMES.get(key, key), arrow, d])
	diff_label.text = "  ".join(diff_parts) if diff_parts.size() > 0 else ""

	# 색상: 전체적으로 이득이면 녹색, 손해면 적색
	var total_diff: int = 0
	for key in stat_diff.keys():
		total_diff += stat_diff.get(key, 0)
	if total_diff > 0:
		diff_label.add_theme_color_override("font_color", COLOR_STAT_UP)
	elif total_diff < 0:
		diff_label.add_theme_color_override("font_color", COLOR_STAT_DOWN)
	else:
		diff_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)

	diff_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(diff_label)

	# 장착 버튼
	var equip_btn := Button.new()
	equip_btn.text = "장착"
	equip_btn.custom_minimum_size = Vector2(60, 28)
	equip_btn.pressed.connect(_on_equip_item.bind(slot, item_id))
	hbox.add_child(equip_btn)

	return hbox

## 아이템 장착 처리.
func _on_equip_item(slot: String, item_id: String) -> void:
	var pm: Node = get_node("/root/PartyManager")
	pm.equip(_selected_char, slot, item_id)
	_close_equip_popup()
	_refresh()

## 장비 해제 처리.
func _on_unequip(slot: String) -> void:
	var pm: Node = get_node("/root/PartyManager")
	pm.unequip(_selected_char, slot)
	_refresh()

## 팝업 오버레이 클릭 시 닫기.
func _on_popup_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_equip_popup()

## 장비 팝업 닫기.
func _close_equip_popup() -> void:
	if _equip_popup != null:
		_equip_popup.queue_free()
		_equip_popup = null

# ── 이벤트 핸들러 ──

## 캐릭터 선택 변경.
func _on_char_selected(char_id: String) -> void:
	_selected_char = char_id
	_refresh()

## 닫기 처리.
func _on_close() -> void:
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.emit("equipment")
	queue_free()

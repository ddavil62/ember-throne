## @fileoverview 아이템 화면. 카테고리별 탭, 아이템 목록, 상세 정보, 사용 기능을 담당한다.
## 카테고리: 소비/재료/열쇠아이템. 소비 아이템만 "사용" 가능.
extends Control

# ── 상수 ──

const PADDING := 16
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_GOLD := Color(0.95, 0.85, 0.3, 1.0)
const COLOR_TAB_ACTIVE := Color(0.25, 0.22, 0.18, 1.0)
const COLOR_TAB_INACTIVE := Color(0.15, 0.15, 0.22, 1.0)
const COLOR_SELECTED := Color(0.2, 0.25, 0.3, 1.0)

# ── 상태 ──

## 현재 카테고리 탭 ("consumable" | "material" | "key")
var _current_category: String = "consumable"
## 현재 선택된 아이템 ID
var _selected_item: String = ""

# ── 노드 참조 ──

var _tab_consumable: Button
var _tab_material: Button
var _tab_key: Button
var _item_list: VBoxContainer
var _detail_container: VBoxContainer
var _use_btn: Button

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	_refresh()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1000, 650)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-500, -325)
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
	title.text = "아이템"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 탭 바
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	_tab_consumable = Button.new()
	_tab_consumable.text = "소비"
	_tab_consumable.custom_minimum_size = Vector2(80, 32)
	_tab_consumable.pressed.connect(_on_tab_change.bind("consumable"))
	tab_bar.add_child(_tab_consumable)

	_tab_material = Button.new()
	_tab_material.text = "재료"
	_tab_material.custom_minimum_size = Vector2(80, 32)
	_tab_material.pressed.connect(_on_tab_change.bind("material"))
	tab_bar.add_child(_tab_material)

	_tab_key = Button.new()
	_tab_key.text = "열쇠"
	_tab_key.custom_minimum_size = Vector2(80, 32)
	_tab_key.pressed.connect(_on_tab_change.bind("key"))
	tab_bar.add_child(_tab_key)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 메인 콘텐츠 (좌: 목록, 우: 상세)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(content)

	# 좌측: 아이템 목록
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(left)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_item_list)

	# 우측: 상세 정보
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(350, 0)
	right.add_theme_constant_override("separation", 8)
	content.add_child(right)

	var detail_title := Label.new()
	detail_title.text = "상세 정보"
	detail_title.add_theme_font_size_override("font_size", 16)
	detail_title.add_theme_color_override("font_color", COLOR_TEXT)
	right.add_child(detail_title)

	_detail_container = VBoxContainer.new()
	_detail_container.add_theme_constant_override("separation", 6)
	right.add_child(_detail_container)

	_use_btn = Button.new()
	_use_btn.text = "사용"
	_use_btn.custom_minimum_size = Vector2(120, 36)
	_use_btn.visible = false
	_use_btn.pressed.connect(_on_use_item)
	right.add_child(_use_btn)

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

# ── 데이터 갱신 ──

## 화면을 갱신한다.
func _refresh() -> void:
	_update_tabs()
	_refresh_item_list()
	_refresh_detail()

## 탭 스타일 갱신.
func _update_tabs() -> void:
	var tabs := {"consumable": _tab_consumable, "material": _tab_material, "key": _tab_key}
	var active_style := StyleBoxFlat.new()
	active_style.bg_color = COLOR_TAB_ACTIVE
	active_style.corner_radius_top_left = 4
	active_style.corner_radius_top_right = 4
	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = COLOR_TAB_INACTIVE
	inactive_style.corner_radius_top_left = 4
	inactive_style.corner_radius_top_right = 4

	for key in tabs.keys():
		var btn: Button = tabs[key]
		if btn == null:
			continue
		if key == _current_category:
			btn.add_theme_stylebox_override("normal", active_style)
		else:
			btn.add_theme_stylebox_override("normal", inactive_style)

## 아이템 목록을 갱신한다.
func _refresh_item_list() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	var im: Node = get_node("/root/InventoryManager")
	var all_items: Dictionary = im.get_all_items()
	var found_items: Array = []

	for item_id in all_items.keys():
		var count: int = all_items[item_id]
		if count <= 0:
			continue
		var item_data: Dictionary = im.get_item_data(item_id)
		if item_data.is_empty():
			continue
		if _matches_category(item_data):
			found_items.append({"id": item_id, "data": item_data, "count": count})

	if found_items.is_empty():
		var empty := Label.new()
		empty.text = "아이템이 없습니다."
		empty.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_item_list.add_child(empty)
		return

	for item_info in found_items:
		var btn := Button.new()
		btn.text = "%s  x%d" % [item_info["data"].get("name_ko", item_info["id"]), item_info["count"]]
		btn.custom_minimum_size = Vector2(350, 32)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

		if item_info["id"] == _selected_item:
			var style := StyleBoxFlat.new()
			style.bg_color = COLOR_SELECTED
			style.corner_radius_top_left = 4
			style.corner_radius_top_right = 4
			style.corner_radius_bottom_left = 4
			style.corner_radius_bottom_right = 4
			btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(_on_item_selected.bind(item_info["id"]))
		_item_list.add_child(btn)

## 현재 카테고리에 맞는 아이템인지 확인한다.
func _matches_category(item_data: Dictionary) -> bool:
	var category: String = item_data.get("category", "")
	match _current_category:
		"consumable":
			return category == "consumable"
		"material":
			# 재료/소재 아이템 (무기/방어구/악세서리가 아니고, 소비 아이템도 아닌 것)
			# 현재 데이터 구조상 소재 아이템은 별도 카테고리가 없으므로
			# 소비 아이템 중 effect_type이 없는 것을 재료로 분류
			if category == "consumable":
				var effect_type: String = item_data.get("effect_type", "")
				return effect_type == "" or effect_type == "material"
			return category == "" or category == "material"
		"key":
			# 열쇠 아이템 (key_item 플래그가 있는 것)
			return item_data.get("key_item", false)
	return false

## 상세 정보를 갱신한다.
func _refresh_detail() -> void:
	for child in _detail_container.get_children():
		child.queue_free()
	_use_btn.visible = false

	if _selected_item == "":
		var placeholder := Label.new()
		placeholder.text = "아이템을 선택하세요."
		placeholder.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_container.add_child(placeholder)
		return

	var im: Node = get_node("/root/InventoryManager")
	var item_data: Dictionary = im.get_item_data(_selected_item)
	if item_data.is_empty():
		return

	# 이름
	var name_label := Label.new()
	name_label.text = item_data.get("name_ko", _selected_item)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_detail_container.add_child(name_label)

	# 영문명
	var name_en := Label.new()
	name_en.text = item_data.get("name_en", "")
	name_en.add_theme_font_size_override("font_size", 14)
	name_en.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_detail_container.add_child(name_en)

	var sep := HSeparator.new()
	_detail_container.add_child(sep)

	# 설명
	var desc := Label.new()
	desc.text = item_data.get("description_ko", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(300, 0)
	desc.add_theme_color_override("font_color", COLOR_TEXT)
	_detail_container.add_child(desc)

	# 보유 수량
	var count_label := Label.new()
	count_label.text = "보유: %d개" % im.get_count(_selected_item)
	count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_detail_container.add_child(count_label)

	# 소비 아이템이면 "사용" 버튼 표시 (월드맵에서만)
	var category: String = item_data.get("category", "")
	if category == "consumable" and _current_category == "consumable":
		var gm: Node = get_node("/root/GameManager")
		if gm.current_state == gm.GameState.WORLD_MAP or gm.current_state == gm.GameState.MENU:
			# 전투 전용 아이템은 월드맵에서 사용 불가
			var usable_in_battle_only: bool = item_data.get("usable_in_battle", false)
			var effect_type: String = item_data.get("effect_type", "")
			# 회복 아이템은 월드맵에서도 사용 가능
			if effect_type.begins_with("heal_"):
				_use_btn.visible = true
				_use_btn.disabled = false
			elif not usable_in_battle_only:
				_use_btn.visible = true
				_use_btn.disabled = false

# ── 이벤트 핸들러 ──

## 아이템 선택.
func _on_item_selected(item_id: String) -> void:
	_selected_item = item_id
	_refresh_item_list()
	_refresh_detail()

## 탭 변경.
func _on_tab_change(category: String) -> void:
	_current_category = category
	_selected_item = ""
	_refresh()

## 아이템 사용. (소비 아이템만, 월드맵에서만)
func _on_use_item() -> void:
	if _selected_item == "":
		return
	var im: Node = get_node("/root/InventoryManager")
	var item_data: Dictionary = im.get_item_data(_selected_item)
	if item_data.is_empty():
		return

	var effect_type: String = item_data.get("effect_type", "")
	var value: int = item_data.get("value", 0)

	# 회복 아이템: 전체 파티 회복 (월드맵)
	if effect_type.begins_with("heal_"):
		var pm: Node = get_node("/root/PartyManager")
		if im.remove_item(_selected_item, 1):
			# 파티 전체 회복 적용
			for member in pm.party:
				var stats: Dictionary = pm.calc_stats(member["id"])
				match effect_type:
					"heal_hp_percent":
						var max_hp: int = stats.get("hp", 1)
						var heal: int = int(max_hp * value / 100.0)
						member["current_hp"] = mini(member["current_hp"] + heal, max_hp)
					"heal_mp_percent":
						var max_mp: int = stats.get("mp", 1)
						var heal: int = int(max_mp * value / 100.0)
						member["current_mp"] = mini(member["current_mp"] + heal, max_mp)
					"heal_hp_flat":
						var max_hp: int = stats.get("hp", 1)
						member["current_hp"] = mini(member["current_hp"] + value, max_hp)
			_refresh()

## 닫기 처리.
func _on_close() -> void:
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.emit("inventory")
	queue_free()

## @fileoverview 상점 화면. 구매/판매 탭, 아이템 목록, 골드 관리를 담당한다.
## 구매: 현재 막의 상점 인벤토리 표시. 판매: 보유 아이템 표시 (판매가 = price * 0.5).
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
const COLOR_WARN := Color(0.8, 0.3, 0.3, 1.0)

## 판매 배율
const SELL_RATE := 0.5

# ── 상태 ──

## 현재 탭 ("buy" | "sell")
var _current_tab: String = "buy"
## 상점 데이터 (현재 막/거점)
var _shop_data: Dictionary = {}
## 상점 ID (예: "belmar")
var _shop_id: String = ""
## 현재 막 (예: "act_1")
var _current_act: String = ""

# ── 노드 참조 ──

var _gold_label: Label
var _buy_tab_btn: Button
var _sell_tab_btn: Button
var _item_list: VBoxContainer
var _shop_name_label: Label

# ── 초기화 ──

## 상점 화면 초기화. shop_id와 act를 지정해야 한다.
## @param shop_id 상점 ID (예: "belmar")
## @param act 현재 막 (예: "act_1")
func init(shop_id: String, act: String) -> void:
	_shop_id = shop_id
	_current_act = act
	var dm: Node = get_node("/root/DataManager")
	var shops_data: Dictionary = dm.shops
	if shops_data.has(act):
		var act_shops: Dictionary = shops_data[act]
		if act_shops.has(shop_id):
			_shop_data = act_shops[shop_id]
	_refresh()

func _ready() -> void:
	_build_ui()

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
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	_shop_name_label = Label.new()
	_shop_name_label.text = "상점"
	_shop_name_label.add_theme_font_size_override("font_size", 24)
	_shop_name_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_shop_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_shop_name_label)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", COLOR_GOLD)
	header.add_child(_gold_label)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_close)
	header.add_child(close_btn)

	# 탭 바
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	vbox.add_child(tab_bar)

	_buy_tab_btn = Button.new()
	_buy_tab_btn.text = "구매"
	_buy_tab_btn.custom_minimum_size = Vector2(100, 36)
	_buy_tab_btn.pressed.connect(_on_tab_buy)
	tab_bar.add_child(_buy_tab_btn)

	_sell_tab_btn = Button.new()
	_sell_tab_btn.text = "판매"
	_sell_tab_btn.custom_minimum_size = Vector2(100, 36)
	_sell_tab_btn.pressed.connect(_on_tab_sell)
	tab_bar.add_child(_sell_tab_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 아이템 목록
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_item_list = VBoxContainer.new()
	_item_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_item_list)

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_close()
		get_viewport().set_input_as_handled()

# ── 데이터 갱신 ──

## 화면을 갱신한다.
func _refresh() -> void:
	_update_gold()
	_update_tabs()
	_update_shop_name()
	if _current_tab == "buy":
		_refresh_buy_list()
	else:
		_refresh_sell_list()

## 골드 표시 갱신.
func _update_gold() -> void:
	if _gold_label == null:
		return
	var im: Node = get_node("/root/InventoryManager")
	_gold_label.text = "소지금: %s G" % _format_number(im.gold)

## 상점 이름 갱신.
func _update_shop_name() -> void:
	if _shop_name_label == null:
		return
	_shop_name_label.text = _shop_data.get("name_ko", "상점")

## 탭 스타일 갱신.
func _update_tabs() -> void:
	if _buy_tab_btn == null:
		return

	var active_style := StyleBoxFlat.new()
	active_style.bg_color = COLOR_TAB_ACTIVE
	active_style.corner_radius_top_left = 4
	active_style.corner_radius_top_right = 4

	var inactive_style := StyleBoxFlat.new()
	inactive_style.bg_color = COLOR_TAB_INACTIVE
	inactive_style.corner_radius_top_left = 4
	inactive_style.corner_radius_top_right = 4

	if _current_tab == "buy":
		_buy_tab_btn.add_theme_stylebox_override("normal", active_style)
		_sell_tab_btn.add_theme_stylebox_override("normal", inactive_style)
	else:
		_buy_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		_sell_tab_btn.add_theme_stylebox_override("normal", active_style)

## 구매 목록을 갱신한다.
func _refresh_buy_list() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	if _shop_data.is_empty():
		var empty := Label.new()
		empty.text = "상점 데이터가 없습니다."
		empty.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_item_list.add_child(empty)
		return

	var im: Node = get_node("/root/InventoryManager")

	# 카테고리별 아이템 수집
	var categories := [
		{"key": "weapons", "name": "무기"},
		{"key": "armor", "name": "방어구"},
		{"key": "accessories", "name": "악세서리"},
		{"key": "consumables", "name": "소비"},
	]

	for cat in categories:
		var items: Array = _get_shop_items(cat["key"])
		if items.is_empty():
			continue

		# 카테고리 헤더
		var cat_label := Label.new()
		cat_label.text = "── %s ──" % cat["name"]
		cat_label.add_theme_font_size_override("font_size", 16)
		cat_label.add_theme_color_override("font_color", COLOR_ACCENT)
		_item_list.add_child(cat_label)

		for item_entry in items:
			var item_id: String = ""
			var stock: int = -1  # -1 = 무한
			var restriction: String = ""

			# 문자열이면 단순 아이템, Dictionary면 추가 정보 있음
			if item_entry is String:
				item_id = item_entry
			elif item_entry is Dictionary:
				item_id = item_entry.get("item", "")
				stock = item_entry.get("stock", -1)
				restriction = item_entry.get("restriction", "")

			var item_data: Dictionary = im.get_item_data(item_id)
			if item_data.is_empty():
				continue

			# 난이도 제한 확인
			if restriction == "normal_only":
				var gm: Node = get_node("/root/GameManager")
				if gm.difficulty != "normal":
					continue

			var row := _create_buy_row(item_id, item_data, stock)
			_item_list.add_child(row)

## 상점 카테고리별 아이템 목록을 반환한다. extends 체인도 해석한다.
## @param category 카테고리 키 (weapons, armor 등)
## @returns 아이템 목록 Array
func _get_shop_items(category: String) -> Array:
	var items: Array = []

	# extends 체인 해석
	if _shop_data.has("extends"):
		var parent_id: String = _shop_data["extends"]
		var dm: Node = get_node("/root/DataManager")
		var shops_data: Dictionary = dm.shops
		if shops_data.has(_current_act):
			var act_shops: Dictionary = shops_data[_current_act]
			if act_shops.has(parent_id):
				var parent_data: Dictionary = act_shops[parent_id]
				# 재귀적으로 부모 데이터 수집 (간단 구현: 1단계만)
				items.append_array(parent_data.get(category, []))

	# 자체 아이템
	items.append_array(_shop_data.get(category, []))

	# additional 아이템 (extends 모델)
	var add_key := "additional_%s" % category
	items.append_array(_shop_data.get(add_key, []))

	return items

## 구매 행을 생성한다.
func _create_buy_row(item_id: String, item_data: Dictionary, stock: int) -> Control:
	var im: Node = get_node("/root/InventoryManager")

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	# 아이템 이름
	var name_label := Label.new()
	name_label.text = item_data.get("name_ko", item_id)
	name_label.custom_minimum_size = Vector2(200, 0)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	hbox.add_child(name_label)

	# 스탯 요약
	var stat_label := Label.new()
	stat_label.text = _get_item_stat_summary(item_data)
	stat_label.custom_minimum_size = Vector2(250, 0)
	stat_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	stat_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(stat_label)

	# 재고 표시
	if stock >= 0:
		var stock_label := Label.new()
		stock_label.text = "재고: %d" % stock
		stock_label.custom_minimum_size = Vector2(60, 0)
		stock_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		hbox.add_child(stock_label)

	# 가격
	var price: int = item_data.get("price", 0)
	var price_label := Label.new()
	price_label.text = "%s G" % _format_number(price)
	price_label.custom_minimum_size = Vector2(80, 0)
	if im.gold >= price:
		price_label.add_theme_color_override("font_color", COLOR_GOLD)
	else:
		price_label.add_theme_color_override("font_color", COLOR_WARN)
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)

	# 구매 버튼
	var buy_btn := Button.new()
	buy_btn.text = "구매"
	buy_btn.custom_minimum_size = Vector2(60, 28)
	buy_btn.disabled = (im.gold < price) or (price <= 0) or (stock == 0)
	buy_btn.pressed.connect(_on_buy.bind(item_id, price))
	hbox.add_child(buy_btn)

	return hbox

## 판매 목록을 갱신한다.
func _refresh_sell_list() -> void:
	for child in _item_list.get_children():
		child.queue_free()

	var im: Node = get_node("/root/InventoryManager")
	var all_items: Dictionary = im.get_all_items()

	if all_items.is_empty():
		var empty := Label.new()
		empty.text = "판매할 아이템이 없습니다."
		empty.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_item_list.add_child(empty)
		return

	for item_id in all_items.keys():
		var count: int = all_items[item_id]
		if count <= 0:
			continue

		var item_data: Dictionary = im.get_item_data(item_id)
		if item_data.is_empty():
			continue

		# 유니크 장비는 판매 불가
		if item_data.get("unique", false):
			continue

		# 가격 없는 아이템 (비매품)은 판매 불가
		var base_price: int = item_data.get("price", 0)
		if base_price <= 0:
			continue

		var sell_price: int = int(base_price * SELL_RATE)
		var row := _create_sell_row(item_id, item_data, count, sell_price)
		_item_list.add_child(row)

## 판매 행을 생성한다.
func _create_sell_row(item_id: String, item_data: Dictionary, count: int, sell_price: int) -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var name_label := Label.new()
	name_label.text = "%s (x%d)" % [item_data.get("name_ko", item_id), count]
	name_label.custom_minimum_size = Vector2(250, 0)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	hbox.add_child(name_label)

	var stat_label := Label.new()
	stat_label.text = _get_item_stat_summary(item_data)
	stat_label.custom_minimum_size = Vector2(250, 0)
	stat_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	stat_label.add_theme_font_size_override("font_size", 14)
	hbox.add_child(stat_label)

	var price_label := Label.new()
	price_label.text = "%s G" % _format_number(sell_price)
	price_label.custom_minimum_size = Vector2(80, 0)
	price_label.add_theme_color_override("font_color", COLOR_GOLD)
	price_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(price_label)

	var sell_btn := Button.new()
	sell_btn.text = "판매"
	sell_btn.custom_minimum_size = Vector2(60, 28)
	sell_btn.pressed.connect(_on_sell.bind(item_id, sell_price))
	hbox.add_child(sell_btn)

	return hbox

# ── 아이템 스탯 요약 ──

## 아이템의 주요 스탯을 요약 문자열로 반환한다.
func _get_item_stat_summary(data: Dictionary) -> String:
	var category: String = data.get("category", "")
	match category:
		"weapon":
			var parts: Array = ["ATK+%d" % data.get("atk", 0)]
			if data.get("hit", 0) > 0:
				parts.append("명중 %d" % data["hit"])
			if data.get("crit", 0) > 0:
				parts.append("치명 %d" % data["crit"])
			return "  ".join(parts)
		"armor":
			return "DEF+%d  MDEF+%d" % [data.get("def", 0), data.get("mdef", 0)]
		"accessory":
			var bonuses: Array = []
			var stat_bonus: Dictionary = data.get("stat_bonus", {})
			for key in stat_bonus.keys():
				var v: int = stat_bonus[key]
				if v != 0:
					bonuses.append("%s+%d" % [key.to_upper(), v])
			return "  ".join(bonuses) if bonuses.size() > 0 else "-"
		"consumable":
			return data.get("description_ko", "")
	return ""

# ── 유틸 ──

## 숫자를 천 단위 구분자 포함 문자열로 반환한다.
func _format_number(n: int) -> String:
	var s := str(n)
	var result := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

# ── 이벤트 핸들러 ──

## 구매 처리.
func _on_buy(item_id: String, price: int) -> void:
	var im: Node = get_node("/root/InventoryManager")
	if im.spend_gold(price):
		im.add_item(item_id, 1)
		_refresh()

## 판매 처리.
func _on_sell(item_id: String, sell_price: int) -> void:
	var im: Node = get_node("/root/InventoryManager")
	if im.remove_item(item_id, 1):
		im.add_gold(sell_price)
		_refresh()

## 구매 탭 전환.
func _on_tab_buy() -> void:
	_current_tab = "buy"
	_refresh()

## 판매 탭 전환.
func _on_tab_sell() -> void:
	_current_tab = "sell"
	_refresh()

## 닫기 처리.
func _on_close() -> void:
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.emit("shop")
	queue_free()

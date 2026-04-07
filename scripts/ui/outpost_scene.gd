## @fileoverview 거점 씬 오케스트레이터. 편성/장비/아이템 화면을 탭으로 전환한다.
## 각 하위 화면은 자체 _build_ui()로 UI를 구성하므로 여기서는 탭 전환만 관리한다.
extends Control

# ── 상수 ──

const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)

# ── 노드 참조 ──

## 하위 화면들
var _party_screen: Control = null
var _equipment_screen: Control = null
var _inventory_screen: Control = null

## 탭 버튼
var _tab_party: Button = null
var _tab_equip: Button = null
var _tab_item: Button = null

## 현재 활성 탭
var _current_tab: String = "party"

# ── 초기화 ──

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	# 하위 화면 생성 (class_name이 없으므로 preload)
	var PartyScript := preload("res://scripts/ui/party_screen.gd")
	var EquipScript := preload("res://scripts/ui/equipment_screen.gd")
	var InvScript := preload("res://scripts/ui/inventory_screen.gd")

	_party_screen = Control.new()
	_party_screen.set_script(PartyScript)
	_party_screen.name = "PartyScreen"
	add_child(_party_screen)

	_equipment_screen = Control.new()
	_equipment_screen.set_script(EquipScript)
	_equipment_screen.name = "EquipmentScreen"
	add_child(_equipment_screen)

	_inventory_screen = Control.new()
	_inventory_screen.set_script(InvScript)
	_inventory_screen.name = "InventoryScreen"
	add_child(_inventory_screen)

	_build_tab_bar()
	_switch_tab("party")

	# EventBus 메뉴 닫기 시그널 수신 (하위 화면의 닫기 버튼)
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.connect(_on_menu_closed)

## 상단 탭 바를 생성한다.
func _build_tab_bar() -> void:
	var tab_bar := HBoxContainer.new()
	tab_bar.anchors_preset = Control.PRESET_TOP_WIDE
	tab_bar.offset_top = 0
	tab_bar.offset_bottom = 48
	tab_bar.add_theme_constant_override("separation", 4)
	add_child(tab_bar)

	_tab_party = _create_tab_button("편성", "party")
	tab_bar.add_child(_tab_party)

	_tab_equip = _create_tab_button("장비", "equipment")
	tab_bar.add_child(_tab_equip)

	_tab_item = _create_tab_button("아이템", "inventory")
	tab_bar.add_child(_tab_item)

	# 스페이서
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_bar.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "월드맵"
	back_btn.custom_minimum_size = Vector2(120, 44)
	back_btn.pressed.connect(_return_to_world_map)
	tab_bar.add_child(back_btn)

	# 하위 화면들의 상단 여백 확보
	for screen in [_party_screen, _equipment_screen, _inventory_screen]:
		screen.offset_top = 52

## 탭 버튼을 생성한다.
## @param label 버튼 텍스트
## @param tab_id 탭 식별자
## @returns 버튼 노드
func _create_tab_button(label: String, tab_id: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(140, 44)
	btn.pressed.connect(_switch_tab.bind(tab_id))
	return btn

## 탭을 전환한다.
## @param tab_id 전환할 탭 ("party" | "equipment" | "inventory")
func _switch_tab(tab_id: String) -> void:
	_current_tab = tab_id
	_party_screen.visible = (tab_id == "party")
	_equipment_screen.visible = (tab_id == "equipment")
	_inventory_screen.visible = (tab_id == "inventory")

	# 탭 버튼 스타일 갱신
	_update_tab_style(_tab_party, tab_id == "party")
	_update_tab_style(_tab_equip, tab_id == "equipment")
	_update_tab_style(_tab_item, tab_id == "inventory")

## 탭 버튼 활성/비활성 스타일 적용
func _update_tab_style(btn: Button, active: bool) -> void:
	if active:
		btn.add_theme_color_override("font_color", COLOR_ACCENT)
	else:
		btn.add_theme_color_override("font_color", COLOR_TEXT)

## EventBus에서 메뉴 닫기 시그널 수신
func _on_menu_closed(menu_type: String) -> void:
	if menu_type in ["party", "equipment", "inventory"]:
		_return_to_world_map()

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

## @fileoverview 전투 HUD. 턴 표시, 미니맵 placeholder, 선택/대상 유닛 정보 패널을
## 상시 표시한다. 모든 요소를 코드로 생성하며 EventBus 시그널에 반응한다.
class_name BattleHUD
extends CanvasLayer

# ── 상수 ──

## HUD 렌더 레이어
const HUD_LAYER: int = 10

## 색상 팔레트
const COLOR_BG_PANEL := Color(0.08, 0.08, 0.12, 0.85)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_HP_HIGH := Color(0.2, 0.9, 0.2)
const COLOR_HP_MID := Color(0.9, 0.9, 0.2)
const COLOR_HP_LOW := Color(0.9, 0.2, 0.2)
const COLOR_MP := Color(0.3, 0.5, 0.9)
const COLOR_PHASE_PLAYER := Color(0.3, 0.5, 1.0)
const COLOR_PHASE_ENEMY := Color(1.0, 0.3, 0.3)
const COLOR_PHASE_NPC := Color(0.3, 0.9, 0.3)
const COLOR_ADVANTAGE := Color(0.3, 0.9, 0.3)
const COLOR_DISADVANTAGE := Color(0.9, 0.3, 0.3)
const COLOR_NEUTRAL := Color(0.6, 0.6, 0.6)

## 유닛 패널 크기
const UNIT_PANEL_SIZE := Vector2(220, 170)

## 초상화 크기
const PORTRAIT_SIZE := Vector2(64, 64)

## 패널 여백
const PADDING: int = 12

# ── 멤버 변수 ──

## BattleMap 참조 (외부에서 주입)
var battle_map: Node2D = null

## 턴 표시 라벨
var _turn_label: Label = null

## 미니맵 placeholder 패널
var _minimap_panel: Panel = null

## 좌측 유닛 패널 (선택 유닛)
var _selected_panel: PanelContainer = null
var _selected_portrait: Control = null
var _selected_name: Label = null
var _selected_class: Label = null
var _selected_hp_bar: ProgressBar = null
var _selected_hp_label: Label = null
var _selected_mp_bar: ProgressBar = null
var _selected_mp_label: Label = null
var _selected_stats: Label = null

## 우측 유닛 패널 (대상 유닛)
var _target_panel: PanelContainer = null
var _target_portrait: Control = null
var _target_name: Label = null
var _target_class: Label = null
var _target_hp_bar: ProgressBar = null
var _target_hp_label: Label = null
var _target_mp_bar: ProgressBar = null
var _target_mp_label: Label = null
var _target_stats: Label = null
var _target_advantage: Label = null

## 현재 선택된 유닛 참조
var _current_selected_unit: BattleUnit = null

# ── 초기화 ──

func _ready() -> void:
	layer = HUD_LAYER
	_build_ui()
	_connect_signals()

## 전체 HUD UI를 코드로 구성한다.
func _build_ui() -> void:
	# 턴 표시 (좌상단)
	_build_turn_display()
	# 미니맵 placeholder (우상단)
	_build_minimap_placeholder()
	# 선택 유닛 패널 (좌하단)
	_selected_panel = _build_unit_panel(true)
	_selected_panel.visible = false
	# 대상 유닛 패널 (우하단)
	_target_panel = _build_unit_panel(false)
	_target_panel.visible = false

## EventBus 시그널을 연결한다.
func _connect_signals() -> void:
	if not Engine.has_singleton("EventBus"):
		var tree := Engine.get_main_loop() as SceneTree
		if tree and tree.root.has_node("EventBus"):
			var eb: Node = tree.root.get_node("EventBus")
			eb.turn_started.connect(_on_turn_started)
			eb.unit_selected.connect(_on_unit_selected)
			eb.unit_deselected.connect(_on_unit_deselected)
			eb.cell_hovered.connect(_on_cell_hovered)
			eb.damage_dealt.connect(_on_damage_dealt)
			eb.heal_applied.connect(_on_heal_applied)

# ── 턴 표시 ──

## 좌상단 턴 표시 라벨을 생성한다.
func _build_turn_display() -> void:
	_turn_label = Label.new()
	_turn_label.text = "Turn 1 - Player Phase"
	_turn_label.add_theme_font_size_override("font_size", 20)
	_turn_label.add_theme_color_override("font_color", COLOR_PHASE_PLAYER)
	_turn_label.position = Vector2(16, 12)
	add_child(_turn_label)

## 턴 정보를 갱신한다.
## @param phase 현재 페이즈 ("player" / "enemy" / "npc")
## @param turn_number 턴 번호
func update_turn_info(phase: String, turn_number: int) -> void:
	if _turn_label == null:
		return

	var phase_label: String = ""
	var phase_color: Color = COLOR_PHASE_PLAYER

	match phase:
		"player":
			phase_label = "Player Phase"
			phase_color = COLOR_PHASE_PLAYER
		"enemy":
			phase_label = "Enemy Phase"
			phase_color = COLOR_PHASE_ENEMY
		"npc":
			phase_label = "NPC Phase"
			phase_color = COLOR_PHASE_NPC
		_:
			phase_label = phase
			phase_color = COLOR_TEXT

	_turn_label.text = "Turn %d - %s" % [turn_number, phase_label]
	_turn_label.add_theme_color_override("font_color", phase_color)

# ── 미니맵 Placeholder ──

## 우상단 미니맵 placeholder를 생성한다 (추후 SubViewport + TextureRect로 교체 예정).
func _build_minimap_placeholder() -> void:
	_minimap_panel = Panel.new()
	_minimap_panel.custom_minimum_size = Vector2(160, 120)
	_minimap_panel.size = Vector2(160, 120)
	# 화면 우상단 배치
	_minimap_panel.position = Vector2(1920 - 160 - 16, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.7)
	style.border_color = Color(0.4, 0.4, 0.5, 0.5)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_minimap_panel.add_theme_stylebox_override("panel", style)
	add_child(_minimap_panel)

	# placeholder 텍스트
	var placeholder_label := Label.new()
	placeholder_label.text = "Minimap"
	placeholder_label.add_theme_font_size_override("font_size", 14)
	placeholder_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder_label.anchors_preset = Control.PRESET_FULL_RECT
	_minimap_panel.add_child(placeholder_label)

# ── 유닛 정보 패널 ──

## 유닛 정보 패널을 생성한다.
## @param is_selected true면 좌하단 (선택 유닛), false면 우하단 (대상 유닛)
## @returns 생성된 PanelContainer
func _build_unit_panel(is_selected: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = UNIT_PANEL_SIZE
	panel.size = UNIT_PANEL_SIZE

	# 위치: 좌하단 또는 우하단
	if is_selected:
		panel.position = Vector2(16, 1080 - UNIT_PANEL_SIZE.y - 16)
	else:
		panel.position = Vector2(1920 - UNIT_PANEL_SIZE.x - 16, 1080 - UNIT_PANEL_SIZE.y - 16)

	# 패널 스타일
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_PANEL
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# 내부 레이아웃
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# 상단: 초상화 + 이름/클래스
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	# 초상화 (TextureRect 또는 ColorRect placeholder)
	var portrait: Control = _create_portrait_placeholder()
	top_row.add_child(portrait)

	# 이름/클래스 컨테이너
	var name_box := VBoxContainer.new()
	name_box.add_theme_constant_override("separation", 2)
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(name_box)

	var name_label := Label.new()
	name_label.text = ""
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_box.add_child(name_label)

	var class_label := Label.new()
	class_label.text = ""
	class_label.add_theme_font_size_override("font_size", 12)
	class_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	name_box.add_child(class_label)

	# HP바
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 4)
	vbox.add_child(hp_row)

	var hp_icon := Label.new()
	hp_icon.text = "HP"
	hp_icon.add_theme_font_size_override("font_size", 12)
	hp_icon.add_theme_color_override("font_color", COLOR_HP_HIGH)
	hp_icon.custom_minimum_size = Vector2(24, 0)
	hp_row.add_child(hp_icon)

	var hp_bar := ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(100, 12)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bar.show_percentage = false
	var hp_style_bg := StyleBoxFlat.new()
	hp_style_bg.bg_color = Color(0.15, 0.15, 0.2)
	hp_style_bg.corner_radius_top_left = 2
	hp_style_bg.corner_radius_top_right = 2
	hp_style_bg.corner_radius_bottom_left = 2
	hp_style_bg.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("background", hp_style_bg)
	var hp_style_fill := StyleBoxFlat.new()
	hp_style_fill.bg_color = COLOR_HP_HIGH
	hp_style_fill.corner_radius_top_left = 2
	hp_style_fill.corner_radius_top_right = 2
	hp_style_fill.corner_radius_bottom_left = 2
	hp_style_fill.corner_radius_bottom_right = 2
	hp_bar.add_theme_stylebox_override("fill", hp_style_fill)
	hp_row.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.text = ""
	hp_label.add_theme_font_size_override("font_size", 11)
	hp_label.add_theme_color_override("font_color", COLOR_TEXT)
	hp_label.custom_minimum_size = Vector2(60, 0)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(hp_label)

	# MP바
	var mp_row := HBoxContainer.new()
	mp_row.add_theme_constant_override("separation", 4)
	vbox.add_child(mp_row)

	var mp_icon := Label.new()
	mp_icon.text = "MP"
	mp_icon.add_theme_font_size_override("font_size", 12)
	mp_icon.add_theme_color_override("font_color", COLOR_MP)
	mp_icon.custom_minimum_size = Vector2(24, 0)
	mp_row.add_child(mp_icon)

	var mp_bar := ProgressBar.new()
	mp_bar.custom_minimum_size = Vector2(100, 12)
	mp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mp_bar.show_percentage = false
	var mp_style_bg := StyleBoxFlat.new()
	mp_style_bg.bg_color = Color(0.15, 0.15, 0.2)
	mp_style_bg.corner_radius_top_left = 2
	mp_style_bg.corner_radius_top_right = 2
	mp_style_bg.corner_radius_bottom_left = 2
	mp_style_bg.corner_radius_bottom_right = 2
	mp_bar.add_theme_stylebox_override("background", mp_style_bg)
	var mp_style_fill := StyleBoxFlat.new()
	mp_style_fill.bg_color = COLOR_MP
	mp_style_fill.corner_radius_top_left = 2
	mp_style_fill.corner_radius_top_right = 2
	mp_style_fill.corner_radius_bottom_left = 2
	mp_style_fill.corner_radius_bottom_right = 2
	mp_bar.add_theme_stylebox_override("fill", mp_style_fill)
	mp_row.add_child(mp_bar)

	var mp_label := Label.new()
	mp_label.text = ""
	mp_label.add_theme_font_size_override("font_size", 11)
	mp_label.add_theme_color_override("font_color", COLOR_TEXT)
	mp_label.custom_minimum_size = Vector2(60, 0)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mp_row.add_child(mp_label)

	# 스탯 요약
	var stats_label := Label.new()
	stats_label.text = ""
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(stats_label)

	# 무기 상성 표시 (대상 패널 전용)
	var advantage_label: Label = null
	if not is_selected:
		advantage_label = Label.new()
		advantage_label.text = ""
		advantage_label.add_theme_font_size_override("font_size", 13)
		vbox.add_child(advantage_label)

	# 노드 참조 저장
	if is_selected:
		_selected_portrait = portrait
		_selected_name = name_label
		_selected_class = class_label
		_selected_hp_bar = hp_bar
		_selected_hp_label = hp_label
		_selected_mp_bar = mp_bar
		_selected_mp_label = mp_label
		_selected_stats = stats_label
	else:
		_target_portrait = portrait
		_target_name = name_label
		_target_class = class_label
		_target_hp_bar = hp_bar
		_target_hp_label = hp_label
		_target_mp_bar = mp_bar
		_target_mp_label = mp_label
		_target_stats = stats_label
		_target_advantage = advantage_label

	return panel

## 초상화 placeholder를 생성한다. 에셋이 있으면 TextureRect, 없으면 ColorRect.
## @returns Control 노드
func _create_portrait_placeholder() -> Control:
	var rect := ColorRect.new()
	rect.custom_minimum_size = PORTRAIT_SIZE
	rect.size = PORTRAIT_SIZE
	rect.color = Color(0.2, 0.2, 0.3, 1.0)
	return rect

# ── 유닛 정보 표시 ──

## 유닛 정보를 패널에 표시한다.
## @param unit 표시할 유닛
## @param is_selected true면 좌측 (선택 유닛), false면 우측 (대상 유닛)
func show_unit_info(unit: BattleUnit, is_selected: bool) -> void:
	if unit == null:
		return

	var panel: PanelContainer
	var portrait: Control
	var name_label: Label
	var class_label: Label
	var hp_bar: ProgressBar
	var hp_label: Label
	var mp_bar: ProgressBar
	var mp_label: Label
	var stats_label: Label

	if is_selected:
		panel = _selected_panel
		portrait = _selected_portrait
		name_label = _selected_name
		class_label = _selected_class
		hp_bar = _selected_hp_bar
		hp_label = _selected_hp_label
		mp_bar = _selected_mp_bar
		mp_label = _selected_mp_label
		stats_label = _selected_stats
		_current_selected_unit = unit
	else:
		panel = _target_panel
		portrait = _target_portrait
		name_label = _target_name
		class_label = _target_class
		hp_bar = _target_hp_bar
		hp_label = _target_hp_label
		mp_bar = _target_mp_bar
		mp_label = _target_mp_label
		stats_label = _target_stats

	if panel == null:
		return

	# 이름, 클래스
	name_label.text = "%s  Lv.%d" % [unit.unit_name_ko if unit.unit_name_ko != "" else unit.unit_id, unit.level]
	class_label.text = unit.class_name_ko if unit.class_name_ko != "" else unit.team

	# HP
	var max_hp: int = maxi(unit.stats.get("hp", 1), 1)
	hp_bar.max_value = max_hp
	hp_bar.value = unit.current_hp
	hp_label.text = "%d/%d" % [unit.current_hp, max_hp]
	_update_hp_bar_color(hp_bar, unit.current_hp, max_hp)

	# MP
	var max_mp: int = maxi(unit.stats.get("mp", 1), 1)
	mp_bar.max_value = max_mp
	mp_bar.value = unit.current_mp
	mp_label.text = "%d/%d" % [unit.current_mp, max_mp]

	# 스탯 요약
	stats_label.text = "ATK:%d  DEF:%d  SPD:%d" % [
		unit.stats.get("atk", 0),
		unit.stats.get("def", 0),
		unit.stats.get("spd", 0),
	]

	# 초상화 로드 시도
	_try_load_portrait(unit, portrait)

	panel.visible = true

## 유닛 정보를 숨긴다.
## @param is_selected true면 좌측, false면 우측
func hide_unit_info(is_selected: bool) -> void:
	if is_selected:
		if _selected_panel:
			_selected_panel.visible = false
		_current_selected_unit = null
	else:
		if _target_panel:
			_target_panel.visible = false

## 무기 상성 표시를 갱신한다.
## @param advantage -1(불리), 0(중립), +1(유리)
func show_weapon_advantage(advantage: int) -> void:
	if _target_advantage == null:
		return

	match advantage:
		1:
			_target_advantage.text = "  ▲ 유리"
			_target_advantage.add_theme_color_override("font_color", COLOR_ADVANTAGE)
		-1:
			_target_advantage.text = "  ▼ 불리"
			_target_advantage.add_theme_color_override("font_color", COLOR_DISADVANTAGE)
		_:
			_target_advantage.text = "  — 중립"
			_target_advantage.add_theme_color_override("font_color", COLOR_NEUTRAL)

# ── HP바 색상 갱신 ──

## HP 비율에 따라 HP바 fill 색상을 갱신한다.
## @param bar ProgressBar 노드
## @param current 현재 HP
## @param max_val 최대 HP
func _update_hp_bar_color(bar: ProgressBar, current: int, max_val: int) -> void:
	var ratio: float = float(current) / float(maxi(max_val, 1))
	var color: Color
	if ratio > 0.5:
		color = COLOR_HP_HIGH
	elif ratio > 0.25:
		color = COLOR_HP_MID
	else:
		color = COLOR_HP_LOW

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)

# ── 초상화 로드 ──

## 유닛의 초상화 에셋을 로드한다. 없으면 placeholder 유지.
## @param unit 대상 유닛
## @param portrait_node 초상화 Control 노드
func _try_load_portrait(unit: BattleUnit, portrait_node: Control) -> void:
	var portrait_path := "res://assets/portraits/%s_neutral.png" % unit.unit_id
	if ResourceLoader.exists(portrait_path):
		var tex: Texture2D = load(portrait_path)
		if tex and portrait_node is ColorRect:
			# ColorRect를 TextureRect로 교체
			var parent: Node = portrait_node.get_parent()
			var idx: int = portrait_node.get_index()
			portrait_node.queue_free()
			var tex_rect := TextureRect.new()
			tex_rect.texture = tex
			tex_rect.custom_minimum_size = PORTRAIT_SIZE
			tex_rect.size = PORTRAIT_SIZE
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			parent.add_child(tex_rect)
			parent.move_child(tex_rect, idx)
	else:
		# placeholder 색상을 팀에 따라 변경
		if portrait_node is ColorRect:
			if unit.team == "player":
				portrait_node.color = Color(0.15, 0.2, 0.35, 1.0)
			elif unit.team == "enemy":
				portrait_node.color = Color(0.35, 0.15, 0.15, 1.0)
			else:
				portrait_node.color = Color(0.2, 0.3, 0.2, 1.0)

# ── EventBus 콜백 ──

## 턴 시작 시그널 콜백
## @param phase 페이즈
## @param turn_number 턴 번호
func _on_turn_started(phase: String, turn_number: int) -> void:
	update_turn_info(phase, turn_number)

## 유닛 선택 시그널 콜백
## @param unit_id 선택된 유닛 ID
func _on_unit_selected(unit_id: String) -> void:
	if battle_map == null:
		return
	var unit: BattleUnit = battle_map.get_unit_by_id(unit_id)
	if unit:
		show_unit_info(unit, true)

## 유닛 선택 해제 시그널 콜백
func _on_unit_deselected() -> void:
	hide_unit_info(true)
	hide_unit_info(false)

## 셀 호버 시그널 콜백. 호버된 셀에 유닛이 있으면 우측 패널 갱신.
## @param cell 호버된 셀 좌표
func _on_cell_hovered(cell: Vector2i) -> void:
	if battle_map == null:
		return
	var unit: BattleUnit = battle_map.get_unit_at(cell)
	if unit:
		show_unit_info(unit, false)
		# 무기 상성 계산 (선택된 유닛이 있을 때만)
		if _current_selected_unit and _current_selected_unit != unit:
			var attacker_weapon: String = _get_unit_weapon_type(_current_selected_unit)
			var defender_weapon: String = _get_unit_weapon_type(unit)
			var advantage: int = WeaponTriangle.get_weapon_advantage(attacker_weapon, defender_weapon)
			show_weapon_advantage(advantage)
		else:
			show_weapon_advantage(0)
	else:
		hide_unit_info(false)

## 데미지 발생 시 패널 갱신
## @param _attacker_id 공격자 ID
## @param defender_id 피격자 ID
## @param _amount 데미지량
## @param _is_crit 크리티컬 여부
func _on_damage_dealt(_attacker_id: String, defender_id: String, _amount: int, _is_crit: bool) -> void:
	# 선택 유닛이 맞았으면 좌측 갱신
	if _current_selected_unit and _current_selected_unit.unit_id == defender_id:
		show_unit_info(_current_selected_unit, true)

## 힐 발생 시 패널 갱신
## @param _healer_id 힐러 ID
## @param target_id 대상 ID
## @param _amount 힐량
func _on_heal_applied(_healer_id: String, target_id: String, _amount: int) -> void:
	if _current_selected_unit and _current_selected_unit.unit_id == target_id:
		show_unit_info(_current_selected_unit, true)

# ── 내부 유틸 ──

## 유닛의 무기 타입을 조회한다.
## @param unit 대상 유닛
## @returns 무기 타입 문자열
func _get_unit_weapon_type(unit: BattleUnit) -> String:
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return ""
	var dm: Node = _get_data_manager()
	if dm == null:
		return ""
	var weapon_data: Dictionary = dm.get_weapon(weapon_id)
	return weapon_data.get("type", "")

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

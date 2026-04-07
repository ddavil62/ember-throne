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
var battle_map: Node2D = null:
	set(value):
		battle_map = value
		if _battle_log:
			_battle_log.battle_map = value

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

## 지형 정보 패널 (2-6: 좌하단 지형 표시)
var _terrain_panel: PanelContainer = null
var _terrain_name: Label = null
var _terrain_cost: Label = null
var _terrain_evade: Label = null
var _terrain_def: Label = null
var _terrain_special: Label = null

## 유닛 상세 정보 팝업 (2-5)
var _detail_popup: PanelContainer = null
var _detail_content: VBoxContainer = null
var _detail_visible: bool = false

## 턴 종료 확인 대화상자 (2-7)
var _confirm_dialog: PanelContainer = null
var _confirm_label: Label = null
var _confirm_visible: bool = false

## 전투 로그 패널
var _battle_log: BattleLog = null

## 배속 토글 버튼
var _speed_button: Button = null

# ── 초기화 ──

func _ready() -> void:
	layer = HUD_LAYER
	_build_ui()
	_connect_signals()

## 전체 HUD UI를 코드로 구성한다.
func _build_ui() -> void:
	# 턴 표시 (좌상단)
	_build_turn_display()
	# 배속 토글 버튼 (턴 라벨 우측)
	_build_speed_button()
	# 미니맵 placeholder (우상단)
	_build_minimap_placeholder()
	# 선택 유닛 패널 (좌하단)
	_selected_panel = _build_unit_panel(true)
	_selected_panel.visible = false
	# 대상 유닛 패널 (우하단)
	_target_panel = _build_unit_panel(false)
	_target_panel.visible = false
	# 지형 정보 패널 (우하단 위)
	_build_terrain_panel()
	# 유닛 상세 정보 팝업 (중앙)
	_build_detail_popup()
	# 턴 종료 확인 대화상자 (중앙)
	_build_confirm_dialog()
	# 전투 로그 패널 (우측, 미니맵 아래)
	_build_battle_log()

## 전투 로그 패널을 생성한다.
func _build_battle_log() -> void:
	_battle_log = BattleLog.new()
	_battle_log.name = "BattleLog"
	_battle_log.battle_map = battle_map
	add_child(_battle_log)

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
			eb.unit_info_requested.connect(_on_unit_info_requested)
			eb.end_turn_confirm_needed.connect(_on_end_turn_confirm_needed)

# ── 턴 표시 ──

## 좌상단 턴 표시 라벨을 생성한다.
func _build_turn_display() -> void:
	_turn_label = Label.new()
	_turn_label.text = "Turn 1 - Player Phase"
	_turn_label.add_theme_font_size_override("font_size", 20)
	_turn_label.add_theme_color_override("font_color", COLOR_PHASE_PLAYER)
	_turn_label.position = Vector2(16, 12)
	add_child(_turn_label)

## 배속 토글 버튼을 생성한다. 턴 라벨 우측에 배치.
func _build_speed_button() -> void:
	_speed_button = Button.new()
	_speed_button.text = BattleSpeed.get_speed_label()
	_speed_button.custom_minimum_size = Vector2(56, 28)
	_speed_button.position = Vector2(260, 10)
	_speed_button.add_theme_font_size_override("font_size", 16)
	_speed_button.pressed.connect(_on_speed_button_pressed)

	# 스타일: 반투명 배경 + 악센트 테두리
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.12, 0.12, 0.18, 0.85)
	style_normal.border_color = COLOR_ACCENT
	style_normal.set_border_width_all(1)
	style_normal.set_corner_radius_all(4)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	_speed_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.18, 0.18, 0.24, 0.9)
	_speed_button.add_theme_stylebox_override("hover", style_hover)

	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.25, 0.2, 0.12, 0.9)
	_speed_button.add_theme_stylebox_override("pressed", style_pressed)

	_speed_button.add_theme_color_override("font_color", COLOR_ACCENT)
	add_child(_speed_button)

## 배속 버튼 클릭 콜백
func _on_speed_button_pressed() -> void:
	BattleSpeed.cycle_speed()
	_speed_button.text = BattleSpeed.get_speed_label()

## Tab 키로 배속 토글
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB:
			_on_speed_button_pressed()
			get_viewport().set_input_as_handled()

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
## 지형 정보도 갱신한다.
## @param cell 호버된 셀 좌표
func _on_cell_hovered(cell: Vector2i) -> void:
	# 지형 정보 갱신 (2-6)
	_update_terrain_info(cell)

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

# ── 지형 정보 패널 (2-6) ──

## 우하단 상단에 지형 정보 패널을 생성한다. 커서 위치의 지형을 상시 표시.
func _build_terrain_panel() -> void:
	_terrain_panel = PanelContainer.new()
	_terrain_panel.custom_minimum_size = Vector2(180, 100)
	_terrain_panel.size = Vector2(180, 100)
	# 우상단 미니맵 아래에 배치
	_terrain_panel.position = Vector2(1920 - 180 - 16, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG_PANEL
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_terrain_panel.add_theme_stylebox_override("panel", style)
	add_child(_terrain_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_terrain_panel.add_child(vbox)

	_terrain_name = Label.new()
	_terrain_name.text = "—"
	_terrain_name.add_theme_font_size_override("font_size", 14)
	_terrain_name.add_theme_color_override("font_color", COLOR_ACCENT)
	vbox.add_child(_terrain_name)

	_terrain_cost = Label.new()
	_terrain_cost.text = ""
	_terrain_cost.add_theme_font_size_override("font_size", 11)
	_terrain_cost.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(_terrain_cost)

	_terrain_evade = Label.new()
	_terrain_evade.text = ""
	_terrain_evade.add_theme_font_size_override("font_size", 11)
	_terrain_evade.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(_terrain_evade)

	_terrain_def = Label.new()
	_terrain_def.text = ""
	_terrain_def.add_theme_font_size_override("font_size", 11)
	_terrain_def.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	vbox.add_child(_terrain_def)

	_terrain_special = Label.new()
	_terrain_special.text = ""
	_terrain_special.add_theme_font_size_override("font_size", 10)
	_terrain_special.add_theme_color_override("font_color", COLOR_TEXT)
	_terrain_special.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_terrain_special)

## 지형 정보를 갱신한다.
## @param cell 대상 셀 좌표
func _update_terrain_info(cell: Vector2i) -> void:
	if _terrain_panel == null:
		return

	var dm: Node = _get_data_manager()
	if dm == null:
		return

	if battle_map == null or battle_map.grid == null:
		return

	var terrain_type: String = battle_map.grid.get_tile_at(cell)
	if terrain_type.is_empty():
		_terrain_name.text = "—"
		_terrain_cost.text = ""
		_terrain_evade.text = ""
		_terrain_def.text = ""
		_terrain_special.text = ""
		return

	var terrain_data: Dictionary = dm.get_terrain(terrain_type)
	if terrain_data.is_empty():
		_terrain_name.text = terrain_type
		_terrain_cost.text = ""
		_terrain_evade.text = ""
		_terrain_def.text = ""
		_terrain_special.text = ""
		return

	_terrain_name.text = terrain_data.get("name_ko", terrain_type)
	var move_cost: int = terrain_data.get("move_cost", 1)
	_terrain_cost.text = "이동 비용: %s" % (str(move_cost) if move_cost > 0 else "통행 불가")
	var evade_bonus: int = terrain_data.get("evade_bonus", 0)
	_terrain_evade.text = "회피: %+d%%" % evade_bonus if evade_bonus != 0 else "회피: —"
	var def_bonus: int = terrain_data.get("def_bonus", 0)
	_terrain_def.text = "방어: %+d%%" % def_bonus if def_bonus != 0 else "방어: —"

	var special: Variant = terrain_data.get("special_effect", null)
	if special != null and special is String and special != "":
		_terrain_special.text = _translate_special_effect(special as String)
	else:
		_terrain_special.text = ""

## 지형 특수 효과 키를 한국어 설명으로 변환한다.
## @param effect_key 특수 효과 키
## @returns 한국어 설명 문자열
func _translate_special_effect(effect_key: String) -> String:
	match effect_key:
		"bow_range_minus_1":
			return "활 사거리 -1"
		"heavy_unit_blocked":
			return "중장갑/기마 통과 불가"
		"magic_attack_plus_10":
			return "마법 공격 +10%"
		"special_skill_only":
			return "특수 스킬만 통과"
		"destructible":
			return "파괴 가능"
		"mounted_mov_minus_1":
			return "기마 이동력 -1"
		"impassable_burn_adjacent":
			return "인접 유닛 화상"
		"adjacent_ally_hp_regen_5_percent":
			return "인접 아군 HP 5% 회복"
		"turn_start_hp_minus_5_percent":
			return "턴 시작 시 HP 5% 감소"
		"destructible_building":
			return "파괴 가능 건물"
		"boss_stat_boost":
			return "보스 스탯 강화"
		"turn_start_hp_regen_3_percent":
			return "턴 시작 시 HP 3% 회복"
		_:
			return effect_key

# ── 유닛 상세 정보 팝업 (2-5) ──

## 화면 중앙에 유닛 상세 정보 팝업을 생성한다 (I키로 토글).
func _build_detail_popup() -> void:
	_detail_popup = PanelContainer.new()
	_detail_popup.custom_minimum_size = Vector2(400, 500)
	_detail_popup.size = Vector2(400, 500)
	_detail_popup.position = Vector2(
		(1920 - 400) / 2.0,
		(1080 - 500) / 2.0
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.border_color = COLOR_ACCENT
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = PADDING
	style.content_margin_right = PADDING
	style.content_margin_top = PADDING
	style.content_margin_bottom = PADDING
	_detail_popup.add_theme_stylebox_override("panel", style)
	_detail_popup.visible = false
	add_child(_detail_popup)

	# 스크롤 컨테이너 (내용이 길 수 있으므로)
	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	_detail_popup.add_child(scroll)

	_detail_content = VBoxContainer.new()
	_detail_content.add_theme_constant_override("separation", 4)
	_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_content)

## 유닛 상세 정보 팝업에 내용을 채운다.
## @param unit 표시할 유닛
func _show_detail_popup(unit: BattleUnit) -> void:
	if _detail_popup == null or _detail_content == null:
		return

	# 기존 내용 제거
	for child: Node in _detail_content.get_children():
		child.queue_free()

	# 이름 + 레벨
	var header := Label.new()
	header.text = "%s  Lv.%d" % [
		unit.unit_name_ko if unit.unit_name_ko != "" else unit.unit_id,
		unit.level
	]
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_content.add_child(header)

	# 클래스
	var class_label := Label.new()
	class_label.text = "클래스: %s" % (unit.class_name_ko if unit.class_name_ko != "" else "—")
	class_label.add_theme_font_size_override("font_size", 14)
	class_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_detail_content.add_child(class_label)

	# 구분선
	_add_separator(_detail_content)

	# HP / MP
	var hp_label := Label.new()
	hp_label.text = "HP: %d / %d" % [unit.current_hp, unit.stats.get("hp", 0)]
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", COLOR_HP_HIGH)
	_detail_content.add_child(hp_label)

	var mp_label := Label.new()
	mp_label.text = "MP: %d / %d" % [unit.current_mp, unit.stats.get("mp", 0)]
	mp_label.add_theme_font_size_override("font_size", 14)
	mp_label.add_theme_color_override("font_color", COLOR_MP)
	_detail_content.add_child(mp_label)

	# 구분선
	_add_separator(_detail_content)

	# 기본 스탯
	var stat_keys: Array = [
		["atk", "ATK"], ["def", "DEF"], ["matk", "MATK"],
		["mdef", "MDEF"], ["spd", "SPD"], ["mov", "MOV"]
	]
	for pair: Array in stat_keys:
		var stat_label := Label.new()
		stat_label.text = "%s: %d" % [pair[1], unit.stats.get(pair[0], 0)]
		stat_label.add_theme_font_size_override("font_size", 13)
		stat_label.add_theme_color_override("font_color", COLOR_TEXT)
		_detail_content.add_child(stat_label)

	# 구분선
	_add_separator(_detail_content)

	# 장비
	var equip_header := Label.new()
	equip_header.text = "장비"
	equip_header.add_theme_font_size_override("font_size", 14)
	equip_header.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_content.add_child(equip_header)

	var equip_slots: Array = [
		["weapon", "무기"], ["armor", "방어구"], ["accessory", "장신구"]
	]
	for slot: Array in equip_slots:
		var equip_id: String = unit.equipment.get(slot[0], "")
		var equip_label := Label.new()
		equip_label.text = "%s: %s" % [slot[1], equip_id if equip_id != "" else "없음"]
		equip_label.add_theme_font_size_override("font_size", 12)
		equip_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_content.add_child(equip_label)

	# 구분선
	_add_separator(_detail_content)

	# 스킬 목록
	var skill_header := Label.new()
	skill_header.text = "스킬"
	skill_header.add_theme_font_size_override("font_size", 14)
	skill_header.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_content.add_child(skill_header)

	if unit.skills.is_empty():
		var no_skill := Label.new()
		no_skill.text = "  없음"
		no_skill.add_theme_font_size_override("font_size", 12)
		no_skill.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_content.add_child(no_skill)
	else:
		for skill_id: String in unit.skills:
			var skill_label := Label.new()
			skill_label.text = "  - %s" % skill_id
			skill_label.add_theme_font_size_override("font_size", 12)
			skill_label.add_theme_color_override("font_color", COLOR_TEXT)
			_detail_content.add_child(skill_label)

	# 구분선
	_add_separator(_detail_content)

	# 상태이상
	var status_header := Label.new()
	status_header.text = "상태이상"
	status_header.add_theme_font_size_override("font_size", 14)
	status_header.add_theme_color_override("font_color", COLOR_ACCENT)
	_detail_content.add_child(status_header)

	if unit.status_effects.is_empty():
		var no_status := Label.new()
		no_status.text = "  없음"
		no_status.add_theme_font_size_override("font_size", 12)
		no_status.add_theme_color_override("font_color", COLOR_TEXT_DIM)
		_detail_content.add_child(no_status)
	else:
		for effect: Dictionary in unit.status_effects:
			var status_label := Label.new()
			var duration: int = effect.get("duration", 0)
			status_label.text = "  - %s (%d턴)" % [effect.get("status_id", "?"), duration]
			status_label.add_theme_font_size_override("font_size", 12)
			status_label.add_theme_color_override("font_color", COLOR_HP_LOW)
			_detail_content.add_child(status_label)

	_detail_popup.visible = true
	_detail_visible = true

## 유닛 상세 정보 팝업을 숨긴다.
func _hide_detail_popup() -> void:
	if _detail_popup:
		_detail_popup.visible = false
	_detail_visible = false

## 유닛 정보 요청 콜백 (I키)
## @param cell 대상 셀 좌표
func _on_unit_info_requested(cell: Vector2i) -> void:
	# 이미 표시 중이면 닫기
	if _detail_visible:
		_hide_detail_popup()
		return

	if battle_map == null:
		return

	var unit: BattleUnit = battle_map.get_unit_at(cell)
	if unit:
		_show_detail_popup(unit)

## 구분선을 추가한다.
## @param container 부모 컨테이너
func _add_separator(container: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.3, 0.3, 0.4, 0.5)
	sep_style.content_margin_top = 2
	sep_style.content_margin_bottom = 2
	sep.add_theme_stylebox_override("separator", sep_style)
	container.add_child(sep)

# ── 턴 종료 확인 대화상자 (2-7) ──

## 턴 종료 확인 대화상자를 생성한다.
func _build_confirm_dialog() -> void:
	_confirm_dialog = PanelContainer.new()
	_confirm_dialog.custom_minimum_size = Vector2(360, 140)
	_confirm_dialog.size = Vector2(360, 140)
	_confirm_dialog.position = Vector2(
		(1920 - 360) / 2.0,
		(1080 - 140) / 2.0
	)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.1, 0.95)
	style.border_color = Color(0.8, 0.4, 0.2)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_confirm_dialog.add_theme_stylebox_override("panel", style)
	_confirm_dialog.visible = false
	add_child(_confirm_dialog)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_confirm_dialog.add_child(vbox)

	_confirm_label = Label.new()
	_confirm_label.text = ""
	_confirm_label.add_theme_font_size_override("font_size", 15)
	_confirm_label.add_theme_color_override("font_color", COLOR_TEXT)
	_confirm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_confirm_label)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 16)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)

	var yes_btn := Button.new()
	yes_btn.text = "예"
	yes_btn.custom_minimum_size = Vector2(80, 32)
	yes_btn.pressed.connect(_on_confirm_yes)
	btn_row.add_child(yes_btn)

	var no_btn := Button.new()
	no_btn.text = "아니오"
	no_btn.custom_minimum_size = Vector2(80, 32)
	no_btn.pressed.connect(_on_confirm_no)
	btn_row.add_child(no_btn)

## 턴 종료 확인 대화상자를 표시한다.
## @param unacted_count 미행동 유닛 수
func show_end_turn_confirm(unacted_count: int) -> void:
	if _confirm_dialog == null:
		return
	_confirm_label.text = "%d명의 유닛이 행동하지 않았습니다.\n턴을 종료하시겠습니까?" % unacted_count
	_confirm_dialog.visible = true
	_confirm_visible = true

## 턴 종료 확인 - 예 버튼 콜백
func _on_confirm_yes() -> void:
	_confirm_dialog.visible = false
	_confirm_visible = false
	EventBus.end_turn_confirmed.emit()

## 턴 종료 확인 - 아니오 버튼 콜백
func _on_confirm_no() -> void:
	_confirm_dialog.visible = false
	_confirm_visible = false

## 턴 종료 확인 필요 콜백. TurnManager가 미행동 유닛을 감지하여 발신.
## @param unacted_count 미행동 유닛 수
func _on_end_turn_confirm_needed(unacted_count: int) -> void:
	# 확인 대화상자가 이미 열려 있으면 무시
	if _confirm_visible:
		return
	# 상세 팝업이 열려 있으면 닫기
	if _detail_visible:
		_hide_detail_popup()
	show_end_turn_confirm(unacted_count)

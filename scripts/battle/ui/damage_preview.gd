## @fileoverview 데미지/명중률 미리보기 패널. 공격 전 예상 데미지, 명중률, 크리티컬률,
## 무기 상성 정보를 화면 하단 중앙에 표시한다.
class_name DamagePreview
extends CanvasLayer

# ── 상수 ──

## 렌더 레이어
const PREVIEW_LAYER: int = 40

## 패널 크기
const PANEL_WIDTH: float = 480.0
const PANEL_HEIGHT: float = 200.0

## 색상
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.9)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_DAMAGE := Color(1.0, 0.4, 0.3, 1.0)
const COLOR_HEAL := Color(0.3, 0.9, 0.5, 1.0)
const COLOR_ADVANTAGE := Color(0.3, 0.9, 0.3)
const COLOR_DISADVANTAGE := Color(0.9, 0.3, 0.3)
const COLOR_NEUTRAL := Color(0.6, 0.6, 0.6)
const COLOR_HP_HIGH := Color(0.2, 0.9, 0.2)
const COLOR_HP_MID := Color(0.9, 0.9, 0.2)
const COLOR_HP_LOW := Color(0.9, 0.2, 0.2)

## NinePatch 에셋 경로
const NINEPATCH_PANEL := "res://assets/ui/panel_light.png"

## 패널 여백
const PADDING: int = 16

## 데미지 변동 범위 배율
const DAMAGE_MIN_MULT: float = 0.9
const DAMAGE_MAX_MULT: float = 1.1

# ── 멤버 변수 ──

## 미리보기 패널 컨테이너
var _panel: Control = null

## 미리보기 표시 여부
var _is_visible: bool = false

# ── 초기화 ──

func _ready() -> void:
	layer = PREVIEW_LAYER
	visible = false

# ── 공격 미리보기 ──

## 물리/마법 공격 미리보기를 표시한다.
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param combat_calc 전투 계산기
## @param grid GridSystem 참조
func show_preview(attacker: BattleUnit, defender: BattleUnit, combat_calc: CombatCalculator, grid: GridSystem) -> void:
	_cleanup()

	# 전투 수치 계산
	var hit_rate: int = combat_calc.calc_hit_rate(attacker, defender, grid)
	var crit_rate: int = combat_calc.calc_crit_rate(attacker, defender)

	# 예상 데미지 계산 (크리티컬 없는 기본 데미지 범위)
	var base_damage: int = _calc_base_physical_damage(attacker, defender, combat_calc, grid)
	var damage_min: int = maxi(int(float(base_damage) * DAMAGE_MIN_MULT), 1)
	var damage_max: int = maxi(int(float(base_damage) * DAMAGE_MAX_MULT), 1)

	# 무기 상성
	var attacker_weapon: String = _get_unit_weapon_type(attacker)
	var defender_weapon: String = _get_unit_weapon_type(defender)
	var advantage: int = WeaponTriangle.get_weapon_advantage(attacker_weapon, defender_weapon)

	# 패널 생성
	_panel = _build_preview_panel(attacker, defender, damage_min, damage_max, hit_rate, crit_rate, advantage)
	add_child(_panel)

	visible = true
	_is_visible = true

## 스킬 미리보기를 표시한다.
## @param caster 시전자 유닛
## @param skill_data 스킬 데이터 Dictionary
## @param targets 대상 유닛 배열
## @param combat_calc 전투 계산기
## @param grid GridSystem 참조
func show_skill_preview(caster: BattleUnit, skill_data: Dictionary, targets: Array[BattleUnit], combat_calc: CombatCalculator, grid: GridSystem) -> void:
	_cleanup()

	if targets.is_empty():
		return

	# 첫 번째 대상 기준으로 미리보기
	var primary_target: BattleUnit = targets[0]
	var skill_mult: float = skill_data.get("power", 1.0)
	var skill_type: String = skill_data.get("type", "physical")
	var skill_name: String = skill_data.get("name_ko", "스킬")

	var hit_rate: int = combat_calc.calc_hit_rate(caster, primary_target, grid)
	var crit_rate: int = combat_calc.calc_crit_rate(caster, primary_target)

	# 스킬 타입별 데미지 계산
	var base_damage: int = 0
	if skill_type == "heal":
		base_damage = combat_calc.calc_heal_amount(caster, primary_target, skill_mult)
	elif skill_type == "magic":
		var element: String = skill_data.get("element", "")
		base_damage = _calc_base_magic_damage(caster, primary_target, skill_mult, element, grid)
	else:
		base_damage = _calc_base_physical_damage_with_mult(caster, primary_target, skill_mult, grid)

	var damage_min: int = maxi(int(float(base_damage) * DAMAGE_MIN_MULT), 1)
	var damage_max: int = maxi(int(float(base_damage) * DAMAGE_MAX_MULT), 1)

	# 스킬용 패널 생성
	_panel = _build_skill_preview_panel(caster, primary_target, skill_name, skill_type, damage_min, damage_max, hit_rate, crit_rate, targets.size())
	add_child(_panel)

	visible = true
	_is_visible = true

## 미리보기를 숨긴다.
func hide_preview() -> void:
	visible = false
	_is_visible = false
	_cleanup()

# ── 패널 생성 ──

## 공격 미리보기 패널을 구성한다.
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param dmg_min 최소 데미지
## @param dmg_max 최대 데미지
## @param hit 명중률
## @param crit 크리티컬률
## @param advantage 무기 상성 (-1/0/+1)
## @returns Control 패널 노드
func _build_preview_panel(attacker: BattleUnit, defender: BattleUnit, dmg_min: int, dmg_max: int, hit: int, crit: int, advantage: int) -> Control:
	var panel := _create_panel_background()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	if panel is NinePatchRect:
		vbox.position = Vector2(PADDING, PADDING)
		vbox.size = Vector2(PANEL_WIDTH - PADDING * 2, PANEL_HEIGHT - PADDING * 2)
	panel.add_child(vbox)

	# 헤더: 공격자 -> 방어자
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var atk_name := Label.new()
	atk_name.text = "%s Lv.%d" % [attacker.unit_name_ko if attacker.unit_name_ko != "" else attacker.unit_id, attacker.level]
	atk_name.add_theme_font_size_override("font_size", 16)
	atk_name.add_theme_color_override("font_color", COLOR_TEXT)
	atk_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(atk_name)

	var arrow := Label.new()
	arrow.text = " -> "
	arrow.add_theme_font_size_override("font_size", 16)
	arrow.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_child(arrow)

	var def_name := Label.new()
	def_name.text = "%s Lv.%d" % [defender.unit_name_ko if defender.unit_name_ko != "" else defender.unit_id, defender.level]
	def_name.add_theme_font_size_override("font_size", 16)
	def_name.add_theme_color_override("font_color", COLOR_TEXT)
	def_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(def_name)

	# HP 표시
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(hp_row)

	var atk_hp := Label.new()
	atk_hp.text = "HP: %d/%d" % [attacker.current_hp, attacker.stats.get("hp", 0)]
	atk_hp.add_theme_font_size_override("font_size", 13)
	atk_hp.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	atk_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_row.add_child(atk_hp)

	var def_hp := Label.new()
	def_hp.text = "HP: %d/%d" % [defender.current_hp, defender.stats.get("hp", 0)]
	def_hp.add_theme_font_size_override("font_size", 13)
	def_hp.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	def_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	def_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_row.add_child(def_hp)

	# 구분선
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 전투 수치
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stats_grid)

	# 예상 데미지
	_add_stat_row(stats_grid, "예상 데미지:", "%d~%d" % [dmg_min, dmg_max], COLOR_DAMAGE)

	# 명중률
	var hit_color: Color = COLOR_TEXT if hit >= 70 else COLOR_HP_LOW
	_add_stat_row(stats_grid, "명중률:", "%d%%" % hit, hit_color)

	# 크리티컬률
	_add_stat_row(stats_grid, "크리티컬:", "%d%%" % crit, COLOR_TEXT)

	# 무기 상성
	var advantage_text: String = ""
	var advantage_color: Color = COLOR_NEUTRAL
	match advantage:
		1:
			advantage_text = "▲ 유리 (+%d%%)" % int(WeaponTriangle.WEAPON_ADVANTAGE_MOD * 100)
			advantage_color = COLOR_ADVANTAGE
		-1:
			advantage_text = "▼ 불리 (-%d%%)" % int(WeaponTriangle.WEAPON_ADVANTAGE_MOD * 100)
			advantage_color = COLOR_DISADVANTAGE
		_:
			advantage_text = "— 중립"
			advantage_color = COLOR_NEUTRAL
	_add_stat_row(stats_grid, "상성:", advantage_text, advantage_color)

	return panel

## 스킬 미리보기 패널을 구성한다.
## @param caster 시전자
## @param target 대상
## @param skill_name 스킬 이름
## @param skill_type 스킬 타입 ("physical"/"magic"/"heal")
## @param dmg_min 최소 효과량
## @param dmg_max 최대 효과량
## @param hit 명중률
## @param crit 크리티컬률
## @param target_count 대상 수
## @returns Control 패널 노드
func _build_skill_preview_panel(caster: BattleUnit, target: BattleUnit, skill_name: String, skill_type: String, dmg_min: int, dmg_max: int, hit: int, crit: int, target_count: int) -> Control:
	var panel := _create_panel_background()

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	if panel is NinePatchRect:
		vbox.position = Vector2(PADDING, PADDING)
		vbox.size = Vector2(PANEL_WIDTH - PADDING * 2, PANEL_HEIGHT - PADDING * 2)
	panel.add_child(vbox)

	# 스킬 이름 헤더
	var skill_header := Label.new()
	skill_header.text = skill_name
	skill_header.add_theme_font_size_override("font_size", 18)
	skill_header.add_theme_color_override("font_color", COLOR_ACCENT)
	skill_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(skill_header)

	# 시전자 -> 대상
	var unit_row := HBoxContainer.new()
	unit_row.add_theme_constant_override("separation", 8)
	vbox.add_child(unit_row)

	var caster_label := Label.new()
	caster_label.text = "%s Lv.%d" % [caster.unit_name_ko if caster.unit_name_ko != "" else caster.unit_id, caster.level]
	caster_label.add_theme_font_size_override("font_size", 14)
	caster_label.add_theme_color_override("font_color", COLOR_TEXT)
	caster_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	unit_row.add_child(caster_label)

	var target_label := Label.new()
	if target_count > 1:
		target_label.text = "%s 외 %d명" % [target.unit_name_ko if target.unit_name_ko != "" else target.unit_id, target_count - 1]
	else:
		target_label.text = "%s Lv.%d" % [target.unit_name_ko if target.unit_name_ko != "" else target.unit_id, target.level]
	target_label.add_theme_font_size_override("font_size", 14)
	target_label.add_theme_color_override("font_color", COLOR_TEXT)
	target_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	unit_row.add_child(target_label)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 수치 표시
	var stats_grid := GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 16)
	stats_grid.add_theme_constant_override("v_separation", 4)
	vbox.add_child(stats_grid)

	var effect_label: String = "예상 회복:" if skill_type == "heal" else "예상 데미지:"
	var effect_color: Color = COLOR_HEAL if skill_type == "heal" else COLOR_DAMAGE
	_add_stat_row(stats_grid, effect_label, "%d~%d" % [dmg_min, dmg_max], effect_color)
	_add_stat_row(stats_grid, "명중률:", "%d%%" % hit, COLOR_TEXT)
	_add_stat_row(stats_grid, "크리티컬:", "%d%%" % crit, COLOR_TEXT)

	return panel

## 수치 행을 GridContainer에 추가한다.
## @param grid GridContainer 노드
## @param label_text 라벨 텍스트
## @param value_text 값 텍스트
## @param value_color 값 색상
func _add_stat_row(grid: GridContainer, label_text: String, value_text: String, value_color: Color) -> void:
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	grid.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", value_color)
	grid.add_child(value)

# ── 패널 배경 생성 ──

## 패널 배경을 생성한다. NinePatch 에셋이 있으면 NinePatchRect, 없으면 PanelContainer.
## @returns Control 노드
func _create_panel_background() -> Control:
	# NinePatch 에셋 확인
	if ResourceLoader.exists(NINEPATCH_PANEL):
		var tex: Texture2D = load(NINEPATCH_PANEL)
		if tex:
			var nine := NinePatchRect.new()
			nine.texture = tex
			nine.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
			# 화면 하단 중앙
			nine.position = Vector2(960 - PANEL_WIDTH / 2, 1080 - PANEL_HEIGHT - 20)
			# 마진 로드
			var margins: Dictionary = _load_ninepatch_margins("panel_light.png")
			nine.patch_margin_left = margins.get("left", 48)
			nine.patch_margin_right = margins.get("right", 48)
			nine.patch_margin_top = margins.get("top", 48)
			nine.patch_margin_bottom = margins.get("bottom", 48)
			return nine

	# Fallback: PanelContainer
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	# 화면 하단 중앙
	panel.position = Vector2(960 - PANEL_WIDTH / 2, 1080 - PANEL_HEIGHT - 20)

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
## @param asset_name 에셋 파일명
## @returns {left, right, top, bottom}
func _load_ninepatch_margins(asset_name: String) -> Dictionary:
	var default_margins := {"left": 48, "right": 48, "top": 48, "bottom": 48}
	var json_path := "res://assets/ui/ninepatch_data.json"
	if not FileAccess.file_exists(json_path):
		return default_margins

	var file := FileAccess.open(json_path, FileAccess.READ)
	if file == null:
		return default_margins

	var json_text: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	if json.parse(json_text) != OK:
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

# ── 데미지 계산 유틸 ──

## 물리 기본 데미지를 계산한다 (크리티컬/RNG 제외).
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param combat_calc 전투 계산기
## @param grid GridSystem
## @returns 기본 데미지 값
func _calc_base_physical_damage(attacker: BattleUnit, defender: BattleUnit, combat_calc: CombatCalculator, grid: GridSystem) -> int:
	return _calc_base_physical_damage_with_mult(attacker, defender, 1.0, grid)

## 배율 적용 물리 기본 데미지를 계산한다.
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param skill_mult 스킬 배율
## @param grid GridSystem
## @returns 기본 데미지 값
func _calc_base_physical_damage_with_mult(attacker: BattleUnit, defender: BattleUnit, skill_mult: float, grid: GridSystem) -> int:
	var atk: float = float(attacker.stats.get("atk", 0))
	var def_val: float = float(defender.stats.get("def", 0))
	var base: float = atk * skill_mult - def_val / 2.0

	# 지형 방어 보정
	var terrain_type: String = grid.get_tile_at(defender.cell)
	var terrain_mod: float = 1.0
	if not terrain_type.is_empty():
		var dm: Node = _get_data_manager()
		if dm:
			var terrain_data: Dictionary = dm.get_terrain(terrain_type)
			var def_bonus: int = terrain_data.get("def_bonus", 0)
			terrain_mod = 1.0 - float(def_bonus) / 100.0

	# 무기 상성 보정
	var attacker_weapon: String = _get_unit_weapon_type(attacker)
	var defender_weapon: String = _get_unit_weapon_type(defender)
	var weapon_mod: float = WeaponTriangle.get_weapon_damage_mod(attacker_weapon, defender_weapon)

	var damage: float = base * terrain_mod * weapon_mod
	return maxi(int(damage), 1)

## 마법 기본 데미지를 계산한다 (크리티컬/RNG 제외).
## @param attacker 공격 유닛
## @param defender 방어 유닛
## @param skill_mult 스킬 배율
## @param element 마법 속성
## @param grid GridSystem
## @returns 기본 데미지 값
func _calc_base_magic_damage(attacker: BattleUnit, defender: BattleUnit, skill_mult: float, element: String, grid: GridSystem) -> int:
	var matk: float = float(attacker.stats.get("matk", 0))
	var mdef: float = float(defender.stats.get("mdef", 0))
	var base: float = matk * skill_mult - mdef / 2.0

	# 지형 방어 보정
	var terrain_type: String = grid.get_tile_at(defender.cell)
	var terrain_mod: float = 1.0
	if not terrain_type.is_empty():
		var dm: Node = _get_data_manager()
		if dm:
			var terrain_data: Dictionary = dm.get_terrain(terrain_type)
			var def_bonus: int = terrain_data.get("def_bonus", 0)
			terrain_mod = 1.0 - float(def_bonus) / 100.0

	# 마법 상성 보정
	var magic_mod: float = WeaponTriangle.get_magic_damage_mod(element, "")

	var damage: float = base * terrain_mod * magic_mod
	return maxi(int(damage), 1)

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

## 내부 노드를 정리한다.
func _cleanup() -> void:
	if _panel:
		_panel.queue_free()
		_panel = null

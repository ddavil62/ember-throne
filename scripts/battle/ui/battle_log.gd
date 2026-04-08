## @fileoverview 전투 로그 패널. 전투 중 발생하는 행동(공격, 스킬, 데미지, 회복,
## 상태이상, 턴 시작 등)의 기록을 화면 우측에 반투명 패널로 표시한다.
## EventBus 시그널을 구독하여 자동으로 로그를 수집하며, 토글 키(L)로 표시/숨김 전환.
class_name BattleLog
extends CanvasLayer

# ── 상수 ──

## 렌더 레이어 (HUD와 동일)
const LOG_LAYER: int = 10

## 패널 크기
const PANEL_WIDTH: int = 360
const PANEL_HEIGHT: int = 440

## 색상 팔레트
const COLOR_BG := Color(0.06, 0.06, 0.10, 0.80)
const COLOR_BORDER := Color(0.35, 0.35, 0.45, 0.5)
const COLOR_TITLE := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.85, 0.85, 0.8, 1.0)
const COLOR_DAMAGE := Color(1.0, 0.4, 0.3, 1.0)
const COLOR_CRIT := Color(1.0, 0.85, 0.2, 1.0)
const COLOR_HEAL := Color(0.3, 0.9, 0.4, 1.0)
const COLOR_STATUS := Color(0.7, 0.5, 0.9, 1.0)
const COLOR_TURN := Color(0.4, 0.6, 1.0, 1.0)
const COLOR_DEATH := Color(0.6, 0.15, 0.15, 1.0)
const COLOR_MISS := Color(0.5, 0.5, 0.5, 1.0)
const COLOR_DIM := Color(0.55, 0.55, 0.5, 1.0)

## 최대 보관 로그 수
const MAX_LOG_ENTRIES: int = 50

## 표시되는 최근 로그 수
const VISIBLE_ENTRIES: int = 25

## 패널 여백
const PADDING: int = 10

## 토글 키
const TOGGLE_KEY: Key = KEY_L

# ── 멤버 변수 ──

## 로그 항목 배열 [{text: String, color: Color}]
var _entries: Array[Dictionary] = []

## 패널 루트
var _panel: Panel = null

## 제목 라벨
var _title_label: Label = null

## 로그 텍스트 (RichTextLabel — BBCode 색상 지원)
var _log_text: RichTextLabel = null

## 토글 버튼
var _toggle_btn: Button = null

## 패널 표시 여부
var _visible: bool = true

## BattleMap 참조 (유닛 이름 조회용)
var battle_map: Node2D = null

# ── 초기화 ──

func _ready() -> void:
	layer = LOG_LAYER
	_build_ui()
	_connect_signals()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	# 메인 패널 — 화면 우측 미니맵 아래
	_panel = Panel.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	_panel.position = Vector2(1920 - PANEL_WIDTH - 16, 140)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BORDER
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	# 제목
	_title_label = Label.new()
	_title_label.text = "전투 로그"
	_title_label.add_theme_font_size_override("font_size", 14)
	_title_label.add_theme_color_override("font_color", COLOR_TITLE)
	_title_label.position = Vector2(PADDING, 6)
	_panel.add_child(_title_label)

	# 토글 힌트 (우측 상단)
	var hint_label := Label.new()
	hint_label.text = "[L] 숨기기"
	hint_label.add_theme_font_size_override("font_size", 11)
	hint_label.add_theme_color_override("font_color", COLOR_DIM)
	hint_label.position = Vector2(PANEL_WIDTH - 80, 8)
	_panel.add_child(hint_label)

	# 로그 텍스트 영역 (RichTextLabel — 스크롤 지원)
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true
	_log_text.selection_enabled = false
	_log_text.position = Vector2(PADDING, 28)
	_log_text.size = Vector2(PANEL_WIDTH - PADDING * 2, PANEL_HEIGHT - 36)
	_log_text.add_theme_font_size_override("normal_font_size", 12)
	_log_text.add_theme_color_override("default_color", COLOR_TEXT)

	# 배경 투명 처리
	var text_style := StyleBoxFlat.new()
	text_style.bg_color = Color(0, 0, 0, 0)
	_log_text.add_theme_stylebox_override("normal", text_style)
	_panel.add_child(_log_text)

	# 토글 버튼 (패널 숨겨진 상태에서 표시용) — 화면 우측 상단 근처
	_toggle_btn = Button.new()
	_toggle_btn.text = "로그"
	_toggle_btn.add_theme_font_size_override("font_size", 12)
	_toggle_btn.position = Vector2(1920 - 70, 140)
	_toggle_btn.size = Vector2(54, 28)
	_toggle_btn.visible = false
	_toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(_toggle_btn)

## EventBus 시그널을 연결한다.
func _connect_signals() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not tree.root.has_node("EventBus"):
		return

	var eb: Node = tree.root.get_node("EventBus")
	eb.turn_started.connect(_on_turn_started)
	eb.damage_dealt.connect(_on_damage_dealt)
	eb.heal_applied.connect(_on_heal_applied)
	eb.skill_used.connect(_on_skill_used)
	eb.status_applied.connect(_on_status_applied)
	eb.status_removed.connect(_on_status_removed)
	eb.unit_died.connect(_on_unit_died)
	eb.battle_won.connect(_on_battle_won)
	eb.battle_lost.connect(_on_battle_lost)

## 씬 트리에서 제거될 때 EventBus 시그널을 해제한다.
func _exit_tree() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root and tree.root.has_node("EventBus"):
		var eb: Node = tree.root.get_node("EventBus")
		eb.turn_started.disconnect(_on_turn_started)
		eb.damage_dealt.disconnect(_on_damage_dealt)
		eb.heal_applied.disconnect(_on_heal_applied)
		eb.skill_used.disconnect(_on_skill_used)
		eb.status_applied.disconnect(_on_status_applied)
		eb.status_removed.disconnect(_on_status_removed)
		eb.unit_died.disconnect(_on_unit_died)
		eb.battle_won.disconnect(_on_battle_won)
		eb.battle_lost.disconnect(_on_battle_lost)

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == TOGGLE_KEY:
			_toggle_panel()
			get_viewport().set_input_as_handled()

## 패널 표시/숨김 전환
func _toggle_panel() -> void:
	_visible = not _visible
	_panel.visible = _visible
	_toggle_btn.visible = not _visible

## 토글 버튼 콜백
func _on_toggle_pressed() -> void:
	_toggle_panel()

# ── 로그 추가 ──

## 로그 항목을 추가한다.
## @param text 표시할 텍스트
## @param color 텍스트 색상
func add_entry(text: String, color: Color = COLOR_TEXT) -> void:
	_entries.append({"text": text, "color": color})

	# 최대 수 초과 시 오래된 항목 제거
	while _entries.size() > MAX_LOG_ENTRIES:
		_entries.pop_front()

	# RichTextLabel 갱신
	_refresh_log_text()

## RichTextLabel의 BBCode를 갱신한다.
func _refresh_log_text() -> void:
	if _log_text == null:
		return

	var bbcode: String = ""
	# 최근 VISIBLE_ENTRIES개만 표시
	var start_idx: int = maxi(0, _entries.size() - VISIBLE_ENTRIES)
	for i: int in range(start_idx, _entries.size()):
		var entry: Dictionary = _entries[i]
		var hex: String = entry["color"].to_html(false)
		bbcode += "[color=#%s]%s[/color]\n" % [hex, entry["text"]]

	_log_text.text = ""
	_log_text.append_text(bbcode)

## 모든 로그를 초기화한다.
func clear_log() -> void:
	_entries.clear()
	if _log_text:
		_log_text.text = ""

# ── 유닛 이름 조회 유틸 ──

## unit_id로 한국어 이름을 조회한다. 없으면 unit_id 반환.
## @param unit_id 유닛 ID
## @returns 한국어 이름 또는 unit_id
func _get_name(unit_id: String) -> String:
	if battle_map == null:
		return unit_id
	if battle_map.has_method("get_unit_by_id"):
		var unit: BattleUnit = battle_map.get_unit_by_id(unit_id)
		if unit and not unit.unit_name_ko.is_empty():
			return unit.unit_name_ko
	return unit_id

## skill_id로 한국어 스킬 이름을 조회한다.
## @param skill_id 스킬 ID
## @returns 한국어 이름 또는 skill_id
func _get_skill_name(skill_id: String) -> String:
	var dm: Node = _get_data_manager()
	if dm and dm.has_method("get_skill"):
		var skill_data: Dictionary = dm.get_skill(skill_id)
		var name_ko: String = skill_data.get("name_ko", "")
		if not name_ko.is_empty():
			return name_ko
	return skill_id

## 상태이상 ID를 한국어 이름으로 변환한다.
## @param status_id 상태이상 ID
## @returns 한국어 이름
func _get_status_name(status_id: String) -> String:
	match status_id:
		"poison": return "독"
		"burn": return "화상"
		"freeze": return "빙결"
		"paralyze": return "마비"
		"silence": return "침묵"
		"sleep": return "수면"
		"ash_burn": return "재화"
		"atk_up": return "공격력 상승"
		"def_up": return "방어력 상승"
		"matk_up": return "마공 상승"
		"mdef_up": return "마방 상승"
		"spd_up": return "속도 상승"
		"regen": return "재생"
		"oath_buff": return "서약의 버프"
		_: return status_id

## DataManager 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

# ── EventBus 콜백 ──

## 턴 시작
func _on_turn_started(phase: String, turn_number: int) -> void:
	var phase_ko: String = ""
	match phase:
		"player": phase_ko = "플레이어"
		"enemy": phase_ko = "적"
		"npc": phase_ko = "NPC"
		_: phase_ko = phase

	add_entry("── 턴 %d — %s 페이즈 ──" % [turn_number, phase_ko], COLOR_TURN)

## 데미지 발생
func _on_damage_dealt(attacker_id: String, defender_id: String, amount: int, is_crit: bool) -> void:
	var atk_name: String = _get_name(attacker_id)
	var def_name: String = _get_name(defender_id)

	if is_crit:
		add_entry("%s → %s — %d 데미지 (크리티컬!)" % [atk_name, def_name, amount], COLOR_CRIT)
	else:
		add_entry("%s → %s — %d 데미지" % [atk_name, def_name, amount], COLOR_DAMAGE)

## 힐 발생
func _on_heal_applied(healer_id: String, target_id: String, amount: int) -> void:
	var healer_name: String = _get_name(healer_id)
	var target_name: String = _get_name(target_id)
	add_entry("%s → %s — HP %d 회복" % [healer_name, target_name, amount], COLOR_HEAL)

## 스킬 사용
func _on_skill_used(caster_id: String, skill_id: String, targets: Array) -> void:
	var caster_name: String = _get_name(caster_id)
	var skill_name: String = _get_skill_name(skill_id)

	if targets.size() == 0:
		add_entry("%s — %s 시전" % [caster_name, skill_name], COLOR_TEXT)
	elif targets.size() == 1:
		var target_name: String = _get_name(str(targets[0]))
		add_entry("%s — %s → %s" % [caster_name, skill_name, target_name], COLOR_TEXT)
	else:
		var first_target: String = _get_name(str(targets[0]))
		add_entry("%s — %s → %s 외 %d명" % [caster_name, skill_name, first_target, targets.size() - 1], COLOR_TEXT)

## 상태이상 적용
func _on_status_applied(target_id: String, status_id: String, duration: int) -> void:
	var target_name: String = _get_name(target_id)
	var status_name: String = _get_status_name(status_id)
	add_entry("%s — %s 부여 (%d턴)" % [target_name, status_name, duration], COLOR_STATUS)

## 상태이상 해제
func _on_status_removed(target_id: String, status_id: String) -> void:
	var target_name: String = _get_name(target_id)
	var status_name: String = _get_status_name(status_id)
	add_entry("%s — %s 해제" % [target_name, status_name], COLOR_DIM)

## 유닛 사망
func _on_unit_died(unit_id: String, killer_id: String) -> void:
	var unit_name: String = _get_name(unit_id)
	var killer_name: String = _get_name(killer_id)
	add_entry("%s 전사 (by %s)" % [unit_name, killer_name], COLOR_DEATH)

## 전투 승리
func _on_battle_won(battle_id: String) -> void:
	add_entry("══ 전투 승리! ══", COLOR_HEAL)

## 전투 패배
func _on_battle_lost(battle_id: String) -> void:
	add_entry("══ 전투 패배... ══", COLOR_DEATH)

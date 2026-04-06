## @fileoverview 타이틀 화면. 새 게임, 이어하기, 옵션, CG 갤러리, 종료 메뉴를 제공한다.
## 모든 UI 노드를 _ready()에서 코드로 생성하며, 씬 파일 없이 동작한다.
class_name TitleScreen
extends Control

# ── 상수 ──

const BUTTON_SIZE := Vector2(280, 52)
const SUB_BUTTON_SIZE := Vector2(240, 44)
const SLOT_BUTTON_SIZE := Vector2(480, 72)
const PADDING := 24

const COLOR_BG := Color(0.04, 0.03, 0.06, 1.0)
const COLOR_BG_OVERLAY := Color(0.0, 0.0, 0.0, 0.6)
const COLOR_PANEL := Color(0.1, 0.08, 0.14, 0.95)
const COLOR_BUTTON := Color(0.14, 0.12, 0.2, 1.0)
const COLOR_BUTTON_HOVER := Color(0.2, 0.18, 0.28, 1.0)
const COLOR_BUTTON_DISABLED := Color(0.1, 0.1, 0.12, 0.6)
const COLOR_ACCENT := Color(0.92, 0.5, 0.15, 1.0)
const COLOR_ACCENT_DIM := Color(0.7, 0.38, 0.1, 1.0)
const COLOR_TITLE := Color(0.95, 0.85, 0.6, 1.0)
const COLOR_SUBTITLE := Color(0.7, 0.6, 0.45, 1.0)
const COLOR_TEXT_DIM := Color(0.5, 0.5, 0.45, 1.0)
const COLOR_SLOT_EMPTY := Color(0.12, 0.12, 0.16, 1.0)
const COLOR_SLOT_FILLED := Color(0.16, 0.18, 0.24, 1.0)

const FIRST_SCENE_ID := "1-1"
const TITLE_BGM := "title_theme"

# ── 노드 참조 ──
var _menu_container: VBoxContainer = null
var _difficulty_panel: PanelContainer = null
var _save_slots_panel: PanelContainer = null
var _overlay: ColorRect = null
var _buttons: Dictionary = {}

# ── 라이프사이클 ──
func _ready() -> void:
	_build_ui()
	_play_title_bgm()
	var gm: Node = get_node("/root/GameManager")
	gm.change_state(gm.GameState.TITLE)
	if _buttons.has("new_game"):
		_buttons["new_game"].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var panel_visible: bool = (
			(_difficulty_panel and _difficulty_panel.visible)
			or (_save_slots_panel and _save_slots_panel.visible)
		)
		if panel_visible:
			_hide_sub_panels()
			get_viewport().set_input_as_handled()

# ── UI 구축 ──
## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	_build_background()
	_build_title_labels()
	_build_menu_buttons()
	_build_overlay()
	_build_difficulty_panel()
	_build_save_slots_panel()

## 배경을 구성한다. 컨셉아트 TextureRect + 하단 그라데이션.
func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)
	# 컨셉아트 배경 (에셋이 있으면 표시)
	var bg_tex := TextureRect.new()
	bg_tex.anchors_preset = Control.PRESET_FULL_RECT
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(0.6, 0.6, 0.6, 1.0)
	var path := "res://assets/concepts/title_bg.png"
	if ResourceLoader.exists(path):
		bg_tex.texture = load(path)
	add_child(bg_tex)
	# 하단 그라데이션 (메뉴 가독성)
	var grad := ColorRect.new()
	grad.anchors_preset = Control.PRESET_BOTTOM_WIDE
	grad.anchor_top = 0.4
	grad.color = Color(0.0, 0.0, 0.0, 0.5)
	add_child(grad)

## 타이틀 라벨과 부제를 구성한다.
func _build_title_labels() -> void:
	var box := VBoxContainer.new()
	box.anchors_preset = Control.PRESET_CENTER_TOP
	box.anchor_left = 0.5; box.anchor_right = 0.5
	box.offset_left = -300; box.offset_right = 300
	box.offset_top = 80; box.offset_bottom = 240
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	box.add_child(_create_label("Ember Throne", 64, COLOR_TITLE, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_create_label("불꽃의 왕좌", 22, COLOR_SUBTITLE, HORIZONTAL_ALIGNMENT_CENTER))

## 메뉴 버튼 5개를 구성한다.
func _build_menu_buttons() -> void:
	_menu_container = VBoxContainer.new()
	_menu_container.anchors_preset = Control.PRESET_CENTER
	_menu_container.anchor_left = 0.5; _menu_container.anchor_top = 0.5
	_menu_container.anchor_right = 0.5; _menu_container.anchor_bottom = 0.5
	_menu_container.offset_left = -BUTTON_SIZE.x / 2.0
	_menu_container.offset_right = BUTTON_SIZE.x / 2.0
	_menu_container.offset_top = 20; _menu_container.offset_bottom = 20 + (BUTTON_SIZE.y + 8) * 5
	_menu_container.add_theme_constant_override("separation", 8)
	add_child(_menu_container)
	var items: Array[Array] = [
		["new_game", "새 게임", _on_new_game_pressed],
		["continue", "이어하기", _on_continue_pressed],
		["options", "옵션", _on_options_pressed],
		["gallery", "CG 갤러리", _on_gallery_pressed],
		["quit", "종료", _on_quit_pressed],
	]

	var prev: Button = null
	for item in items:
		var btn := _create_menu_button(item[1])
		btn.pressed.connect(item[2])
		_menu_container.add_child(btn)
		_buttons[item[0]] = btn
		if prev:
			btn.focus_neighbor_top = prev.get_path()
			prev.focus_neighbor_bottom = btn.get_path()
		prev = btn
	_buttons["new_game"].focus_neighbor_top = _buttons["quit"].get_path()
	_buttons["quit"].focus_neighbor_bottom = _buttons["new_game"].get_path()
	_update_continue_button()

## 서브패널 배경 오버레이를 구성한다.
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = COLOR_BG_OVERLAY
	_overlay.anchors_preset = Control.PRESET_FULL_RECT
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_hide_sub_panels()
	)
	add_child(_overlay)

## 난이도 선택 서브패널을 구성한다.
func _build_difficulty_panel() -> void:
	_difficulty_panel = _create_centered_panel(Vector2(400, 280))
	add_child(_difficulty_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_difficulty_panel.add_child(vbox)
	vbox.add_child(_create_label("난이도 선택", 22, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(HSeparator.new())
	var normal_btn := _create_sub_button("Normal")
	normal_btn.add_theme_stylebox_override("normal", _make_flat_style(Color(0.2, 0.4, 0.7), 6))
	normal_btn.pressed.connect(_on_difficulty_selected.bind("normal"))
	vbox.add_child(normal_btn)
	vbox.add_child(_create_label("균형 잡힌 난이도. 입문자에게 적합합니다.", 13, COLOR_TEXT_DIM))
	var hard_btn := _create_sub_button("Hard")
	hard_btn.add_theme_stylebox_override("normal", _make_flat_style(Color(0.7, 0.2, 0.2), 6))
	hard_btn.pressed.connect(_on_difficulty_selected.bind("hard"))
	vbox.add_child(hard_btn)
	vbox.add_child(_create_label("적 스탯 상승. 전략적 판단이 요구됩니다.", 13, COLOR_TEXT_DIM))
	var cancel := _create_sub_button("취소")
	cancel.pressed.connect(_hide_sub_panels)
	vbox.add_child(cancel)

## 세이브 슬롯 선택 서브패널을 구성한다.
func _build_save_slots_panel() -> void:
	_save_slots_panel = _create_centered_panel(Vector2(520, 400))
	add_child(_save_slots_panel)
	var vbox := VBoxContainer.new()
	vbox.name = "SlotList"
	vbox.add_theme_constant_override("separation", 8)
	_save_slots_panel.add_child(vbox)
	vbox.add_child(_create_label("세이브 슬롯 선택", 22, COLOR_ACCENT, HORIZONTAL_ALIGNMENT_CENTER))
	vbox.add_child(HSeparator.new())
	var cancel := _create_sub_button("취소")
	cancel.name = "CancelBtn"
	cancel.pressed.connect(_hide_sub_panels)
	vbox.add_child(cancel)

# ── 메뉴 핸들러 ──
func _on_new_game_pressed() -> void:
	_overlay.visible = true
	_difficulty_panel.visible = true
	_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_continue_pressed() -> void:
	_overlay.visible = true
	_save_slots_panel.visible = true
	_menu_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_save_slots()

func _on_options_pressed() -> void:
	var path := "res://scenes/ui/options_screen.tscn"
	if ResourceLoader.exists(path):
		get_node("/root/GameManager").transition_to_scene(path)
	else:
		push_warning("[TitleScreen] 옵션 화면 씬 없음: %s" % path)

func _on_gallery_pressed() -> void:
	var path := "res://scenes/ui/cg_gallery.tscn"
	if ResourceLoader.exists(path):
		get_node("/root/GameManager").transition_to_scene(path)
	else:
		push_warning("[TitleScreen] CG 갤러리 씬 없음: %s" % path)

func _on_quit_pressed() -> void:
	get_tree().quit()

# ── 난이도 선택 ──
## 난이도 선택 후 새 게임을 시작한다.
## @param value 난이도 ("normal" | "hard")
func _on_difficulty_selected(value: String) -> void:
	_hide_sub_panels()
	var gm: Node = get_node("/root/GameManager")
	gm.difficulty = value
	gm.current_scene_id = FIRST_SCENE_ID
	gm.flags.clear()
	gm.play_time = 0.0
	get_node("/root/PartyManager").init_default_party()
	print("[TitleScreen] 새 게임 시작 (난이도: %s)" % value)
	# 페이드 전환 대신 즉시 씬 변경 (디버깅용)
	gm.change_state(gm.GameState.WORLD_MAP)
	var map := "res://scenes/world/world_map.tscn"
	if ResourceLoader.exists(map):
		print("[TitleScreen] 월드맵으로 즉시 전환: %s" % map)
		get_tree().change_scene_to_file(map)
	else:
		push_error("[TitleScreen] world_map.tscn 없음!")

# ── 세이브 슬롯 ──
## 세이브 슬롯 버튼들을 갱신한다.
func _refresh_save_slots() -> void:
	var vbox: VBoxContainer = _save_slots_panel.get_node("SlotList")
	var cancel_btn: Button = vbox.get_node("CancelBtn")
	# 기존 슬롯 버튼 제거
	var to_remove: Array[Node] = []
	for child in vbox.get_children():
		if child is Button and child != cancel_btn:
			to_remove.append(child)
	for node in to_remove:
		node.queue_free()
	var sm: Node = get_node("/root/SaveManager")
	for slot in range(4):
		var info: Dictionary = sm.get_save_info(slot)
		var has_data: bool = not info.is_empty()
		var slot_name: String = "[자동 세이브]" if slot == 0 else "슬롯 %d" % slot
		var btn := Button.new()
		btn.custom_minimum_size = SLOT_BUTTON_SIZE
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(_on_save_slot_selected.bind(slot))
		if has_data:
			var ts: String = info.get("timestamp", "")
			var t: float = info.get("play_time", 0.0)
			var sid: String = info.get("scene_id", "")
			var diff: String = info.get("difficulty", "").to_upper()
			btn.text = "%s\n  씬: %s  |  %s  |  %s  |  %s" % [slot_name, sid, diff, _fmt_time(t), ts]
			btn.add_theme_stylebox_override("normal", _make_flat_style(COLOR_SLOT_FILLED, 4, 12, 8))
		else:
			btn.text = "%s\n  비어있음" % slot_name
			btn.disabled = true
			btn.add_theme_stylebox_override("normal", _make_flat_style(COLOR_SLOT_EMPTY, 4, 12, 8))
		vbox.add_child(btn)
		vbox.move_child(btn, vbox.get_child_count() - 2)

## 세이브 슬롯 선택 시 게임을 로드한다.
## @param slot_num 선택된 슬롯 번호
func _on_save_slot_selected(slot_num: int) -> void:
	var sm: Node = get_node("/root/SaveManager")
	if not sm.has_save(slot_num):
		return
	_hide_sub_panels()

	if sm.load_game(slot_num):
		print("[TitleScreen] 슬롯 %d 로드 완료" % slot_num)
		var gm: Node = get_node("/root/GameManager")
		var path := "res://scenes/world/world_map.tscn"
		if ResourceLoader.exists(path):
			gm.transition_to_scene(path, 0.5, gm.GameState.WORLD_MAP)
	else:
		push_error("[TitleScreen] 슬롯 %d 로드 실패" % slot_num)

# ── 서브패널 관리 ──
## 모든 서브패널과 오버레이를 숨기고 메뉴에 포커스를 복원한다.
func _hide_sub_panels() -> void:
	_overlay.visible = false
	_difficulty_panel.visible = false
	_save_slots_panel.visible = false
	_menu_container.mouse_filter = Control.MOUSE_FILTER_PASS
	if _buttons.has("new_game"):
		_buttons["new_game"].grab_focus()

# ── 오디오 ──
func _play_title_bgm() -> void:
	get_node("/root/AudioManager").play_bgm(TITLE_BGM)

# ── 이어하기 상태 ──
## 세이브 데이터 존재 여부에 따라 이어하기 버튼을 활성/비활성 처리한다.
func _update_continue_button() -> void:
	if not _buttons.has("continue"):
		return
	var sm: Node = get_node("/root/SaveManager")
	var has_any: bool = false
	for s in range(4):
		if sm.has_save(s):
			has_any = true
			break
	_buttons["continue"].disabled = not has_any
	_buttons["continue"].tooltip_text = "" if has_any else "저장된 데이터가 없습니다"

# ── UI 팩토리 ──
## 메뉴 버튼을 생성한다.
## @param text 버튼 텍스트
## @returns Button
func _create_menu_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text; btn.custom_minimum_size = BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", 20)
	btn.focus_mode = Control.FOCUS_ALL
	btn.add_theme_stylebox_override("normal", _make_flat_style(COLOR_BUTTON, 6, 16, 8))
	var hover := _make_flat_style(COLOR_BUTTON_HOVER, 6, 14, 6)
	hover.border_width_left = 2; hover.border_width_right = 2
	hover.border_width_top = 2; hover.border_width_bottom = 2
	hover.border_color = COLOR_ACCENT
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover.duplicate())
	btn.add_theme_stylebox_override("disabled", _make_flat_style(COLOR_BUTTON_DISABLED, 6, 16, 8))
	btn.add_theme_color_override("font_disabled_color", COLOR_TEXT_DIM)
	return btn

## 서브패널용 버튼을 생성한다.
## @param text 버튼 텍스트
## @returns 생성된 Button 노드
func _create_sub_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = SUB_BUTTON_SIZE
	btn.add_theme_font_size_override("font_size", 18)
	btn.focus_mode = Control.FOCUS_ALL
	return btn

## 중앙 정렬 PanelContainer를 생성한다 (초기 숨김).
## @param sz 패널 크기
## @returns PanelContainer
func _create_centered_panel(sz: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchors_preset = Control.PRESET_CENTER
	p.anchor_left = 0.5; p.anchor_top = 0.5
	p.anchor_right = 0.5; p.anchor_bottom = 0.5
	p.offset_left = -sz.x / 2.0; p.offset_right = sz.x / 2.0
	p.offset_top = -sz.y / 2.0; p.offset_bottom = sz.y / 2.0
	var style := _make_flat_style(COLOR_PANEL, 8, PADDING, PADDING)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = COLOR_ACCENT_DIM
	p.add_theme_stylebox_override("panel", style)
	p.visible = false
	return p

## Label을 생성한다.
## @param text 텍스트
## @param size 폰트 크기
## @param color 글자 색상
## @param align 수평 정렬 (기본 LEFT)
## @returns 생성된 Label
func _create_label(text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = align
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return lbl

## StyleBoxFlat를 생성한다.
## @param bg 배경색  @param r 코너 반경  @param mh 좌우 마진  @param mv 상하 마진
func _make_flat_style(bg: Color, r: int = 4, mh: int = 0, mv: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = r; s.corner_radius_top_right = r
	s.corner_radius_bottom_left = r; s.corner_radius_bottom_right = r
	if mh > 0:
		s.content_margin_left = mh; s.content_margin_right = mh
	if mv > 0:
		s.content_margin_top = mv; s.content_margin_bottom = mv
	return s

# ── 유틸리티 ──
## 플레이타임을 HH:MM:SS 형식으로 포맷한다.
## @param seconds 총 플레이 시간 (초)
## @returns 포맷된 문자열
func _fmt_time(seconds: float) -> String:
	var h := int(seconds) / 3600
	var m := (int(seconds) % 3600) / 60
	var s := int(seconds) % 60
	return "%02d:%02d:%02d" % [h, m, s]

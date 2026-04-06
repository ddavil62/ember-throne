## @fileoverview CG 갤러리 화면. 해금된 CG 이미지를 열람하는 갤러리.
## 스토리에서 등장한 CG를 수집하고, 썸네일 그리드 + 전체 화면 뷰어로 열람한다.
class_name CGGallery
extends Control

# ── 시그널 ──

## 뒤로 버튼 클릭 시 발행
signal back_pressed

# ── 상수 ──

const PADDING := 16
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)
const COLOR_LOCKED := Color(0.15, 0.15, 0.2, 1.0)
const COLOR_OVERLAY := Color(0.0, 0.0, 0.0, 0.85)

## CG 이미지 리소스 경로
const CG_PATH := "res://assets/cg/"

## 그리드 열 수
const GRID_COLUMNS := 4

## 썸네일 크기
const THUMB_SIZE := Vector2(240, 135)

## CG 목록 (4막에 걸친 이벤트 CG)
const CG_LIST: Array = [
	{"id": "cg_irhen_village", "scene": "1-1", "name_ko": "이르헨 마을의 화재", "name_en": "Irhen Village Fire"},
	{"id": "cg_seria_meeting", "scene": "1-2", "name_ko": "세리아와의 만남", "name_en": "Meeting Seria"},
	{"id": "cg_silvaren_forest", "scene": "1-4", "name_ko": "실바렌 숲", "name_en": "Silvaren Forest"},
	{"id": "cg_pina_death", "scene": "2-4", "name_ko": "피나의 죽음", "name_en": "Pina's Death"},
	{"id": "cg_harden_night", "scene": "2-7", "name_ko": "하르덴의 밤", "name_en": "Night at Harden"},
	{"id": "cg_rinen_memory", "scene": "3-6", "name_ko": "리넨의 기억", "name_en": "Rinen's Memory"},
	{"id": "cg_kael_oath", "scene": "3-7", "name_ko": "카엘의 서약", "name_en": "Kael's Oath"},
	{"id": "cg_crowfel_battle", "scene": "3-12", "name_ko": "크로우펠 전투", "name_en": "Battle of Crowfel"},
	{"id": "cg_last_night", "scene": "3-15", "name_ko": "마지막 밤", "name_en": "The Last Night"},
	{"id": "cg_eris_death", "scene": "4-3", "name_ko": "에리스의 죽음", "name_en": "Eris's Death"},
	{"id": "cg_ending_a", "scene": "ending_a", "name_ko": "엔딩 A: 시원화의 재점화", "name_en": "Ending A: Rekindling"},
	{"id": "cg_ending_b", "scene": "ending_b", "name_ko": "엔딩 B: 불꽃의 분산", "name_en": "Ending B: Dispersal"},
]

# ── 노드 참조 ──

## 썸네일 그리드
var _grid: GridContainer
## 전체 화면 뷰어 (오버레이 + 이미지)
var _fullscreen_viewer: Control = null
## 전체 화면 이미지 노드
var _fullscreen_image: TextureRect = null
## 해금 카운트 라벨
var _count_label: Label

# ── 상태 ──

## 현재 전체 화면 표시 중인 CG 인덱스 (해금 목록 기준)
var _current_fullscreen_index: int = -1
## 해금된 CG ID 배열 (탐색용 캐시)
var _unlocked_ids: Array[String] = []

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	_populate_gallery()

## 전체 UI 노드를 코드로 생성한다.
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	# 배경
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 메인 패널
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1100, 700)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-550, -350)
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
	title.text = "CG 갤러리"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	# 해금 카운트
	_count_label = Label.new()
	_count_label.add_theme_font_size_override("font_size", 16)
	_count_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	header.add_child(_count_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	header.add_child(spacer)

	var back_btn := Button.new()
	back_btn.text = "뒤로"
	back_btn.pressed.connect(_on_back_pressed)
	header.add_child(back_btn)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 스크롤 + 그리드
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = GRID_COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

## CG 항목을 그리드에 채운다. 해금 상태에 따라 썸네일/잠금 표시를 분기한다.
func _populate_gallery() -> void:
	# 기존 항목 제거
	for child in _grid.get_children():
		child.queue_free()

	# 해금 목록 캐시 갱신
	_unlocked_ids.clear()
	var gm: Node = get_node("/root/GameManager")

	for cg in CG_LIST:
		var cg_id: String = cg["id"]
		var unlocked: bool = gm.has_flag("cg_unlocked_" + cg_id)
		if unlocked:
			_unlocked_ids.append(cg_id)

		# 카드 패널
		var card := PanelContainer.new()
		card.custom_minimum_size = THUMB_SIZE + Vector2(8, 32)
		var card_style := StyleBoxFlat.new()
		card_style.bg_color = COLOR_LOCKED if not unlocked else Color(0.18, 0.18, 0.25, 1.0)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card_style.content_margin_left = 4
		card_style.content_margin_right = 4
		card_style.content_margin_top = 4
		card_style.content_margin_bottom = 4
		card.add_theme_stylebox_override("panel", card_style)
		_grid.add_child(card)

		var card_vbox := VBoxContainer.new()
		card_vbox.add_theme_constant_override("separation", 4)
		card.add_child(card_vbox)

		if unlocked:
			# 썸네일 이미지
			var tex_rect := TextureRect.new()
			tex_rect.custom_minimum_size = THUMB_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

			var thumb_path: String = CG_PATH + cg_id + "_thumb.png"
			var full_path: String = CG_PATH + cg_id + ".png"
			# 썸네일이 있으면 사용, 없으면 원본
			if ResourceLoader.exists(thumb_path):
				tex_rect.texture = load(thumb_path)
			elif ResourceLoader.exists(full_path):
				tex_rect.texture = load(full_path)
			card_vbox.add_child(tex_rect)

			# CG 이름
			var name_label := Label.new()
			name_label.text = cg["name_ko"]
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.add_theme_color_override("font_color", COLOR_TEXT)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_vbox.add_child(name_label)

			# 클릭 이벤트
			card.gui_input.connect(_on_cg_card_input.bind(cg_id))
		else:
			# 잠긴 CG: 어두운 실루엣 + ???
			var locked_rect := ColorRect.new()
			locked_rect.color = COLOR_LOCKED
			locked_rect.custom_minimum_size = THUMB_SIZE
			card_vbox.add_child(locked_rect)

			var locked_label := Label.new()
			locked_label.text = "???"
			locked_label.add_theme_font_size_override("font_size", 14)
			locked_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
			locked_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			card_vbox.add_child(locked_label)

	# 카운트 갱신
	_count_label.text = "%d / %d" % [get_unlocked_count(), get_total_count()]

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if _fullscreen_viewer != null:
		if event.is_action_pressed("ui_cancel"):
			_hide_fullscreen()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_left"):
			_navigate_cg(-1)
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_right"):
			_navigate_cg(1)
			get_viewport().set_input_as_handled()
	else:
		if event.is_action_pressed("ui_cancel"):
			_on_back_pressed()
			get_viewport().set_input_as_handled()

## 썸네일 카드 클릭 시 전체 화면 뷰어를 연다.
## @param event 입력 이벤트
## @param cg_id CG ID
func _on_cg_card_input(event: InputEvent, cg_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cg_selected(cg_id)

# ── 전체 화면 뷰어 ──

## CG 선택 시 전체 화면 뷰어를 표시한다.
## @param cg_id 선택된 CG ID
func _on_cg_selected(cg_id: String) -> void:
	_show_fullscreen(cg_id)

## 전체 화면 뷰어를 표시한다.
## @param cg_id 표시할 CG ID
func _show_fullscreen(cg_id: String) -> void:
	# 인덱스 찾기
	var idx := _unlocked_ids.find(cg_id)
	if idx < 0:
		return
	_current_fullscreen_index = idx

	# 기존 뷰어 제거
	if _fullscreen_viewer != null:
		_fullscreen_viewer.queue_free()

	_fullscreen_viewer = Control.new()
	_fullscreen_viewer.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_fullscreen_viewer)

	# 어두운 배경 오버레이
	var overlay := ColorRect.new()
	overlay.color = COLOR_OVERLAY
	overlay.anchors_preset = Control.PRESET_FULL_RECT
	overlay.gui_input.connect(_on_fullscreen_overlay_input)
	_fullscreen_viewer.add_child(overlay)

	# CG 이미지
	_fullscreen_image = TextureRect.new()
	_fullscreen_image.anchors_preset = Control.PRESET_FULL_RECT
	_fullscreen_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_fullscreen_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fullscreen_viewer.add_child(_fullscreen_image)

	_load_fullscreen_image(cg_id)

	# CG 이름 하단 표시
	var name_label := Label.new()
	name_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
	name_label.offset_top = -40
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.text = _get_cg_name(cg_id)
	_fullscreen_viewer.add_child(name_label)

## CG 이름을 반환한다.
## @param cg_id CG ID
## @returns 한국어 CG 이름
func _get_cg_name(cg_id: String) -> String:
	for cg in CG_LIST:
		if cg["id"] == cg_id:
			return cg["name_ko"]
	return ""

## 전체 화면 이미지 로드
## @param cg_id CG ID
func _load_fullscreen_image(cg_id: String) -> void:
	var path: String = CG_PATH + cg_id + ".png"
	if ResourceLoader.exists(path):
		_fullscreen_image.texture = load(path)
	else:
		_fullscreen_image.texture = null

## 전체 화면 뷰어를 닫는다.
func _hide_fullscreen() -> void:
	if _fullscreen_viewer != null:
		_fullscreen_viewer.queue_free()
		_fullscreen_viewer = null
		_fullscreen_image = null
		_current_fullscreen_index = -1

## 해금된 CG 간 좌우 탐색.
## @param direction 방향 (+1: 다음, -1: 이전)
func _navigate_cg(direction: int) -> void:
	if _unlocked_ids.is_empty():
		return
	var new_index: int = _current_fullscreen_index + direction
	# 범위 클램핑
	new_index = clampi(new_index, 0, _unlocked_ids.size() - 1)
	if new_index == _current_fullscreen_index:
		return
	_current_fullscreen_index = new_index
	var cg_id: String = _unlocked_ids[new_index]
	_load_fullscreen_image(cg_id)
	# 이름 라벨 갱신 (마지막 자식)
	var children := _fullscreen_viewer.get_children()
	if children.size() > 0:
		var last_child := children[children.size() - 1]
		if last_child is Label:
			last_child.text = _get_cg_name(cg_id)

## 전체 화면 오버레이 클릭 시 닫기
## @param event 입력 이벤트
func _on_fullscreen_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_hide_fullscreen()

# ── 조회 ──

## 해금된 CG 수를 반환한다.
## @returns 해금 CG 수
func get_unlocked_count() -> int:
	var count: int = 0
	var gm: Node = get_node("/root/GameManager")
	for cg in CG_LIST:
		if gm.has_flag("cg_unlocked_" + cg["id"]):
			count += 1
	return count

## 전체 CG 수를 반환한다.
## @returns 전체 CG 수
func get_total_count() -> int:
	return CG_LIST.size()

# ── 이벤트 핸들러 ──

## 뒤로 버튼 클릭 처리
func _on_back_pressed() -> void:
	back_pressed.emit()
	queue_free()

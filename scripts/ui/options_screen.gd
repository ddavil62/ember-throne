## @fileoverview 옵션 화면. BGM/SFX 볼륨, 텍스트 속도, 화면 모드, 해상도, 언어 설정을 관리한다.
## ConfigFile을 사용하여 user://settings.cfg에 독립적으로 저장/로드한다.
class_name OptionsScreen
extends Control

# ── 시그널 ──

## 뒤로 가기 시 발행. 부모 씬에서 연결하여 화면 전환에 사용한다.
signal back_pressed

# ── 상수 ──

## 설정 파일 경로
const SETTINGS_PATH := "user://settings.cfg"
## 텍스트 속도 (초/글자): 느리게 / 보통 / 빠르게
const TEXT_SPEEDS: Array = [0.05, 0.03, 0.01]
## 해상도 목록
const RESOLUTIONS: Array = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

## 패딩
const PADDING := 16
## 색상 테마
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.95)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)

# ── 노드 참조 ──

## ConfigFile 인스턴스
var _config: ConfigFile
## BGM 볼륨 슬라이더
var _bgm_slider: HSlider
## BGM 볼륨 수치 라벨
var _bgm_label: Label
## SFX 볼륨 슬라이더
var _sfx_slider: HSlider
## SFX 볼륨 수치 라벨
var _sfx_label: Label
## 텍스트 속도 드롭다운
var _text_speed_btn: OptionButton
## 화면 모드 드롭다운
var _window_mode_btn: OptionButton
## 해상도 드롭다운
var _resolution_btn: OptionButton
## 언어 드롭다운
var _language_btn: OptionButton

# ── 초기화 ──

func _ready() -> void:
	_config = ConfigFile.new()
	_build_ui()
	load_settings()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	# 풀스크린 배경
	anchors_preset = Control.PRESET_FULL_RECT

	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 메인 패널 (중앙 정렬)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 600)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-350, -300)
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

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	panel.add_child(root_vbox)

	# 헤더: 타이틀 + 닫기 버튼
	var header := HBoxContainer.new()
	root_vbox.add_child(header)

	var title := Label.new()
	title.text = "옵션"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.pressed.connect(_on_back_pressed)
	header.add_child(close_btn)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	# 설정 항목 리스트
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(scroll)

	var settings_vbox := VBoxContainer.new()
	settings_vbox.add_theme_constant_override("separation", 16)
	settings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(settings_vbox)

	# ── 오디오 섹션 ──
	_add_section_label(settings_vbox, "오디오")

	# BGM 볼륨
	var bgm_row := _create_setting_row("BGM 볼륨")
	settings_vbox.add_child(bgm_row)
	_bgm_slider = HSlider.new()
	_bgm_slider.min_value = 0
	_bgm_slider.max_value = 100
	_bgm_slider.step = 1
	_bgm_slider.value = 80
	_bgm_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bgm_slider.custom_minimum_size = Vector2(300, 0)
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	bgm_row.add_child(_bgm_slider)
	_bgm_label = Label.new()
	_bgm_label.text = "80%"
	_bgm_label.custom_minimum_size = Vector2(50, 0)
	_bgm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bgm_label.add_theme_color_override("font_color", COLOR_TEXT)
	bgm_row.add_child(_bgm_label)

	# SFX 볼륨
	var sfx_row := _create_setting_row("SFX 볼륨")
	settings_vbox.add_child(sfx_row)
	_sfx_slider = HSlider.new()
	_sfx_slider.min_value = 0
	_sfx_slider.max_value = 100
	_sfx_slider.step = 1
	_sfx_slider.value = 80
	_sfx_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sfx_slider.custom_minimum_size = Vector2(300, 0)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	sfx_row.add_child(_sfx_slider)
	_sfx_label = Label.new()
	_sfx_label.text = "80%"
	_sfx_label.custom_minimum_size = Vector2(50, 0)
	_sfx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sfx_label.add_theme_color_override("font_color", COLOR_TEXT)
	sfx_row.add_child(_sfx_label)

	# ── 게임플레이 섹션 ──
	_add_section_label(settings_vbox, "게임플레이")

	# 텍스트 속도
	var text_row := _create_setting_row("텍스트 속도")
	settings_vbox.add_child(text_row)
	_text_speed_btn = OptionButton.new()
	_text_speed_btn.add_item("느리게", 0)
	_text_speed_btn.add_item("보통", 1)
	_text_speed_btn.add_item("빠르게", 2)
	_text_speed_btn.selected = 1
	_text_speed_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text_speed_btn.item_selected.connect(_on_text_speed_changed)
	text_row.add_child(_text_speed_btn)

	# 언어
	var lang_row := _create_setting_row("언어")
	settings_vbox.add_child(lang_row)
	_language_btn = OptionButton.new()
	_language_btn.add_item("한국어", 0)
	_language_btn.add_item("English", 1)
	_language_btn.selected = 0
	_language_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_language_btn.item_selected.connect(_on_language_changed)
	lang_row.add_child(_language_btn)

	# ── 디스플레이 섹션 ──
	_add_section_label(settings_vbox, "디스플레이")

	# 화면 모드
	var wm_row := _create_setting_row("화면 모드")
	settings_vbox.add_child(wm_row)
	_window_mode_btn = OptionButton.new()
	_window_mode_btn.add_item("창 모드", 0)
	_window_mode_btn.add_item("전체 화면", 1)
	_window_mode_btn.add_item("무테두리", 2)
	_window_mode_btn.selected = 0
	_window_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window_mode_btn.item_selected.connect(_on_window_mode_changed)
	wm_row.add_child(_window_mode_btn)

	# 해상도
	var res_row := _create_setting_row("해상도")
	settings_vbox.add_child(res_row)
	_resolution_btn = OptionButton.new()
	_resolution_btn.add_item("1280x720", 0)
	_resolution_btn.add_item("1600x900", 1)
	_resolution_btn.add_item("1920x1080", 2)
	_resolution_btn.selected = 0
	_resolution_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resolution_btn.item_selected.connect(_on_resolution_changed)
	res_row.add_child(_resolution_btn)

	# ── 하단 버튼 ──
	var footer_sep := HSeparator.new()
	root_vbox.add_child(footer_sep)

	var footer := HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	root_vbox.add_child(footer)

	var reset_btn := Button.new()
	reset_btn.text = "초기화"
	reset_btn.custom_minimum_size = Vector2(100, 36)
	reset_btn.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_btn)

	var apply_btn := Button.new()
	apply_btn.text = "적용"
	apply_btn.custom_minimum_size = Vector2(100, 36)
	apply_btn.pressed.connect(_on_apply_pressed)
	footer.add_child(apply_btn)

	var back_btn := Button.new()
	back_btn.text = "뒤로"
	back_btn.custom_minimum_size = Vector2(100, 36)
	back_btn.pressed.connect(_on_back_pressed)
	footer.add_child(back_btn)

# ── UI 헬퍼 ──

## 섹션 구분 라벨을 추가한다.
## @param parent 부모 컨테이너
## @param text 섹션 이름
func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	parent.add_child(label)

## 설정 항목 행(HBoxContainer)을 생성한다. 좌측에 항목명 라벨을 포함.
## @param label_text 항목 이름
## @returns HBoxContainer (우측에 위젯 추가 필요)
func _create_setting_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(140, 0)
	label.add_theme_color_override("font_color", COLOR_TEXT)
	label.add_theme_font_size_override("font_size", 16)
	row.add_child(label)

	return row

# ── 입력 처리 ──

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

# ── 설정 저장/로드 ──

## 현재 설정 값을 ConfigFile로 저장한다.
func save_settings() -> void:
	_config.set_value("audio", "bgm_volume", _bgm_slider.value / 100.0)
	_config.set_value("audio", "sfx_volume", _sfx_slider.value / 100.0)
	_config.set_value("display", "window_mode", _window_mode_btn.selected)
	_config.set_value("display", "resolution", _resolution_btn.selected)
	_config.set_value("game", "text_speed", _text_speed_btn.selected)
	var locale: String = "ko" if _language_btn.selected == 0 else "en"
	_config.set_value("game", "language", locale)

	var err := _config.save(SETTINGS_PATH)
	if err != OK:
		push_error("[OptionsScreen] 설정 저장 실패: %d" % err)
	else:
		print("[OptionsScreen] 설정 저장 완료")

## ConfigFile에서 설정을 로드하고 UI 및 시스템에 적용한다.
func load_settings() -> void:
	var err := _config.load(SETTINGS_PATH)
	if err != OK:
		# 파일 없으면 기본값 사용 (UI는 이미 기본값으로 초기화됨)
		print("[OptionsScreen] 설정 파일 없음, 기본값 사용")
		_apply_all_current()
		return

	# 오디오
	var bgm_vol: float = _config.get_value("audio", "bgm_volume", 0.8)
	var sfx_vol: float = _config.get_value("audio", "sfx_volume", 0.8)
	_bgm_slider.value = bgm_vol * 100.0
	_sfx_slider.value = sfx_vol * 100.0
	_bgm_label.text = "%d%%" % int(_bgm_slider.value)
	_sfx_label.text = "%d%%" % int(_sfx_slider.value)

	# 디스플레이
	var wm_idx: int = _config.get_value("display", "window_mode", 0)
	var res_idx: int = _config.get_value("display", "resolution", 0)
	_window_mode_btn.selected = clampi(wm_idx, 0, 2)
	_resolution_btn.selected = clampi(res_idx, 0, 2)

	# 게임플레이
	var ts_idx: int = _config.get_value("game", "text_speed", 1)
	var locale: String = _config.get_value("game", "language", "ko")
	_text_speed_btn.selected = clampi(ts_idx, 0, 2)
	_language_btn.selected = 0 if locale == "ko" else 1

	# 로드한 값을 시스템에 적용
	_apply_all_current()

## 현재 UI 값을 모든 시스템에 일괄 적용한다.
func _apply_all_current() -> void:
	_apply_bgm_volume(_bgm_slider.value / 100.0)
	_apply_sfx_volume(_sfx_slider.value / 100.0)
	_apply_window_mode(_window_mode_btn.selected)
	_apply_resolution(_resolution_btn.selected)
	_apply_text_speed(_text_speed_btn.selected)
	_apply_language(_language_btn.selected)

# ── 실시간 적용 함수 ──

## BGM 볼륨을 AudioManager에 반영한다.
## @param vol 볼륨 (0.0 ~ 1.0)
func _apply_bgm_volume(vol: float) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am:
		am.bgm_volume = vol

## SFX 볼륨을 AudioManager에 반영한다.
## @param vol 볼륨 (0.0 ~ 1.0)
func _apply_sfx_volume(vol: float) -> void:
	var am: Node = get_node_or_null("/root/AudioManager")
	if am:
		am.sfx_volume = vol

## 화면 모드를 DisplayServer에 적용한다.
## @param mode_idx 0=창 모드, 1=전체 화면, 2=무테두리 전체 화면
func _apply_window_mode(mode_idx: int) -> void:
	match mode_idx:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

## 해상도를 DisplayServer에 적용한다.
## @param idx 해상도 인덱스 (RESOLUTIONS 배열 참조)
func _apply_resolution(idx: int) -> void:
	if idx < 0 or idx >= RESOLUTIONS.size():
		return
	var res: Vector2i = RESOLUTIONS[idx]
	DisplayServer.window_set_size(res)
	# 화면 중앙 정렬
	var screen_size := DisplayServer.screen_get_size()
	var win_pos := Vector2i(
		(screen_size.x - res.x) / 2,
		(screen_size.y - res.y) / 2,
	)
	DisplayServer.window_set_position(win_pos)

## 텍스트 속도를 GameManager 플래그에 저장한다.
## @param idx 속도 인덱스 (0=느리게, 1=보통, 2=빠르게)
func _apply_text_speed(idx: int) -> void:
	if idx < 0 or idx >= TEXT_SPEEDS.size():
		return
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.set_flag("text_speed", TEXT_SPEEDS[idx])

## 언어를 TranslationServer에 적용한다.
## @param idx 0=한국어, 1=English
func _apply_language(idx: int) -> void:
	var locale: String = "ko" if idx == 0 else "en"
	TranslationServer.set_locale(locale)

# ── 이벤트 핸들러 ──

## BGM 슬라이더 값 변경 시 호출. 즉시 AudioManager에 반영한다.
## @param value 슬라이더 값 (0~100)
func _on_bgm_changed(value: float) -> void:
	_bgm_label.text = "%d%%" % int(value)
	_apply_bgm_volume(value / 100.0)

## SFX 슬라이더 값 변경 시 호출. 즉시 AudioManager에 반영하고 테스트 효과음을 재생한다.
## @param value 슬라이더 값 (0~100)
func _on_sfx_changed(value: float) -> void:
	_sfx_label.text = "%d%%" % int(value)
	_apply_sfx_volume(value / 100.0)
	# 테스트 효과음 재생
	var am: Node = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("ui_click")

## 텍스트 속도 변경 시 호출.
## @param idx 선택된 인덱스
func _on_text_speed_changed(idx: int) -> void:
	_apply_text_speed(idx)

## 화면 모드 변경 시 호출. 즉시 DisplayServer에 반영한다.
## @param idx 선택된 인덱스
func _on_window_mode_changed(idx: int) -> void:
	_apply_window_mode(idx)

## 해상도 변경 시 호출. 즉시 윈도우 크기를 변경한다.
## @param idx 선택된 인덱스
func _on_resolution_changed(idx: int) -> void:
	_apply_resolution(idx)

## 언어 변경 시 호출. 즉시 TranslationServer에 반영한다.
## @param idx 선택된 인덱스
func _on_language_changed(idx: int) -> void:
	_apply_language(idx)

## 초기화 버튼: 모든 설정을 기본값으로 복원한다.
func _on_reset_pressed() -> void:
	_bgm_slider.value = 80
	_sfx_slider.value = 80
	_text_speed_btn.selected = 1
	_window_mode_btn.selected = 0
	_resolution_btn.selected = 0
	_language_btn.selected = 0
	_apply_all_current()
	print("[OptionsScreen] 설정 초기화")

## 적용 버튼: 현재 값을 저장한다.
func _on_apply_pressed() -> void:
	save_settings()

## 뒤로 버튼: 설정 저장 후 back_pressed 시그널을 발행한다.
func _on_back_pressed() -> void:
	save_settings()
	back_pressed.emit()

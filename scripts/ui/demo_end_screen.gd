## @fileoverview 데모 종료 화면. 체험판 종료 메시지와 Steam 스토어 링크를 표시한다.
class_name DemoEndScreen
extends Control

# ── 상수 ──

## Steam 스토어 페이지 URL (App ID 480 = Spacewar 테스트용)
const STORE_URL := "https://store.steampowered.com/app/480"

## 색상 테마 (OptionsScreen과 동일)
const COLOR_BG := Color(0.04, 0.03, 0.06, 1.0)
const COLOR_PANEL := Color(0.12, 0.12, 0.18, 1.0)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)

func _ready() -> void:
	_build_ui()

## 전체 UI를 코드로 구성한다.
func _build_ui() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	# 배경
	var bg := ColorRect.new()
	bg.color = COLOR_BG
	bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(bg)

	# 중앙 패널
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 400)
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-300, -200)
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	panel.add_child(vbox)

	# 감사 메시지
	var title_label := Label.new()
	title_label.text = "체험판을 플레이해 주셔서 감사합니다!"
	title_label.add_theme_font_size_override("font_size", 28)
	title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_label)

	var desc_label := Label.new()
	desc_label.text = "Ember Throne의 정식 버전에서\n더 많은 이야기와 전투를 경험하세요."
	desc_label.add_theme_font_size_override("font_size", 18)
	desc_label.add_theme_color_override("font_color", COLOR_TEXT)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# 버튼 행
	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 16)
	vbox.add_child(btn_box)

	var store_btn := Button.new()
	store_btn.text = "Steam 스토어 페이지"
	store_btn.custom_minimum_size = Vector2(200, 48)
	store_btn.pressed.connect(_on_store_pressed)
	btn_box.add_child(store_btn)

	var title_btn := Button.new()
	title_btn.text = "타이틀로 돌아가기"
	title_btn.custom_minimum_size = Vector2(200, 48)
	title_btn.pressed.connect(_on_title_pressed)
	btn_box.add_child(title_btn)

## Steam 스토어 페이지를 브라우저에서 연다.
func _on_store_pressed() -> void:
	OS.shell_open(STORE_URL)

## 타이틀 화면으로 돌아간다.
func _on_title_pressed() -> void:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.transition_to_scene("res://scenes/main/main_menu.tscn", 0.5)
	else:
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

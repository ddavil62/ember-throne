## @fileoverview 미구현 씬의 플레이스홀더. 씬 이름과 돌아가기 버튼을 표시한다.
extends Control

## 플레이스홀더에 표시할 씬 이름
@export var scene_label: String = "미구현 씬"

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	# 배경
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.08, 1.0)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# 중앙 컨테이너
	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.anchor_left = 0.5; vbox.anchor_top = 0.5
	vbox.anchor_right = 0.5; vbox.anchor_bottom = 0.5
	vbox.offset_left = -200; vbox.offset_right = 200
	vbox.offset_top = -80; vbox.offset_bottom = 80
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)
	# 씬 이름
	var title := Label.new()
	title.text = scene_label
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(title)
	# 안내 문구
	var desc := Label.new()
	desc.text = "이 씬은 아직 구현되지 않았습니다."
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.55))
	vbox.add_child(desc)
	# 돌아가기 버튼
	var btn := Button.new()
	btn.text = "월드맵으로 돌아가기"
	btn.custom_minimum_size = Vector2(240, 48)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_back_pressed)
	vbox.add_child(btn)

func _on_back_pressed() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

## @fileoverview 본드 배너. 유대 레벨업 시 화면 상단에 슬라이드인 배너를 표시한다.
class_name BondBanner
extends CanvasLayer

# ── 상수 ──

## 렌더 레이어
const BANNER_LAYER: int = 50

## 배너 크기
const BANNER_WIDTH: float = 400.0
const BANNER_HEIGHT: float = 60.0

## 표시 시간 (초)
const DISPLAY_DURATION: float = 3.0

## 슬라이드 시간 (초)
const SLIDE_DURATION: float = 0.4

## 색상
const COLOR_BG := Color(0.08, 0.08, 0.12, 0.9)
const COLOR_ACCENT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT := Color(0.9, 0.9, 0.85, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)

# ── 멤버 변수 ──

## 배너 패널
var _banner: PanelContainer = null

## 표시 큐 (연속 레벨업 대응)
var _queue: Array[Dictionary] = []

## 현재 표시 중 여부
var _showing: bool = false

# ── 초기화 ──

func _ready() -> void:
	layer = BANNER_LAYER
	_connect_signals()

## EventBus 시그널을 연결한다.
func _connect_signals() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("EventBus"):
		var eb: Node = tree.root.get_node("EventBus")
		eb.bond_leveled_up.connect(_on_bond_leveled_up)

## 유대 레벨업 시그널 수신
## @param pair 유대 쌍 배열
## @param bond_name 유대 이름 (한국어)
## @param new_level 새 레벨
func _on_bond_leveled_up(pair: Array, bond_name: String, new_level: int) -> void:
	_queue.append({"pair": pair, "name": bond_name, "level": new_level})
	if not _showing:
		_show_next()

## 큐에서 다음 배너를 표시한다.
func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var data: Dictionary = _queue.pop_front()
	_show_banner(data["name"], data["level"])

## 배너를 생성하고 슬라이드인 연출한다.
## @param bond_name 유대 이름
## @param new_level 새 레벨
func _show_banner(bond_name: String, new_level: int) -> void:
	if _banner:
		_banner.queue_free()

	_banner = PanelContainer.new()
	_banner.custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	_banner.size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	# 화면 상단 중앙, 초기 위치는 화면 밖(위)
	_banner.position = Vector2(960 - BANNER_WIDTH / 2.0, -BANNER_HEIGHT)

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_ACCENT
	style.border_width_bottom = 2
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_banner.add_theme_stylebox_override("panel", style)
	add_child(_banner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	_banner.add_child(vbox)

	var title := Label.new()
	title.text = "유대 레벨 UP!"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var detail := Label.new()
	detail.text = "%s  Lv.%d" % [bond_name, new_level]
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_color_override("font_color", COLOR_TEXT)
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(detail)

	# 슬라이드인 → 대기 → 슬라이드아웃
	var tween := create_tween()
	tween.tween_property(_banner, "position:y", 0.0, SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(DISPLAY_DURATION)
	tween.tween_property(_banner, "position:y", -BANNER_HEIGHT, SLIDE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_banner.queue_free()
		_banner = null
		_show_next()
	)

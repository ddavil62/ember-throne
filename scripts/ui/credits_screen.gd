## @fileoverview 크레딧 롤 화면. 스태프 크레딧을 스크롤하고
## 완료 후 타이틀 화면으로 복귀한다.
class_name CreditsScreen
extends CanvasLayer

# ── 상수 ──

## 스크롤 속도 (px/s)
const SCROLL_SPEED: float = 150.0

## 페이드 인/아웃 시간 (초)
const FADE_DURATION: float = 1.0

## 배경 색상
const BG_COLOR := Color(0.0, 0.0, 0.0, 1.0)

## 제목 색상
const TITLE_COLOR := Color(1.0, 0.85, 0.2, 1.0)

## 텍스트 색상
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## 역할 색상
const ROLE_COLOR := Color(0.7, 0.8, 1.0, 1.0)

## 크레딧 데이터 (role/names 구조)
const CREDITS_DATA: Array = [
	{ "role": "Game Director", "names": ["Lazy Slime Studio"] },
	{ "role": "Scenario", "names": ["Lazy Slime Studio"] },
	{ "role": "Game Design", "names": ["Lazy Slime Studio"] },
	{ "role": "Programming", "names": ["Lazy Slime Studio", "Claude AI"] },
	{ "role": "Art Direction", "names": ["Lazy Slime Studio"] },
	{ "role": "Pixel Art", "names": ["PixelLab AI"] },
	{ "role": "Concept Art", "names": ["Stable Diffusion"] },
	{ "role": "Music", "names": ["Lazy Slime Studio"] },
	{ "role": "Sound Effects", "names": ["Lazy Slime Studio"] },
	{ "role": "Engine", "names": ["Godot Engine 4.6"] },
	{ "role": "Special Thanks", "names": ["모든 플레이어 여러분", "All Players"] },
]

# ── 상태 변수 ──

## 스크롤 활성 여부
var _scrolling: bool = false

## 스킵 가능 여부 (페이드 중 차단)
var _skippable: bool = false

# ── UI 노드 ──

## 루트 Control
var _root: Control = null

## 배경
var _bg: ColorRect = null

## 스크롤 컨테이너
var _scroll_content: VBoxContainer = null

## 게임 타이틀 라벨
var _game_title: Label = null

# ── 시그널 ──

## 크레딧 종료 시 발신
signal credits_finished

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	visible = false

## UI를 동적으로 구성한다.
func _build_ui() -> void:
	layer = 120  # 최상위

	_root = Control.new()
	_root.name = "Root"
	add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 배경 (검정)
	_bg = ColorRect.new()
	_bg.name = "Bg"
	_bg.color = BG_COLOR
	_root.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 스크롤 컨텐츠 (아래에서 위로 스크롤)
	_scroll_content = VBoxContainer.new()
	_scroll_content.name = "ScrollContent"
	_root.add_child(_scroll_content)
	_scroll_content.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_scroll_content.custom_minimum_size = Vector2(600, 0)
	_scroll_content.add_theme_constant_override("separation", 8)
	# 시작 위치: 화면 아래
	_scroll_content.position = Vector2(-300, 0)

	# 게임 타이틀
	_game_title = Label.new()
	_game_title.name = "GameTitle"
	_game_title.text = "EMBER THRONE"
	_game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_title.add_theme_font_size_override("font_size", 36)
	_game_title.add_theme_color_override("font_color", TITLE_COLOR)
	_scroll_content.add_child(_game_title)

	# 구분선
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 60)
	_scroll_content.add_child(spacer1)

	# 크레딧 항목 생성
	for entry: Dictionary in CREDITS_DATA:
		var role_label := Label.new()
		role_label.text = entry.get("role", "")
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		role_label.add_theme_font_size_override("font_size", 20)
		role_label.add_theme_color_override("font_color", ROLE_COLOR)
		_scroll_content.add_child(role_label)

		var names: Array = entry.get("names", [])
		for n: String in names:
			var name_label := Label.new()
			name_label.text = n
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size", 16)
			name_label.add_theme_color_override("font_color", TEXT_COLOR)
			_scroll_content.add_child(name_label)

		# 항목 간 여백
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 40)
		_scroll_content.add_child(spacer)

	# 마지막 여백 (화면 밖으로 스크롤되기 전 여유)
	var end_spacer := Control.new()
	end_spacer.custom_minimum_size = Vector2(0, 400)
	_scroll_content.add_child(end_spacer)

# ── 크레딧 재생 ──

## 크레딧 롤을 시작한다.
func start_credits() -> void:
	visible = true
	_scrolling = false
	_skippable = false

	# 화면 해상도 가져오기
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# 스크롤 시작 위치: 화면 아래
	_scroll_content.position.y = viewport_size.y

	# 페이드 인
	_root.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_callback(_begin_scroll)

	print("[CreditsScreen] 크레딧 시작")

## 스크롤을 시작한다.
func _begin_scroll() -> void:
	_scrolling = true
	_skippable = true

func _process(delta: float) -> void:
	if not _scrolling:
		return

	_scroll_content.position.y -= SCROLL_SPEED * delta

	# 모든 컨텐츠가 화면 위로 사라졌는지 확인
	var content_bottom: float = _scroll_content.position.y + _scroll_content.size.y
	if content_bottom < 0:
		_end_credits()

## 크레딧을 종료하고 타이틀로 복귀한다.
func _end_credits() -> void:
	_scrolling = false
	_skippable = false

	# 페이드 아웃
	var tween := create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(_on_credits_done)

## 크레딧 완료 처리.
func _on_credits_done() -> void:
	visible = false
	print("[CreditsScreen] 크레딧 종료 → 타이틀 복귀")
	credits_finished.emit()

	# 타이틀 화면으로 전환
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		gm.transition_to_scene("res://scenes/ui/title_screen.tscn", 0.5, gm.GameState.TITLE)

# ── 입력 처리 (스킵) ──

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _skippable:
		return

	var accepted := false
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ENTER, KEY_SPACE, KEY_ESCAPE:
					accepted = true

	if accepted:
		get_viewport().set_input_as_handled()
		_end_credits()

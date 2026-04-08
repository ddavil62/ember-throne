## @fileoverview 로딩 화면. 씬 전환 시 페이드 인/아웃과 로딩 메시지를 표시한다.
class_name LoadingScreen
extends CanvasLayer

# ── 상수 ──

## 렌더 레이어 (최상위)
const LOADING_LAYER: int = 100

## 페이드 시간 (초)
const FADE_DURATION: float = 0.5

## 색상
const COLOR_BG := Color(0.02, 0.02, 0.05, 1.0)
const COLOR_TEXT := Color(0.85, 0.55, 0.2, 1.0)
const COLOR_TEXT_DIM := Color(0.55, 0.55, 0.5, 1.0)

# ── 멤버 변수 ──

## 배경 ColorRect
var _bg: ColorRect = null

## 로딩 텍스트 라벨
var _label: Label = null

## 팁 텍스트 라벨
var _tip_label: Label = null

## 페이드 Tween
var _tween: Tween = null

# ── 팁 목록 ──

const TIPS: Array[String] = [
	"지형을 활용하면 방어와 회피에 보너스를 받을 수 있습니다.",
	"무기 상성: 검 > 도끼 > 창 > 검",
	"유대 레벨이 높은 캐릭터를 인접 배치하면 전투 보너스를 받습니다.",
	"적의 위험 범위를 확인하고 안전한 위치에서 턴을 마무리하세요.",
	"크리티컬률은 SPD 차이에 영향을 받습니다.",
]

# ── 초기화 ──

func _ready() -> void:
	layer = LOADING_LAYER
	_build_ui()
	visible = false

## UI를 구성한다.
func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.color = COLOR_BG
	_bg.anchors_preset = Control.PRESET_FULL_RECT
	add_child(_bg)

	# 로딩 텍스트 (중앙)
	_label = Label.new()
	_label.text = "로딩 중..."
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.anchors_preset = Control.PRESET_CENTER
	_label.position = Vector2(-100, -40)
	_label.size = Vector2(200, 40)
	add_child(_label)

	# 팁 텍스트 (하단)
	_tip_label = Label.new()
	_tip_label.text = ""
	_tip_label.add_theme_font_size_override("font_size", 16)
	_tip_label.add_theme_color_override("font_color", COLOR_TEXT_DIM)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	_tip_label.position = Vector2(-300, -60)
	_tip_label.size = Vector2(600, 30)
	add_child(_tip_label)

# ── 공개 API ──

## 로딩 화면을 페이드인으로 표시한다.
## @param message 표시할 메시지 (기본: "로딩 중...")
func show_loading(message: String = "로딩 중...") -> void:
	_label.text = message
	_tip_label.text = TIPS[randi() % TIPS.size()]
	visible = true
	_bg.modulate.a = 0.0
	_label.modulate.a = 0.0
	_tip_label.modulate.a = 0.0

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_bg, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_property(_label, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_property(_tip_label, "modulate:a", 1.0, FADE_DURATION)

## 로딩 화면을 페이드아웃으로 숨긴다.
func hide_loading() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_bg, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_property(_label, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_property(_tip_label, "modulate:a", 0.0, FADE_DURATION)
	_tween.chain().tween_callback(func() -> void: visible = false)

## 메시지를 갱신한다.
## @param message 새 메시지 텍스트
func update_message(message: String) -> void:
	_label.text = message

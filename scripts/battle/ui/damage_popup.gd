## @fileoverview 대미지 팝업. 유닛 위치에 떠오르는 숫자 텍스트를 표시한다.
## 일반 데미지(흰), 크리티컬(노랑+크게), 회복(초록), 회피(회색)를 구분한다.
class_name DamagePopup
extends Node2D

# ── 상수 ──

## 팝업 상승 거리 (px)
const FLOAT_DISTANCE: float = 40.0

## 팝업 수명 (초)
const LIFETIME: float = 0.8

## 색상
const COLOR_NORMAL := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CRITICAL := Color(1.0, 0.85, 0.2, 1.0)
const COLOR_HEAL := Color(0.3, 0.9, 0.5, 1.0)
const COLOR_MISS := Color(0.6, 0.6, 0.6, 1.0)

## 폰트 크기
const FONT_SIZE_NORMAL: int = 18
const FONT_SIZE_CRITICAL: int = 26
const FONT_SIZE_HEAL: int = 18
const FONT_SIZE_MISS: int = 16

# ── 멤버 변수 ──

## 표시할 라벨
var _label: Label = null

# ── 팩토리 메서드 ──

## 대미지 팝업을 생성한다.
## @param amount 대미지량
## @param is_crit 크리티컬 여부
## @param world_pos 월드 좌표 (유닛 위치)
## @returns DamagePopup 인스턴스
static func create_damage(amount: int, is_crit: bool, world_pos: Vector2) -> DamagePopup:
	var popup := DamagePopup.new()
	popup.position = world_pos
	popup._setup_label(
		str(amount),
		COLOR_CRITICAL if is_crit else COLOR_NORMAL,
		FONT_SIZE_CRITICAL if is_crit else FONT_SIZE_NORMAL,
	)
	return popup

## 회복 팝업을 생성한다.
## @param amount 회복량
## @param world_pos 월드 좌표
## @returns DamagePopup 인스턴스
static func create_heal(amount: int, world_pos: Vector2) -> DamagePopup:
	var popup := DamagePopup.new()
	popup.position = world_pos
	popup._setup_label("+%d" % amount, COLOR_HEAL, FONT_SIZE_HEAL)
	return popup

## 회피 팝업을 생성한다.
## @param world_pos 월드 좌표
## @returns DamagePopup 인스턴스
static func create_miss(world_pos: Vector2) -> DamagePopup:
	var popup := DamagePopup.new()
	popup.position = world_pos
	popup._setup_label("MISS", COLOR_MISS, FONT_SIZE_MISS)
	return popup

# ── 내부 메서드 ──

## 라벨을 설정한다.
func _setup_label(text: String, color: Color, font_size: int) -> void:
	_label = Label.new()
	_label.text = text
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", color)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(-40, -20)
	_label.size = Vector2(80, 30)
	add_child(_label)

## 씬 트리에 추가된 후 애니메이션을 자동 재생한다.
func _ready() -> void:
	_animate()

## 상승 + 페이드아웃 애니메이션을 재생한다.
func _animate() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - FLOAT_DISTANCE, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)

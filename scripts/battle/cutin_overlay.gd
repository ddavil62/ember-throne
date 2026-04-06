## @fileoverview 컷인 연출 오버레이. S등급 스킬 시전 시 전체 화면 컷인 애니메이션을
## 재생한다. 반투명 배경 → 컷인 이미지 슬라이드 인 → 유지 → 플래시+페이드 아웃.
class_name CutinOverlay
extends CanvasLayer

# ── 상수 ──

## 컷인 레이어 (최상위)
const CUTIN_LAYER: int = 90

## 컷인 이미지 해상도 (세로 기준 비율)
const CUTIN_IMAGE_WIDTH: float = 400.0
const CUTIN_IMAGE_HEIGHT: float = 500.0

## 타이밍 상수 (초)
const FADE_IN_DURATION: float = 0.1    ## 배경 페이드 인
const SLIDE_DURATION: float = 0.3      ## 컷인 슬라이드
const HOLD_DURATION: float = 0.2       ## 유지
const FADE_OUT_DURATION: float = 0.2   ## 플래시 + 페이드 아웃

## 컷인 초상화 에셋 경로 패턴
const CUTIN_PATH_PATTERN: String = "res://assets/portraits/%s_cutin.png"

# ── 시그널 ──

## 컷인 연출 완료 시 발생
signal cutin_finished()

# ── 멤버 변수 ──

## 반투명 검은 배경
var _bg_rect: ColorRect = null

## 컷인 이미지
var _cutin_image: TextureRect = null

## 화면 플래시 (흰색)
var _flash_rect: ColorRect = null

## 뷰포트 크기 캐시
var _viewport_size: Vector2 = Vector2(1280, 720)

# ── 초기화 ──

func _ready() -> void:
	layer = CUTIN_LAYER
	visible = false
	_setup_nodes()

## 내부 노드를 코드로 생성한다.
func _setup_nodes() -> void:
	# 뷰포트 크기 조회
	var tree := get_tree()
	if tree:
		_viewport_size = tree.root.get_visible_rect().size
		if _viewport_size == Vector2.ZERO:
			_viewport_size = Vector2(1280, 720)

	# 반투명 검은 배경
	_bg_rect = ColorRect.new()
	_bg_rect.name = "Background"
	_bg_rect.color = Color(0, 0, 0, 0)
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bg_rect)

	# 컷인 이미지 (TextureRect)
	_cutin_image = TextureRect.new()
	_cutin_image.name = "CutinImage"
	_cutin_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cutin_image.size = Vector2(CUTIN_IMAGE_WIDTH, CUTIN_IMAGE_HEIGHT)
	# 화면 좌측 바깥에서 시작
	_cutin_image.position = Vector2(-CUTIN_IMAGE_WIDTH, (_viewport_size.y - CUTIN_IMAGE_HEIGHT) / 2.0)
	_cutin_image.modulate = Color(1, 1, 1, 0)
	add_child(_cutin_image)

	# 화면 플래시
	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashOverlay"
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_flash_rect)

# ── 컷인 재생 ──

## 컷인 연출을 재생한다. 총 0.8초.
## 에셋이 없으면 placeholder(텍스트)로 대체한다.
## @param character_id 캐릭터 ID (에셋 경로에 사용)
func play_cutin(character_id: String) -> void:
	visible = true

	# 컷인 이미지 로드 시도
	var cutin_path: String = CUTIN_PATH_PATTERN % character_id
	if ResourceLoader.exists(cutin_path):
		var tex: Texture2D = load(cutin_path)
		_cutin_image.texture = tex
	else:
		# placeholder — 빈 텍스처, 배경만으로 연출
		_cutin_image.texture = null
		print("[CutinOverlay] 컷인 에셋 없음: %s — placeholder 사용" % cutin_path)

	# 초기 상태 리셋
	_bg_rect.color = Color(0, 0, 0, 0)
	_cutin_image.position = Vector2(-CUTIN_IMAGE_WIDTH, (_viewport_size.y - CUTIN_IMAGE_HEIGHT) / 2.0)
	_cutin_image.modulate = Color(1, 1, 1, 0)
	_flash_rect.color = Color(1, 1, 1, 0)

	# 연출 시퀀스
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)

	# 1단계: 배경 페이드 인 (0.1초)
	tween.tween_property(_bg_rect, "color", Color(0, 0, 0, 0.8), FADE_IN_DURATION)

	# 2단계: 컷인 이미지 슬라이드 인 (0.3초)
	var target_x: float = (_viewport_size.x - CUTIN_IMAGE_WIDTH) / 2.0
	var target_y: float = (_viewport_size.y - CUTIN_IMAGE_HEIGHT) / 2.0
	tween.parallel().tween_property(
		_cutin_image, "position",
		Vector2(target_x, target_y), SLIDE_DURATION
	)
	tween.parallel().tween_property(
		_cutin_image, "modulate",
		Color(1, 1, 1, 1), SLIDE_DURATION
	)

	# 3단계: 유지 (0.2초)
	tween.tween_interval(HOLD_DURATION)

	# 4단계: 플래시 + 페이드 아웃 (0.2초)
	tween.tween_property(_flash_rect, "color", Color(1, 1, 1, 0.8), FADE_OUT_DURATION * 0.3)
	tween.parallel().tween_property(_bg_rect, "color", Color(0, 0, 0, 0), FADE_OUT_DURATION * 0.7)
	tween.parallel().tween_property(_cutin_image, "modulate", Color(1, 1, 1, 0), FADE_OUT_DURATION * 0.7)
	tween.tween_property(_flash_rect, "color", Color(1, 1, 1, 0), FADE_OUT_DURATION * 0.5)

	await tween.finished

	visible = false
	cutin_finished.emit()

## @fileoverview VFX 재생 매니저. 스킬 이펙트, 화면 흔들림, 화면 플래시 등
## 전투 연출 시각 효과를 담당한다. 에셋이 없으면 placeholder(컬러 플래시)로 대체한다.
class_name VfxPlayer
extends Node2D

# ── 상수 ──

## 등급별 이펙트 지속시간 (초)
const TIER_DURATION: Dictionary = {
	"S": 3.5,
	"A": 2.5,
	"B": 1.5,
	"C": 0.7,
}

## placeholder 이펙트 크기
const PLACEHOLDER_SIZE: Vector2 = Vector2(48, 48)

## 화면 흔들림 기본 강도
const DEFAULT_SHAKE_INTENSITY: float = 8.0
const DEFAULT_SHAKE_DURATION: float = 0.3

## 화면 플래시 기본 색상
const DEFAULT_FLASH_COLOR: Color = Color(1, 1, 1, 0.6)
const DEFAULT_FLASH_DURATION: float = 0.15

## 파티클 에셋 경로 패턴
const PARTICLE_PATH_PATTERN: String = "res://assets/particles/%s.tres"

## 스프라이트 이펙트 경로 패턴
const SPRITE_EFFECT_PATH_PATTERN: String = "res://assets/sprites/effects/%s"

## 셰이더 경로 패턴
const SHADER_PATH_PATTERN: String = "res://assets/shaders/%s.gdshader"

# ── 시그널 ──

## 이펙트 재생 완료 시 발생
signal effect_finished()

# ── 멤버 변수 ──

## 화면 흔들림용 원래 카메라 오프셋
var _original_camera_offset: Vector2 = Vector2.ZERO

## 화면 플래시용 CanvasLayer
var _flash_layer: CanvasLayer = null

## 플래시 ColorRect
var _flash_rect: ColorRect = null

## dim overlay CanvasLayer (S등급용)
var _dim_layer: CanvasLayer = null

## dim overlay ColorRect
var _dim_rect: ColorRect = null

# ── 초기화 ──

func _ready() -> void:
	_setup_flash_layer()
	_setup_dim_layer()

## 플래시 오버레이 레이어를 생성한다.
func _setup_flash_layer() -> void:
	_flash_layer = CanvasLayer.new()
	_flash_layer.layer = 80
	_flash_layer.name = "VfxFlashLayer"
	add_child(_flash_layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_layer.add_child(_flash_rect)

## dim 오버레이 레이어를 생성한다. (S등급 암전 연출)
func _setup_dim_layer() -> void:
	_dim_layer = CanvasLayer.new()
	_dim_layer.layer = 70
	_dim_layer.name = "VfxDimLayer"
	_dim_layer.visible = false
	add_child(_dim_layer)

	_dim_rect = ColorRect.new()
	_dim_rect.name = "DimRect"
	_dim_rect.color = Color(0, 0, 0, 0)
	_dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim_layer.add_child(_dim_rect)

# ── 이펙트 재생 ──

## 이펙트를 재생한다. effect_id로 에셋 매핑을 시도하고, 없으면 placeholder를 표시한다.
## @param effect_id 이펙트 ID (스킬 ID 또는 이펙트 이름)
## @param world_pos 이펙트 표시 월드 좌표
## @param tier 등급 문자열 ("S", "A", "B", "C")
func play_effect(effect_id: String, world_pos: Vector2, tier: String) -> void:
	var duration: float = BattleSpeed.apply(TIER_DURATION.get(tier, 1.0))

	# 등급별 추가 연출 (모든 타이밍에 배속 적용)
	match tier:
		"S":
			# S등급: 화면 암전 + 플래시 + 강조 이펙트
			await _play_screen_dim(BattleSpeed.apply(0.5))
			play_screen_flash(Color(1, 1, 1, 0.8), BattleSpeed.apply(0.2))
			await _play_effect_at(effect_id, world_pos, maxf(duration - BattleSpeed.apply(1.0), 0.01))
			play_screen_shake(DEFAULT_SHAKE_INTENSITY * 1.5, BattleSpeed.apply(0.4))
			play_screen_flash(DEFAULT_FLASH_COLOR, BattleSpeed.apply(0.2))
			await _end_screen_dim(BattleSpeed.apply(0.3))

		"A":
			# A등급: 카메라 흔들림 + 강조 이펙트
			play_screen_shake(DEFAULT_SHAKE_INTENSITY, BattleSpeed.apply(DEFAULT_SHAKE_DURATION))
			await _play_effect_at(effect_id, world_pos, duration)
			play_screen_flash(Color(1, 1, 0.8, 0.4), BattleSpeed.apply(0.15))

		"B":
			# B등급: 기본 이펙트
			await _play_effect_at(effect_id, world_pos, duration)

		"C":
			# C등급: 간단한 flash
			await _play_placeholder_flash(world_pos, duration)

		_:
			await _play_placeholder_flash(world_pos, BattleSpeed.apply(0.5))

	effect_finished.emit()

## 화면 흔들림 효과를 재생한다.
## @param intensity 흔들림 강도 (픽셀)
## @param duration 지속 시간 (초)
func play_screen_shake(intensity: float, duration: float) -> void:
	var camera: Camera2D = _get_active_camera()
	if camera == null:
		# 카메라 없으면 자체 Node2D 위치로 흔들기
		var tween := create_tween()
		var original_pos: Vector2 = position
		var shake_count: int = int(duration / 0.05)
		for i: int in range(shake_count):
			var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
			tween.tween_property(self, "position", original_pos + offset, 0.05)
		tween.tween_property(self, "position", original_pos, 0.05)
		return

	_original_camera_offset = camera.offset
	var tween := create_tween()
	var shake_count: int = int(duration / 0.05)

	for i: int in range(shake_count):
		var offset := Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", _original_camera_offset + offset, 0.05)

	tween.tween_property(camera, "offset", _original_camera_offset, 0.05)

## 화면 플래시 효과를 재생한다.
## @param color 플래시 색상
## @param duration 지속 시간 (초)
func play_screen_flash(color: Color, duration: float) -> void:
	if _flash_rect == null:
		return

	_flash_rect.color = color
	var tween := create_tween()
	tween.tween_property(_flash_rect, "color", Color(color.r, color.g, color.b, 0), duration)

# ── 내부 이펙트 재생 ──

## 지정 위치에 이펙트를 재생한다. 에셋을 찾지 못하면 placeholder를 사용한다.
## @param effect_id 이펙트 ID
## @param world_pos 월드 좌표
## @param duration 지속 시간
func _play_effect_at(effect_id: String, world_pos: Vector2, duration: float) -> void:
	# 파티클 에셋 검색
	var particle_path: String = PARTICLE_PATH_PATTERN % effect_id
	if ResourceLoader.exists(particle_path):
		await _play_particle_effect(particle_path, world_pos, duration)
		return

	# 스프라이트 이펙트 검색
	var sprite_path: String = SPRITE_EFFECT_PATH_PATTERN % (effect_id + ".tres")
	if ResourceLoader.exists(sprite_path):
		await _play_sprite_effect(sprite_path, world_pos, duration)
		return

	# 에셋 없음 — placeholder
	await _play_placeholder_flash(world_pos, duration)

## 파티클 이펙트를 재생한다.
## @param path 파티클 리소스 경로
## @param world_pos 월드 좌표
## @param duration 지속 시간
func _play_particle_effect(path: String, world_pos: Vector2, duration: float) -> void:
	var particles := GPUParticles2D.new()
	particles.process_material = load(path)
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.lifetime = duration
	add_child(particles)

	await get_tree().create_timer(duration + BattleSpeed.apply(0.5)).timeout

	particles.queue_free()

## 스프라이트 이펙트를 재생한다.
## @param path SpriteFrames 리소스 경로
## @param world_pos 월드 좌표
## @param duration 지속 시간
func _play_sprite_effect(path: String, world_pos: Vector2, duration: float) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = load(path)
	sprite.position = world_pos
	sprite.play("default")
	add_child(sprite)

	await get_tree().create_timer(duration).timeout

	sprite.queue_free()

## placeholder 플래시 이펙트를 재생한다. (에셋 없을 때)
## 원형 ColorRect가 팽창하며 페이드 아웃한다.
## @param world_pos 월드 좌표
## @param duration 지속 시간
func _play_placeholder_flash(world_pos: Vector2, duration: float) -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 0.8, 0.2, 0.8)  # 황금색 반투명
	flash.size = PLACEHOLDER_SIZE
	flash.position = world_pos - PLACEHOLDER_SIZE / 2.0
	flash.pivot_offset = PLACEHOLDER_SIZE / 2.0
	add_child(flash)

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	# 팽창 + 페이드 아웃
	tween.tween_property(flash, "scale", Vector2(2.5, 2.5), duration * 0.4)
	tween.parallel().tween_property(flash, "color", Color(1, 0.8, 0.2, 0.0), duration * 0.8)
	tween.tween_interval(duration * 0.2)

	await tween.finished

	flash.queue_free()

# ── S등급 화면 암전 ──

## 화면 암전 시작 (S등급 연출)
## @param duration 암전 페이드 인 시간
func _play_screen_dim(duration: float) -> void:
	if _dim_layer == null:
		return
	_dim_layer.visible = true
	_dim_rect.color = Color(0, 0, 0, 0)

	var tween := create_tween()
	tween.tween_property(_dim_rect, "color", Color(0, 0, 0, 0.6), duration)
	await tween.finished

## 화면 암전 종료
## @param duration 암전 페이드 아웃 시간
func _end_screen_dim(duration: float) -> void:
	if _dim_layer == null:
		return

	var tween := create_tween()
	tween.tween_property(_dim_rect, "color", Color(0, 0, 0, 0), duration)
	await tween.finished

	_dim_layer.visible = false

# ── 유틸 ──

## 현재 활성 Camera2D를 찾는다.
## @returns Camera2D 또는 null
func _get_active_camera() -> Camera2D:
	var tree := get_tree()
	if tree == null:
		return null
	var viewport := tree.root
	if viewport == null:
		return null
	# 현재 카메라 탐색
	var cameras := tree.get_nodes_in_group("camera")
	if not cameras.is_empty():
		return cameras[0] as Camera2D
	# 부모 트리에서 Camera2D 검색
	var parent: Node = get_parent()
	while parent != null:
		if parent is Camera2D:
			return parent
		for child: Node in parent.get_children():
			if child is Camera2D:
				return child
		parent = parent.get_parent()
	return null

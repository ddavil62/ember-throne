## @fileoverview 카메라 흔들림(Screen Shake) 유틸리티.
## Camera2D 노드에 attach하여 전투 피격, 폭발, 필살기 등에서
## 감쇠 진동 기반의 화면 흔들림을 제공한다.
##
## 사용법:
##   1) Camera2D 노드에 이 스크립트를 추가(또는 자식 노드로 연결)
##   2) shake(amplitude, duration) 호출
##   3) 자동으로 감쇠하며 원래 위치로 복귀
class_name ScreenShake
extends Node


# ── 시그널 ──

## 흔들림이 완전히 종료되었을 때 발생
signal shake_finished


# ── 내부 상태 ──

## 흔들림 최대 진폭 (px 단위)
var _amplitude: float = 0.0

## 흔들림 주파수 (Hz). 높을수록 빠르게 진동
var _frequency: float = 15.0

## 감쇠 계수. 높을수록 빠르게 멈춤
var _decay: float = 5.0

## 흔들림 경과 시간
var _elapsed: float = 0.0

## 흔들림 총 지속 시간
var _duration: float = 0.0

## 흔들림 활성 여부
var _is_shaking: bool = false

## 대상 Camera2D 참조
var _camera: Camera2D = null


# ── 라이프사이클 ──

func _ready() -> void:
	# 부모가 Camera2D이면 자동으로 대상 설정
	if get_parent() is Camera2D:
		_camera = get_parent() as Camera2D
	set_process(false)


func _process(delta: float) -> void:
	if not _is_shaking or _camera == null:
		return

	_elapsed += delta

	if _elapsed >= _duration:
		# 흔들림 종료 — 오프셋 원복
		_is_shaking = false
		_camera.offset = Vector2.ZERO
		set_process(false)
		shake_finished.emit()
		return

	# 지수 감쇠 계수: 시간이 지남에 따라 진폭이 줄어든다
	var decay_factor: float = exp(-_decay * _elapsed / _duration)
	var current_amplitude: float = _amplitude * decay_factor

	# sin 기반 X/Y 독립 진동 (Y는 위상을 살짝 어긋나게 하여 자연스러운 궤적)
	var offset_x: float = current_amplitude * sin(TAU * _frequency * _elapsed)
	var offset_y: float = current_amplitude * sin(TAU * _frequency * _elapsed * 1.3 + 0.7)

	_camera.offset = Vector2(offset_x, offset_y)


# ── 공개 API ──

## 카메라 흔들림을 시작한다.
## [param amplitude] 최대 진폭(px). 보통 2~10 사이.
## [param duration] 지속 시간(초). 보통 0.2~0.8 사이.
## [param frequency] 진동 주파수(Hz). 기본 15.
## [param decay] 감쇠 계수. 기본 5.
func shake(amplitude: float, duration: float, frequency: float = 15.0, decay: float = 5.0) -> void:
	_amplitude = amplitude
	_duration = duration
	_frequency = frequency
	_decay = decay
	_elapsed = 0.0
	_is_shaking = true
	set_process(true)


## 대상 카메라를 수동으로 지정한다.
## 부모가 Camera2D가 아닌 경우 사용한다.
## [param camera] 흔들림을 적용할 Camera2D 노드
func set_camera(camera: Camera2D) -> void:
	_camera = camera


## 현재 진행 중인 흔들림을 즉시 중단한다.
func stop() -> void:
	_is_shaking = false
	if _camera != null:
		_camera.offset = Vector2.ZERO
	set_process(false)

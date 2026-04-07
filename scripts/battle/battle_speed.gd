## @fileoverview 전투 애니메이션 배속 관리. 3단계 속도(1x / 2x / 스킵)를 제공하며,
## 설정은 user://settings.cfg에 저장되어 세션 간 유지된다.
## static 메서드로만 접근하므로 autoload 등록 불필요.
class_name BattleSpeed
extends RefCounted

# ── 상수 ──

## 속도 단계별 제수 (duration을 이 값으로 나눈다)
## 1x = 1.0, 2x = 2.0, 스킵 = duration을 0.01로 대체
const SPEED_DIVISORS: Array[float] = [1.0, 2.0, 100.0]

## 속도 단계별 표시 라벨
const SPEED_LABELS: Array[String] = ["1x", "2x", ">>"]

## 단계 수
const SPEED_COUNT: int = 3

## 설정 파일 경로 (options_screen.gd와 동일)
const SETTINGS_PATH: String = "user://settings.cfg"

# ── 정적 변수 ──

## 현재 속도 인덱스 (0=1x, 1=2x, 2=스킵)
static var _speed_index: int = 0

## 초기화 완료 여부
static var _initialized: bool = false

# ── 정적 메서드 ──

## 설정 파일에서 배속 인덱스를 로드한다. 최초 1회만 실행.
static func _ensure_loaded() -> void:
	if _initialized:
		return
	_initialized = true
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		_speed_index = clampi(cfg.get_value("battle", "speed_index", 0), 0, SPEED_COUNT - 1)

## 현재 속도 인덱스를 반환한다 (0=1x, 1=2x, 2=스킵).
## @returns 속도 인덱스
static func get_speed_index() -> int:
	_ensure_loaded()
	return _speed_index

## 현재 속도 라벨을 반환한다 ("1x", "2x", ">>").
## @returns 표시 문자열
static func get_speed_label() -> String:
	_ensure_loaded()
	return SPEED_LABELS[_speed_index]

## 다음 속도 단계로 순환한다. 변경된 값을 설정 파일에 저장한다.
## @returns 새 속도 인덱스
static func cycle_speed() -> int:
	_ensure_loaded()
	_speed_index = (_speed_index + 1) % SPEED_COUNT
	_save()
	return _speed_index

## 속도 인덱스를 직접 설정한다.
## @param idx 설정할 인덱스 (0~2)
static func set_speed_index(idx: int) -> void:
	_ensure_loaded()
	_speed_index = clampi(idx, 0, SPEED_COUNT - 1)
	_save()

## 지정 duration에 배속을 적용한 값을 반환한다.
## 스킵 모드(인덱스 2)에서는 고정 0.01초를 반환한다.
## @param base_duration 원래 지속 시간 (초)
## @returns 배속 적용된 지속 시간
static func apply(base_duration: float) -> float:
	_ensure_loaded()
	if _speed_index >= 2:
		return 0.01
	return base_duration / SPEED_DIVISORS[_speed_index]

## 현재 설정을 ConfigFile에 저장한다.
static func _save() -> void:
	var cfg := ConfigFile.new()
	# 기존 설정 로드 (다른 섹션 보존)
	cfg.load(SETTINGS_PATH)
	cfg.set_value("battle", "speed_index", _speed_index)
	cfg.save(SETTINGS_PATH)

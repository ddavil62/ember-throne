## @fileoverview 난이도 관리 시스템. 난이도 설정에 따른 전투/AI/보상 보정치를 제공한다.
## GameManager.difficulty와 DataManager.difficulty_data를 참조하여 보정치를 반환한다.
## 싱글톤 패턴: DifficultyManager.get_instance()로 단일 인스턴스를 참조한다.
class_name DifficultyManager
extends RefCounted

# ── 싱글톤 ──

## 캐시된 싱글톤 인스턴스
static var _instance: DifficultyManager = null

## 싱글톤 인스턴스를 반환한다. 최초 호출 시 1회만 생성된다.
## @returns DifficultyManager 인스턴스
static func get_instance() -> DifficultyManager:
	if _instance == null:
		_instance = DifficultyManager.new()
	return _instance

# ── 상수 ──

## 적 스탯 보정 키 매핑 (stat 이름 → JSON 키)
const ENEMY_MULTIPLIER_KEYS: Dictionary = {
	"hp": "enemy_hp_multiplier",
	"atk": "enemy_atk_multiplier",
	"def": "enemy_def_multiplier",
	"spd": "enemy_spd_multiplier",
}

## 기본 난이도 (폴백)
const DEFAULT_DIFFICULTY := "normal"

# ── 캐시 ──

## 현재 난이도 설정 캐시
var _difficulty_cache: Dictionary = {}

# ── 초기화 ──

func _init() -> void:
	_load_difficulty_data()

## 난이도 데이터를 로드한다. DataManager가 사용 가능하면 참조, 아니면 JSON 직접 로드.
func _load_difficulty_data() -> void:
	# DataManager에서 로드 시도
	var dm_node: Node = Engine.get_main_loop().root.get_node_or_null("DataManager")
	if dm_node != null and dm_node.difficulty_data.size() > 0:
		_difficulty_cache = dm_node.difficulty_data.duplicate(true)
		return

	# DataManager 미사용 시 JSON 직접 로드
	var path := "res://data/difficulty.json"
	if not FileAccess.file_exists(path):
		push_warning("[DifficultyManager] 난이도 파일 없음: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DifficultyManager] 파일 열기 실패: %s" % path)
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[DifficultyManager] JSON 파싱 실패: %s" % path)
		return

	if json.data is Dictionary:
		_difficulty_cache = json.data.duplicate(true)

# ── 난이도 조회 ──

## 현재 난이도 문자열을 반환한다. ("normal" | "hard")
## @returns 난이도 문자열
func get_current_difficulty() -> String:
	var gm_node: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm_node != null:
		return gm_node.difficulty
	return DEFAULT_DIFFICULTY

## 현재 난이도의 전체 설정 Dictionary를 반환한다.
## @returns 난이도 설정 Dictionary
func get_difficulty_data() -> Dictionary:
	var key: String = get_current_difficulty()
	return _difficulty_cache.get(key, _difficulty_cache.get(DEFAULT_DIFFICULTY, {}))

# ── 적 보정치 ──

## 적 스탯 보정치를 반환한다.
## @param stat 스탯 키 ("hp" | "atk" | "def" | "spd")
## @returns 보정 배율 (기본 1.0)
func get_enemy_multiplier(stat: String) -> float:
	var data: Dictionary = get_difficulty_data()
	# 개별 스탯 보정 키 확인
	var json_key: String = ENEMY_MULTIPLIER_KEYS.get(stat, "")
	if json_key != "" and data.has(json_key):
		return data[json_key]
	# 범용 스탯 보정
	return data.get("enemy_stat_multiplier", 1.0)

## 적 레벨 보너스를 반환한다.
## @returns 레벨 보너스 (기본 0)
func get_enemy_level_bonus() -> int:
	var data: Dictionary = get_difficulty_data()
	return data.get("enemy_level_bonus", 0)

## 적 기본 스탯에 난이도 보정치를 적용하여 반환한다.
## @param base_stats 보정 전 적 스탯 Dictionary {hp, atk, def, spd, ...}
## @returns 보정 적용된 스탯 Dictionary
func apply_enemy_stats(base_stats: Dictionary) -> Dictionary:
	var result: Dictionary = base_stats.duplicate()
	var data: Dictionary = get_difficulty_data()

	# 개별 스탯 보정
	for stat_key in ENEMY_MULTIPLIER_KEYS.keys():
		if result.has(stat_key):
			var multiplier: float = get_enemy_multiplier(stat_key)
			result[stat_key] = int(result[stat_key] * multiplier)

	# 범용 보정 (개별 키에 매핑되지 않은 스탯)
	var general_mult: float = data.get("enemy_stat_multiplier", 1.0)
	for key in result.keys():
		if key not in ENEMY_MULTIPLIER_KEYS and result[key] is int:
			result[key] = int(result[key] * general_mult)

	return result

# ── 보상 보정치 ──

## 경험치 보정 배율을 반환한다.
## @returns 경험치 배율 (기본 1.0)
func get_exp_multiplier() -> float:
	var data: Dictionary = get_difficulty_data()
	return data.get("exp_multiplier", 1.0)

## 골드 보정 배율을 반환한다.
## @returns 골드 배율 (기본 1.0)
func get_gold_multiplier() -> float:
	var data: Dictionary = get_difficulty_data()
	return data.get("gold_multiplier", 1.0)

## 아이템 드롭률 보정 배율을 반환한다.
## @returns 드롭률 배율 (기본 1.0)
func get_item_drop_rate() -> float:
	var data: Dictionary = get_difficulty_data()
	return data.get("item_drop_rate", 1.0)

# ── AI 설정 ──

## AI가 힐러를 우선 타겟팅하는지 반환한다.
## @returns 힐러 우선 타겟팅 여부
func is_healer_priority() -> bool:
	var data: Dictionary = get_difficulty_data()
	return data.get("ai_target_healer_priority", false)

## AI가 집중 공격을 사용하는지 반환한다.
## @returns 집중 공격 여부
func is_focus_fire() -> bool:
	var data: Dictionary = get_difficulty_data()
	return data.get("ai_focus_fire", false)

## AI가 지형을 활용하는지 반환한다.
## @returns 지형 활용 여부
func is_terrain_ai() -> bool:
	var data: Dictionary = get_difficulty_data()
	return data.get("ai_use_terrain", false)

## AI 타겟 선택 방식을 반환한다. ("nearest_low_hp" | "threat_based")
## @returns 타겟 선택 방식 문자열
func get_target_selection() -> String:
	var data: Dictionary = get_difficulty_data()
	var ai_behavior: Dictionary = data.get("ai_behavior", {})
	return ai_behavior.get("target_selection", "nearest_low_hp")

# ── 게임플레이 설정 ──

## 불사조 깃털 구매 가능 여부를 반환한다.
## @returns 구매 가능 여부
func can_buy_phoenix_feather() -> bool:
	var data: Dictionary = get_difficulty_data()
	return data.get("phoenix_feather_purchasable", true)

## 패배 재시도 임계값을 반환한다. 0이면 무제한.
## @returns 재시도 임계 횟수 (0 = 무제한)
func get_defeat_retry_threshold() -> int:
	var data: Dictionary = get_difficulty_data()
	var value: Variant = data.get("defeat_retry_prompt_threshold", null)
	if value == null or value is float and is_nan(value):
		return 0
	return int(value)

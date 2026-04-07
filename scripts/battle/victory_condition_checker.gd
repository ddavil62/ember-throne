## @fileoverview 승리/패배 조건 판별기 (VCC). battle JSON의 victory_conditions /
## defeat_conditions 배열을 파싱하여 rout, escape, survive/survive_turns, unit_death,
## turn_limit_exceeded, unit_hp_threshold 조건 타입을 이벤트 구동 방식으로
## 실시간 판별한다. TurnManager의 자식 노드로 추가된다.
class_name VictoryConditionChecker
extends Node

# ── 시그널 ──

## 승리 조건 달성
signal victory_achieved(condition_type: String, reason_ko: String)
## 패배 조건 달성
signal defeat_achieved(condition_type: String, reason_ko: String)

# ── 멤버 변수 ──

## JSON에서 파싱된 승리 조건 배열
var _victory_conditions: Array = []

## JSON에서 파싱된 패배 조건 배열
var _defeat_conditions: Array = []

## BattleMap 참조 (유닛 조회용)
var _battle_map: Node2D = null

## 판별 활성화 여부 (BATTLE_END 후 중단)
var _active: bool = false

# ── 한국어 결과 메시지 ──

## 승리 조건별 기본 메시지
const VICTORY_MESSAGES: Dictionary = {
	"escape": "탈출 작전 성공!",
	"rout": "모든 적을 섬멸했다!",
	"survive_turns": "거점을 수호했다!",
	"survive": "거점을 수호했다!",
	"boss_kill": "{unit_name}을(를) 격파했다!",
}

## 패배 조건별 기본 메시지
const DEFEAT_MESSAGES: Dictionary = {
	"turn_limit_exceeded": "시간 제한을 초과했다...",
	"unit_death": "{unit_name}이(가) 전사했다...",
	"unit_hp_threshold": "{unit_name}이(가) 쓰러졌다...",
	"rout": "아군이 전멸했다...",
}

# ── 공개 메서드 ──

## 전투 시작 시 JSON 조건 파싱 및 EventBus 신호 연결.
## @param map_data 맵 데이터 Dictionary (victory_conditions, defeat_conditions 포함)
## @param battle_map_ref BattleMap 참조
func setup(map_data: Dictionary, battle_map_ref: Node2D) -> void:
	_battle_map = battle_map_ref
	_victory_conditions = map_data.get("victory_conditions", [])
	_defeat_conditions = map_data.get("defeat_conditions", [])
	_active = true

	# EventBus 신호 연결
	EventBus.unit_died.connect(_on_unit_died)
	EventBus.unit_moved.connect(_on_unit_moved)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.damage_dealt.connect(_on_damage_dealt)

	print("[VCC] 조건 초기화 완료 — 승리: %d개, 패배: %d개" % [
		_victory_conditions.size(), _defeat_conditions.size()
	])

## 조건 판별 중단 (전투 종료 후 호출).
func deactivate() -> void:
	_active = false

	# EventBus 신호 해제
	if EventBus.unit_died.is_connected(_on_unit_died):
		EventBus.unit_died.disconnect(_on_unit_died)
	if EventBus.unit_moved.is_connected(_on_unit_moved):
		EventBus.unit_moved.disconnect(_on_unit_moved)
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)

# ── EventBus 신호 콜백 ──

## 유닛 사망 시 — unit_death 패배 조건 체크 후 rout 승리/패배 조건 체크
## @param unit_id 사망한 유닛 ID
## @param _killer_id 처치한 유닛 ID
func _on_unit_died(unit_id: String, _killer_id: String) -> void:
	if not _active:
		return

	# 1. defeat 조건 먼저 체크 (unit_death)
	var context: Dictionary = {"unit_id": unit_id}
	if _check_defeat_conditions("unit_death", context):
		return

	# 2. victory 조건 체크 (boss_kill — 대상 보스 사망)
	if _check_victory_conditions("boss_kill", context):
		return

	# 3. victory 조건 체크 (rout — 적 전멸)
	if _check_victory_conditions("rout", context):
		return

	# 4. 아군 전멸 패배 체크 (JSON에 명시 안 된 경우에도 기본 동작)
	if _get_alive_player_count() == 0:
		var msg: String = DEFEAT_MESSAGES.get("rout", "아군이 전멸했다...")
		defeat_achieved.emit("rout", msg)

## 유닛 이동 시 — escape 승리 조건 체크
## @param unit_id 이동한 유닛 ID
## @param _from 이전 위치
## @param to 이동 후 위치
func _on_unit_moved(unit_id: String, _from: Vector2i, to: Vector2i) -> void:
	if not _active:
		return

	var context: Dictionary = {"unit_id": unit_id, "to": to}
	_check_victory_conditions("escape", context)

## 턴 시작 시 — turn_limit_exceeded 패배 후 survive/survive_turns 승리 체크 (player 페이즈만)
## @param phase 페이즈 ("player" / "enemy" / "npc")
## @param turn_number 현재 턴 번호
func _on_turn_started(phase: String, turn_number: int) -> void:
	if not _active:
		return
	if phase != "player":
		return

	var context: Dictionary = {"turn_number": turn_number}

	# 1. 턴 제한 경고 발신
	_emit_turn_limit_warning(turn_number)

	# 2. defeat 먼저 (turn_limit_exceeded)
	if _check_defeat_conditions("turn_limit_exceeded", context):
		return

	# 3. victory (survive_turns / survive — JSON 타입명 호환)
	if _check_victory_conditions("survive_turns", context):
		return
	_check_victory_conditions("survive", context)

## 데미지 발생 시 — unit_hp_threshold 패배 조건 체크
## @param _attacker_id 공격자 ID
## @param defender_id 방어자 ID
## @param _amount 데미지량
## @param _is_crit 크리티컬 여부
func _on_damage_dealt(_attacker_id: String, defender_id: String, _amount: int, _is_crit: bool) -> void:
	if not _active:
		return

	var context: Dictionary = {"defender_id": defender_id}
	_check_defeat_conditions("unit_hp_threshold", context)

# ── 내부 체크 메서드 ──

## defeat_conditions를 순회하여 event_type에 해당하는 조건을 체크한다.
## @param event_type 이벤트 타입 문자열 ("unit_death", "turn_limit_exceeded", "unit_hp_threshold")
## @param context 이벤트 문맥 Dictionary
## @returns 조건 충족 시 true
func _check_defeat_conditions(event_type: String, context: Dictionary) -> bool:
	for condition: Variant in _defeat_conditions:
		if not condition is Dictionary:
			continue
		var cond: Dictionary = condition as Dictionary
		var cond_type: String = cond.get("type", "")

		if cond_type != event_type:
			continue

		match cond_type:
			"unit_death":
				var target_uid: String = cond.get("unit_id", "")
				if context.get("unit_id", "") == target_uid:
					var unit_name: String = _get_unit_name_ko(target_uid)
					var msg: String = DEFEAT_MESSAGES.get("unit_death", "").replace("{unit_name}", unit_name)
					defeat_achieved.emit(cond_type, msg)
					return true

			"turn_limit_exceeded":
				var turn_limit: int = cond.get("turn_limit", 999)
				var current_turn: int = context.get("turn_number", 0)
				if current_turn > turn_limit:
					var msg: String = DEFEAT_MESSAGES.get("turn_limit_exceeded", "시간 제한을 초과했다...")
					defeat_achieved.emit(cond_type, msg)
					return true

			"unit_hp_threshold":
				var target_uid: String = cond.get("unit_id", "")
				var defender_id: String = context.get("defender_id", "")
				if defender_id == target_uid:
					var hp_threshold: float = float(cond.get("hp_percent", 0))
					var current_hp_pct: float = _get_unit_hp_percent(target_uid)
					if current_hp_pct <= hp_threshold and current_hp_pct > 0.0:
						var unit_name: String = _get_unit_name_ko(target_uid)
						var msg: String = DEFEAT_MESSAGES.get("unit_hp_threshold", "").replace("{unit_name}", unit_name)
						defeat_achieved.emit(cond_type, msg)
						return true

			_:
				# 미처리 패배 조건 타입 (boss_kill, any_unit_death 등은 별도 작업에서 구현 예정)
				push_warning("[VCC] 미처리 패배 조건 타입: %s" % cond_type)

	return false

## victory_conditions를 순회하여 event_type에 해당하는 조건을 체크한다.
## @param event_type 이벤트 타입 문자열 ("rout", "escape", "survive_turns", "survive")
## @param context 이벤트 문맥 Dictionary
## @returns 조건 충족 시 true
func _check_victory_conditions(event_type: String, context: Dictionary) -> bool:
	for condition: Variant in _victory_conditions:
		if not condition is Dictionary:
			continue
		var cond: Dictionary = condition as Dictionary
		var cond_type: String = cond.get("type", "")

		if cond_type != event_type:
			continue

		match cond_type:
			"boss_kill":
				var target_uid: String = cond.get("target_unit", "")
				var died_uid: String = context.get("unit_id", "")
				# uid 형식 "enemy_id_N"에서 base enemy_id 추출하여 비교
				var died_base_id: String = _extract_base_id(died_uid)
				if target_uid != "" and (died_uid == target_uid or died_base_id == target_uid):
					var unit_name: String = _get_unit_name_ko(target_uid)
					var msg: String = VICTORY_MESSAGES.get("boss_kill", "").replace("{unit_name}", unit_name)
					if cond.has("description_ko"):
						msg = cond["description_ko"]
					victory_achieved.emit(cond_type, msg)
					return true

			"rout":
				if _get_alive_enemy_count() == 0:
					var msg: String = VICTORY_MESSAGES.get("rout", "모든 적을 섬멸했다!")
					victory_achieved.emit(cond_type, msg)
					return true

			"escape":
				var target_unit: String = cond.get("target_unit", "")
				var target_pos_arr: Array = cond.get("target_position", [])
				if target_pos_arr.size() < 2:
					continue
				var target_pos := Vector2i(int(target_pos_arr[0]), int(target_pos_arr[1]))

				# 턴 제한 확인 (escape 조건 자체의 turn_limit)
				# null 경계값 처리: JSON에서 turn_limit이 null이면 제한 없음으로 취급
				var tl_value: Variant = cond.get("turn_limit", null)
				if tl_value != null and typeof(tl_value) == TYPE_INT:
					var escape_turn_limit: int = tl_value as int
					var current_turn: int = _get_current_turn()
					if current_turn > escape_turn_limit:
						continue  # 턴 제한 초과 — 이 조건은 더 이상 유효하지 않음

				if target_unit == "all_party":
					# 모든 아군이 target_position에 도달해야 함
					if _all_party_at_position(target_pos):
						var msg: String = VICTORY_MESSAGES.get("escape", "탈출 작전 성공!")
						victory_achieved.emit(cond_type, msg)
						return true
				else:
					# 지정 유닛이 target_position에 도달
					var moved_uid: String = context.get("unit_id", "")
					var moved_to: Vector2i = context.get("to", Vector2i(-1, -1))
					if moved_uid == target_unit and moved_to == target_pos:
						var msg: String = VICTORY_MESSAGES.get("escape", "탈출 작전 성공!")
						victory_achieved.emit(cond_type, msg)
						return true

			"survive_turns", "survive":
				# JSON 호환: survive_turns와 survive 모두 동일 로직 처리
				# 필드명 호환: required_turns 또는 turn_limit에서 목표 턴 수를 읽음
				var rt_value: Variant = cond.get("required_turns", null)
				var tl_value: Variant = cond.get("turn_limit", null)
				var required_turns: int = 999
				if rt_value != null and typeof(rt_value) == TYPE_INT:
					required_turns = rt_value as int
				elif tl_value != null and typeof(tl_value) == TYPE_INT:
					required_turns = tl_value as int
				var current_turn: int = context.get("turn_number", 0)
				if current_turn >= required_turns:
					var msg: String = VICTORY_MESSAGES.get(cond_type, "거점을 수호했다!")
					victory_achieved.emit(cond_type, msg)
					return true

			_:
				# 미처리 승리 조건 타입 (boss_kill, reach_position 등은 별도 작업에서 구현 예정)
				push_warning("[VCC] 미처리 승리 조건 타입: %s" % cond_type)

	return false

# ── 턴 제한 경고 ──

## 턴 제한이 있는 전투에서 남은 턴이 2 이하일 때 경고 신호를 발신한다.
## @param turn_number 현재 턴 번호
func _emit_turn_limit_warning(turn_number: int) -> void:
	for condition: Variant in _defeat_conditions:
		if not condition is Dictionary:
			continue
		var cond: Dictionary = condition as Dictionary
		if cond.get("type", "") != "turn_limit_exceeded":
			continue

		var turn_limit: int = cond.get("turn_limit", 999)
		var turns_remaining: int = turn_limit - turn_number
		if turns_remaining >= 1 and turns_remaining <= 2:
			EventBus.turn_limit_warning.emit(turns_remaining)

# ── 헬퍼 메서드 ──

## 적 팀 생존 유닛 수를 반환한다.
## @returns 생존 적 유닛 수
func _get_alive_enemy_count() -> int:
	if _battle_map == null:
		return 0
	var enemies: Array[BattleUnit] = _battle_map.get_units_by_team("enemy")
	var count: int = 0
	for unit: BattleUnit in enemies:
		if unit.is_alive():
			count += 1
	return count

## 아군 팀 생존 유닛 수를 반환한다.
## @returns 생존 아군 유닛 수
func _get_alive_player_count() -> int:
	if _battle_map == null:
		return 0
	var players: Array[BattleUnit] = _battle_map.get_units_by_team("player")
	var count: int = 0
	for unit: BattleUnit in players:
		if unit.is_alive():
			count += 1
	return count

## 유닛의 현재 HP 백분율을 반환한다.
## @param unit_id 유닛 ID
## @returns HP 백분율 (0.0~100.0), 유닛이 없으면 -1.0
func _get_unit_hp_percent(unit_id: String) -> float:
	if _battle_map == null:
		return -1.0
	var unit: BattleUnit = _battle_map.get_unit_by_id(unit_id)
	if unit == null:
		return -1.0
	var max_hp: int = unit.stats.get("hp", 1)
	if max_hp <= 0:
		return 0.0
	return float(unit.current_hp) / float(max_hp) * 100.0

## 유닛의 한국어 이름을 DataManager에서 조회한다.
## @param unit_id 유닛 ID
## @returns 한국어 이름 (없으면 unit_id 그대로 반환)
func _get_unit_name_ko(unit_id: String) -> String:
	var dm: Node = _get_data_manager()
	if dm:
		var char_data: Dictionary = dm.get_character(unit_id)
		if not char_data.is_empty():
			return char_data.get("name_ko", unit_id)
	return unit_id

## 현재 턴 번호를 TurnManager에서 가져온다 (부모 노드).
## @returns 현재 턴 번호
func _get_current_turn() -> int:
	var parent: Node = get_parent()
	if parent and parent is TurnManager:
		return (parent as TurnManager).turn_number
	return 0

## 모든 아군이 target_position에 있는지 확인한다.
## @param target_pos 목표 셀 좌표
## @returns 모든 아군이 해당 위치에 있으면 true
func _all_party_at_position(target_pos: Vector2i) -> bool:
	if _battle_map == null:
		return false
	var players: Array[BattleUnit] = _battle_map.get_units_by_team("player")
	if players.is_empty():
		return false
	for unit: BattleUnit in players:
		if unit.is_alive() and unit.cell != target_pos:
			return false
	return true

## uid에서 base enemy_id를 추출한다. uid 형식: "enemy_id_N"
## @param uid 유닛 고유 ID (예: "ascended_morgan_22")
## @returns base enemy_id (예: "ascended_morgan")
func _extract_base_id(uid: String) -> String:
	var last_underscore: int = uid.rfind("_")
	if last_underscore < 0:
		return uid
	var suffix: String = uid.substr(last_underscore + 1)
	if suffix.is_valid_int():
		return uid.substr(0, last_underscore)
	return uid

## DataManager 싱글톤 참조 취득
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

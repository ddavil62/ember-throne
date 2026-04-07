## @fileoverview 전투 씬 오케스트레이터. BattleMap, TurnManager, BattleHUD,
## DeploymentScreen, BattleResult, SkillExecutor를 조합하고
## 의존성을 주입한 뒤 전투 플로우를 진행한다.
extends Node

# ── 노드 참조 (.tscn에서 정의된 자식 노드) ──

## 전투 맵 (PackedScene 인스턴스)
@onready var _battle_map: Node2D = $BattleMap

## 턴 매니저
@onready var _turn_manager: TurnManager = $TurnManager

## 스킬 연출기
@onready var _skill_executor: SkillExecutor = $SkillExecutor

## 전투 HUD
@onready var _battle_hud: BattleHUD = $BattleHUD

## 배치 화면
@onready var _deployment: DeploymentScreen = $DeploymentScreen

## 전투 결과 화면
@onready var _battle_result: BattleResult = $BattleResult

## 현재 전투의 다단계 보스전 페이즈 (1부터 시작)
var _current_boss_phase: int = 1

## 다단계 보스전 총 페이즈 수
var _total_boss_phases: int = 1

## 페이즈별 보스 유닛 ID (special_rules에서 추출)
## {2: "reborn_morgan", 3: "ascended_morgan"}
var _phase_boss_ids: Dictionary = {}

# ── 초기화 ──

func _ready() -> void:
	# 의존성 주입
	_turn_manager.battle_map = _battle_map
	_turn_manager.connect_battle_map()
	_battle_hud.battle_map = _battle_map

	# 시그널 연결
	_deployment.deployment_finished.connect(_on_deployment_finished)
	_deployment.deployment_cancelled.connect(_on_deployment_cancelled)
	_battle_result.result_confirmed.connect(_on_result_confirmed)
	_battle_result.retry_requested.connect(_on_retry_requested)
	_battle_result.return_to_map.connect(_on_return_to_map)

	# 전투 조건 달성 시 결과 표시 (EventBus 경유)
	EventBus.battle_condition_triggered.connect(_on_battle_condition_triggered)

	# 유닛 사망 시 페이즈 전환 확인 (다단계 보스전)
	EventBus.unit_died.connect(_on_unit_died_check_phase)

	# 전투 데이터 로드 및 배치 화면 시작
	_start_battle()

# ── 전투 플로우 ──

## 전투 데이터를 로드하고 배치 단계를 시작한다.
func _start_battle() -> void:
	var gm: Node = get_node("/root/GameManager")
	var battle_id: String = gm.current_battle_id

	if battle_id.is_empty():
		battle_id = "battle_01"
		gm.current_battle_id = battle_id

	print("[BattleScene] 전투 시작: %s" % battle_id)

	# 맵 로드
	_battle_map.load_map(battle_id)

	# 배치 데이터 준비
	var dm: Node = get_node("/root/DataManager")
	var map_data: Dictionary = dm.get_map(battle_id)
	var deploy_cells: Array[Vector2i] = []
	# 맵 JSON의 deploy_zones 필드에서 배치 가능 셀 추출
	for cell_arr in map_data.get("deploy_zones", []):
		if cell_arr is Array and cell_arr.size() >= 2:
			deploy_cells.append(Vector2i(int(cell_arr[0]), int(cell_arr[1])))

	# 파티 데이터 (타이틀 씬 없이 직접 실행 시 기본 파티로 폴백)
	var pm: Node = get_node("/root/PartyManager")
	if pm.get_active_party().is_empty():
		pm.init_default_party()
	var party: Array[Dictionary] = pm.get_active_party()
	var deploy_limit: int = map_data.get("deploy_count", 8)

	print("[BattleScene] 배치 구역: %d개, 파티: %d명, 제한: %d" % [
		deploy_cells.size(), party.size(), deploy_limit
	])

	# 다단계 보스전 페이즈 초기화
	_init_boss_phases(map_data)

	# 배치 화면 시작
	_deployment.setup(_battle_map, deploy_cells, party, deploy_limit)
	_deployment.visible = true
	_battle_hud.visible = false

## 배치 완료 시 전투 시작
func _on_deployment_finished(deployed_units: Array) -> void:
	print("[BattleScene] 배치 완료: %d명" % deployed_units.size())
	_deployment.visible = false
	_battle_hud.visible = true

	# 적군은 load_map() 내부에서 자동 배치됨
	var gm: Node = get_node("/root/GameManager")
	gm.change_state(gm.GameState.BATTLE)

	# 턴 매니저 시작
	_turn_manager.start_battle()

## 배치 취소 시 월드맵 복귀
func _on_deployment_cancelled() -> void:
	print("[BattleScene] 배치 취소 — 월드맵 복귀")
	_return_to_world_map()

## 전투 결과 확인 (승리) — 월드맵으로 복귀한다.
## 노드 완료 처리는 ProgressionManager._on_battle_won()이
## battle_won 시그널 수신 시 battle_id 기반으로 이미 수행하므로
## 여기서는 중복 호출하지 않는다.
func _on_result_confirmed() -> void:
	_return_to_world_map()

## 재도전 요청
func _on_retry_requested() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/battle/battle_scene.tscn", 0.5, gm.GameState.DEPLOYMENT)

## 월드맵 복귀 요청
func _on_return_to_map() -> void:
	_return_to_world_map()

## 전투 조건 달성 시 결과 화면을 표시한다 (EventBus 콜백).
## @param is_victory 승리 여부
## @param condition_type 조건 타입 문자열
## @param reason_ko 한국어 결과 설명
func _on_battle_condition_triggered(is_victory: bool, condition_type: String, reason_ko: String) -> void:
	var result_data: Dictionary = {
		"victory": is_victory,
		"condition_type": condition_type,
		"reason_ko": reason_ko,
	}

	# 승리 시 맵 데이터에서 보상 정보를 읽어 표시 + 인벤토리에 반영
	if is_victory:
		result_data["exp_results"] = []

		var gm: Node = get_node("/root/GameManager")
		var dm: Node = get_node("/root/DataManager")
		var map_data: Dictionary = dm.get_map(gm.current_battle_id)
		var rewards: Dictionary = map_data.get("rewards", {})

		# 골드 보상
		var gold_amount: int = rewards.get("gold", 0)
		result_data["gold_earned"] = gold_amount
		if gold_amount > 0:
			var pm: Node = get_node("/root/PartyManager")
			pm.add_gold(gold_amount)

		# 아이템 보상 — "_xN" 접미사는 수량 N으로 파싱
		var items_earned: Array = []
		var im: Node = get_node("/root/InventoryManager")
		for raw_id: String in rewards.get("items", []):
			var item_id: String = raw_id
			var count: int = 1
			# "_x숫자" 패턴 파싱 (예: "herb_x3" → "herb" x 3)
			var regex := RegEx.new()
			regex.compile("^(.+)_x(\\d+)$")
			var m := regex.search(raw_id)
			if m:
				item_id = m.get_string(1)
				count = int(m.get_string(2))
			# 인벤토리에 추가
			im.add_item(item_id, count)
			# 결과 화면용 데이터 (name_ko는 DataManager에서 조회)
			var item_data: Dictionary = im.get_item_data(item_id)
			items_earned.append({
				"item_id": item_id,
				"name_ko": item_data.get("name_ko", item_id),
				"count": count,
			})
		result_data["items_earned"] = items_earned

	_battle_result.show_result(result_data)

# ── 다단계 보스전 페이즈 전환 ──

## 맵 데이터의 special_rules에서 다단계 보스전 정보를 초기화한다.
## @param map_data 맵 데이터 Dictionary
func _init_boss_phases(map_data: Dictionary) -> void:
	_current_boss_phase = 1
	_total_boss_phases = 1
	_phase_boss_ids.clear()

	var special_rules: Array = map_data.get("special_rules", [])
	for rule: Variant in special_rules:
		if not rule is Dictionary:
			continue
		var r: Dictionary = rule as Dictionary
		var rule_type: String = r.get("type", "")

		if rule_type == "multi_phase":
			_total_boss_phases = r.get("phases", 1)
		elif rule_type == "phase2_boss":
			_phase_boss_ids[2] = r.get("unit_id", "")
		elif rule_type == "phase3_boss":
			_phase_boss_ids[3] = r.get("unit_id", "")

	if _total_boss_phases > 1:
		print("[BattleScene] 다단계 보스전: %d페이즈, 보스ID: %s" % [
			_total_boss_phases, str(_phase_boss_ids)
		])

## 유닛 사망 시 페이즈 전환 여부를 확인한다 (EventBus 콜백).
## 현재 페이즈의 보스가 사망하면 다음 페이즈의 적을 스폰한다.
## @param unit_id 사망한 유닛 ID
## @param _killer_id 처치한 유닛 ID
func _on_unit_died_check_phase(unit_id: String, _killer_id: String) -> void:
	if _total_boss_phases <= 1:
		return

	# 현재 페이즈 + 1의 보스 ID와 비교하여 현재 페이즈 보스인지 판별
	var next_phase: int = _current_boss_phase + 1
	if next_phase > _total_boss_phases:
		return

	# 현재 페이즈의 보스가 사망했는지 확인
	# Phase 1 보스: enemy_placements의 첫 번째 보스 (corrupted_morgan)
	# Phase 2+ 보스: _phase_boss_ids에서 조회
	var current_boss_id: String = ""
	if _current_boss_phase == 1:
		# Phase 1 보스는 enemy_placements에서 is_boss인 적의 id를 사용
		# unit_id 형식: "enemy_id_N" (예: "corrupted_morgan_0")
		var gm: Node = get_node("/root/GameManager")
		var dm: Node = get_node("/root/DataManager")
		var map_data: Dictionary = dm.get_map(gm.current_battle_id)
		for placement: Variant in map_data.get("enemy_placements", []):
			if not placement is Dictionary:
				continue
			var p: Dictionary = placement as Dictionary
			var eid: String = p.get("enemy_id", "")
			var enemy_data: Dictionary = dm.get_enemy(eid)
			if enemy_data.get("is_boss", false):
				current_boss_id = eid
				break
	else:
		current_boss_id = _phase_boss_ids.get(_current_boss_phase, "")

	if current_boss_id.is_empty():
		return

	# unit_id가 "enemy_id_N" 형식이므로 enemy_id 부분만 추출하여 비교
	var died_enemy_id: String = _extract_enemy_id_from_uid(unit_id)
	if died_enemy_id != current_boss_id:
		return

	# 페이즈 전환 실행
	print("[BattleScene] 보스 %s 격파! Phase %d → Phase %d 전환" % [
		current_boss_id, _current_boss_phase, next_phase
	])
	_current_boss_phase = next_phase
	_spawn_phase_enemies(next_phase)

## uid에서 원래 enemy_id를 추출한다. uid 형식: "enemy_id_N"
## @param uid 유닛 고유 ID
## @returns 원래 enemy_id
func _extract_enemy_id_from_uid(uid: String) -> String:
	# uid 끝에서 "_숫자" 패턴을 제거 (예: "corrupted_morgan_0" → "corrupted_morgan")
	var last_underscore: int = uid.rfind("_")
	if last_underscore < 0:
		return uid
	var suffix: String = uid.substr(last_underscore + 1)
	if suffix.is_valid_int():
		return uid.substr(0, last_underscore)
	return uid

## 지정 페이즈의 적 유닛을 스폰한다.
## @param phase 스폰할 페이즈 번호
func _spawn_phase_enemies(phase: int) -> void:
	var gm: Node = get_node("/root/GameManager")
	var dm: Node = get_node("/root/DataManager")
	var map_data: Dictionary = dm.get_map(gm.current_battle_id)

	# 페이즈별 적 배열 키: "phase_2_enemies", "phase_3_enemies", ...
	var enemies_key: String = "phase_%d_enemies" % phase
	var phase_enemies: Array = map_data.get(enemies_key, [])

	if phase_enemies.is_empty():
		push_warning("[BattleScene] %s 데이터 없음" % enemies_key)
		return

	# 기존 적 중 남은 유닛 수를 카운트 (스폰 인덱스 충돌 방지)
	var spawn_offset: int = _battle_map.get_units_by_team("enemy").size()

	for i: int in range(phase_enemies.size()):
		var placement: Variant = phase_enemies[i]
		if not placement is Dictionary:
			continue
		var p: Dictionary = placement as Dictionary
		var enemy_id: String = p.get("enemy_id", "")
		var enemy_level: int = p.get("level", 1)
		var pos: Array = p.get("position", [0, 0])
		var spawn_cell := Vector2i(int(pos[0]), int(pos[1]))

		var enemy_data: Dictionary = dm.get_enemy(enemy_id)
		if enemy_data.is_empty():
			push_warning("[BattleScene] Phase %d 적 데이터 없음: %s" % [phase, enemy_id])
			continue

		# 고유 유닛 ID 생성 (기존 유닛과 충돌 방지)
		var uid: String = "%s_%d" % [enemy_id, spawn_offset + i]
		_battle_map.spawn_unit(enemy_data, spawn_cell, "enemy", uid, enemy_level)
		print("[BattleScene] Phase %d 적 스폰: %s (lv%d) at %s" % [
			phase, enemy_id, enemy_level, str(spawn_cell)
		])

	# 승리 조건은 이미 최종 보스(ascended_morgan)로 설정되어 있으므로
	# VCC를 다시 설정할 필요 없음 — boss_kill target_unit이 최종 보스를 가리킴
	print("[BattleScene] Phase %d 적 스폰 완료 (%d체)" % [phase, phase_enemies.size()])

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

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

## 전투 결과 확인 (승리)
func _on_result_confirmed() -> void:
	# 진행도 갱신
	var gm: Node = get_node("/root/GameManager")
	var prog: Node = get_node("/root/ProgressionManager")
	prog.complete_node(gm.current_scene_id)
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

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

## @fileoverview 전투 씬 오케스트레이터. BattleMap, TurnManager, BattleHUD,
## DeploymentScreen, BattleResult, SkillExecutor를 조합하고
## 의존성을 주입한 뒤 전투 플로우를 진행한다.
extends Node

# ── 노드 참조 ──

## 전투 맵 (서브씬 인스턴스)
var _battle_map: Node2D = null

## 턴 매니저
var _turn_manager: TurnManager = null

## 전투 HUD
var _battle_hud: BattleHUD = null

## 배치 화면
var _deployment: DeploymentScreen = null

## 전투 결과 화면
var _battle_result: BattleResult = null

## 스킬 연출기
var _skill_executor: SkillExecutor = null

# ── 초기화 ──

func _ready() -> void:
	# 자식 노드 참조 취득
	_battle_map = $BattleMap
	_turn_manager = $TurnManager
	_battle_hud = $BattleHUD
	_deployment = $DeploymentScreen
	_battle_result = $BattleResult
	_skill_executor = $SkillExecutor

	# 의존성 주입
	_turn_manager.battle_map = _battle_map
	_turn_manager.connect_battle_map()
	_battle_hud.battle_map = _battle_map
	# SkillExecutor는 _ready()에서 자동 초기화 (CutinOverlay, VfxPlayer 자동 생성)

	# 시그널 연결
	_deployment.deployment_finished.connect(_on_deployment_finished)
	_deployment.deployment_cancelled.connect(_on_deployment_cancelled)
	_battle_result.result_confirmed.connect(_on_result_confirmed)
	_battle_result.retry_requested.connect(_on_retry_requested)
	_battle_result.return_to_map.connect(_on_return_to_map)

	# 전투 데이터 로드 및 배치 화면 시작
	_start_battle()

# ── 전투 플로우 ──

## 전투 데이터를 로드하고 배치 단계를 시작한다.
func _start_battle() -> void:
	var gm: Node = get_node("/root/GameManager")
	var battle_id: String = gm.current_battle_id

	if battle_id.is_empty():
		push_error("[BattleScene] battle_id가 비어있음")
		_return_to_world_map()
		return

	print("[BattleScene] 전투 시작: %s" % battle_id)

	# 맵 로드
	_battle_map.load_map(battle_id)

	# 배치 화면 초기화
	var dm: Node = get_node("/root/DataManager")
	var map_data: Dictionary = dm.get_map(battle_id)
	var deploy_cells: Array[Vector2i] = []
	for cell_arr in map_data.get("deploy_cells", []):
		if cell_arr is Array and cell_arr.size() >= 2:
			deploy_cells.append(Vector2i(int(cell_arr[0]), int(cell_arr[1])))

	var pm: Node = get_node("/root/PartyManager")
	var party: Array[Dictionary] = pm.get_active_party_data() if pm.has_method("get_active_party_data") else []
	var deploy_limit: int = map_data.get("deploy_count", 8)

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

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

## @fileoverview 배치 화면 → 전투 시작 흐름 인터랙션 테스트.
## 배치 완료 후 BattleHUD 표시, TurnManager 플레이어 턴 진입을 검증한다.
extends GdUnitTestSuite

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const STABILIZE_FRAMES := 90
const PLAYER_TURN_TIMEOUT := 200

func _setup_battle_state() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.flags.clear()
	gm.difficulty = "normal"
	gm.current_scene_id = "1-3"
	gm.current_battle_id = "battle_01"
	var pm: Node = get_node("/root/PartyManager")
	if pm.has_method("init_default_party"):
		pm.init_default_party()

# ── 테스트: 배치 화면 초기 상태 ──

## 배틀 씬 진입 시 배치 화면이 표시되고 BattleHUD는 숨겨진다.
func test_deployment_screen_visible_on_start() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var deploy: Node = scene.get_node_or_null("DeploymentScreen")
	var hud: Node = scene.get_node_or_null("BattleHUD")

	assert_object(deploy).is_not_null()
	assert_object(hud).is_not_null()

	assert_bool(deploy.visible).is_true()
	assert_bool(hud.visible).is_false()

# ── 테스트: 전투 시작 후 씬 전환 ──

## 전투 시작 버튼 누름 후 배치 화면 숨김 + BattleHUD 표시 확인.
func test_hud_shown_after_battle_start() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var deploy: Node = scene.get_node_or_null("DeploymentScreen")
	var hud: Node = scene.get_node_or_null("BattleHUD")

	deploy._on_start_pressed()
	await runner.simulate_frames(30)

	assert_bool(deploy.visible).is_false()
	assert_bool(hud.visible).is_true()

# ── 테스트: 플레이어 턴 진입 ──

## 전투 시작 후 TurnManager가 player phase/IDLE 상태가 되어야 한다.
func test_player_turn_after_battle_start() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var deploy: Node = scene.get_node_or_null("DeploymentScreen")
	var tm: Node = scene.get_node_or_null("TurnManager")

	deploy._on_start_pressed()

	# 플레이어 턴 대기
	var elapsed := 0
	while elapsed < PLAYER_TURN_TIMEOUT:
		await runner.simulate_frames(10)
		elapsed += 10
		if str(tm.current_phase) == "player":
			break

	assert_str(str(tm.current_phase)).is_equal("player")

# ── 테스트: 배치된 유닛이 맵에 존재 ──

## 전투 시작 후 플레이어 유닛이 BattleMap에 배치되어 있어야 한다.
func test_player_units_exist_after_start() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var deploy: Node = scene.get_node_or_null("DeploymentScreen")
	var bm: Node = scene.get_node_or_null("BattleMap")

	deploy._on_start_pressed()
	await runner.simulate_frames(PLAYER_TURN_TIMEOUT)

	assert_object(bm).is_not_null()
	var player_units: Array = bm.get_units_by_team("player")
	assert_bool(player_units.is_empty()).is_false()

	# 카엘은 반드시 존재
	var has_kael := false
	for u in player_units:
		if u.unit_id == "kael":
			has_kael = true
			break
	assert_bool(has_kael).is_true()

## @fileoverview 전투 입력 처리 인터랙션 테스트.
## 전투 시작 후 클릭이 정상 전달되는지, mouse_filter 설정이 올바른지 검증한다.
## gdUnit4 GdUnitTestSuite 기반.
extends GdUnitTestSuite

# ── 상수 ──

## 배틀 씬 경로
const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
## GameManager 초기화용 배틀 ID
const TEST_BATTLE_ID := "battle_01"
## 씬 로딩 안정화 대기 프레임
const STABILIZE_FRAMES := 90
## 플레이어 턴 대기 최대 프레임
const PLAYER_TURN_TIMEOUT := 200

# ── 헬퍼 ──

## GameManager와 PartyManager를 배틀 진입 상태로 초기화한다.
func _setup_battle_state() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.flags.clear()
	gm.difficulty = "normal"
	gm.current_scene_id = "1-3"
	gm.current_battle_id = TEST_BATTLE_ID
	var pm: Node = get_node("/root/PartyManager")
	if pm.has_method("init_default_party"):
		pm.init_default_party()

# ── 테스트: mouse_filter 회귀 ──

## BattleHUD의 _minimap_dots가 MOUSE_FILTER_IGNORE인지 검증한다.
## 이전에 MOUSE_FILTER_STOP(기본값)으로 전체 화면 입력을 차단하던 버그 회귀 방지.
func test_minimap_dots_mouse_filter() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	# BattleHUD 노드 접근
	var scene: Node = runner.scene()
	var hud: Node = scene.get_node_or_null("BattleHUD")
	assert_object(hud).is_not_null()

	# _minimap_dots는 private이므로 get 프로퍼티로 접근
	var dots = hud.get("_minimap_dots")
	assert_object(dots).is_not_null()

	# MOUSE_FILTER_IGNORE(2)여야 입력을 통과시킨다
	assert_int(dots.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

# ── 테스트: 전투 시작 후 클릭 처리 ──

## 배치 화면 → 전투 시작 후 맵 클릭이 TurnManager에 전달되는지 검증한다.
## mouse_filter 버그가 재현될 경우 TurnManager 상태가 변하지 않는다.
func test_battle_click_after_start() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var deploy = scene.get_node_or_null("DeploymentScreen")
	var tm: Node = scene.get_node_or_null("TurnManager")
	assert_object(deploy).is_not_null()
	assert_object(tm).is_not_null()

	# 전투 시작 (내부 메서드 직접 호출 — deployment_finished 시그널 발신)
	deploy._on_start_pressed()
	await runner.simulate_frames(PLAYER_TURN_TIMEOUT)

	# 플레이어 턴 진입 확인
	assert_str(str(tm.current_phase)).is_equal("player")

	# 플레이어 유닛 위치로 클릭 시뮬레이션
	var bm: Node = scene.get_node_or_null("BattleMap")
	assert_object(bm).is_not_null()

	var player_units: Array = bm.get_units_by_team("player")
	assert_bool(player_units.is_empty()).is_false()

	var kael: Node = null
	for u in player_units:
		if u.unit_id == "kael":
			kael = u
			break
	assert_object(kael).is_not_null()

	# TurnManager 초기 상태 저장
	var state_before = tm._state

	# 카엘 셀 위치를 월드 좌표로 변환하여 클릭
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT, kael.global_position)
	await runner.simulate_frames(10)

	# 상태가 변해야 한다 (IDLE → UNIT_SELECTED 등)
	# 같은 상태라면 클릭이 차단된 것
	assert_int(tm._state).is_not_equal(int(state_before))

# ── 테스트: BattleHUD Control 레이어 mouse_filter 전수 검사 ──

## BattleHUD 하위의 전체 화면 크기 Control이 STOP이면 입력을 차단한다.
## 새로 추가되는 Control 노드에도 동일한 문제가 발생하지 않도록 검증한다.
func test_no_fullscreen_control_with_mouse_stop() -> void:
	_setup_battle_state()
	var runner := scene_runner(BATTLE_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var hud: Node = scene.get_node_or_null("BattleHUD")
	assert_object(hud).is_not_null()

	# HUD 하위 모든 Control을 순회하여 전체 화면 + STOP 조합 탐색
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var blocking_nodes: Array[String] = []
	_check_blocking_controls(hud, viewport_size, blocking_nodes)

	# 차단 노드가 없어야 한다
	if not blocking_nodes.is_empty():
		assert_failure(
			"전체 화면을 차단하는 MOUSE_FILTER_STOP Control 발견:\n" + "\n".join(blocking_nodes)
		)

## Control 노드를 재귀 순회하여 전체 화면 차단 후보를 수집한다.
## @param node 검사할 노드
## @param vp_size 뷰포트 크기
## @param out 차단 노드 이름 목록 (출력)
func _check_blocking_controls(node: Node, vp_size: Vector2, out: Array[String]) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP:
			var rect: Rect2 = ctrl.get_global_rect()
			# 뷰포트의 50% 이상을 커버하면 잠재적 차단
			var coverage: float = (rect.size.x * rect.size.y) / (vp_size.x * vp_size.y)
			if coverage > 0.5:
				out.append("  %s (coverage %.0f%%)" % [node.get_path(), coverage * 100.0])
	for child in node.get_children():
		_check_blocking_controls(child, vp_size, out)

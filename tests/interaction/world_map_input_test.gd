## @fileoverview 월드맵 입력 처리 인터랙션 테스트.
## 월드맵 노드 클릭 응답, 씬 전환 트리거를 검증한다.
extends GdUnitTestSuite

const WORLD_MAP_SCENE := "res://scenes/world/world_map.tscn"
const STABILIZE_FRAMES := 60

func _setup_new_game() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.flags.clear()
	gm.difficulty = "normal"
	gm.current_scene_id = "1-1"
	gm.play_time = 0.0
	var pm: Node = get_node("/root/PartyManager")
	if pm.has_method("init_default_party"):
		pm.init_default_party()

# ── 테스트: 월드맵 로딩 ──

## 월드맵 씬이 정상 로딩되고 맵 노드가 존재한다.
func test_world_map_loads() -> void:
	_setup_new_game()
	var runner := scene_runner(WORLD_MAP_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	assert_object(scene).is_not_null()

	# WorldMap 또는 하위 맵 컨테이너가 있어야 한다
	var has_map_node := (
		scene.get_node_or_null("WorldMap") != null
		or scene.get_node_or_null("Map") != null
		or scene.get_node_or_null("MapContainer") != null
		or scene.get_node_or_null("MapView") != null
	)
	assert_bool(has_map_node).is_true()

# ── 테스트: 월드맵 Control 입력 차단 없음 ──

## 월드맵의 전체 화면 MOUSE_FILTER_STOP Control이 없는지 검증.
## 배틀 씬과 동일한 유형의 입력 차단 버그 예방.
func test_no_blocking_controls_on_world_map() -> void:
	_setup_new_game()
	var runner := scene_runner(WORLD_MAP_SCENE)
	await runner.simulate_frames(STABILIZE_FRAMES)

	var scene: Node = runner.scene()
	var viewport_size: Vector2 = scene.get_viewport().get_visible_rect().size
	var blocking_nodes: Array[String] = []
	_check_blocking_controls(scene, viewport_size, blocking_nodes)

	if not blocking_nodes.is_empty():
		assert_failure(
			"월드맵에서 전체 화면을 차단하는 Control 발견:\n" + "\n".join(blocking_nodes)
		)

func _check_blocking_controls(node: Node, vp_size: Vector2, out: Array[String]) -> void:
	if node is Control:
		var ctrl := node as Control
		if ctrl.mouse_filter == Control.MOUSE_FILTER_STOP and ctrl.visible:
			var rect: Rect2 = ctrl.get_global_rect()
			var coverage: float = (rect.size.x * rect.size.y) / (vp_size.x * vp_size.y)
			if coverage > 0.5:
				out.append("  %s (coverage %.0f%%)" % [node.get_path(), coverage * 100.0])
	for child in node.get_children():
		_check_blocking_controls(child, vp_size, out)

## @fileoverview 전투 GIF 캡처 오토플레이 오토로드.
## 배치 화면 건너뜀 → 전투 시작 → 카엘 이동 → 공격 장면을 PNG 프레임으로 저장한다.
## run_battle_gif.js가 이 스크립트를 임시 autoload로 등록하여 실행한다.
extends Node

# ── 상수 ──

## PNG 프레임 저장 디렉토리
const CAPTURE_DIR := "res://tests/gif_capture/frames"

## 최대 실행 프레임 (안전 타임아웃)
const MAX_FRAMES := 900

# ── 내부 상태 ──

## 저장된 프레임 수
var _frames_captured: int = 0

## _process에서 매 프레임 캡처 여부
var _is_capturing: bool = false

## 안전 타임아웃 카운터
var _total_frames: int = 0

func _ready() -> void:
	# 프레임 저장 디렉토리 초기화
	var abs_dir := ProjectSettings.globalize_path(CAPTURE_DIR)
	DirAccess.make_dir_recursive_absolute(abs_dir)
	# 기존 PNG 제거
	var da := DirAccess.open(abs_dir)
	if da:
		da.list_dir_begin()
		var f := da.get_next()
		while f != "":
			if f.ends_with(".png"):
				da.remove(f)
			f = da.get_next()
		da.list_dir_end()
	print("[GifCapture] 프레임 디렉토리: %s" % abs_dir)
	# 코루틴 시작
	_run.call_deferred()

func _process(_delta: float) -> void:
	_total_frames += 1
	if _total_frames > MAX_FRAMES:
		print("[GifCapture] 타임아웃 — 강제 종료")
		get_tree().quit(1)
	if _is_capturing:
		_save_frame()

# ── 캡처 헬퍼 ──

## 현재 뷰포트를 PNG로 저장한다.
func _save_frame() -> void:
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(
		"%s/frame_%04d.png" % [CAPTURE_DIR, _frames_captured]
	)
	img.save_png(path)
	_frames_captured += 1

# ── 메인 코루틴 ──

## 전투 오토플레이 및 프레임 캡처를 순차 실행한다.
func _run() -> void:
	# 1. GameManager/PartyManager 초기화
	_setup_battle()

	# 2. 배틀 씬 전환
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")

	# 3. 씬 로딩 대기 (60프레임)
	for _i in 60:
		await get_tree().process_frame

	var scene := get_tree().current_scene
	if scene == null or not scene.has_node("DeploymentScreen"):
		push_error("[GifCapture] battle_scene 로딩 실패")
		get_tree().quit(1)
		return

	var deploy: DeploymentScreen = scene.get_node("DeploymentScreen") as DeploymentScreen
	var tm: TurnManager       = scene.get_node("TurnManager")       as TurnManager
	var bm                    = scene.get_node("BattleMap")  # 타입 어노테이션 없이 동적 접근

	if deploy == null or tm == null or bm == null:
		push_error("[GifCapture] 필수 노드 없음 (deploy=%s tm=%s bm=%s)" % [deploy, tm, bm])
		get_tree().quit(1)
		return

	# 4. 파티원 추가 배치 (카엘 외 1명까지)
	_deploy_extra_party(deploy)
	await get_tree().process_frame

	# 5. 배치 화면 닫고 전투 시작
	print("[GifCapture] 전투 시작 버튼 클릭")
	deploy._on_start_pressed()

	# 6. 플레이어 턴 대기
	for _i in 150:
		await get_tree().process_frame
		if tm.current_phase == "player" and tm._state == TurnManager.TurnState.IDLE:
			break

	if tm.current_phase != "player":
		push_error("[GifCapture] 플레이어 턴 대기 타임아웃 (현재: %s)" % tm.current_phase)
		get_tree().quit(1)
		return

	print("[GifCapture] 플레이어 턴 시작 확인")

	# 7. 카엘 유닛 찾기
	var player_units := bm.get_units_by_team("player") as Array
	var kael: BattleUnit = null
	for u in player_units:
		if (u as BattleUnit).unit_id == "kael":
			kael = u as BattleUnit
			break

	if kael == null:
		push_error("[GifCapture] 카엘 유닛 없음")
		get_tree().quit(1)
		return

	# 8. 가장 가까운 적 유닛 찾기
	var enemy_units := bm.get_units_by_team("enemy") as Array
	if enemy_units.is_empty():
		push_error("[GifCapture] 적 유닛 없음")
		get_tree().quit(1)
		return

	var target: BattleUnit = enemy_units[0] as BattleUnit
	var min_dist := 9999
	for e in enemy_units:
		var eu := e as BattleUnit
		var d := absi(eu.cell.x - kael.cell.x) + absi(eu.cell.y - kael.cell.y)
		if d < min_dist:
			min_dist = d
			target = eu

	print("[GifCapture] 카엘: %s, 타겟: %s (거리: %d)" % [kael.cell, target.cell, min_dist])

	# 9. 캡처 시작 — 이후 매 프레임 저장
	_is_capturing = true

	# 10. 카엘 선택
	tm._on_unit_clicked(kael)
	for _i in 5:
		await get_tree().process_frame

	# 11. 이동이 필요하면 적 인접 셀로 이동
	var already_adjacent := (min_dist == 1)
	if not already_adjacent:
		var adj_candidates := [
			Vector2i(target.cell.x + 1, target.cell.y),
			Vector2i(target.cell.x - 1, target.cell.y),
			Vector2i(target.cell.x,     target.cell.y + 1),
			Vector2i(target.cell.x,     target.cell.y - 1),
		]
		var move_target := Vector2i(-1, -1)
		for adj in adj_candidates:
			if tm._move_cells.has(adj):
				move_target = adj
				break

		if move_target != Vector2i(-1, -1):
			print("[GifCapture] %s → %s 이동" % [kael.cell, move_target])
			tm._on_cell_clicked(move_target)
			# 이동 애니메이션 완료 대기
			await kael.move_finished
			print("[GifCapture] 이동 완료")
			for _i in 10:
				await get_tree().process_frame
		else:
			print("[GifCapture] 이동 가능 인접 셀 없음 — 이동 생략")
			# 이동 없이 행동 메뉴 직접 표시
			tm._state = TurnManager.TurnState.UNIT_MOVED
			tm._show_action_menu()

	# 12. 행동 메뉴 → 공격 선택
	print("[GifCapture] 공격 선택")
	tm._on_action_menu_pressed("attack")
	for _i in 5:
		await get_tree().process_frame

	# 13. 공격 실행 (이제 코루틴으로 애니메이션 포함)
	print("[GifCapture] 공격 실행 → %s" % target.unit_id)
	tm._execute_attack(kael, target)

	# 14. 공격 + 피격/사망 + 반격 애니메이션이 모두 끝날 때까지 캡처
	# 최대 3.5초(210프레임@60fps) — attack(0.75s) + hit/death(0.75s) + counterattack(0.75s) + 여유
	for _i in 180:
		await get_tree().process_frame

	# 15. 종료
	_is_capturing = false
	print("[GifCapture] 캡처 완료: %d 프레임" % _frames_captured)
	get_tree().quit(0)

# ── 배치 헬퍼 ──

## 카엘 외 파티원을 두 번째 배치 셀부터 배치한다 (최대 1명).
## @param deploy DeploymentScreen 인스턴스
func _deploy_extra_party(deploy: DeploymentScreen) -> void:
	var deploy_cells: Array = deploy._deploy_cells
	var party: Array       = deploy._party_characters
	var deployed: Dictionary = deploy._deployed

	var slot_idx := 0
	# 카엘이 차지하는 셀 건너뛰기 위해 배치된 셀 확인
	for char_data in party:
		if char_data.get("id", "") == "kael":
			continue
		# 빈 배치 셀 찾기
		while slot_idx < deploy_cells.size():
			var cell: Vector2i = deploy_cells[slot_idx]
			slot_idx += 1
			if not deployed.has(cell):
				print("[GifCapture] 추가 배치: %s → %s" % [char_data.get("id", "?"), cell])
				deploy._place_unit(char_data, cell)
				break
		# 1명만 추가 배치
		break

# ── GameManager 초기화 ──

## battle_01 전투 진입을 위해 GameManager/PartyManager를 초기화한다.
func _setup_battle() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.flags.clear()
	gm.difficulty = "normal"
	gm.current_scene_id = "1-3"
	gm.current_battle_id = "battle_01"
	var pm: Node = get_node("/root/PartyManager")
	if pm.has_method("init_default_party"):
		pm.init_default_party()
	print("[GifCapture] GameManager 초기화 완료 (battle_01)")

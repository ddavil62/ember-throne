## @fileoverview 턴 매니저. 페이즈 순환(player→enemy→npc), 유닛 선택, 행동 FSM,
## 전투 연출 트리거, 반격 처리, 전투 종료 판정을 관리한다.
class_name TurnManager
extends Node

# ── 상수 ──

## 페이즈 순서
const PHASE_ORDER: Array[String] = ["player", "enemy", "npc"]

## 지형 효과 - 인접 아군 HP 회복률 (결계석)
const BARRIER_STONE_HEAL_RATIO: float = 0.05

## 지형 효과 - HP 감소율 (재의 땅)
const ASHEN_LAND_DAMAGE_RATIO: float = 0.05

## 지형 효과 - HP 회복률 (마을)
const VILLAGE_HEAL_RATIO: float = 0.03

## 지형 효과 - 인접 유닛 HP 감소율 (용암)
const LAVA_DAMAGE_RATIO: float = 0.10

## 행동 메뉴 버튼 크기
const ACTION_BUTTON_SIZE: Vector2 = Vector2(120, 36)

# ── 열거형 ──

## 턴 FSM 상태
enum TurnState {
	IDLE,              ## 유닛 선택 대기
	UNIT_SELECTED,     ## 유닛 선택됨 — 이동 범위 표시 중
	UNIT_MOVED,        ## 유닛 이동 완료 — 행동 메뉴 표시
	TARGET_SELECT,     ## 공격/스킬 대상 선택 중
	ACTION_EXECUTE,    ## 전투 연출 + 데미지 계산 진행 중
	ACTION_COMPLETE,   ## 유닛 행동 완료 처리 중
	PHASE_END,         ## 페이즈 종료 처리 중
	BATTLE_END,        ## 전투 종료
}

# ── 시그널 ──

## 행동 메뉴 항목 선택 시
signal action_menu_selected(action: String)

# ── 멤버 변수 ──

## BattleMap 참조 (외부에서 주입)
var battle_map: Node2D = null

## 전투 계산기
var combat_calc: CombatCalculator = CombatCalculator.new()

## 경험치 시스템
var exp_system: ExperienceSystem = ExperienceSystem.new()

## 현재 페이즈 ("player" / "enemy" / "npc")
var current_phase: String = "player"

## 현재 턴 번호
var turn_number: int = 0

## FSM 현재 상태
var _state: TurnState = TurnState.IDLE

## 현재 선택된 유닛
var _selected_unit: BattleUnit = null

## 이동 가능 셀 목록
var _move_cells: Array[Vector2i] = []

## 공격 가능 셀 목록
var _attack_cells: Array[Vector2i] = []

## 유닛의 이동 전 원래 위치 (되돌리기용)
var _original_cell: Vector2i = Vector2i.ZERO

## 유닛이 실제로 이동했는지 여부 (되돌리기 가능 판정용)
var _has_moved: bool = false

## 행동 메뉴 CanvasLayer 참조
var _action_menu_layer: CanvasLayer = null

## 행동 메뉴 컨테이너
var _action_menu_container: VBoxContainer = null

## 이번 전투에서 각 유닛이 획득한 EXP 누적 {unit_id: int}
var _battle_exp_gained: Dictionary = {}

## 이번 전투에서 적 처치로 누적된 골드
var _battle_gold_gained: int = 0

## 이번 전투에서 사망한 플레이어 유닛 ID 추적 (벤치 EXP 제외용)
var _battle_dead_player_ids: Dictionary = {}

## 승리/패배 조건 판별기
var _vcc: VictoryConditionChecker = null

# ── 초기화 ──

func _ready() -> void:
	_create_action_menu()

	# VCC 생성 및 자식 노드로 추가
	_vcc = VictoryConditionChecker.new()
	_vcc.name = "VictoryConditionChecker"
	add_child(_vcc)
	_vcc.victory_achieved.connect(_on_victory_achieved)
	_vcc.defeat_achieved.connect(_on_defeat_achieved)

	# 사망 유닛 추적 (벤치 EXP 오지급 방지)
	EventBus.unit_died.connect(_on_unit_died_for_exp_tracking)

## 입력 처리 — 행동 메뉴 표시 중 취소 키로 이동 되돌리기
func _unhandled_input(event: InputEvent) -> void:
	if _state == TurnState.UNIT_MOVED and event.is_action_pressed("ui_cancel"):
		if _has_moved:
			_hide_action_menu()
			_undo_move()
			get_viewport().set_input_as_handled()

## BattleMap 시그널을 연결한다. battle_map 주입 후 호출해야 한다.
func connect_battle_map() -> void:
	if battle_map == null:
		push_error("[TurnManager] battle_map이 설정되지 않았다")
		return
	battle_map.unit_clicked.connect(_on_unit_clicked)
	battle_map.cell_clicked.connect(_on_cell_clicked)

# ── 전투 시작/종료 ──

## 전투를 시작한다 (1턴 player 페이즈부터)
func start_battle() -> void:
	turn_number = 1
	_battle_exp_gained.clear()
	_battle_gold_gained = 0
	_battle_dead_player_ids.clear()

	# VCC 초기화 — 맵 데이터에서 승리/패배 조건 로드
	if _vcc and battle_map:
		var map_data: Dictionary = battle_map.get_map_data()
		_vcc.setup(map_data, battle_map)

	_start_phase("player")

## 페이즈를 시작한다
## @param phase 시작할 페이즈 ("player" / "enemy" / "npc")
func _start_phase(phase: String) -> void:
	current_phase = phase
	_state = TurnState.IDLE
	_selected_unit = null

	# 해당 팀 유닛 턴 리셋
	if battle_map:
		battle_map.reset_units_turn(phase)

	# 지형 효과 적용
	_apply_terrain_effects(phase)

	# 상태이상 턴 차감 및 효과 (reset_turn에서 이미 처리됨)
	_apply_status_effects(phase)

	# 시그널 발신
	EventBus.turn_started.emit(phase, turn_number)
	print("[TurnManager] 턴 %d - %s 페이즈 시작" % [turn_number, phase])

	# 적/NPC 페이즈면 AI 행동 시작
	if phase == "enemy" or phase == "npc":
		_execute_ai_phase(phase)

## 페이즈를 종료하고 다음 페이즈 또는 다음 턴으로 넘어간다
func _end_phase() -> void:
	EventBus.turn_ended.emit(current_phase, turn_number)

	# 전투 종료 상태면 중단 (VCC가 이미 BATTLE_END 처리함)
	if _state == TurnState.BATTLE_END:
		return

	# 다음 페이즈 결정
	var current_idx: int = PHASE_ORDER.find(current_phase)
	var next_idx: int = current_idx + 1

	if next_idx >= PHASE_ORDER.size():
		# 모든 페이즈 완료 → 다음 턴
		turn_number += 1
		next_idx = 0

	var next_phase: String = PHASE_ORDER[next_idx]

	# NPC 페이즈는 NPC가 있을 때만
	if next_phase == "npc":
		var npc_units: Array[BattleUnit] = _get_units_by_team("npc")
		if npc_units.is_empty():
			# NPC 없으면 다음 턴으로
			turn_number += 1
			next_phase = PHASE_ORDER[0]

	_start_phase(next_phase)

# ── 입력 처리 (BattleMap 시그널) ──

## 유닛 클릭 콜백
## @param unit 클릭된 유닛
func _on_unit_clicked(unit: BattleUnit) -> void:
	match _state:
		TurnState.IDLE:
			if unit.team == current_phase and not unit.acted:
				_select_unit(unit)
			elif unit.team != current_phase and current_phase == "player":
				# 적 유닛 정보 표시 (추후 구현)
				pass
		TurnState.UNIT_SELECTED:
			if unit == _selected_unit:
				# 같은 유닛 재클릭 → 선택 해제
				_deselect_unit()
			elif unit.team == current_phase and not unit.acted:
				# 다른 아군 유닛 선택
				_deselect_unit()
				_select_unit(unit)
			elif unit.team != current_phase:
				# 적 유닛 클릭 → 이동 범위 내면 무시 (이동은 cell_clicked로)
				pass
		TurnState.TARGET_SELECT:
			# 공격 대상 선택
			if unit.team != current_phase and unit.cell in _attack_cells:
				_execute_attack(_selected_unit, unit)
		_:
			pass

## 빈 셀 클릭 콜백
## @param cell 클릭된 셀 좌표
func _on_cell_clicked(cell: Vector2i) -> void:
	match _state:
		TurnState.IDLE:
			pass  # 빈 셀 클릭 — 무시
		TurnState.UNIT_SELECTED:
			if cell in _move_cells:
				# 이동 실행
				_move_unit_to(cell)
			else:
				# 범위 밖 클릭 → 선택 해제
				_deselect_unit()
		TurnState.UNIT_MOVED:
			pass  # 행동 메뉴 표시 중 — 빈 셀 클릭 무시
		TurnState.TARGET_SELECT:
			# 범위 밖 클릭 → 대상 선택 취소, 행동 메뉴로 복귀
			if cell not in _attack_cells:
				_cancel_target_select()
		_:
			pass

# ── 유닛 선택/이동 ──

## 유닛을 선택한다 (이동 범위 표시)
## @param unit 선택할 유닛
func _select_unit(unit: BattleUnit) -> void:
	_selected_unit = unit
	_original_cell = unit.cell
	unit.show_selection()

	# 이동 범위 계산
	if battle_map and battle_map.grid:
		_move_cells = battle_map.grid.get_movement_range(
			unit.cell, unit.stats.get("mov", 0), unit.team
		)
		battle_map.show_movement_range(_move_cells)

		# 공격 범위도 미리 계산 (무기 사거리)
		var weapon_data: Dictionary = _get_unit_weapon_data(unit)
		var range_min: int = weapon_data.get("range_min", 1)
		var range_max: int = weapon_data.get("range_max", 1)
		_attack_cells = battle_map.grid.get_attack_range(unit.cell, range_min, range_max)

	_state = TurnState.UNIT_SELECTED
	EventBus.unit_selected.emit(unit.unit_id)

## 유닛 선택을 해제한다
func _deselect_unit() -> void:
	if _selected_unit:
		_selected_unit.hide_selection()
	_selected_unit = null
	_move_cells.clear()
	_attack_cells.clear()
	_has_moved = false
	if battle_map:
		battle_map.clear_highlights()
	_state = TurnState.IDLE
	EventBus.unit_deselected.emit()

## 유닛을 지정 셀로 이동시킨다
## @param target_cell 목표 셀
func _move_unit_to(target_cell: Vector2i) -> void:
	if _selected_unit == null or battle_map == null:
		return

	_state = TurnState.ACTION_EXECUTE  # 이동 중 입력 차단

	# 경로 탐색
	var path: Array[Vector2i] = battle_map.grid.find_path(
		_selected_unit.cell, target_cell,
		_selected_unit.stats.get("mov", 0), _selected_unit.team
	)

	if path.is_empty():
		_state = TurnState.UNIT_SELECTED
		return

	# BattleMap 유닛 매핑 갱신
	battle_map.move_unit(_selected_unit.cell, target_cell)

	# 유닛 이동 애니메이션
	_selected_unit.move_to(target_cell, path)
	await _selected_unit.move_finished

	# 이동 완료 플래그
	_has_moved = (_original_cell != target_cell)

	# 이동 시그널
	EventBus.unit_moved.emit(_selected_unit.unit_id, _original_cell, target_cell)

	# 하이라이트 정리
	battle_map.clear_highlights()

	# 행동 메뉴 표시
	_state = TurnState.UNIT_MOVED
	_show_action_menu()

# ── 행동 메뉴 ──

## 행동 메뉴를 생성한다 (CanvasLayer + VBoxContainer)
func _create_action_menu() -> void:
	_action_menu_layer = CanvasLayer.new()
	_action_menu_layer.layer = 50
	_action_menu_layer.visible = false
	add_child(_action_menu_layer)

	# 반투명 배경 패널
	var panel := PanelContainer.new()
	panel.name = "ActionPanel"
	panel.anchors_preset = Control.PRESET_CENTER
	panel.position = Vector2(-70, -80)
	_action_menu_layer.add_child(panel)

	_action_menu_container = VBoxContainer.new()
	_action_menu_container.name = "ButtonContainer"
	panel.add_child(_action_menu_container)

## 행동 메뉴를 표시한다 (공격, 스킬, 아이템, 대기)
func _show_action_menu() -> void:
	# 기존 버튼 제거
	for child: Node in _action_menu_container.get_children():
		child.queue_free()

	# 행동 버튼 추가
	var actions: Array[Dictionary] = [
		{"id": "attack", "label": "공격"},
		{"id": "skill", "label": "스킬"},
		{"id": "item", "label": "아이템"},
		{"id": "wait", "label": "대기"},
	]

	# 이동한 경우에만 되돌리기 버튼 추가
	if _has_moved:
		actions.append({"id": "undo_move", "label": "되돌리기"})

	for action_info: Dictionary in actions:
		var btn := Button.new()
		btn.text = action_info["label"]
		btn.custom_minimum_size = ACTION_BUTTON_SIZE
		var action_id: String = action_info["id"]
		btn.pressed.connect(_on_action_menu_pressed.bind(action_id))
		_action_menu_container.add_child(btn)

	_action_menu_layer.visible = true

## 행동 메뉴를 숨긴다
func _hide_action_menu() -> void:
	_action_menu_layer.visible = false

## 행동 메뉴 버튼 클릭 콜백
## @param action 선택된 행동 ID ("attack", "skill", "item", "wait")
func _on_action_menu_pressed(action: String) -> void:
	_hide_action_menu()

	match action:
		"attack":
			_enter_target_select()
		"skill":
			# 스킬 선택은 추후 Phase에서 구현
			# 현재는 공격과 동일하게 대상 선택으로 진입
			_enter_target_select()
		"item":
			# 아이템 사용은 추후 Phase에서 구현
			# 현재는 대기 처리
			_execute_wait()
		"wait":
			_execute_wait()
		"undo_move":
			_undo_move()

# ── 대상 선택 ──

## 공격 대상 선택 모드 진입
func _enter_target_select() -> void:
	if _selected_unit == null or battle_map == null:
		return

	# 현재 위치 기준 공격 범위 재계산
	var weapon_data: Dictionary = _get_unit_weapon_data(_selected_unit)
	var range_min: int = weapon_data.get("range_min", 1)
	var range_max: int = weapon_data.get("range_max", 1)
	_attack_cells = battle_map.grid.get_attack_range(_selected_unit.cell, range_min, range_max)

	# 공격 범위 하이라이트
	battle_map.show_attack_range(_attack_cells)

	_state = TurnState.TARGET_SELECT

## 대상 선택 취소 → 행동 메뉴로 복귀
func _cancel_target_select() -> void:
	if battle_map:
		battle_map.clear_highlights()
	_state = TurnState.UNIT_MOVED
	_show_action_menu()

# ── 이동 되돌리기 ──

## 유닛의 이동을 되돌리고 원래 위치로 복귀시킨다.
## 행동(공격/스킬/아이템/대기)을 확정하기 전에만 가능하다.
func _undo_move() -> void:
	if _selected_unit == null or battle_map == null:
		return
	if not _has_moved:
		return

	var current_cell: Vector2i = _selected_unit.cell

	# BattleMap 유닛 매핑을 원래 위치로 복원
	battle_map.move_unit(current_cell, _original_cell)

	# 유닛 위치를 즉시 원래 셀로 이동 (애니메이션 없이)
	_selected_unit.cell = _original_cell
	_selected_unit.position = GridSystem.cell_to_world(_original_cell)

	# idle 애니메이션 복귀
	if _selected_unit._sprite and _selected_unit._sprite.sprite_frames:
		var idle_anim := "idle_%s" % _selected_unit.facing
		if _selected_unit._sprite.sprite_frames.has_animation(idle_anim):
			_selected_unit._sprite.play(idle_anim)

	_has_moved = false

	# 시그널 발신
	EventBus.unit_move_undone.emit(_selected_unit.unit_id, current_cell, _original_cell)

	# 하이라이트 정리 후 이동 범위 재표시, UNIT_SELECTED 상태로 복귀
	battle_map.clear_highlights()

	# 이동 범위 재계산 및 표시
	if battle_map.grid:
		_move_cells = battle_map.grid.get_movement_range(
			_selected_unit.cell, _selected_unit.stats.get("mov", 0), _selected_unit.team
		)
		battle_map.show_movement_range(_move_cells)

	_state = TurnState.UNIT_SELECTED
	print("[TurnManager] %s 이동 되돌리기: (%d,%d) → (%d,%d)" % [
		_selected_unit.unit_id, current_cell.x, current_cell.y,
		_original_cell.x, _original_cell.y
	])

# ── 공격 실행 ──

## 공격을 실행한다 (데미지 계산 + 애니메이션 + 반격 처리, 코루틴)
## @param attacker 공격 유닛
## @param defender 방어 유닛
func _execute_attack(attacker: BattleUnit, defender: BattleUnit) -> void:
	_state = TurnState.ACTION_EXECUTE
	if battle_map:
		battle_map.clear_highlights()

	# 공격/방어 방향 전환
	attacker.face_towards(defender.cell)
	defender.face_towards(attacker.cell)

	# 공격 애니메이션 시작 (fire-and-forget 코루틴)
	attacker.play_attack_anim()

	# 공격 히트 타이밍 대기 — 6프레임 중 3번째(중반)에 데미지 적용
	# 6frames @ 8fps → 0.75s 총 재생 / 2 = 0.375s
	await get_tree().create_timer(BattleSpeed.apply(3.0 / 8.0)).timeout

	# 물리 데미지 계산
	var result: Dictionary = combat_calc.calc_physical_damage(
		attacker, defender, 1.0, battle_map.grid
	)

	if result["hit"]:
		var damage: int = result["damage"]
		defender.take_damage(damage)
		EventBus.damage_dealt.emit(attacker.unit_id, defender.unit_id, damage, result["is_crit"])

		# 경험치 처리
		var action_exp: int = exp_system.calc_action_exp("attack", attacker.level, defender.level)
		_accumulate_exp(attacker.unit_id, action_exp)

		# 대상 사망 판정
		if not defender.is_alive():
			var kill_exp: int = exp_system.calc_kill_exp(attacker.level, defender.level)
			_accumulate_exp(attacker.unit_id, kill_exp)

			# 골드 드롭 처리
			if defender.team == "enemy":
				var gr: Dictionary = defender._source_data.get("gold_reward", {})
				var g_min: int = int(gr.get("min", 0))
				var g_max: int = int(gr.get("max", 0))
				if g_max > 0:
					_battle_gold_gained += randi_range(g_min, g_max)

			# 사망 애니메이션 완료 대기 후 유닛 제거
			await defender.play_death_anim()
			EventBus.unit_died.emit(defender.unit_id, attacker.unit_id)
			if battle_map:
				battle_map.remove_unit(defender.cell)
		else:
			# 생존 — 피격 애니메이션 (fire-and-forget)
			defender.play_hit_anim()
	else:
		# 빗나감 표시 (추후 UI 연출)
		print("[TurnManager] %s의 공격이 빗나감!" % attacker.unit_id)

	# 공격 애니메이션 나머지 완료 대기 (남은 3프레임 분)
	await get_tree().create_timer(BattleSpeed.apply(3.0 / 8.0)).timeout

	# 반격 처리 (방어자 생존 + 적중 + 사거리 내)
	if defender.is_alive() and result["hit"]:
		await _execute_counterattack(defender, attacker)

	# 행동 완료
	_complete_action()

## 반격을 실행한다 (1회, 애니메이션 포함, 코루틴)
## @param counter_attacker 반격하는 유닛 (원래 방어자)
## @param counter_target 반격 대상 (원래 공격자)
func _execute_counterattack(counter_attacker: BattleUnit, counter_target: BattleUnit) -> void:
	# 반격자의 무기 사거리 확인
	var weapon_data: Dictionary = _get_unit_weapon_data(counter_attacker)
	var range_min: int = weapon_data.get("range_min", 1)
	var range_max: int = weapon_data.get("range_max", 1)

	# 두 유닛 사이 맨해튼 거리
	var dist: int = absi(counter_attacker.cell.x - counter_target.cell.x) + absi(counter_attacker.cell.y - counter_target.cell.y)
	if dist < range_min or dist > range_max:
		return  # 사거리 밖 — 반격 불가

	# 반격 방향 전환
	counter_attacker.face_towards(counter_target.cell)
	counter_target.face_towards(counter_attacker.cell)

	# 반격 애니메이션 시작
	counter_attacker.play_attack_anim()
	await get_tree().create_timer(BattleSpeed.apply(3.0 / 8.0)).timeout

	# 반격 데미지 계산 (기본 공격, skill_mult 1.0)
	var counter_result: Dictionary = combat_calc.calc_physical_damage(
		counter_attacker, counter_target, 1.0, battle_map.grid
	)

	if counter_result["hit"]:
		var damage: int = counter_result["damage"]
		counter_target.take_damage(damage)
		EventBus.damage_dealt.emit(
			counter_attacker.unit_id, counter_target.unit_id,
			damage, counter_result["is_crit"]
		)

		# 반격으로 사망
		if not counter_target.is_alive():
			# 골드 드롭 처리 (반격으로 적 사망 시)
			if counter_target.team == "enemy":
				var gr: Dictionary = counter_target._source_data.get("gold_reward", {})
				var g_min: int = int(gr.get("min", 0))
				var g_max: int = int(gr.get("max", 0))
				if g_max > 0:
					_battle_gold_gained += randi_range(g_min, g_max)

			# 사망 애니메이션 완료 대기
			await counter_target.play_death_anim()
			EventBus.unit_died.emit(counter_target.unit_id, counter_attacker.unit_id)
			if battle_map:
				battle_map.remove_unit(counter_target.cell)
		else:
			counter_target.play_hit_anim()

	await get_tree().create_timer(BattleSpeed.apply(3.0 / 8.0)).timeout

# ── 대기 ──

## 대기 행동을 실행한다
func _execute_wait() -> void:
	_state = TurnState.ACTION_EXECUTE
	if battle_map:
		battle_map.clear_highlights()
	_complete_action()

# ── 행동 완료 ──

## 유닛 행동 완료 후 처리
func _complete_action() -> void:
	# VCC가 동기 시그널 처리 중 BATTLE_END를 설정했으면 덮어쓰지 않고 즉시 반환
	if _state == TurnState.BATTLE_END:
		return

	_state = TurnState.ACTION_COMPLETE

	if _selected_unit:
		_selected_unit.acted = true
		_selected_unit.show_acted()
		_selected_unit.hide_selection()
		EventBus.unit_action_completed.emit(_selected_unit.unit_id)

	_selected_unit = null
	_move_cells.clear()
	_attack_cells.clear()
	_has_moved = false

	# 전투 종료 상태면 중단 (VCC가 이미 BATTLE_END 처리함)
	if _state == TurnState.BATTLE_END:
		return

	# 같은 페이즈에서 행동 가능한 유닛이 남았는지 확인
	var remaining: Array[BattleUnit] = _get_actionable_units(current_phase)
	if remaining.is_empty():
		_state = TurnState.PHASE_END
		_end_phase()
	else:
		_state = TurnState.IDLE

# ── 전투 종료 판정 (VCC 콜백) ──

## VCC 승리 조건 달성 콜백
## @param condition_type 조건 타입 문자열
## @param reason_ko 한국어 결과 메시지
func _on_victory_achieved(condition_type: String, reason_ko: String) -> void:
	if _state == TurnState.BATTLE_END:
		return

	_state = TurnState.BATTLE_END
	_vcc.deactivate()

	# 경험치 적용
	_apply_battle_exp()

	# 골드 적용
	_apply_battle_gold()

	var gm: Node = _get_game_manager()
	var battle_id: String = gm.current_battle_id if gm else ""

	EventBus.battle_won.emit(battle_id)
	EventBus.battle_condition_triggered.emit(true, condition_type, reason_ko)
	print("[TurnManager] 전투 승리! 조건: %s (battle_id: %s)" % [condition_type, battle_id])

## VCC 패배 조건 달성 콜백
## @param condition_type 조건 타입 문자열
## @param reason_ko 한국어 결과 메시지
func _on_defeat_achieved(condition_type: String, reason_ko: String) -> void:
	if _state == TurnState.BATTLE_END:
		return

	_state = TurnState.BATTLE_END
	_vcc.deactivate()

	var gm: Node = _get_game_manager()
	var battle_id: String = gm.current_battle_id if gm else ""

	EventBus.battle_lost.emit(battle_id)
	EventBus.battle_condition_triggered.emit(false, condition_type, reason_ko)
	print("[TurnManager] 전투 패배! 조건: %s (battle_id: %s)" % [condition_type, battle_id])

# ── 지형 효과 ──

## 페이즈 시작 시 지형 효과를 적용한다
## @param phase 현재 페이즈
func _apply_terrain_effects(phase: String) -> void:
	if battle_map == null:
		return

	var units: Array[BattleUnit] = _get_units_by_team(phase)

	for unit: BattleUnit in units:
		if not unit.is_alive():
			continue

		var terrain_type: String = battle_map.grid.get_tile_at(unit.cell)

		match terrain_type:
			"ashen_land":
				# 재의 땅: HP 5% 감소
				var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * ASHEN_LAND_DAMAGE_RATIO), 1)
				unit.take_damage(damage)
				print("[TurnManager] %s - 재의 땅 데미지: %d" % [unit.unit_id, damage])

			"village":
				# 마을: HP 3% 회복
				var heal: int = maxi(int(float(unit.stats.get("hp", 0)) * VILLAGE_HEAL_RATIO), 1)
				unit.heal(heal)
				EventBus.heal_applied.emit("terrain", unit.unit_id, heal)

			"barrier_stone":
				# 결계석: 인접 아군 HP 5% 회복
				_apply_barrier_stone_heal(unit)

	# 용암: 인접 유닛 HP 10% 감소 (모든 유닛 대상, 페이즈 무관하게 체크)
	_apply_lava_damage()

## 결계석 인접 아군 회복 효과
## @param barrier_unit 결계석 위의 유닛
func _apply_barrier_stone_heal(barrier_unit: BattleUnit) -> void:
	if battle_map == null:
		return

	# 4방향 인접 셀 확인
	for offset: Vector2i in GridSystem.NEIGHBOR_OFFSETS:
		var adj_cell: Vector2i = barrier_unit.cell + offset
		var adj_unit: BattleUnit = battle_map.get_unit_at(adj_cell)
		if adj_unit and adj_unit.is_alive() and adj_unit.team == barrier_unit.team:
			var heal: int = maxi(int(float(adj_unit.stats.get("hp", 0)) * BARRIER_STONE_HEAL_RATIO), 1)
			adj_unit.heal(heal)
			EventBus.heal_applied.emit("barrier_stone", adj_unit.unit_id, heal)

## 용암 인접 데미지 효과 (페이즈별 1회)
func _apply_lava_damage() -> void:
	if battle_map == null or battle_map.grid == null:
		return

	# 맵 전체에서 용암 타일을 찾아 인접 유닛에 데미지
	var checked_units: Dictionary = {}  # 중복 방지

	for cell_pos: Vector2i in battle_map.units:
		var unit: BattleUnit = battle_map.units[cell_pos]
		if not unit.is_alive() or checked_units.has(unit.unit_id):
			continue

		# 이 유닛의 인접 셀에 용암이 있는지 확인
		for offset: Vector2i in GridSystem.NEIGHBOR_OFFSETS:
			var adj_cell: Vector2i = unit.cell + offset
			var adj_terrain: String = battle_map.grid.get_tile_at(adj_cell)
			if adj_terrain == "lava":
				var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * LAVA_DAMAGE_RATIO), 1)
				unit.take_damage(damage)
				checked_units[unit.unit_id] = true
				print("[TurnManager] %s - 용암 인접 데미지: %d" % [unit.unit_id, damage])
				break  # 한 유닛에 1회만

# ── 상태이상 ──

## 페이즈 시작 시 상태이상 효과를 적용한다 (턴 차감은 BattleUnit.reset_turn에서 처리)
## @param phase 현재 페이즈
func _apply_status_effects(phase: String) -> void:
	var units: Array[BattleUnit] = _get_units_by_team(phase)

	for unit: BattleUnit in units:
		if not unit.is_alive():
			continue

		for effect: Dictionary in unit.status_effects:
			var status_id: String = effect.get("status_id", "")
			match status_id:
				"poison":
					# 독: 매 턴 HP 10% 감소
					var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * 0.10), 1)
					unit.take_damage(damage)
				"burn":
					# 화상: 매 턴 HP 5% 감소
					var damage: int = maxi(int(float(unit.stats.get("hp", 0)) * 0.05), 1)
					unit.take_damage(damage)
				"regen":
					# 재생: 매 턴 HP 5% 회복
					var heal: int = maxi(int(float(unit.stats.get("hp", 0)) * 0.05), 1)
					unit.heal(heal)
				_:
					pass  # 기타 상태이상은 전투 계산 시 적용

# ── AI 행동 (적/NPC) ──

## AI 페이즈 행동을 실행한다
## @param phase AI 페이즈 ("enemy" 또는 "npc")
func _execute_ai_phase(phase: String) -> void:
	var ai_units: Array[BattleUnit] = _get_actionable_units(phase)

	# SPD 내림차순 정렬
	ai_units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		return a.stats.get("spd", 0) > b.stats.get("spd", 0)
	)

	for unit: BattleUnit in ai_units:
		# 전투 종료 확인 (VCC가 중도 판정한 경우)
		if _state == TurnState.BATTLE_END:
			return
		if not unit.is_alive() or unit.acted:
			continue
		await _execute_ai_unit_action(unit)

	# 전투 종료 상태면 페이즈 전환하지 않음
	if _state == TurnState.BATTLE_END:
		return

	# AI 페이즈 종료
	_state = TurnState.PHASE_END
	_end_phase()

## 개별 AI 유닛 행동 실행
## @param unit AI 유닛
func _execute_ai_unit_action(unit: BattleUnit) -> void:
	if battle_map == null:
		return

	# 가장 가까운 적 유닛 찾기
	var target_team: String = "player" if unit.team == "enemy" else "enemy"
	var targets: Array[BattleUnit] = _get_units_by_team(target_team)
	if targets.is_empty():
		unit.acted = true
		unit.show_acted()
		return

	# 가장 가까운 대상 선택
	var closest_target: BattleUnit = null
	var min_dist: int = 999
	for target: BattleUnit in targets:
		if not target.is_alive():
			continue
		var dist: int = absi(unit.cell.x - target.cell.x) + absi(unit.cell.y - target.cell.y)
		if dist < min_dist:
			min_dist = dist
			closest_target = target

	if closest_target == null:
		unit.acted = true
		unit.show_acted()
		return

	# 이동 범위 계산
	var move_range: Array[Vector2i] = battle_map.grid.get_movement_range(
		unit.cell, unit.stats.get("mov", 0), unit.team
	)

	# 무기 사거리
	var weapon_data: Dictionary = _get_unit_weapon_data(unit)
	var range_max: int = weapon_data.get("range_max", 1)

	# 최적 이동 위치 찾기 (대상에게 공격 가능한 가장 가까운 셀)
	var best_cell: Vector2i = unit.cell
	var best_dist_to_target: int = min_dist

	for cell: Vector2i in move_range:
		var dist_to_target: int = absi(cell.x - closest_target.cell.x) + absi(cell.y - closest_target.cell.y)
		if dist_to_target < best_dist_to_target:
			best_dist_to_target = dist_to_target
			best_cell = cell

	# 이동 실행
	if best_cell != unit.cell:
		var path: Array[Vector2i] = battle_map.grid.find_path(
			unit.cell, best_cell, unit.stats.get("mov", 0), unit.team
		)
		if not path.is_empty():
			battle_map.move_unit(unit.cell, best_cell)
			unit.move_to(best_cell, path)
			await unit.move_finished
			EventBus.unit_moved.emit(unit.unit_id, unit.cell, best_cell)

	# 공격 가능 여부 확인
	var attack_dist: int = absi(unit.cell.x - closest_target.cell.x) + absi(unit.cell.y - closest_target.cell.y)
	var range_min: int = weapon_data.get("range_min", 1)

	if attack_dist >= range_min and attack_dist <= range_max:
		# 공격 실행
		unit.face_towards(closest_target.cell)
		closest_target.face_towards(unit.cell)

		var result: Dictionary = combat_calc.calc_physical_damage(
			unit, closest_target, 1.0, battle_map.grid
		)

		if result["hit"]:
			var damage: int = result["damage"]
			closest_target.take_damage(damage)
			EventBus.damage_dealt.emit(unit.unit_id, closest_target.unit_id, damage, result["is_crit"])

			if not closest_target.is_alive():
				EventBus.unit_died.emit(closest_target.unit_id, unit.unit_id)
				if battle_map:
					battle_map.remove_unit(closest_target.cell)
			else:
				# AI 반격 받기
				_execute_counterattack(closest_target, unit)

	# VCC가 전투 종료를 판정했으면 나머지 처리 생략
	if _state == TurnState.BATTLE_END:
		return

	# 행동 완료
	unit.acted = true
	unit.show_acted()
	EventBus.unit_action_completed.emit(unit.unit_id)

	# 대기 (연출 간격)
	await get_tree().create_timer(BattleSpeed.apply(0.3)).timeout

# ── 경험치 처리 ──

## 유닛의 EXP를 누적한다
## @param unit_id 유닛 ID
## @param exp_amount 획득 EXP
func _accumulate_exp(unit_id: String, exp_amount: int) -> void:
	_battle_exp_gained[unit_id] = _battle_exp_gained.get(unit_id, 0) + exp_amount

## 전투 종료 시 누적된 골드를 파티에 지급한다 (적 드롭 + 맵 보상)
func _apply_battle_gold() -> void:
	if battle_map == null:
		return
	var map_data: Dictionary = battle_map.get_map_data()
	var bonus_gold: int = int(map_data.get("rewards", {}).get("gold", 0))
	var total_gold: int = _battle_gold_gained + bonus_gold
	if total_gold <= 0:
		return
	var pm: Node = _get_party_manager()
	if pm == null:
		return
	pm.add_gold(total_gold)
	EventBus.gold_gained.emit(total_gold)
	print("[TurnManager] 골드 획득: %d (드롭: %d + 보상: %d)" % [total_gold, _battle_gold_gained, bonus_gold])

## 전투 종료 시 누적된 경험치를 각 유닛에 적용한다
func _apply_battle_exp() -> void:
	if battle_map == null:
		return

	# 참전 유닛 EXP 적용
	var active_exp_list: Array[int] = []
	for unit_id: String in _battle_exp_gained:
		var unit: BattleUnit = battle_map.get_unit_by_id(unit_id)
		if unit and unit.team == "player":
			var exp_amount: int = _battle_exp_gained[unit_id]
			exp_system.apply_exp(unit, exp_amount)
			active_exp_list.append(exp_amount)

	# 벤치 유닛 EXP (비참전 파티원에게 참전 유닛 평균 EXP × 0.5 적용)
	var bench_exp: int = exp_system.calc_bench_exp(active_exp_list)
	if bench_exp > 0:
		var pm: Node = _get_party_manager()
		if pm:
			# 전투 맵에 배치된 플레이어 유닛 ID 목록 (생존 유닛)
			var active_ids: Dictionary = {}
			var player_units: Array[BattleUnit] = _get_units_by_team("player")
			for pu: BattleUnit in player_units:
				active_ids[pu.unit_id] = true

			# 파티 전체 멤버 중 전투에 참전하지 않은 유닛에 벤치 EXP 적용
			# 사망한 플레이어 유닛은 벤치 유닛이 아니므로 제외한다
			for member: Dictionary in pm.party:
				var char_id: String = member.get("id", "")
				if char_id == "" or active_ids.has(char_id):
					continue
				# 전투 중 사망한 유닛은 벤치 EXP 대상에서 제외
				if _battle_dead_player_ids.has(char_id):
					continue
				pm.gain_exp(char_id, bench_exp)

	# 전투 클리어 보너스 EXP: 맵 rewards.exp_bonus > 0이면 참전 유닛 전체에 flat EXP 추가
	if battle_map != null:
		var map_data: Dictionary = battle_map.get_map_data()
		var bonus_exp: int = int(map_data.get("rewards", {}).get("exp_bonus", 0))
		if bonus_exp > 0:
			for bid: String in _battle_exp_gained:
				var bunit: BattleUnit = battle_map.get_unit_by_id(bid)
				if bunit != null and bunit.team == "player":
					exp_system.apply_exp(bunit, bonus_exp)
			print("[TurnManager] 클리어 보너스 EXP: %d (참전 유닛 전체)" % bonus_exp)

# ── 사망 유닛 추적 ──

## 유닛 사망 시 플레이어 유닛이면 기록한다 (벤치 EXP 오지급 방지).
## 전투 중 사망한 유닛이 맵에서 제거된 후 벤치 유닛으로 잘못 분류되지 않도록 한다.
## @param unit_id 사망한 유닛 ID
## @param _killer_id 처치한 유닛 ID (미사용)
func _on_unit_died_for_exp_tracking(unit_id: String, _killer_id: String) -> void:
	# 맵에서 유닛을 조회하여 플레이어 팀인지 확인 (시그널은 remove_unit 전에 발생)
	if battle_map:
		var unit: BattleUnit = battle_map.get_unit_by_id(unit_id)
		if unit and unit.team == "player":
			_battle_dead_player_ids[unit_id] = true
			return
	# 폴백: 맵에서 조회 불가 시 파티 매니저로 플레이어 유닛 여부 확인
	var pm: Node = _get_party_manager()
	if pm and pm.get_party_member(unit_id).size() > 0:
		_battle_dead_player_ids[unit_id] = true

# ── 유틸 ──

## 팀별 유닛 목록 조회
## @param team_name 팀 이름
## @returns BattleUnit 배열
func _get_units_by_team(team_name: String) -> Array[BattleUnit]:
	if battle_map:
		return battle_map.get_units_by_team(team_name)
	return []

## 행동 가능한 유닛 목록 조회
## @param team_name 팀 이름
## @returns 아직 행동하지 않은 생존 유닛 배열
func _get_actionable_units(team_name: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	var units: Array[BattleUnit] = _get_units_by_team(team_name)
	for unit: BattleUnit in units:
		if unit.is_alive() and not unit.acted:
			result.append(unit)
	return result

## 유닛의 무기 데이터 조회
## @param unit 대상 유닛
## @returns 무기 데이터 Dictionary (없으면 기본값)
func _get_unit_weapon_data(unit: BattleUnit) -> Dictionary:
	var weapon_id: String = unit.equipment.get("weapon", "")
	if weapon_id.is_empty():
		return {"type": "", "atk": 0, "hit": 100, "crit": 0, "weight": 0, "range_min": 1, "range_max": 1}
	var dm: Node = _get_data_manager()
	if dm == null:
		return {"type": "", "atk": 0, "hit": 100, "crit": 0, "weight": 0, "range_min": 1, "range_max": 1}
	var data: Dictionary = dm.get_weapon(weapon_id)
	if data.is_empty():
		return {"type": "", "atk": 0, "hit": 100, "crit": 0, "weight": 0, "range_min": 1, "range_max": 1}
	return data

## DataManager 싱글톤 참조 취득
func _get_data_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("DataManager"):
		return tree.root.get_node("DataManager")
	return null

## GameManager 싱글톤 참조 취득
func _get_game_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("GameManager"):
		return tree.root.get_node("GameManager")
	return null

## PartyManager 싱글톤 참조 취득
func _get_party_manager() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree and tree.root.has_node("PartyManager"):
		return tree.root.get_node("PartyManager")
	return null

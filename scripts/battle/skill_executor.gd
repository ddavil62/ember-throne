## @fileoverview 스킬 연출 시퀀서. 스킬 실행 파이프라인 전체를 관리한다.
## 컷인 연출 → 시전 모션 → VFX 재생 → 데미지/힐/버프 계산+적용 → 상태이상 적용 → 결과 시그널.
class_name SkillExecutor
extends Node

# ── 시그널 ──

## 스킬 실행 완료 시 발생
signal skill_execution_finished()

# ── 멤버 변수 ──

## 전투 계산기
var combat_calc: CombatCalculator = CombatCalculator.new()

## 상태이상 매니저
var status_manager: StatusEffectManager = StatusEffectManager.new()

## 컷인 오버레이 (외부에서 주입하거나 자동 생성)
var _cutin_overlay: CutinOverlay = null

## VFX 플레이어 (외부에서 주입하거나 자동 생성)
var _vfx_player: VfxPlayer = null

# ── 초기화 ──

func _ready() -> void:
	_ensure_cutin_overlay()
	_ensure_vfx_player()

## 컷인 오버레이가 없으면 생성한다.
func _ensure_cutin_overlay() -> void:
	if _cutin_overlay != null:
		return
	_cutin_overlay = CutinOverlay.new()
	_cutin_overlay.name = "CutinOverlay"
	add_child(_cutin_overlay)

## VFX 플레이어가 없으면 생성한다.
func _ensure_vfx_player() -> void:
	if _vfx_player != null:
		return
	_vfx_player = VfxPlayer.new()
	_vfx_player.name = "VfxPlayer"
	add_child(_vfx_player)

# ── 스킬 실행 ──

## 스킬을 실행한다. 전체 파이프라인을 순차 진행한다.
## @param caster 시전 유닛
## @param skill_data 스킬 데이터 Dictionary
## @param target_cells 대상 셀 좌표 배열
## @param battle_map 전투 맵 노드 (유닛 조회용)
func execute_skill(caster: BattleUnit, skill_data: Dictionary, target_cells: Array[Vector2i], battle_map: Node2D) -> void:
	var skill_id: String = skill_data.get("id", "")
	var animation_tier: String = skill_data.get("animation_tier", "C")
	var has_cutin: bool = skill_data.get("cutin", false)

	print("[SkillExecutor] %s가 %s 시전 (등급: %s, 컷인: %s)" % [
		caster.unit_id, skill_id, animation_tier, str(has_cutin)
	])

	# EventBus 스킬 사용 시그널
	var target_ids: Array = []
	for cell: Vector2i in target_cells:
		var unit: BattleUnit = _get_unit_at(battle_map, cell)
		if unit:
			target_ids.append(unit.unit_id)
	EventBus.skill_used.emit(caster.unit_id, skill_id, target_ids)

	# 1. 컷인 연출 (S등급, cutin: true일 때)
	if has_cutin and animation_tier == "S":
		await _play_cutin(caster)

	# 2. 시전 모션 (첫 번째 대상 방향으로 facing 갱신)
	if not target_cells.is_empty():
		var first_target_cell: Vector2i = target_cells[0]
		if first_target_cell != caster.cell:
			caster.face_towards(first_target_cell)

	# 3. VFX 재생
	await _play_vfx(skill_data, target_cells, battle_map)

	# 4. 데미지/힐/버프 계산 + 적용
	await _apply_damage(caster, skill_data, target_cells, battle_map)

	# 5. 상태이상 적용
	var targets: Array[BattleUnit] = _collect_targets(target_cells, battle_map)
	_apply_effects(caster, skill_data, targets)

	# 6. 실행 완료
	print("[SkillExecutor] %s의 %s 실행 완료" % [caster.unit_id, skill_id])
	skill_execution_finished.emit()

# ── 컷인 연출 ──

## 컷인 오버레이를 표시한다 (0.8초).
## @param caster 시전 유닛
func _play_cutin(caster: BattleUnit) -> void:
	_ensure_cutin_overlay()
	_cutin_overlay.play_cutin(caster.unit_id)
	await _cutin_overlay.cutin_finished

# ── VFX 재생 ──

## 등급별 VFX를 재생한다.
## @param skill_data 스킬 데이터
## @param target_cells 대상 셀 좌표 배열
## @param battle_map 전투 맵 노드
func _play_vfx(skill_data: Dictionary, target_cells: Array[Vector2i], battle_map: Node2D) -> void:
	_ensure_vfx_player()

	var skill_id: String = skill_data.get("id", "")
	var tier: String = skill_data.get("animation_tier", "C")

	if target_cells.is_empty():
		return

	# 대표 셀 1개의 월드 좌표에서 이펙트 재생
	# (범위 공격이면 첫 번째 셀 기준, 추후 다중 셀 이펙트 확장 가능)
	var center_cell: Vector2i = target_cells[0]
	var world_pos: Vector2 = GridSystem.cell_to_world(center_cell)

	# VFX 재생
	_vfx_player.play_effect(skill_id, world_pos, tier)
	await _vfx_player.effect_finished

# ── 데미지/힐/버프 적용 ──

## 스킬 타입에 따라 데미지, 힐, 버프를 적용한다.
## @param caster 시전 유닛
## @param skill_data 스킬 데이터
## @param target_cells 대상 셀 좌표 배열
## @param battle_map 전투 맵 노드
func _apply_damage(caster: BattleUnit, skill_data: Dictionary, target_cells: Array[Vector2i], battle_map: Node2D) -> void:
	var skill_type: String = skill_data.get("type", "physical")
	var damage_type: String = skill_data.get("damage_type", "physical")
	var multiplier: float = skill_data.get("multiplier", 1.0)

	# 배율이 0이면 데미지/힐 계산 생략 (순수 버프/유틸 스킬)
	if multiplier <= 0.0:
		return

	var grid: GridSystem = _get_grid(battle_map)

	for cell: Vector2i in target_cells:
		var target: BattleUnit = _get_unit_at(battle_map, cell)
		if target == null or not target.is_alive():
			continue

		# guaranteed_crit 조건 판정
		var force_crit: bool = _check_guaranteed_crit(skill_data, caster, target)

		match damage_type:
			"physical":
				_apply_physical_damage(caster, target, multiplier, grid, force_crit)

			"magical", "magic":
				var element: String = skill_data.get("element", "")
				_apply_magic_damage(caster, target, multiplier, element, grid, force_crit)

			"heal":
				_apply_heal(caster, target, multiplier)

			_:
				# 기본: 물리 데미지로 처리
				if skill_type == "heal":
					_apply_heal(caster, target, multiplier)
				else:
					_apply_physical_damage(caster, target, multiplier, grid, force_crit)

## 물리 데미지를 적용한다.
## @param caster 시전 유닛
## @param target 대상 유닛
## @param multiplier 스킬 배율
## @param grid GridSystem
## @param force_crit 크리티컬 확정 여부
func _apply_physical_damage(caster: BattleUnit, target: BattleUnit, multiplier: float, grid: GridSystem, force_crit: bool = false) -> void:
	var result: Dictionary = combat_calc.calc_physical_damage(caster, target, multiplier, grid, force_crit)

	if result["hit"]:
		var damage: int = result["damage"]
		target.take_damage(damage)
		EventBus.damage_dealt.emit(caster.unit_id, target.unit_id, damage, result["is_crit"])

		# 피격 시 수면 해제
		status_manager.on_hit(target)

		# 사망 판정
		if not target.is_alive():
			EventBus.unit_died.emit(target.unit_id, caster.unit_id)
	else:
		print("[SkillExecutor] %s → %s 빗나감!" % [caster.unit_id, target.unit_id])

## 마법 데미지를 적용한다.
## @param caster 시전 유닛
## @param target 대상 유닛
## @param multiplier 스킬 배율
## @param element 마법 속성
## @param grid GridSystem
## @param force_crit 크리티컬 확정 여부
func _apply_magic_damage(caster: BattleUnit, target: BattleUnit, multiplier: float, element: String, grid: GridSystem, force_crit: bool = false) -> void:
	var result: Dictionary = combat_calc.calc_magic_damage(caster, target, multiplier, element, grid, force_crit)

	if result["hit"]:
		var damage: int = result["damage"]
		target.take_damage(damage)
		EventBus.damage_dealt.emit(caster.unit_id, target.unit_id, damage, result["is_crit"])

		# 피격 시 수면 해제
		status_manager.on_hit(target)

		# 사망 판정
		if not target.is_alive():
			EventBus.unit_died.emit(target.unit_id, caster.unit_id)
	else:
		print("[SkillExecutor] %s → %s 빗나감!" % [caster.unit_id, target.unit_id])

## 치유를 적용한다.
## @param caster 시전 유닛 (힐러)
## @param target 대상 유닛
## @param multiplier 스킬 배율
func _apply_heal(caster: BattleUnit, target: BattleUnit, multiplier: float) -> void:
	var heal_amount: int = combat_calc.calc_heal_amount(caster, target, multiplier)
	if heal_amount > 0:
		target.heal(heal_amount)
		EventBus.heal_applied.emit(caster.unit_id, target.unit_id, heal_amount)

# ── 상태이상 적용 ──

## 스킬의 effects 배열을 순회하여 상태이상/버프를 적용한다.
## @param caster 시전 유닛
## @param skill_data 스킬 데이터
## @param targets 대상 유닛 배열
func _apply_effects(caster: BattleUnit, skill_data: Dictionary, targets: Array[BattleUnit]) -> void:
	var effects: Array = skill_data.get("effects", [])
	if effects.is_empty():
		return

	for effect_data: Dictionary in effects:
		var status_id: String = effect_data.get("status", "")
		if status_id.is_empty():
			continue

		# 특수 상태 (no_friendly_fire, guaranteed_crit 등)는 전투 로직에서 별도 처리
		if status_id in ["no_friendly_fire", "guaranteed_crit", "heal_percent", "cleanse_all",
						  "undying", "ritual", "dispel_buffs", "bonus_damage", "accuracy_up",
						  "atk_def_spd_up"]:
			continue

		var chance: float = effect_data.get("chance", 1.0)
		var duration: int = effect_data.get("duration", 2)
		var value: float = effect_data.get("value", 0.0)
		var effect_target: String = effect_data.get("target", "enemy")

		# 확률 판정
		if randf() > chance:
			continue

		# 대상 결정
		match effect_target:
			"self":
				status_manager.apply_status(caster, status_id, duration, value)

			"pair":
				# 쌍방 적용 (시전자 + 대상)
				status_manager.apply_status(caster, status_id, duration, value)
				for target: BattleUnit in targets:
					if target != caster:
						status_manager.apply_status(target, status_id, duration, value)

			"self_and_adjacent":
				# 시전자 + 인접 아군 (targets에 이미 포함됨)
				status_manager.apply_status(caster, status_id, duration, value)
				for target: BattleUnit in targets:
					if target != caster and target.team == caster.team:
						status_manager.apply_status(target, status_id, duration, value)

			_:
				# 기본: 모든 대상에게 적용
				for target: BattleUnit in targets:
					status_manager.apply_status(target, status_id, duration, value)

# ── guaranteed_crit 조건 판정 ──

## 스킬 effects에서 guaranteed_crit 효과의 조건을 평가하여 크리티컬 확정 여부를 반환한다.
## 지원 조건: "backstab" (시전자가 대상 뒤에 있음), "target_hp_below_N" (대상 HP N% 이하)
## @param skill_data 스킬 데이터
## @param caster 시전 유닛
## @param target 대상 유닛
## @returns 크리티컬 확정이면 true
func _check_guaranteed_crit(skill_data: Dictionary, caster: BattleUnit, target: BattleUnit) -> bool:
	var effects: Array = skill_data.get("effects", [])
	for effect: Dictionary in effects:
		var status_id: String = effect.get("status", "")
		if status_id != "guaranteed_crit":
			continue

		# 확률 판정
		var chance: float = effect.get("chance", 1.0)
		if randf() > chance:
			continue

		# 조건 확인
		var cond: String = effect.get("condition", "")
		if cond.is_empty():
			# 조건 없으면 무조건 확정 크리티컬
			return true

		if _evaluate_crit_condition(cond, caster, target):
			return true

	return false

## guaranteed_crit 조건 문자열을 평가한다.
## @param cond 조건 문자열 ("backstab", "target_hp_below_20" 등)
## @param caster 시전 유닛
## @param target 대상 유닛
## @returns 조건 충족 시 true
func _evaluate_crit_condition(cond: String, caster: BattleUnit, target: BattleUnit) -> bool:
	# backstab — 시전자가 대상의 뒤에 있는지 (facing 반대 방향)
	if cond == "backstab":
		return _is_backstab(caster, target)

	# target_hp_below_N — 대상 HP가 N% 이하인지
	if cond.begins_with("target_hp_below_"):
		var threshold_str: String = cond.substr("target_hp_below_".length())
		var threshold_pct: float = float(threshold_str) / 100.0
		if threshold_pct <= 0.0:
			return false
		var max_hp: int = maxi(target.stats.get("hp", 1), 1)
		var hp_ratio: float = float(target.current_hp) / float(max_hp)
		return hp_ratio <= threshold_pct

	# 알 수 없는 조건 — 충족하지 않은 것으로 처리
	print("[SkillExecutor] 알 수 없는 guaranteed_crit 조건: %s" % cond)
	return false

## 시전자가 대상의 뒤를 공격하는지 판정한다 (backstab).
## 대상의 facing 방향과 시전자의 상대적 위치를 비교한다.
## @param caster 시전 유닛
## @param target 대상 유닛
## @returns 뒤에서 공격이면 true
func _is_backstab(caster: BattleUnit, target: BattleUnit) -> bool:
	# facing_direction이 있으면 사용, 없으면 false
	if not "facing_direction" in target:
		return false
	var facing: Vector2i = target.facing_direction
	# 시전자가 대상의 facing 반대쪽에 있는지
	var diff: Vector2i = caster.cell - target.cell
	# 내적이 음수면 뒤에서 공격 (대상이 바라보는 방향의 반대)
	var dot: int = facing.x * diff.x + facing.y * diff.y
	return dot < 0

# ── 유틸 ──

## 대상 셀 목록에서 BattleUnit 배열을 수집한다.
## @param target_cells 셀 좌표 배열
## @param battle_map 전투 맵 노드
## @returns BattleUnit 배열
func _collect_targets(target_cells: Array[Vector2i], battle_map: Node2D) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for cell: Vector2i in target_cells:
		var unit: BattleUnit = _get_unit_at(battle_map, cell)
		if unit != null and unit.is_alive():
			result.append(unit)
	return result

## battle_map에서 지정 셀의 유닛을 조회한다.
## @param battle_map 전투 맵 노드
## @param cell 셀 좌표
## @returns BattleUnit 또는 null
func _get_unit_at(battle_map: Node2D, cell: Vector2i) -> BattleUnit:
	if battle_map == null:
		return null
	if battle_map.has_method("get_unit_at"):
		return battle_map.get_unit_at(cell)
	# fallback: units Dictionary 직접 접근
	if "units" in battle_map:
		return battle_map.units.get(cell, null)
	return null

## battle_map에서 GridSystem을 조회한다.
## @param battle_map 전투 맵 노드
## @returns GridSystem 또는 새 인스턴스
func _get_grid(battle_map: Node2D) -> GridSystem:
	if battle_map == null:
		return GridSystem.new()
	if "grid" in battle_map:
		return battle_map.grid
	return GridSystem.new()

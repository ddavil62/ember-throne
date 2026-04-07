## @fileoverview 전투 유닛 클래스. 캐릭터/적 초기화, 이동, 전투 상태 관리를 담당한다.
class_name BattleUnit
extends Node2D

# class_name(SpriteLoader)은 에디터 없이 실행 시 클래스 레지스트리에 등록되지 않을 수 있으므로
# preload로 명시적으로 참조하여 컴파일 오류를 방지한다.
const SpriteLoader = preload("res://scripts/utils/sprite_loader.gd")

# ── 상수 ──

## 이동 Tween 세그먼트당 소요 시간 (초)
const MOVE_SEGMENT_DURATION: float = 0.15

## 스프라이트 배율 (1.0 = 원본 크기)
const SPRITE_SCALE: float = 1.2

## 스프라이트 Y 오프셋 (sprite local space)
const SPRITE_OFFSET_Y: float = -10.0

## 스프라이트에서 머리까지의 추정 높이 (픽셀, 로컬 언스케일)
## PixelLab 48px 캐릭터 기준 — 68px 캔버스 내 실제 머리 위치에서 역산
const SPRITE_HEAD_H: float = 20.0

## 8방향 이름 배열
const DIRECTION_NAMES: Array[String] = [
	"south", "south_west", "west", "north_west",
	"north", "north_east", "east", "south_east"
]

# ── 시그널 ──

## 이동 완료 시 발생
signal move_finished()

# ── 기본 속성 ──

## 유닛 고유 ID (캐릭터 id 또는 "enemy_0" 등)
var unit_id: String = ""

## 소속 팀 ("player" 또는 "enemy")
var team: String = "player"

## 기본 스탯 (레벨 적용 완료 상태)
var stats: Dictionary = {
	"hp": 0, "mp": 0, "atk": 0, "def": 0,
	"matk": 0, "mdef": 0, "spd": 0, "mov": 0
}

## 현재 HP
var current_hp: int = 0

## 현재 MP
var current_mp: int = 0

## 현재 위치 (그리드 좌표)
var cell: Vector2i = Vector2i.ZERO

## 현재 바라보는 방향 (8방향 문자열)
var facing: String = "south"

## 장비 슬롯
var equipment: Dictionary = {
	"weapon": "",
	"armor": "",
	"accessory": ""
}

## 보유 스킬 ID 배열
var skills: Array[String] = []

## 활성 상태이상 배열 [{status_id, duration, ...}]
var status_effects: Array[Dictionary] = []

## 이번 턴 행동 완료 여부
var acted: bool = false

## 이동 중 여부 (Tween 애니메이션 진행 중)
var _is_moving: bool = false

## 레벨
var level: int = 1

## 클래스 이름 (표시용)
var class_name_ko: String = ""

## 유닛 이름 (표시용)
var unit_name_ko: String = ""

## 원본 데이터 참조 (디버그/UI용)
var _source_data: Dictionary = {}

# ── 자식 노드 참조 ──

## 스프라이트 노드
var _sprite: AnimatedSprite2D = null

## HP바 노드
var _health_bar: ProgressBar = null

## MP바 노드
var _mp_bar: ProgressBar = null

## HP 채움 StyleBox (색상 동적 변경용)
var _hp_fill_style: StyleBoxFlat = null

## MP 채움 StyleBox
var _mp_fill_style: StyleBoxFlat = null

## 상태이상 아이콘 컨테이너
var _status_icons: HBoxContainer = null

## 선택 표시 노드
var _selection_indicator: Sprite2D = null

# ── 초기화 ──

func _ready() -> void:
	_find_child_nodes()

## 자식 노드 참조 취득
func _find_child_nodes() -> void:
	if has_node("Sprite"):
		_sprite = get_node("Sprite") as AnimatedSprite2D
	if has_node("HealthBar"):
		_health_bar = get_node("HealthBar") as ProgressBar
	if has_node("MpBar"):
		_mp_bar = get_node("MpBar") as ProgressBar
	if has_node("StatusIcons"):
		_status_icons = get_node("StatusIcons") as HBoxContainer
	if has_node("SelectionIndicator"):
		_selection_indicator = get_node("SelectionIndicator") as Sprite2D
		_selection_indicator.visible = false
	_setup_bar_styles()
	_reposition_hud()

## HP바·MP바 시각 스타일을 적용한다 (어두운 배경 + 검은 테두리 + 채움색)
func _setup_bar_styles() -> void:
	# 공통 배경: 어두운 반투명 + 검은 1px 테두리
	var make_bg := func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.06, 0.06, 0.06, 0.88)
		s.set_border_width_all(1)
		s.border_color = Color(0.0, 0.0, 0.0, 1.0)
		return s

	_hp_fill_style = StyleBoxFlat.new()
	_hp_fill_style.bg_color = Color(0.18, 0.82, 0.18, 1.0)   # 기본 초록

	_mp_fill_style = StyleBoxFlat.new()
	_mp_fill_style.bg_color = Color(0.22, 0.52, 1.0, 1.0)    # 파랑

	if _health_bar:
		_health_bar.add_theme_stylebox_override("background", make_bg.call())
		_health_bar.add_theme_stylebox_override("fill", _hp_fill_style)
	if _mp_bar:
		_mp_bar.add_theme_stylebox_override("background", make_bg.call())
		_mp_bar.add_theme_stylebox_override("fill", _mp_fill_style)

## HP바·MP바·상태이상 아이콘을 캐릭터 머리 바로 위에 배치한다.
## 아래에서 위 순서: [머리] → [gap] → [HP bar] → [1px] → [MP bar] → [상태이상]
func _reposition_hud() -> void:
	var bar_h    := 3.0   # 바 높이 (게임 px)
	var bar_gap  := 1.0   # HP바와 MP바 사이 간격
	var head_gap := 2.0   # 머리와 HP바 사이 간격

	var head_y: float  = (SPRITE_OFFSET_Y - SPRITE_HEAD_H) * SPRITE_SCALE
	var hp_top: float  = head_y - head_gap - bar_h
	var mp_top: float  = hp_top - bar_gap - bar_h

	if _health_bar:
		_health_bar.offset_top    = hp_top
		_health_bar.offset_bottom = hp_top + bar_h
	if _mp_bar:
		_mp_bar.offset_top    = mp_top
		_mp_bar.offset_bottom = mp_top + bar_h
	if _status_icons:
		_status_icons.offset_top    = mp_top - 8.0
		_status_icons.offset_bottom = mp_top

## 캐릭터 데이터로 유닛 초기화 (플레이어 유닛)
## @param char_data DataManager.get_character()에서 가져온 캐릭터 Dictionary
## @param char_level 캐릭터 레벨
func init_from_character(char_data: Dictionary, char_level: int) -> void:
	_source_data = char_data
	unit_id = char_data.get("id", "")
	team = "player"
	level = char_level
	unit_name_ko = char_data.get("name_ko", "")
	class_name_ko = char_data.get("class_ko", "")

	# 레벨 1 기본 스탯
	var base: Dictionary = char_data.get("stats_lv1", {})
	var growth: Dictionary = char_data.get("growth", {})

	# 레벨 적용: stat = base + growth * (level - 1)
	for key: String in stats:
		var base_val: float = float(base.get(key, 0))
		var growth_val: float = float(growth.get(key, 0))
		stats[key] = int(base_val + growth_val * (char_level - 1))

	# 전직 보너스 (해당하는 경우 — 간략 처리, 전직 시스템은 별도 Phase에서)
	current_hp = stats["hp"]
	current_mp = stats["mp"]

	# 스킬 설정
	skills.clear()
	var skill_list: Array = char_data.get("skills", [])
	for s: Variant in skill_list:
		skills.append(s as String)

	_update_health_bar()
	_update_mp_bar()

	# 스프라이트 로딩 시도 (플레이어 캐릭터)
	var sid: String = char_data.get("sprite_id", unit_id)
	var frames := SpriteLoader.load_sprite_frames(sid, false)
	if frames != null and _sprite != null:
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		_sprite.offset = Vector2(0.0, SPRITE_OFFSET_Y)
		_sprite.visible = true
		_sprite.play("idle_south")
		_reposition_hud()  # 실제 프레임 크기 기반 재계산
	else:
		_setup_placeholder_visual()

## 적 데이터로 유닛 초기화
## @param enemy_data DataManager.get_enemy()에서 가져온 적 Dictionary
## @param enemy_level 적 레벨 (맵 배치 데이터의 level)
func init_from_enemy(enemy_data: Dictionary, enemy_level: int = 1) -> void:
	_source_data = enemy_data
	unit_id = enemy_data.get("id", "")
	team = "enemy"
	unit_name_ko = enemy_data.get("name_ko", "")

	# 난이도 보정: 적 레벨 + 보너스 (Hard: +1, Normal: +0)
	var diff_mgr := DifficultyManager.new()
	var actual_level: int = enemy_level + diff_mgr.get_enemy_level_bonus()
	level = actual_level

	# 기본 스탯 + 레벨 스케일링 계산
	var base: Dictionary = enemy_data.get("base_stats", {})
	var scaling: Dictionary = enemy_data.get("scaling_per_level", {})

	for key: String in stats:
		var base_val: float = float(base.get(key, 0))
		var scale_val: float = float(scaling.get(key, 0))
		stats[key] = int(base_val + scale_val * maxi(actual_level - 1, 0))

	# 난이도 스탯 배율 적용 (Hard: HP×1.3, ATK×1.2, DEF×1.15, SPD×1.1 / Normal: 배율 1.0)
	var scaled: Dictionary = diff_mgr.apply_enemy_stats(stats)
	for key: String in stats:
		if scaled.has(key):
			stats[key] = scaled[key]

	current_hp = stats["hp"]
	current_mp = stats["mp"]

	# 스킬 설정
	skills.clear()
	var skill_list: Array = enemy_data.get("skills", [])
	for s: Variant in skill_list:
		skills.append(s as String)

	_update_health_bar()
	_update_mp_bar()

	# 스프라이트 로딩 시도 (적 유닛)
	var sid: String = enemy_data.get("sprite_id", unit_id)
	var frames := SpriteLoader.load_sprite_frames(sid, true)
	if frames != null and _sprite != null:
		_sprite.sprite_frames = frames
		_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		_sprite.offset = Vector2(0.0, SPRITE_OFFSET_Y)
		_sprite.visible = true
		_sprite.play("idle_south")
		_reposition_hud()  # 실제 프레임 크기 기반 재계산
	else:
		_setup_placeholder_visual()

# ── 이동 ──

## 경로를 따라 유닛을 이동시킨다 (Tween 애니메이션)
## @param target_cell 목표 셀 좌표
## @param path 경로 셀 배열 (시작 셀 포함)
func move_to(target_cell: Vector2i, path: Array[Vector2i]) -> void:
	if _is_moving:
		return
	if path.size() < 2:
		cell = target_cell
		position = GridSystem.cell_to_world(target_cell)
		move_finished.emit()
		return

	_is_moving = true

	# 경로 포인트를 순회하며 Tween 이동
	var tween := create_tween()
	for i: int in range(1, path.size()):
		var world_pos := GridSystem.cell_to_world(path[i])
		# 각 세그먼트 시작 시 방향 갱신
		var prev_cell: Vector2i = path[i - 1]
		var next_cell: Vector2i = path[i]
		var dir := GridSystem.get_direction(prev_cell, next_cell)
		tween.tween_callback(_set_facing.bind(dir))
		tween.tween_property(self, "position", world_pos, MOVE_SEGMENT_DURATION)

	await tween.finished

	cell = target_cell
	_is_moving = false
	move_finished.emit()

## 방향 설정 (Tween 콜백용)
## @param dir 방향 문자열
func _set_facing(dir: String) -> void:
	facing = dir
	_update_sprite_direction()

## 대상 셀 방향으로 facing 갱신
## @param target_cell 바라볼 대상 셀 좌표
func face_towards(target_cell: Vector2i) -> void:
	if target_cell == cell:
		return
	facing = GridSystem.get_direction(cell, target_cell)
	_update_sprite_direction()

# ── 전투 액션 ──

# ── 전투 애니메이션 (코루틴) ──

## 공격 애니메이션을 1사이클 재생하고 idle로 복귀한다.
## 스프라이트나 애니메이션이 없으면 즉시 반환한다.
func play_attack_anim() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := "attack_%s" % facing
	if not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.play(anim)
	var frames_n := _sprite.sprite_frames.get_frame_count(anim)
	var fps: float = _sprite.sprite_frames.get_animation_speed(anim)
	await get_tree().create_timer(float(frames_n) / fps).timeout
	if is_instance_valid(_sprite) and _sprite.animation == anim:
		_sprite.play("idle_%s" % facing)

## 피격 애니메이션을 1사이클 재생하고 idle로 복귀한다.
## 스프라이트나 애니메이션이 없으면 즉시 반환한다.
func play_hit_anim() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := "hit_%s" % facing
	if not _sprite.sprite_frames.has_animation(anim):
		return
	_sprite.play(anim)
	var frames_n := _sprite.sprite_frames.get_frame_count(anim)
	var fps: float = _sprite.sprite_frames.get_animation_speed(anim)
	await get_tree().create_timer(float(frames_n) / fps).timeout
	if is_instance_valid(_sprite) and _sprite.animation == anim:
		_sprite.play("idle_%s" % facing)

## 사망 애니메이션을 재생하고 완료(animation_finished)까지 대기한다.
## non-looping이므로 마지막 프레임에서 멈춘다.
func play_death_anim() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	var anim := "death_%s" % facing
	if not _sprite.sprite_frames.has_animation(anim):
		anim = "death_south"  # 방향별 애니메이션 없을 때 fallback
		if not _sprite.sprite_frames.has_animation(anim):
			return
	_sprite.play(anim)
	await _sprite.animation_finished

## 피해를 입힌다
## @param amount 피해량
## @returns 남은 HP
func take_damage(amount: int) -> int:
	current_hp = maxi(current_hp - amount, 0)
	_update_health_bar()
	# 피격 시각 효과 (깜빡임)
	_flash_damage()
	return current_hp

## 회복
## @param amount 회복량
func heal(amount: int) -> void:
	current_hp = mini(current_hp + amount, stats["hp"])
	_update_health_bar()

## 상태이상 적용
## @param status_id 상태이상 ID
## @param duration 지속 턴 수
func apply_status(status_id: String, duration: int) -> void:
	# 기존 동일 상태이상이 있으면 갱신
	for effect: Dictionary in status_effects:
		if effect.get("status_id", "") == status_id:
			effect["duration"] = duration
			return
	status_effects.append({"status_id": status_id, "duration": duration})

## 상태이상 제거
## @param status_id 제거할 상태이상 ID
func remove_status(status_id: String) -> void:
	for i: int in range(status_effects.size() - 1, -1, -1):
		if status_effects[i].get("status_id", "") == status_id:
			status_effects.remove_at(i)
			break

## 생존 여부 확인
## @returns 살아있으면 true
func is_alive() -> bool:
	return current_hp > 0

## 턴 시작 시 리셋 (행동 완료 플래그, 상태이상 턴 차감 등)
func reset_turn() -> void:
	acted = false
	# 상태이상 턴 차감
	var expired: Array[String] = []
	for effect: Dictionary in status_effects:
		effect["duration"] = effect.get("duration", 0) - 1
		if effect["duration"] <= 0:
			expired.append(effect.get("status_id", ""))
	for sid: String in expired:
		remove_status(sid)

# ── 선택 표시 ──

## 선택 표시 활성화
func show_selection() -> void:
	if _selection_indicator:
		_selection_indicator.visible = true

## 선택 표시 비활성화
func hide_selection() -> void:
	if _selection_indicator:
		_selection_indicator.visible = false

## 행동 완료 시 그레이아웃 표시
func show_acted() -> void:
	modulate = Color(0.5, 0.5, 0.5, 1.0)

## 행동 가능 상태로 복원
func clear_acted_visual() -> void:
	modulate = Color(1.0, 1.0, 1.0, 1.0)

# ── 내부 유틸 ──

## 스프라이트 프레임이 없으면 컬러 placeholder를 표시한다.
## 플레이어=파랑, 적=빨강. 첫 글자를 레이블로 표시.
func _setup_placeholder_visual() -> void:
	# 이미 유효한 스프라이트가 있으면 건너뜀
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.get_animation_names().size() > 0:
		return

	# 기존 AnimatedSprite2D를 숨김
	if _sprite:
		_sprite.visible = false

	# 기존 placeholder 제거
	if has_node("PlaceholderRect"):
		get_node("PlaceholderRect").queue_free()

	var tile_size := 28  # GridSystem.TILE_SIZE(32) 보다 약간 작게
	var color: Color
	if team == "player":
		color = Color(0.2, 0.4, 0.9, 0.9)   # 파랑
	else:
		color = Color(0.85, 0.2, 0.2, 0.9)   # 빨강

	# 컬러 사각형
	var rect := ColorRect.new()
	rect.name = "PlaceholderRect"
	rect.color = color
	rect.size = Vector2(tile_size, tile_size)
	rect.position = Vector2(-tile_size / 2, -tile_size / 2)
	add_child(rect)

	# 유닛 이름 첫 글자 레이블
	var initial := unit_name_ko.substr(0, 1) if not unit_name_ko.is_empty() else "?"
	var lbl := Label.new()
	lbl.text = initial
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(tile_size, tile_size)
	lbl.position = Vector2(-tile_size / 2, -tile_size / 2)
	rect.add_child(lbl)

## HP바 갱신
func _update_health_bar() -> void:
	if _health_bar == null:
		return
	_health_bar.max_value = stats["hp"]
	_health_bar.value = current_hp
	# HP 비율에 따른 채움 색상 변경 (배경은 항상 어둡게 유지)
	if _hp_fill_style:
		var ratio := float(current_hp) / float(maxi(stats["hp"], 1))
		if ratio > 0.5:
			_hp_fill_style.bg_color = Color(0.18, 0.82, 0.18, 1.0)   # 초록
		elif ratio > 0.25:
			_hp_fill_style.bg_color = Color(0.92, 0.78, 0.08, 1.0)   # 노랑
		else:
			_hp_fill_style.bg_color = Color(0.90, 0.18, 0.12, 1.0)   # 빨강

## MP바 갱신
func _update_mp_bar() -> void:
	if _mp_bar == null:
		return
	_mp_bar.max_value = maxi(stats["mp"], 1)
	_mp_bar.value = current_mp

## 스프라이트 방향 갱신
func _update_sprite_direction() -> void:
	if _sprite == null:
		return
	# 방향별 애니메이션이 있으면 전환 (없으면 좌우 반전으로 처리)
	var anim_name := "idle_" + facing
	if _sprite.sprite_frames and _sprite.sprite_frames.has_animation(anim_name):
		_sprite.play(anim_name)
	else:
		# 기본: 좌우 반전으로 처리
		var flip := facing in ["west", "north_west", "south_west"]
		_sprite.flip_h = flip

## 피격 깜빡임 효과
func _flash_damage() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.05)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

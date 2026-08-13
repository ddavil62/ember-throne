## @fileoverview 튜토리얼 오버레이. battle_01 첫 전투에서 4단계(이동/공격/스킬/대기)
## 안내를 순차적으로 표시하고, 해당 행동 외 조작을 차단한다.
class_name TutorialOverlay
extends CanvasLayer

# ── 상수 ──

## 튜토리얼 4단계 정의
const STEPS: Array = [
	{
		"id": "move",
		"title_ko": "이동",
		"title_en": "Move",
		"desc_ko": "유닛을 선택하고 파란색 칸으로 이동하세요.",
		"desc_en": "Select a unit and move to a blue cell.",
		"action": "move",
	},
	{
		"id": "attack",
		"title_ko": "공격",
		"title_en": "Attack",
		"desc_ko": "적 유닛을 선택하여 공격하세요.",
		"desc_en": "Select an enemy unit to attack.",
		"action": "attack",
	},
	{
		"id": "skill",
		"title_ko": "스킬",
		"title_en": "Skill",
		"desc_ko": "스킬 메뉴에서 스킬을 선택하여 사용하세요.",
		"desc_en": "Use a skill from the skill menu.",
		"action": "skill",
	},
	{
		"id": "wait",
		"title_ko": "대기",
		"title_en": "Wait",
		"desc_ko": "남은 행동을 대기로 종료하세요.",
		"desc_en": "End remaining actions by waiting.",
		"action": "wait",
	},
]

## 패널 배경색
const BG_COLOR := Color(0.0, 0.0, 0.0, 0.75)

## 텍스트 색상
const TEXT_COLOR := Color(1.0, 1.0, 1.0, 1.0)

## 강조 색상
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2, 1.0)

## 페이드 시간
const FADE_DURATION := 0.4

# ── 상태 변수 ──

## 현재 튜토리얼 단계 (0~3), -1이면 비활성
var _current_step: int = -1

## 튜토리얼 활성 여부
var _active: bool = false

## 입력 대기 중 (안내 패널 표시 상태)
var _waiting_input: bool = false

# ── UI 노드 ──

## 오버레이 루트 패널
var _overlay_panel: PanelContainer = null

## 단계 제목 라벨
var _title_label: Label = null

## 설명 라벨
var _desc_label: Label = null

## "계속" 안내 라벨
var _continue_label: Label = null

# ── 시그널 ──

## 튜토리얼 완료 시 발신
signal tutorial_completed

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	visible = false

## UI 노드를 동적으로 구성한다.
func _build_ui() -> void:
	layer = 100  # HUD 위에 표시

	# 반투명 배경
	var bg := ColorRect.new()
	bg.name = "TutorialBg"
	bg.color = Color(0.0, 0.0, 0.0, 0.4)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 중앙 패널
	_overlay_panel = PanelContainer.new()
	_overlay_panel.name = "Panel"
	add_child(_overlay_panel)
	_overlay_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_overlay_panel.custom_minimum_size = Vector2(500, 200)
	_overlay_panel.position = Vector2(-250, -100)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	_overlay_panel.add_child(vbox)
	vbox.add_theme_constant_override("separation", 16)

	# 단계 번호 + 제목
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", HIGHLIGHT_COLOR)
	vbox.add_child(_title_label)

	# 설명
	_desc_label = Label.new()
	_desc_label.name = "Desc"
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.add_theme_font_size_override("font_size", 18)
	_desc_label.add_theme_color_override("font_color", TEXT_COLOR)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_label)

	# "계속" 안내
	_continue_label = Label.new()
	_continue_label.name = "Continue"
	_continue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_label.add_theme_font_size_override("font_size", 14)
	_continue_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	_continue_label.text = "Enter / 클릭으로 계속"
	vbox.add_child(_continue_label)

# ── 튜토리얼 제어 ──

## 튜토리얼을 시작한다.
func start() -> void:
	if _active:
		return
	_active = true
	_current_step = -1
	visible = true

	# EventBus 시그널 연결
	var eb: Node = get_node("/root/EventBus")
	if eb:
		if not eb.unit_moved.is_connected(_on_unit_moved):
			eb.unit_moved.connect(_on_unit_moved)
		if not eb.unit_action_completed.is_connected(_on_unit_action_completed):
			eb.unit_action_completed.connect(_on_unit_action_completed)
		if not eb.skill_used.is_connected(_on_skill_used):
			eb.skill_used.connect(_on_skill_used)

	print("[TutorialOverlay] 튜토리얼 시작")
	_advance_step()

## 다음 단계로 진행한다.
func _advance_step() -> void:
	_current_step += 1
	if _current_step >= STEPS.size():
		_finish()
		return

	_waiting_input = true
	var step: Dictionary = STEPS[_current_step]
	_title_label.text = "[%d/4] %s" % [_current_step + 1, step["title_ko"]]
	_desc_label.text = step["desc_ko"]
	_continue_label.visible = true
	_overlay_panel.visible = true

	# 페이드 인
	_overlay_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_overlay_panel, "modulate:a", 1.0, FADE_DURATION)

	print("[TutorialOverlay] 단계 %d: %s" % [_current_step + 1, step["id"]])

## 안내 패널을 닫고 플레이어 행동 대기 상태로 전환한다.
func _dismiss_panel() -> void:
	_waiting_input = false
	_overlay_panel.visible = false

## 튜토리얼을 종료한다.
func _finish() -> void:
	_active = false
	visible = false

	# EventBus 시그널 해제
	var eb: Node = get_node("/root/EventBus")
	if eb:
		if eb.unit_moved.is_connected(_on_unit_moved):
			eb.unit_moved.disconnect(_on_unit_moved)
		if eb.unit_action_completed.is_connected(_on_unit_action_completed):
			eb.unit_action_completed.disconnect(_on_unit_action_completed)
		if eb.skill_used.is_connected(_on_skill_used):
			eb.skill_used.disconnect(_on_skill_used)

	print("[TutorialOverlay] 튜토리얼 완료")
	tutorial_completed.emit()

## 현재 단계에서 특정 행동이 차단되는지 확인한다.
## @param action_type 행동 타입 문자열 ("move", "attack", "skill", "wait")
## @returns 차단 여부 (true이면 해당 행동을 실행하면 안 됨)
func is_action_blocked(action_type: String) -> bool:
	if not _active:
		return false
	if _waiting_input:
		return true  # 안내 표시 중에는 모든 행동 차단

	var step: Dictionary = STEPS[_current_step]
	var allowed: String = step["action"]
	return action_type != allowed

## 튜토리얼이 활성 상태인지 확인한다.
## @returns 활성 여부
func is_active() -> bool:
	return _active

# ── EventBus 콜백 ──

## 유닛 이동 시 move 단계 완료 확인.
## @param _unit_id 이동한 유닛 ID
## @param _from 출발 셀
## @param _to 도착 셀
func _on_unit_moved(_unit_id: String, _from: Vector2i, _to: Vector2i) -> void:
	if not _active or _waiting_input:
		return
	if _current_step < STEPS.size() and STEPS[_current_step]["id"] == "move":
		_advance_step()

## 유닛 행동 완료 시 attack/wait 단계 완료 확인.
## @param _unit_id 행동 완료한 유닛 ID
func _on_unit_action_completed(_unit_id: String) -> void:
	if not _active or _waiting_input:
		return
	if _current_step >= STEPS.size():
		return

	var step_id: String = STEPS[_current_step]["id"]
	# attack 또는 wait 단계에서 행동 완료 시 다음으로
	if step_id == "attack" or step_id == "wait":
		_advance_step()

## 스킬 사용 시 skill 단계 완료 확인.
## @param _caster_id 시전자 ID
## @param _skill_id 스킬 ID
## @param _targets 대상 배열
func _on_skill_used(_caster_id: String, _skill_id: String, _targets: Array) -> void:
	if not _active or _waiting_input:
		return
	if _current_step < STEPS.size() and STEPS[_current_step]["id"] == "skill":
		_advance_step()

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _waiting_input:
		return

	var accepted := false
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accepted = true
	elif event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ENTER, KEY_SPACE:
					accepted = true

	if accepted:
		get_viewport().set_input_as_handled()
		_dismiss_panel()

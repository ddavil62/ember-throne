## @fileoverview 대화 씬 오케스트레이터. DialogueManager, DialogueBox, ChoicePanel,
## CGViewer를 .tscn에서 인스턴스하고 register_ui로 연결한 뒤 대화를 시작한다.
extends Control

# ── 노드 참조 (.tscn에서 정의된 자식 노드) ──

## 대화 매니저
@onready var _dialogue_manager: Node = $DialogueManager

## CG 뷰어
@onready var _cg_viewer: Control = $CGViewer

## 대화 박스 UI
@onready var _dialogue_box: Control = $DialogueBox

## 선택지 패널 UI
@onready var _choice_panel: Control = $ChoicePanel

# ── 초기화 ──

func _ready() -> void:
	# UI 등록 (의존성 주입)
	_dialogue_manager.register_ui(_dialogue_box, _choice_panel, _cg_viewer)

	# EventBus에서 대화 종료 시그널 수신
	var eb: Node = get_node("/root/EventBus")
	eb.scene_ended.connect(_on_scene_ended)

	# 대화 시작
	_start_dialogue()

## GameManager의 current_scene_id로 대화를 시작한다.
func _start_dialogue() -> void:
	var gm: Node = get_node("/root/GameManager")
	var scene_id: String = gm.current_scene_id

	if scene_id.is_empty():
		push_error("[DialogueScene] scene_id가 비어있음")
		_return_to_world_map()
		return

	print("[DialogueScene] 대화 시작: %s" % scene_id)
	_dialogue_manager.start_scene(scene_id)

## 대화 씬 종료 시 월드맵 복귀
func _on_scene_ended(_scene_id: String) -> void:
	print("[DialogueScene] 대화 종료: %s" % _scene_id)
	# 진행도 갱신
	var gm: Node = get_node("/root/GameManager")
	var prog: Node = get_node("/root/ProgressionManager")
	prog.complete_node(gm.current_scene_id)
	_return_to_world_map()

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

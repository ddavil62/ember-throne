## @fileoverview CG 전체화면 뷰어. 이벤트 CG를 페이드 인/아웃으로
## 표시하고 클릭/Enter로 닫는다.
class_name CGViewerClass
extends Control

# ── 상수 ──

## CG 이미지 경로 접두사
const CG_PATH := "res://assets/concepts/"

## 페이드 인 시간 (초)
const FADE_IN_DURATION := 0.5

## 페이드 아웃 시간 (초)
const FADE_OUT_DURATION := 0.3

## 배경 색상
const BG_COLOR := Color(0.0, 0.0, 0.0, 1.0)

# ── 상태 변수 ──

## CG 표시 중 여부
var _showing: bool = false

## 입력 수용 여부 (페이드 중에는 false)
var _accepting_input: bool = false

# ── UI 노드 참조 ──

## 배경 패널 (검정)
var _bg_panel: ColorRect = null

## CG 이미지 텍스처
var _cg_rect: TextureRect = null

# ── 초기화 ──

func _ready() -> void:
	_build_ui()
	hide()

## UI 노드를 동적으로 생성한다.
func _build_ui() -> void:
	# 자신의 앵커를 전체 화면으로
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 배경 (검정)
	_bg_panel = ColorRect.new()
	_bg_panel.name = "BgPanel"
	_bg_panel.color = BG_COLOR
	add_child(_bg_panel)
	_bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# CG 이미지
	_cg_rect = TextureRect.new()
	_cg_rect.name = "CGImage"
	_cg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_cg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_panel.add_child(_cg_rect)
	_cg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# ── CG 표시 ──

## CG 이미지를 전체화면으로 표시한다 (페이드 인).
## @param image CG 이미지 파일명 (확장자 포함)
func show_cg(image: String) -> void:
	if image == "":
		push_warning("[CGViewer] 이미지 경로가 비어 있음")
		_dismiss()
		return

	# 이미지 로드
	var path := CG_PATH + image
	if not ResourceLoader.exists(path):
		push_warning("[CGViewer] CG 이미지 없음: %s" % path)
		_dismiss()
		return

	_cg_rect.texture = load(path)
	_showing = true
	_accepting_input = false

	# 페이드 인
	modulate.a = 0.0
	show()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	tween.tween_callback(_enable_input)

## 입력을 활성화한다.
func _enable_input() -> void:
	_accepting_input = true

# ── 닫기 ──

## CG를 페이드 아웃으로 닫고 DialogueManager에게 진행을 요청한다.
func _dismiss() -> void:
	if not _showing:
		return

	_showing = false
	_accepting_input = false

	# 페이드 아웃
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_OUT_DURATION)
	tween.tween_callback(_on_dismiss_complete)

## 닫기 완료 후 처리.
func _on_dismiss_complete() -> void:
	hide()
	_cg_rect.texture = null

	# DialogueManager에게 진행 요청
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm:
		dm.advance()

# ── 입력 처리 ──

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _accepting_input:
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
		_dismiss()

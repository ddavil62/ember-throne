## @fileoverview 월드맵 개별 노드. 거점 아이콘, 상태 표시, 상호작용을 처리한다.
class_name MapNode
extends Node2D

# ── 시그널 ──

## 노드 클릭 시 발신
signal node_clicked(node_id: String)

# ── 노드 프로퍼티 ──

## 노드 고유 ID
var node_id: String = ""
## 노드 유형 (story_battle, wandering_battle, story_event, shop, outpost, travel)
var node_type: String = ""
## 소속 지역
var region: String = ""
## 한국어 이름
var name_ko: String = ""
## 영어 이름
var name_en: String = ""
## 소속 막 (1~4)
var act: int = 1
## 씬 ID (예: "1-1")
var scene_id: String = ""
## 전투 ID (있는 경우)
var battle_id: String = ""
## 설명 (한국어)
var description_ko: String = ""
## 연결된 노드 ID 목록
var connections: Array = []

# ── 상태 ──

## 노드 상태: "locked" | "available" | "completed"
var state: String = "locked"

# ── 내부 노드 참조 ──

## 배경 아이콘 (ColorRect placeholder)
var _icon_bg: ColorRect = null
## 아이콘 라벨 (타입 표시)
var _icon_label: Label = null
## 이름 라벨 (호버 시 표시)
var _name_label: Label = null
## 체크마크 (완료 시 표시)
var _check_label: Label = null
## 잠금 아이콘 (잠금 시 표시)
var _lock_label: Label = null
## 펄스 애니메이션 트윈
var _pulse_tween: Tween = null

## 아이콘 크기 (정사각형 변 길이)
const ICON_SIZE := 56
## 호버 감지 영역 크기
const HOVER_AREA_SIZE := 64
## 테두리 두께
const BORDER_WIDTH := 2

# ── 타입별 아이콘 매핑 ──

## 노드 타입별 표시 문자
const TYPE_ICONS := {
	"story_battle": "X",
	"wandering_battle": "W",
	"story_event": "?",
	"shop": "$",
	"outpost": "F",
	"travel": "~",
}

## 노드 타입별 배경 색상
const TYPE_COLORS := {
	"story_battle": Color(0.7, 0.15, 0.15),
	"wandering_battle": Color(0.6, 0.3, 0.1),
	"story_event": Color(0.2, 0.4, 0.7),
	"shop": Color(0.2, 0.6, 0.3),
	"outpost": Color(0.5, 0.5, 0.2),
	"travel": Color(0.4, 0.4, 0.4),
}

# ── 라이프사이클 ──

func _ready() -> void:
	_build_visuals()
	_update_visuals()

# ── 초기화 ──

## nodes.json의 데이터로 노드를 초기화한다.
## @param data nodes.json에서 가져온 노드 Dictionary
## @param pos 월드맵 상의 배치 좌표
func setup(data: Dictionary, pos: Vector2) -> void:
	node_id = data.get("node_id", "")
	node_type = data.get("type", "")
	region = data.get("region", "")
	name_ko = data.get("name_ko", "")
	name_en = data.get("name_en", "")
	act = data.get("act", 1)
	scene_id = data.get("scene_id", "")
	battle_id = data.get("battle_id", "")
	description_ko = data.get("description_ko", "")
	connections = data.get("connections", [])
	position = pos
	name = node_id

## 노드 상태를 설정하고 비주얼을 갱신한다.
## @param new_state "locked" | "available" | "completed"
func set_state(new_state: String) -> void:
	state = new_state
	_update_visuals()

# ── 비주얼 구축 ──

## placeholder 아이콘과 라벨들을 생성한다.
func _build_visuals() -> void:
	# 아이콘 테두리 (배경보다 약간 크게)
	var border := ColorRect.new()
	border.custom_minimum_size = Vector2(ICON_SIZE + BORDER_WIDTH * 2, ICON_SIZE + BORDER_WIDTH * 2)
	border.size = Vector2(ICON_SIZE + BORDER_WIDTH * 2, ICON_SIZE + BORDER_WIDTH * 2)
	border.position = Vector2(-(ICON_SIZE + BORDER_WIDTH * 2) / 2.0, -(ICON_SIZE + BORDER_WIDTH * 2) / 2.0)
	border.color = Color(0.85, 0.75, 0.55, 0.8)
	add_child(border)

	# 아이콘 배경 (ColorRect)
	_icon_bg = ColorRect.new()
	_icon_bg.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_bg.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_bg.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0)
	_icon_bg.color = TYPE_COLORS.get(node_type, Color(0.4, 0.4, 0.4))
	add_child(_icon_bg)

	# 타입 아이콘 라벨
	_icon_label = Label.new()
	_icon_label.text = TYPE_ICONS.get(node_type, "?")
	_icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_label.size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon_label.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0)
	_icon_label.add_theme_font_size_override("font_size", 24)
	_icon_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_icon_label)

	# 체크마크 (완료 표시, 초기 비표시)
	_check_label = Label.new()
	_check_label.text = "v"
	_check_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_check_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_check_label.size = Vector2(16, 16)
	_check_label.position = Vector2(ICON_SIZE / 2.0 - 12, -ICON_SIZE / 2.0 - 4)
	_check_label.add_theme_font_size_override("font_size", 14)
	_check_label.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))
	_check_label.visible = false
	add_child(_check_label)

	# 잠금 아이콘 (잠금 표시, 초기 비표시)
	_lock_label = Label.new()
	_lock_label.text = "#"
	_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lock_label.size = Vector2(ICON_SIZE, ICON_SIZE)
	_lock_label.position = Vector2(-ICON_SIZE / 2.0, -ICON_SIZE / 2.0)
	_lock_label.add_theme_font_size_override("font_size", 22)
	_lock_label.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	_lock_label.visible = false
	add_child(_lock_label)

	# 이름 라벨 (호버 시 표시)
	_name_label = Label.new()
	_name_label.text = name_ko
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-100, -ICON_SIZE / 2.0 - 28)
	_name_label.size = Vector2(200, 24)
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
	_name_label.visible = false
	add_child(_name_label)

	# 클릭/호버 감지용 Area2D
	var area := Area2D.new()
	area.name = "ClickArea"
	var shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(HOVER_AREA_SIZE, HOVER_AREA_SIZE)
	shape.shape = rect_shape
	area.add_child(shape)
	area.input_pickable = true
	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)
	add_child(area)

# ── 비주얼 갱신 ──

## 상태에 따라 아이콘과 라벨의 표시를 갱신한다.
func _update_visuals() -> void:
	if _icon_bg == null:
		return
	# 이전 펄스 트윈 제거
	if _pulse_tween:
		_pulse_tween.kill()
		_pulse_tween = null
	match state:
		"locked":
			modulate = Color(0.45, 0.45, 0.45, 0.75)
			_icon_label.visible = false
			_lock_label.visible = true
			_check_label.visible = false
		"available":
			modulate = Color(1.0, 1.0, 1.0, 1.0)
			_icon_label.visible = true
			_lock_label.visible = false
			_check_label.visible = false
			_start_pulse()
		"completed":
			modulate = Color(0.7, 0.7, 0.7, 0.9)
			_icon_label.visible = true
			_lock_label.visible = false
			_check_label.visible = true

## available 상태 노드에 펄스 애니메이션을 적용한다.
func _start_pulse() -> void:
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "modulate", Color(1.3, 1.2, 0.9, 1.0), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# ── 입력 처리 ──

## Area2D 입력 이벤트 핸들러
## @param _viewport 뷰포트
## @param event 입력 이벤트
## @param _shape_idx 셰이프 인덱스
func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			# 잠긴 노드는 클릭 무시
			if state == "locked":
				return
			node_clicked.emit(node_id)

## 마우스 진입 시 이름 라벨 표시
func _on_mouse_entered() -> void:
	if state != "locked":
		_name_label.visible = true
		# 활성 노드는 호버 시 약간 밝게
		if state == "available":
			modulate = Color(1.2, 1.2, 1.0, 1.0)

## 마우스 이탈 시 이름 라벨 숨김
func _on_mouse_exited() -> void:
	_name_label.visible = false
	_update_visuals()

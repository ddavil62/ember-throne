## @fileoverview 세이브/로드 화면. 4슬롯(자동 1 + 수동 3) 표시, 세이브/로드 기능.
extends Control

# ── 모드 ──

## 화면 모드
enum Mode { SAVE, LOAD }

## 현재 모드
var mode: Mode = Mode.SAVE

# ── 내부 참조 ──

## 제목 라벨
var _title_label: Label = null
## 슬롯 컨테이너
var _slot_container: VBoxContainer = null
## 확인 다이얼로그
var _confirm_dialog: ConfirmationDialog = null
## 선택된 슬롯 번호
var _selected_slot: int = -1

# ── 슬롯 상수 ──

## 총 슬롯 수 (자동 1 + 수동 3)
const TOTAL_SLOTS := 4

# ── 라이프사이클 ──

func _ready() -> void:
	_build_ui()
	_refresh_slots()

func _unhandled_input(event: InputEvent) -> void:
	# ESC로 닫기
	if event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

# ── UI 구축 ──

## UI를 코드로 구축한다.
func _build_ui() -> void:
	# 풀스크린 반투명 배경
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# 중앙 패널
	var panel := PanelContainer.new()
	panel.anchors_preset = Control.PRESET_CENTER
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -250
	panel.offset_right = 300
	panel.offset_bottom = 250
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	# 제목
	_title_label = Label.new()
	_title_label.text = "저장하기" if mode == Mode.SAVE else "불러오기"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_title_label)

	# 구분선
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 슬롯 컨테이너
	_slot_container = VBoxContainer.new()
	_slot_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_slot_container)

	# 스페이서
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(spacer)

	# 닫기 버튼
	var close_btn := Button.new()
	close_btn.text = "닫기"
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(_close)
	vbox.add_child(close_btn)

	# 확인 다이얼로그
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.title = "확인"
	_confirm_dialog.confirmed.connect(_on_confirm)
	add_child(_confirm_dialog)

# ── 슬롯 갱신 ──

## 모든 슬롯 정보를 SaveManager에서 읽어 표시한다.
func _refresh_slots() -> void:
	# 기존 슬롯 위젯 제거
	for child: Node in _slot_container.get_children():
		child.queue_free()

	var sm: Node = get_node("/root/SaveManager")
	var all_info: Array = sm.get_all_save_info()

	for i in TOTAL_SLOTS:
		var slot_num: int = i  # 0=자동, 1~3=수동
		var info: Dictionary = all_info[i] if i < all_info.size() else {}
		_create_slot_widget(slot_num, info)

## 개별 슬롯 위젯을 생성한다.
## @param slot_num 슬롯 번호
## @param info 세이브 메타데이터
func _create_slot_widget(slot_num: int, info: Dictionary) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(560, 80)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT

	# 슬롯 이름
	var slot_label: String
	if slot_num == 0:
		slot_label = "[자동 세이브]"
	else:
		slot_label = "슬롯 %d" % slot_num

	if info.is_empty():
		# 빈 슬롯
		btn.text = "%s  -  비어있음" % slot_label
		if mode == Mode.LOAD:
			btn.disabled = true
	else:
		# 데이터가 있는 슬롯
		var timestamp: String = info.get("timestamp", "")
		var play_time: float = info.get("play_time", 0.0)
		var scene_id: String = info.get("scene_id", "")
		var time_str := _format_play_time(play_time)
		btn.text = "%s  |  씬: %s  |  시간: %s  |  %s" % [
			slot_label, scene_id, time_str, timestamp
		]

	# 자동 세이브 슬롯은 세이브 모드에서 수동 저장 불가
	if slot_num == 0 and mode == Mode.SAVE:
		btn.disabled = true

	btn.pressed.connect(_on_slot_pressed.bind(slot_num))
	_slot_container.add_child(btn)

# ── 슬롯 클릭 ──

## 슬롯 클릭 시 확인 다이얼로그를 표시한다.
## @param slot_num 클릭된 슬롯 번호
func _on_slot_pressed(slot_num: int) -> void:
	_selected_slot = slot_num
	if mode == Mode.SAVE:
		var sm: Node = get_node("/root/SaveManager")
		if sm.has_save(slot_num):
			_confirm_dialog.dialog_text = "슬롯 %d에 덮어쓰시겠습니까?" % slot_num
		else:
			_confirm_dialog.dialog_text = "슬롯 %d에 저장하시겠습니까?" % slot_num
	else:
		_confirm_dialog.dialog_text = "슬롯 %d을 불러오시겠습니까?" % slot_num
	_confirm_dialog.popup_centered()

## 확인 다이얼로그에서 확인 시 실행
func _on_confirm() -> void:
	if _selected_slot < 0:
		return
	var sm: Node = get_node("/root/SaveManager")
	if mode == Mode.SAVE:
		var success := sm.save_game(_selected_slot)
		if success:
			print("[SaveLoadScreen] 슬롯 %d 저장 완료" % _selected_slot)
		_refresh_slots()
	else:
		var success := sm.load_game(_selected_slot)
		if success:
			print("[SaveLoadScreen] 슬롯 %d 로드 완료" % _selected_slot)
			# 로드 성공 시 월드맵으로 전환
			var gm: Node = get_node("/root/GameManager")
			gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.5, gm.GameState.WORLD_MAP)
	_selected_slot = -1

# ── 유틸리티 ──

## 플레이타임을 HH:MM:SS 형식으로 포맷한다.
## @param seconds 총 플레이 시간 (초)
## @returns 포맷된 문자열
func _format_play_time(seconds: float) -> String:
	var hours := int(seconds) / 3600
	var minutes := (int(seconds) % 3600) / 60
	var secs := int(seconds) % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

## 화면을 닫고 이전 상태로 돌아간다.
func _close() -> void:
	queue_free()

# ── 외부 설정 ──

## 모드를 설정한다. _ready() 호출 전에 사용한다.
## @param new_mode Mode.SAVE 또는 Mode.LOAD
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	if _title_label:
		_title_label.text = "저장하기" if mode == Mode.SAVE else "불러오기"
	if _slot_container:
		_refresh_slots()

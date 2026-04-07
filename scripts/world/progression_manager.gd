## @fileoverview 월드맵 진행 관리. 노드 해금/완료 상태를 추적하고
## GameManager.flags와 연동하여 세이브/로드 시 진행 상태를 복원한다.
class_name ProgressionManagerClass
extends Node

# ── 상수 ──

## 해금된 노드 목록을 저장할 플래그 키
const FLAG_UNLOCKED_NODES := "unlocked_nodes"
## 완료된 노드 목록을 저장할 플래그 키
const FLAG_COMPLETED_NODES := "completed_nodes"
## 현재 위치 노드를 저장할 플래그 키
const FLAG_CURRENT_NODE := "current_node"

## 1막 시작 시 자동 해금되는 노드 ID
const INITIAL_NODE := "irhen_village"

## 막 전환 트리거 노드: 해당 노드 완료 시 다음 막으로 전환한다.
## { 노드 ID: 전환할 막 번호 }
const ACT_TRIGGER_NODES: Dictionary = {
	"irhen_road": 2,           # 1막 마지막 이동 노드 → 2막
	"crowfel_foothills": 3,    # 2막 마지막 전투 (볼드 합류) → 3막
	"ashen_sea_lord": 4,       # 3막 마지막 이벤트 (재의 군주 대화) → 4막
}

## 막 진입 시 강제 해금하는 노드 목록 (unlock_condition 무시).
## enter_act() 호출 시 해당 막의 진입 노드를 직접 해금한다.
const ACT_ENTRY_NODES: Dictionary = {
	2: ["silvaren_entrance"],
	3: ["ascalon_outskirts", "ascalon_city"],
	4: ["ascalon_outskirts_assault"],
}

# ── 내부 상태 ──

## 해금된 노드 ID 집합
var _unlocked: Dictionary = {}
## 완료된 노드 ID 집합
var _completed: Dictionary = {}
## 현재 위치 노드 ID
var current_node_id: String = ""

# ── 라이프사이클 ──

func _ready() -> void:
	_restore_from_flags()
	# 초기 상태: 해금된 노드가 하나도 없으면 첫 노드 해금
	if _unlocked.is_empty():
		unlock_node(INITIAL_NODE)
	# EventBus 연결 (전투 승리 시 자동 진행)
	var eb: Node = get_node("/root/EventBus")
	eb.battle_won.connect(_on_battle_won)
	eb.scene_ended.connect(_on_scene_ended)

# ── 노드 해금 ──

## 노드를 해금한다. 이미 해금된 노드는 무시한다.
## @param node_id 해금할 노드 ID
func unlock_node(node_id: String) -> void:
	if _unlocked.has(node_id):
		return
	_unlocked[node_id] = true
	_sync_to_flags()
	var eb: Node = get_node("/root/EventBus")
	eb.node_unlocked.emit(node_id)
	print("[ProgressionManager] 노드 해금: %s" % node_id)

## 여러 노드를 한번에 해금한다.
## @param node_ids 해금할 노드 ID 배열
func unlock_nodes(node_ids: Array) -> void:
	for nid: String in node_ids:
		unlock_node(nid)

# ── 노드 완료 ──

## 노드를 완료 처리하고, 연결된 다음 노드들을 자동 해금한다.
## 막 전환 트리거 노드인 경우 다음 막 진입도 수행한다.
## @param node_id 완료할 노드 ID
func complete_node(node_id: String) -> void:
	if not _unlocked.has(node_id):
		push_warning("[ProgressionManager] 해금되지 않은 노드 완료 시도: %s" % node_id)
		return
	_completed[node_id] = true
	current_node_id = node_id
	_sync_to_flags()
	# 연결된 다음 노드 자동 해금
	_unlock_connected_nodes(node_id)
	print("[ProgressionManager] 노드 완료: %s" % node_id)
	# 막 전환 트리거 확인
	if ACT_TRIGGER_NODES.has(node_id):
		var next_act: int = ACT_TRIGGER_NODES[node_id]
		_trigger_act_transition(next_act)

## 연결된 노드 중 해금 조건을 만족하는 노드를 자동 해금한다.
## @param node_id 완료된 노드 ID
func _unlock_connected_nodes(node_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	var node_data: Dictionary = dm.world_nodes.get(node_id, {})
	var connections: Array = node_data.get("connections", [])
	for connected_id: String in connections:
		var connected_data: Dictionary = dm.world_nodes.get(connected_id, {})
		if connected_data.is_empty():
			continue
		# 해금 조건 확인
		var condition: Variant = connected_data.get("unlock_condition")
		if condition == null or _check_unlock_condition(condition):
			unlock_node(connected_id)

## 해금 조건 문자열을 확인한다.
## 조건 형식: "scene_X-Y_clear" — 해당 씬 완료 여부 확인
## @param condition 조건 문자열
## @returns 조건 만족 여부
func _check_unlock_condition(condition: String) -> bool:
	if condition == "":
		return true
	# "scene_X-Y_clear" 형식 처리: 해당 scene_id의 노드가 완료되었는지 확인
	if condition.begins_with("scene_") and condition.ends_with("_clear"):
		var scene_id: String = condition.substr(6, condition.length() - 12)  # "scene_" 제거, "_clear" 제거
		return _is_scene_completed(scene_id)
	# GameManager 플래그로 직접 확인
	var gm: Node = get_node("/root/GameManager")
	return gm.get_flag(condition, false)

## 특정 scene_id에 해당하는 노드가 완료되었는지 확인한다.
## @param scene_id 씬 ID (예: "1-1", "2-4")
## @returns 완료 여부
func _is_scene_completed(scene_id: String) -> bool:
	var dm: Node = get_node("/root/DataManager")
	for nid: String in _completed:
		var node_data: Dictionary = dm.world_nodes.get(nid, {})
		if node_data.get("scene_id", "") == scene_id:
			return true
	return false

# ── 상태 조회 ──

## 노드가 해금되어 접근 가능한지 확인한다.
## @param node_id 노드 ID
## @returns 해금 여부
func is_node_available(node_id: String) -> bool:
	return _unlocked.has(node_id)

## 노드가 완료되었는지 확인한다.
## @param node_id 노드 ID
## @returns 완료 여부
func is_node_completed(node_id: String) -> bool:
	return _completed.has(node_id)

## 노드 상태를 문자열로 반환한다.
## @param node_id 노드 ID
## @returns "locked" | "available" | "completed"
func get_node_state(node_id: String) -> String:
	if _completed.has(node_id):
		return "completed"
	if _unlocked.has(node_id):
		return "available"
	return "locked"

## 해금된 모든 노드 ID 배열을 반환한다.
## @returns 해금된 노드 ID 배열
func get_available_nodes() -> Array[String]:
	var result: Array[String] = []
	for nid: String in _unlocked:
		result.append(nid)
	return result

## 완료된 모든 노드 ID 배열을 반환한다.
## @returns 완료된 노드 ID 배열
func get_completed_nodes() -> Array[String]:
	var result: Array[String] = []
	for nid: String in _completed:
		result.append(nid)
	return result

## 현재 진입 가능한(해금 + 미완료) 노드 목록을 반환한다.
## @returns 진입 가능 노드 ID 배열
func get_enterable_nodes() -> Array[String]:
	var result: Array[String] = []
	for nid: String in _unlocked:
		if not _completed.has(nid):
			result.append(nid)
		else:
			# 완료된 노드 중 상점/거점은 재방문 가능
			var dm: Node = get_node("/root/DataManager")
			var node_data: Dictionary = dm.world_nodes.get(nid, {})
			var ntype: String = node_data.get("type", "")
			if ntype in ["shop", "outpost", "wandering_battle"]:
				result.append(nid)
	return result

# ── 막(Act) 전환 ──

## 막별 기본 BGM (StoryManager.ACT_BGM과 동일)
const ACT_BGM: Dictionary = {
	1: "irhen_theme",
	2: "road_theme",
	3: "war_theme",
	4: "final_theme",
}

## 막 전환 트리거를 처리한다. current_act 플래그를 설정하고
## enter_act()를 호출하여 진입 노드를 해금, BGM도 변경한다.
## @param act 진입할 막 번호 (2~4)
func _trigger_act_transition(act: int) -> void:
	var gm: Node = get_node("/root/GameManager")
	var current_act: int = gm.get_flag("current_act", 1)
	if act <= current_act:
		return
	gm.set_flag("current_act", act)
	enter_act(act)
	# BGM 변경
	if ACT_BGM.has(act):
		var eb: Node = get_node("/root/EventBus")
		eb.bgm_change_requested.emit(ACT_BGM[act])
	print("[ProgressionManager] %d막 전환 트리거" % act)

## 새로운 막에 진입하여 해당 막의 진입 노드들을 해금한다.
## ACT_ENTRY_NODES에 정의된 노드는 unlock_condition을 무시하고 강제 해금하며,
## 그 외 해당 막의 노드 중 조건이 null인 것도 해금한다.
## @param act 진입할 막 번호 (1~4)
func enter_act(act: int) -> void:
	# ACT_ENTRY_NODES에 정의된 진입 노드 강제 해금
	if ACT_ENTRY_NODES.has(act):
		var entry_nodes: Array = ACT_ENTRY_NODES[act]
		for nid: String in entry_nodes:
			unlock_node(nid)
	# 해당 막의 노드 중 조건이 null인 것도 해금
	var dm: Node = get_node("/root/DataManager")
	for nid: String in dm.world_nodes:
		var node_data: Dictionary = dm.world_nodes[nid]
		if node_data.get("act", 0) == act:
			var condition: Variant = node_data.get("unlock_condition")
			if condition == null:
				unlock_node(nid)
	print("[ProgressionManager] %d막 노드 해금 처리" % act)

# ── EventBus 핸들러 ──

## 전투 승리 시 자동 노드 완료 처리
## @param battle_id 승리한 전투 ID
func _on_battle_won(battle_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	# battle_id에 해당하는 노드 찾기
	for nid: String in dm.world_nodes:
		var node_data: Dictionary = dm.world_nodes[nid]
		if node_data.get("battle_id", "") == battle_id:
			if _unlocked.has(nid) and not _completed.has(nid):
				complete_node(nid)
				break

## 씬 종료 시 자동 노드 완료 처리 (이벤트 노드용)
## @param scene_id 종료된 씬 ID
func _on_scene_ended(scene_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	for nid: String in dm.world_nodes:
		var node_data: Dictionary = dm.world_nodes[nid]
		if node_data.get("scene_id", "") == scene_id:
			var ntype: String = node_data.get("type", "")
			# 이벤트/여행 타입 노드는 씬 종료 시 완료
			if ntype in ["story_event", "travel"]:
				if _unlocked.has(nid) and not _completed.has(nid):
					complete_node(nid)

# ── 세이브/로드 연동 ──

## 현재 진행 상태를 GameManager.flags에 동기화한다.
func _sync_to_flags() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.set_flag(FLAG_UNLOCKED_NODES, _unlocked.keys())
	gm.set_flag(FLAG_COMPLETED_NODES, _completed.keys())
	gm.set_flag(FLAG_CURRENT_NODE, current_node_id)

## GameManager.flags로부터 진행 상태를 복원한다.
func _restore_from_flags() -> void:
	var gm: Node = get_node("/root/GameManager")
	_unlocked.clear()
	_completed.clear()
	var unlocked_arr: Variant = gm.get_flag(FLAG_UNLOCKED_NODES, [])
	if unlocked_arr is Array:
		for nid: String in unlocked_arr:
			_unlocked[nid] = true
	var completed_arr: Variant = gm.get_flag(FLAG_COMPLETED_NODES, [])
	if completed_arr is Array:
		for nid: String in completed_arr:
			_completed[nid] = true
	current_node_id = gm.get_flag(FLAG_CURRENT_NODE, "")

## 세이브 로드 후 진행 상태를 다시 불러온다.
func reload_from_save() -> void:
	_restore_from_flags()
	if _unlocked.is_empty():
		unlock_node(INITIAL_NODE)
	print("[ProgressionManager] 세이브에서 진행 상태 복원: 해금 %d / 완료 %d" % [
		_unlocked.size(), _completed.size()
	])

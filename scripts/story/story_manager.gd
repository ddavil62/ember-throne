## @fileoverview 4막 스토리 시퀀스 관리. 씬 흐름(대화->CG->전투->대화->다음 노드 해금),
## 엔딩 분기, 캐릭터 합류, 전직/유대 트리거를 처리한다.
class_name StoryManager
extends RefCounted

# ── 상수 ──

## 씬 종료 시 자동 합류하는 캐릭터 매핑 {scene_id: [{id, level}]}
## LEVEL-DESIGN.md 기준 캐릭터 합류 씬/레벨 (2026-04-07 갱신)
const CHARACTER_JOINS: Dictionary = {
	"1-1": [{"id": "kael", "level": 1}],
	"1-4": [{"id": "seria", "level": 1}],
	"1-5": [{"id": "grid", "level": 2}],
	"1-6": [{"id": "rinen", "level": 2}],
	"2-1": [{"id": "roc", "level": 6}, {"id": "nael", "level": 6}],
	"2-9": [{"id": "drana", "level": 10}],
	"2-10": [{"id": "voldt", "level": 11}],
	"3-1": [{"id": "irene", "level": 13}],
	"3-12": [{"id": "hazel", "level": 18}],
	"3-14": [{"id": "cyr", "level": 18}],
	"4-5": [{"id": "elmira", "level": 25}],
}

## 막(Act)별 기본 BGM 매핑
const ACT_BGM: Dictionary = {
	1: "irhen_theme",
	2: "road_theme",
	3: "war_theme",
	4: "final_theme",
}

## 엔딩 분기가 발생하는 씬 ID
const ENDING_BRANCH_SCENE := "4-8"

## 엔딩 A 분기 씬 ID (리넨 희생 루트)
const ENDING_A_SCENE := "4-8A"
## 엔딩 B 분기 씬 ID (리넨 기억 상실 루트)
const ENDING_B_SCENE := "4-8B"
## 엔딩 A 에필로그 씬 ID (리넨 희생)
const ENDING_A_EPILOGUE := "ending_a_epilogue"
## 엔딩 B 에필로그 씬 ID (리넨 기억 상실)
const ENDING_B_EPILOGUE := "ending_b_epilogue"

# ── 상태 변수 ──

## 현재 진행 중인 월드맵 노드 ID
var _current_node_id: String = ""

## 현재 노드의 데이터 (DataManager.world_nodes에서 조회)
var _current_node_data: Dictionary = {}

## 전투 후 재개할 scene_id (post_battle_scene_id 또는 원래 씬의 나머지 segments)
var _pending_post_battle: String = ""

## 전투가 발생한 씬 ID (전투 중 대화 일시정지 추적용)
var _battle_scene_id: String = ""

## 전직 시스템 참조 (외부 주입)
var _class_change_system = null  # ClassChangeSystem

## 유대 시스템 참조 (외부 주입)
var _bond_system = null  # BondSystem

# ── 초기화 ──

## 외부 시스템 주입 및 EventBus 시그널 연결.
## @param class_change_sys 전직 시스템 인스턴스
## @param bond_sys 유대 시스템 인스턴스
func init(class_change_sys, bond_sys) -> void:
	_class_change_system = class_change_sys
	_bond_system = bond_sys
	# EventBus 시그널 연결
	var eb: Node = _get_event_bus()
	if eb:
		eb.scene_ended.connect(_on_scene_ended)
		eb.battle_won.connect(_on_battle_won)
		eb.battle_lost.connect(_on_battle_lost)

# ── 스토리 노드 시작 ──

## 월드맵에서 선택한 노드의 스토리 시퀀스를 시작한다.
## 노드 타입에 따라 대화/전투/메뉴 등 적절한 흐름으로 분기한다.
## @param node_id 월드맵 노드 ID
func start_story_node(node_id: String) -> void:
	var dm: Node = _get_data_manager()
	if not dm:
		push_error("[StoryManager] DataManager를 찾을 수 없음")
		return

	var node_data: Dictionary = dm.world_nodes.get(node_id, {})
	if node_data.is_empty():
		push_error("[StoryManager] 존재하지 않는 노드: %s" % node_id)
		return

	_current_node_id = node_id
	_current_node_data = node_data
	_pending_post_battle = ""
	_battle_scene_id = ""

	var node_type: String = node_data.get("type", "")
	var scene_id: String = node_data.get("scene_id", "")
	var battle_id: String = node_data.get("battle_id", "")

	print("[StoryManager] 노드 시작: %s (타입: %s)" % [node_id, node_type])

	match node_type:
		"story_battle":
			_start_story_battle(scene_id, battle_id, node_data)
		"story_event":
			_start_story_event(scene_id)
		"travel":
			_start_travel(scene_id)
		"shop", "outpost":
			_start_menu()
		"wandering_battle":
			_start_wandering_battle(battle_id)
		_:
			push_warning("[StoryManager] 알 수 없는 노드 타입: %s" % node_type)

# ── 타입별 시작 처리 ──

## 스토리 전투 시작: 대화 → 전투 → (후일담) → 노드 완료
## @param scene_id 대화 씬 ID
## @param battle_id 전투 ID
## @param node_data 노드 데이터
func _start_story_battle(scene_id: String, battle_id: String, node_data: Dictionary) -> void:
	# 전투 후 대화 씬이 별도로 지정되어 있으면 저장
	var post_battle: String = node_data.get("post_battle_scene_id", "")
	_pending_post_battle = post_battle
	_battle_scene_id = scene_id

	# 전투 전 대화가 있으면 대화부터 시작
	# (DialogueManager가 battle_start segment를 만나면 전투로 전환)
	if scene_id != "":
		var dlg: Node = _get_dialogue_manager()
		if dlg:
			dlg.start_scene(scene_id)
		else:
			push_error("[StoryManager] DialogueManager를 찾을 수 없음")
	else:
		# 대화 없이 바로 전투
		_start_battle_direct(battle_id)

## 스토리 이벤트 시작: 대화만 → 노드 완료
## @param scene_id 대화 씬 ID
func _start_story_event(scene_id: String) -> void:
	if scene_id == "":
		push_warning("[StoryManager] story_event에 scene_id가 없음")
		_complete_current_node()
		return

	var dlg: Node = _get_dialogue_manager()
	if dlg:
		dlg.start_scene(scene_id)
	else:
		push_error("[StoryManager] DialogueManager를 찾을 수 없음")

## 이동 통로 시작: 대화(이동 이벤트) → 노드 완료
## @param scene_id 대화 씬 ID
func _start_travel(scene_id: String) -> void:
	if scene_id != "":
		var dlg: Node = _get_dialogue_manager()
		if dlg:
			dlg.start_scene(scene_id)
			return
	# scene_id가 없으면 즉시 완료
	_complete_current_node()

## 상점/거점 노드 시작: 메뉴 상태로 전환
func _start_menu() -> void:
	var gm: Node = _get_game_manager()
	if gm:
		gm.change_state(gm.GameState.MENU)

## 유랑 전투 시작: 전투 직행
## @param battle_id 전투 ID
func _start_wandering_battle(battle_id: String) -> void:
	if battle_id == "":
		push_warning("[StoryManager] wandering_battle에 battle_id가 없음")
		return
	_start_battle_direct(battle_id)

## 전투 씬을 직접 시작한다. (대화 없이 즉시 전투)
## @param battle_id 전투 ID
func _start_battle_direct(battle_id: String) -> void:
	var gm: Node = _get_game_manager()
	if gm:
		gm.current_battle_id = battle_id
		gm.change_state(gm.GameState.DEPLOYMENT)
	print("[StoryManager] 전투 직행: %s" % battle_id)

# ── EventBus 핸들러 ──

## 씬(대화) 종료 시 호출. 캐릭터 합류, 전직, 유대 트리거를 확인하고
## 노드 타입에 따라 후속 처리를 결정한다.
## @param scene_id 종료된 씬 ID
func _on_scene_ended(scene_id: String) -> void:
	# 캐릭터 합류 확인
	_check_character_joins(scene_id)

	# 전직 트리거 확인
	_check_class_change_trigger(scene_id)

	# 유대 트리거 확인
	_check_bond_trigger(scene_id)

	# 에필로그 종료 → 크레딧 전환
	if scene_id == ENDING_A_EPILOGUE or scene_id == ENDING_B_EPILOGUE:
		_start_credits()
		return

	# 분기 씬(4-8A/4-8B) 종료 → 에필로그 시작
	if scene_id == ENDING_A_SCENE:
		var dlg: Node = _get_dialogue_manager()
		if dlg:
			print("[StoryManager] 4-8A 종료 → 엔딩 A 에필로그 시작")
			dlg.start_scene(ENDING_A_EPILOGUE)
		return
	if scene_id == ENDING_B_SCENE:
		var dlg: Node = _get_dialogue_manager()
		if dlg:
			print("[StoryManager] 4-8B 종료 → 엔딩 B 에필로그 시작")
			dlg.start_scene(ENDING_B_EPILOGUE)
		return

	# 엔딩 분기 확인 (4-8 종료 시 4-8A/4-8B 씬 시작)
	if scene_id == ENDING_BRANCH_SCENE:
		_check_ending_branch()
		return

	# 현재 노드와 관련된 씬인지 확인
	var node_scene: String = _current_node_data.get("scene_id", "")
	var post_battle: String = _current_node_data.get("post_battle_scene_id", "")

	# 전투 후 대화 씬이 종료된 경우 → 노드 완료
	if scene_id == post_battle and post_battle != "":
		_complete_current_node()
		return

	# story_event / travel 타입은 씬 종료 = 노드 완료
	var node_type: String = _current_node_data.get("type", "")
	if node_type in ["story_event", "travel"] and scene_id == node_scene:
		_complete_current_node()
		return

	# story_battle 타입에서 대화 종료 후 전투가 없었다면
	# (battle_start segment 없이 씬이 끝난 경우)
	# → 전투가 대화 안에서 트리거되므로 여기서는 추가 처리 불필요

## 전투 승리 시 호출. 전투 후 대화 재개 또는 노드 완료를 처리한다.
## @param battle_id 승리한 전투 ID
func _on_battle_won(battle_id: String) -> void:
	var node_battle: String = _current_node_data.get("battle_id", "")

	# 현재 노드의 전투인지 확인
	if battle_id != node_battle:
		return

	print("[StoryManager] 전투 승리: %s" % battle_id)

	# 전투 후 대화 재개
	if _pending_post_battle != "":
		var post_scene: String = _pending_post_battle
		_pending_post_battle = ""
		var dlg: Node = _get_dialogue_manager()
		if dlg:
			dlg.start_scene(post_scene)
		return

	# 대화 중 battle_start segment로 전투가 시작된 경우
	# DialogueManager의 남은 segments를 이어서 진행
	if _battle_scene_id != "":
		var dlg: Node = _get_dialogue_manager()
		if dlg and dlg.current_script.size() > 0:
			# DialogueManager 내부에서 _active가 false로 된 상태이므로 재활성화
			dlg._active = true
			var gm: Node = _get_game_manager()
			if gm:
				gm.change_state(gm.GameState.DIALOGUE)
			dlg.advance()
			return

	# 전투 후 대화 없음 → 노드 완료
	_complete_current_node()

## 전투 패배 시 호출. 월드맵으로 복귀한다.
## @param battle_id 패배한 전투 ID
func _on_battle_lost(battle_id: String) -> void:
	print("[StoryManager] 전투 패배: %s" % battle_id)
	_pending_post_battle = ""
	_battle_scene_id = ""

	# 월드맵으로 복귀 (노드는 미완료 상태 유지)
	var gm: Node = _get_game_manager()
	if gm:
		gm.change_state(gm.GameState.WORLD_MAP)

# ── 노드 완료 ──

## 현재 노드를 완료 처리하고 월드맵으로 복귀한다.
func _complete_current_node() -> void:
	if _current_node_id == "":
		return

	var pm: Node = _get_progression_manager()
	if pm:
		pm.complete_node(_current_node_id)

	print("[StoryManager] 노드 완료: %s" % _current_node_id)

	# 상태 초기화
	var completed_id := _current_node_id
	_current_node_id = ""
	_current_node_data = {}
	_pending_post_battle = ""
	_battle_scene_id = ""

	# 월드맵으로 복귀
	var gm: Node = _get_game_manager()
	if gm:
		gm.change_state(gm.GameState.WORLD_MAP)

# ── 캐릭터 합류 ──

## 씬 종료 시 해당 씬에서 합류하는 캐릭터가 있는지 확인하고 파티에 추가한다.
## @param scene_id 종료된 씬 ID
func _check_character_joins(scene_id: String) -> void:
	if not CHARACTER_JOINS.has(scene_id):
		return

	var joins: Array = CHARACTER_JOINS[scene_id]
	var pm: Node = _get_party_manager()
	if not pm:
		push_error("[StoryManager] PartyManager를 찾을 수 없음")
		return

	for join_data: Dictionary in joins:
		var char_id: String = join_data.get("id", "")
		var level: int = join_data.get("level", 1)
		if char_id == "":
			continue

		# 이미 파티에 있으면 건너뛰기
		var existing: Dictionary = pm.get_party_member(char_id)
		if existing.size() > 0:
			continue

		pm.add_character(char_id, level)
		print("[StoryManager] 캐릭터 합류: %s (Lv.%d) at scene %s" % [char_id, level, scene_id])

# ── 막(Act) 전환 ──

## 새로운 막으로 진입한다. 플래그 설정, 월드맵 해금, BGM 변경을 수행한다.
## @param act 진입할 막 번호 (1~4)
func advance_to_act(act: int) -> void:
	var gm: Node = _get_game_manager()
	if gm:
		gm.set_flag("current_act", act)

	var pm: Node = _get_progression_manager()
	if pm:
		pm.enter_act(act)

	# 막별 기본 BGM 변경
	if ACT_BGM.has(act):
		var eb: Node = _get_event_bus()
		if eb:
			eb.bgm_change_requested.emit(ACT_BGM[act])

	# 이전 막 클리어 업적 + 데모 모드 체크
	var sm: Node = _get_steam_manager()
	if sm:
		# 2막 진입 = 1막 클리어, 3막 진입 = 2막 클리어, ...
		if act > 1:
			sm.on_act_cleared(act - 1)
	# 데모 모드: 1막 종료(2막 진입) 시 데모 종료 화면 전환
	if act == 2 and gm and gm.check_demo_end():
		return
	print("[StoryManager] %d막 진입" % act)

# ── 크레딧 전환 ──

## 에필로그 종료 후 크레딧 화면을 시작한다.
func _start_credits() -> void:
	print("[StoryManager] 에필로그 종료 → 크레딧 전환")
	var gm: Node = _get_game_manager()
	if not gm:
		return

	# 크레딧 씬 로드 및 표시
	var credits_scene := load("res://scenes/ui/credits_screen.tscn") as PackedScene
	if credits_scene == null:
		push_warning("[StoryManager] credits_screen.tscn 로드 실패")
		_complete_current_node()
		return

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		var credits: Node = credits_scene.instantiate()
		tree.root.add_child(credits)
		# CreditsScreen 내부에서 타이틀 전환 처리
		credits.start_credits()

# ── 엔딩 분기 ──

## 엔딩 분기 플래그를 확인하고 해당 에필로그 씬을 시작한다.
## Act 4-8 선택지에서 설정된 플래그를 기반으로 분기한다.
func _check_ending_branch() -> void:
	var gm: Node = _get_game_manager()
	if not gm:
		return

	var dlg: Node = _get_dialogue_manager()
	if not dlg:
		return

	if gm.get_flag("ending_a_chosen", false):
		# 엔딩 A: 리넨 희생 → 4-8A 분기 씬 재생 후 에필로그
		print("[StoryManager] 엔딩 A 분기 → 4-8A 씬 시작")
		dlg.start_scene(ENDING_A_SCENE)
	elif gm.get_flag("ending_b_chosen", false):
		# 엔딩 B: 리넨 기억 상실 → 4-8B 분기 씬 재생 후 에필로그
		print("[StoryManager] 엔딩 B 분기 → 4-8B 씬 시작")
		dlg.start_scene(ENDING_B_SCENE)
	else:
		# 분기 플래그가 설정되지 않은 경우 (안전 장치)
		push_warning("[StoryManager] 엔딩 분기 플래그 미설정, 엔딩 A로 기본 진행")
		gm.set_flag("ending_a_chosen", true)
		dlg.start_scene(ENDING_A_SCENE)

# ── 전직 트리거 ──

## 씬 종료 시 전직 조건을 확인한다.
## DataManager.class_changes에서 trigger_scene이 현재 scene_id와 일치하는 항목을 찾는다.
## @param scene_id 종료된 씬 ID
func _check_class_change_trigger(scene_id: String) -> void:
	if _class_change_system == null:
		return

	var dm: Node = _get_data_manager()
	if not dm:
		return

	for entry: Dictionary in dm.class_changes:
		var trigger: String = entry.get("trigger_scene", "")
		if trigger == scene_id:
			var char_id: String = entry.get("character_id", "")
			var new_class: String = entry.get("new_class", "")
			if char_id != "" and new_class != "":
				_class_change_system.trigger_class_change(char_id, new_class)
				print("[StoryManager] 전직 트리거: %s -> %s (scene: %s)" % [
					char_id, new_class, scene_id
				])

# ── 유대 트리거 ──

## 씬 종료 시 유대 레벨 상승 조건을 확인한다.
## DataManager.bonds에서 lv2_trigger.scene 또는 lv3_trigger.scene이
## 현재 scene_id와 일치하는 항목을 찾는다.
## @param scene_id 종료된 씬 ID
func _check_bond_trigger(scene_id: String) -> void:
	if _bond_system == null:
		return

	var dm: Node = _get_data_manager()
	if not dm:
		return

	for bond: Dictionary in dm.bonds:
		var bond_id: String = bond.get("id", "")
		if bond_id == "":
			continue

		# Lv.2 트리거 확인
		var lv2: Dictionary = bond.get("lv2_trigger", {})
		if lv2.get("scene", "") == scene_id:
			_bond_system.advance_bond(bond_id, 2)
			print("[StoryManager] 유대 Lv.2 트리거: %s (scene: %s)" % [bond_id, scene_id])

		# Lv.3 트리거 확인
		var lv3: Dictionary = bond.get("lv3_trigger", {})
		if lv3.get("scene", "") == scene_id:
			_bond_system.advance_bond(bond_id, 3)
			print("[StoryManager] 유대 Lv.3 트리거: %s (scene: %s)" % [bond_id, scene_id])

# ── 상태 조회 ──

## 현재 진행 중인 노드 ID를 반환한다.
## @returns 현재 노드 ID (진행 중이 아니면 빈 문자열)
func get_current_node_id() -> String:
	return _current_node_id

## 스토리 노드 진행 중인지 확인한다.
## @returns 진행 중 여부
func is_in_story_node() -> bool:
	return _current_node_id != ""

## 전투 후 대화 대기 중인지 확인한다.
## @returns 전투 후 대화 대기 여부
func has_pending_post_battle() -> bool:
	return _pending_post_battle != ""

# ── 싱글톤 접근 헬퍼 ──

## EventBus 싱글톤을 반환한다.
## @returns EventBus 노드 또는 null
func _get_event_bus() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("EventBus")
	return null

## GameManager 싱글톤을 반환한다.
## @returns GameManager 노드 또는 null
func _get_game_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("GameManager")
	return null

## DialogueManager 싱글톤을 반환한다.
## @returns DialogueManager 노드 또는 null
func _get_dialogue_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("DialogueManager")
	return null

## ProgressionManager 싱글톤을 반환한다.
## @returns ProgressionManager 노드 또는 null
func _get_progression_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("ProgressionManager")
	return null

## PartyManager 싱글톤을 반환한다.
## @returns PartyManager 노드 또는 null
func _get_party_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("PartyManager")
	return null

## DataManager 싱글톤을 반환한다.
## @returns DataManager 노드 또는 null
func _get_data_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("DataManager")
	return null

## SteamManager 싱글톤을 반환한다.
## @returns SteamManager 노드 또는 null
func _get_steam_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree and tree.root:
		return tree.root.get_node_or_null("SteamManager")
	return null

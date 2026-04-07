## @fileoverview 비주얼 리그레션 테스트 러너. 핵심 씬을 순차 로드하여
## 뷰포트를 캡처하고 레퍼런스 이미지와 픽셀 단위 비교를 수행한다.
## run_visual_tests.js가 이 스크립트를 임시 autoload로 등록하여 실행한다.
extends Node

# ── 테스트 설정 ──

## 픽셀 diff 비율 임계값 (이 이상이면 FAIL)
const DIFF_THRESHOLD := 0.02
## 개별 픽셀 채널 허용 오차 (0~1)
const PIXEL_TOLERANCE := 0.08
## 스크린샷 출력 디렉토리
const SCREENSHOTS_DIR := "res://tests/visual/screenshots"
## 레퍼런스 이미지 디렉토리
const REFERENCES_DIR := "res://tests/visual/references"

# ── 테스트 케이스 ──

## 각 테스트 케이스 정의
## - name: 테스트 이름 (파일명으로도 사용)
## - scene: 로드할 씬 경로
## - wait_frames: 렌더링 안정화 대기 프레임 수
## - setup: 씬 로드 전 실행할 셋업 ("new_game" 등)
var _tests: Array[Dictionary] = [
	{
		"name": "main_menu",
		"scene": "res://scenes/main/main_menu.tscn",
		"wait_frames": 30,
	},
	{
		"name": "world_map_new_game",
		"scene": "res://scenes/world/world_map.tscn",
		"wait_frames": 60,
		"setup": "new_game",
	},
	{
		"name": "battle_scene",
		"scene": "res://scenes/battle/battle_scene.tscn",
		"wait_frames": 90,
		"setup": "battle",
	},
	{
		"name": "dialogue_scene",
		"scene": "res://scenes/dialogue/dialogue_scene.tscn",
		"wait_frames": 60,
		"setup": "dialogue",
	},
]

# ── 내부 상태 ──

var _current: int = -1
var _frames: int = 0
var _results: Array[Dictionary] = []
var _state: String = "init"

# ── 라이프사이클 ──

func _ready() -> void:
	print("[VisualTest] ============================================")
	print("[VisualTest] Ember Throne 비주얼 리그레션 테스트")
	print("[VisualTest] 테스트 수: %d" % _tests.size())
	print("[VisualTest] ============================================")
	# 디렉토리 생성
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SCREENSHOTS_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REFERENCES_DIR))
	# main_menu가 메인 씬으로 이미 로딩 중 — 첫 번째 테스트로 사용
	_current = 0
	_frames = 0
	_state = "stabilizing"

func _process(_delta: float) -> void:
	match _state:
		"stabilizing":
			_frames += 1
			if _frames >= _tests[_current].get("wait_frames", 30):
				_capture_and_compare()
				_load_next()
		"scene_changing":
			# change_scene_to_file 후 씬 교체 대기
			_frames += 1
			if _frames >= 5:
				_state = "stabilizing"
				_frames = 0

# ── 테스트 진행 ──

## 다음 테스트 케이스를 로드한다.
func _load_next() -> void:
	_current += 1
	if _current >= _tests.size():
		_report_and_quit()
		return

	var test := _tests[_current]
	print("\n[VisualTest] --- %s ---" % test.name)

	# 셋업 실행
	var setup: String = test.get("setup", "")
	if setup == "new_game":
		_setup_new_game()
	elif setup == "battle":
		_setup_battle()
	elif setup == "dialogue":
		_setup_dialogue()

	get_tree().change_scene_to_file(test.scene)
	_frames = 0
	_state = "scene_changing"

## 새 게임 상태를 초기화한다 (월드맵 진입 전 필수).
func _setup_new_game() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.flags.clear()
	gm.difficulty = "normal"
	gm.current_scene_id = "1-1"
	gm.play_time = 0.0
	# PartyManager 초기화 (타이틀에서 호출하는 것과 동일)
	var pm: Node = get_node("/root/PartyManager")
	if pm.has_method("init_default_party"):
		pm.init_default_party()

## 전투 씬 진입을 위한 셋업 (battle_01)
func _setup_battle() -> void:
	_setup_new_game()
	var gm: Node = get_node("/root/GameManager")
	gm.current_battle_id = "battle_01"
	gm.current_scene_id = "1-3"

## 대화 씬 진입을 위한 셋업 (act1 첫 번째 씬)
func _setup_dialogue() -> void:
	_setup_new_game()
	var gm: Node = get_node("/root/GameManager")
	gm.current_scene_id = "1-1"

# ── 캡처 및 비교 ──

## 현재 뷰포트를 캡처하고 레퍼런스와 비교한다.
func _capture_and_compare() -> void:
	var test := _tests[_current]
	var img := get_viewport().get_texture().get_image()

	# 스크린샷 저장
	var ss_path := ProjectSettings.globalize_path("%s/%s.png" % [SCREENSHOTS_DIR, test.name])
	img.save_png(ss_path)
	print("[VisualTest] 스크린샷: %s" % ss_path)

	# 레퍼런스 로드
	var ref_path := ProjectSettings.globalize_path("%s/%s.png" % [REFERENCES_DIR, test.name])
	if not FileAccess.file_exists(ref_path):
		# 레퍼런스 없음 → 최초 생성
		img.save_png(ref_path)
		_results.append({
			"name": test.name, "pass": true, "diff": 0.0,
			"note": "레퍼런스 최초 생성",
		})
		print("[VisualTest] 레퍼런스 없음 → 최초 생성 완료")
		return

	var ref_img := Image.load_from_file(ref_path)
	if ref_img == null or ref_img.is_empty():
		_results.append({
			"name": test.name, "pass": false, "diff": 1.0,
			"note": "레퍼런스 로드 실패",
		})
		return

	# 픽셀 비교
	var result := _compare_images(img, ref_img)
	result["name"] = test.name
	_results.append(result)

	var status := "PASS" if result.pass else "FAIL"
	print("[VisualTest] %s (diff: %.2f%%)" % [status, result.diff * 100.0])

	# 실패 시 차이 이미지 생성
	if not result.pass:
		var diff_img := _generate_diff_image(img, ref_img)
		var diff_path := ProjectSettings.globalize_path(
			"%s/%s_diff.png" % [SCREENSHOTS_DIR, test.name]
		)
		diff_img.save_png(diff_path)
		print("[VisualTest] 차이 이미지: %s" % diff_path)

## 두 이미지를 픽셀 단위로 비교한다.
## @param actual 캡처된 이미지
## @param reference 레퍼런스 이미지
## @returns {pass: bool, diff: float, note?: String}
func _compare_images(actual: Image, reference: Image) -> Dictionary:
	if actual.get_size() != reference.get_size():
		return {
			"pass": false, "diff": 1.0,
			"note": "크기 불일치 (%s vs %s)" % [
				str(actual.get_size()), str(reference.get_size())
			],
		}

	var w := actual.get_width()
	var h := actual.get_height()
	var total := w * h
	var diff_count := 0

	for y in range(h):
		for x in range(w):
			var a := actual.get_pixel(x, y)
			var r := reference.get_pixel(x, y)
			if (absf(a.r - r.r) > PIXEL_TOLERANCE
				or absf(a.g - r.g) > PIXEL_TOLERANCE
				or absf(a.b - r.b) > PIXEL_TOLERANCE):
				diff_count += 1

	var diff_ratio := float(diff_count) / float(total)
	return {"pass": diff_ratio <= DIFF_THRESHOLD, "diff": diff_ratio}

## 차이 영역을 빨간색으로 하이라이트한 diff 이미지를 생성한다.
## @param actual 캡처된 이미지
## @param reference 레퍼런스 이미지
## @returns 차이 이미지
func _generate_diff_image(actual: Image, reference: Image) -> Image:
	var w := mini(actual.get_width(), reference.get_width())
	var h := mini(actual.get_height(), reference.get_height())
	var diff := Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in range(h):
		for x in range(w):
			var a := actual.get_pixel(x, y)
			var r := reference.get_pixel(x, y)
			if (absf(a.r - r.r) > PIXEL_TOLERANCE
				or absf(a.g - r.g) > PIXEL_TOLERANCE
				or absf(a.b - r.b) > PIXEL_TOLERANCE):
				# 차이 영역: 빨간색
				diff.set_pixel(x, y, Color(1.0, 0.0, 0.0, 0.8))
			else:
				# 일치 영역: 어둡게
				diff.set_pixel(x, y, Color(a.r * 0.3, a.g * 0.3, a.b * 0.3, 1.0))
	return diff

# ── 결과 리포트 ──

## 테스트 결과를 출력하고 종료한다.
func _report_and_quit() -> void:
	var passed := 0
	var failed := 0

	print("\n[VisualTest] ============================================")
	print("[VisualTest] 결과 요약")
	print("[VisualTest] ============================================")

	for r in _results:
		var status := "PASS" if r.pass else "FAIL"
		var note := ""
		if r.has("note"):
			note = " (%s)" % str(r.note)
		print("[VisualTest]   %s: %s — diff %.2f%%%s" % [
			str(r.name), status, r.get("diff", 0.0) * 100.0, note
		])
		if r.pass:
			passed += 1
		else:
			failed += 1

	print("[VisualTest] --------------------------------------------")
	print("[VisualTest] 통과: %d / 실패: %d / 합계: %d" % [passed, failed, _results.size()])
	print("[VisualTest] ============================================")

	get_tree().quit(1 if failed > 0 else 0)

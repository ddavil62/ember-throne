## @fileoverview 스프라이트 로더 유틸. sprite_id로 PNG 파일을 로드하여
## AnimatedSprite2D에 사용할 SpriteFrames 리소스를 생성한다.
## 플레이어 캐릭터와 적 유닛 모두 지원한다.
class_name SpriteLoader
extends RefCounted

# ── 상수 ──

## 8방향 rotation 파일명 → 애니메이션 접미사 매핑
## 파일: south.png, south-east.png 등 (하이픈 구분)
## 애니메이션: idle_south, idle_south_east 등 (언더스코어 구분)
const DIRECTIONS: Array[Dictionary] = [
	{"file": "south", "anim": "south"},
	{"file": "south-east", "anim": "south_east"},
	{"file": "east", "anim": "east"},
	{"file": "north-east", "anim": "north_east"},
	{"file": "north", "anim": "north"},
	{"file": "north-west", "anim": "north_west"},
	{"file": "west", "anim": "west"},
	{"file": "south-west", "anim": "south_west"},
]

## 기본 애니메이션 FPS
const DEFAULT_FPS: float = 8.0

## idle 애니메이션 FPS (breathing-idle)
const IDLE_FPS: float = 6.0

## JSON sprite_id → 실제 디렉토리명 별칭 매핑
## PixelLab 캐릭터 이름과 게임 데이터의 sprite_id가 다른 경우 사용
const SPRITE_ALIASES: Dictionary = {
	"annette_adjutant": "anette_lieutenant",
	"ash_evil_eye": "ash_mage_eye",
	"ashen_lord_vanguard": "boss_ash_warlord",
	"corrupted_morgan": "boss_corrupted_morgan",
	"lucid": "boss_lucid",
	"secret_police_spy": "secret_police_agent",
	"secret_police_officer": "secret_police_commander",
}

# ── 공개 함수 ──

## sprite_id에 해당하는 SpriteFrames를 생성하여 반환한다.
## 플레이어 캐릭터는 assets/sprites/{sprite_id}/ 에서,
## 적 유닛은 assets/sprites/enemies/{sprite_id}/ 에서 탐색한다.
## 파일이 없으면 null을 반환한다.
## @param sprite_id 스프라이트 식별자 (캐릭터 id 또는 적 sprite_id)
## @param is_enemy 적 유닛 여부 (true면 enemies/ 하위 탐색)
## @returns SpriteFrames 또는 null
static func load_sprite_frames(sprite_id: String, is_enemy: bool = false) -> SpriteFrames:
	var resolved_id: String = sprite_id
	var base_path: String = _build_base_path(resolved_id, is_enemy)

	# rotation 디렉토리 존재 확인 (south.png 필수)
	var south_path: String = base_path + "/rotations/south.png"
	if not ResourceLoader.exists(south_path):
		# 별칭으로 재시도
		if SPRITE_ALIASES.has(sprite_id):
			resolved_id = SPRITE_ALIASES[sprite_id]
			base_path = _build_base_path(resolved_id, is_enemy)
			south_path = base_path + "/rotations/south.png"
			if not ResourceLoader.exists(south_path):
				return null
		else:
			return null

	var frames := SpriteFrames.new()
	# 기본 "default" 애니메이션 제거
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# 8방향 idle 로딩
	var loaded_any: bool = false
	for dir_info: Dictionary in DIRECTIONS:
		var file_name: String = dir_info["file"]
		var anim_suffix: String = dir_info["anim"]
		var anim_name: String = "idle_" + anim_suffix

		var tex_path: String = base_path + "/rotations/" + file_name + ".png"
		if not ResourceLoader.exists(tex_path):
			continue

		var tex: Texture2D = load(tex_path) as Texture2D
		if tex == null:
			continue

		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, IDLE_FPS)
		frames.set_animation_loop(anim_name, true)
		frames.add_frame(anim_name, tex)
		loaded_any = true

	if not loaded_any:
		return null

	# 멀티프레임 애니메이션 로딩 (animations/ 디렉토리)
	_load_animations(frames, base_path)

	return frames

## 유닛의 facing 방향 문자열을 idle 애니메이션명으로 변환한다.
## @param facing 방향 문자열 (예: "south_west")
## @returns 애니메이션명 (예: "idle_south_west")
static func facing_to_anim(facing: String) -> String:
	return "idle_" + facing

# ── 내부 함수 ──

## sprite_id와 팀 정보로 기본 경로를 구성한다.
## @param sid 스프라이트 ID (또는 별칭 해석된 ID)
## @param is_enemy 적 유닛 여부
## @returns 기본 경로 문자열
static func _build_base_path(sid: String, is_enemy: bool) -> String:
	if is_enemy:
		return "res://assets/sprites/enemies/" + sid
	return "res://assets/sprites/" + sid

## animations/ 하위의 멀티프레임 애니메이션을 로드한다.
## 구조: animations/{anim_name}/{direction}/frame_000.png, frame_001.png, ...
## @param frames 대상 SpriteFrames
## @param base_path 스프라이트 기본 경로
static func _load_animations(frames: SpriteFrames, base_path: String) -> void:
	var anim_base: String = base_path + "/animations"

	# 알려진 애니메이션 목록 (PixelLab 출력 기준)
	var known_anims: Array[Dictionary] = [
		{"folder": "breathing-idle", "prefix": "breathe", "fps": IDLE_FPS},
		{"folder": "walk", "prefix": "walk", "fps": DEFAULT_FPS},
		{"folder": "cross-punch", "prefix": "attack", "fps": DEFAULT_FPS},
		{"folder": "fireball", "prefix": "cast", "fps": DEFAULT_FPS},
		{"folder": "taking-punch", "prefix": "hit", "fps": DEFAULT_FPS},
		{"folder": "falling-back-death", "prefix": "death", "fps": DEFAULT_FPS},
	]

	for anim_info: Dictionary in known_anims:
		var folder: String = anim_info["folder"]
		var prefix: String = anim_info["prefix"]
		var fps: float = anim_info["fps"]

		for dir_info: Dictionary in DIRECTIONS:
			var dir_file: String = dir_info["file"]
			var dir_anim: String = dir_info["anim"]
			var anim_name: String = prefix + "_" + dir_anim

			# 첫 프레임 존재 확인
			var first_frame_path: String = anim_base + "/" + folder + "/" + dir_file + "/frame_000.png"
			if not ResourceLoader.exists(first_frame_path):
				continue

			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, fps)
			# death는 루프하지 않음
			frames.set_animation_loop(anim_name, prefix != "death")

			# 프레임 순회 (최대 32프레임 검색)
			for i: int in range(32):
				var frame_path: String = anim_base + "/" + folder + "/" + dir_file + "/frame_%03d.png" % i
				if not ResourceLoader.exists(frame_path):
					break
				var tex: Texture2D = load(frame_path) as Texture2D
				if tex != null:
					frames.add_frame(anim_name, tex)

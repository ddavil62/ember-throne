## @fileoverview 전투 맵 매니저. 맵 로드, 유닛 관리, 하이라이트 표시, 카메라 제어를 담당한다.
extends Node2D

# ── 상수 ──

## 카메라 스크롤 속도 (픽셀/초)
const CAMERA_SCROLL_SPEED: float = 300.0

## 하이라이트 색상
const COLOR_MOVE: Color = Color(0.2, 0.4, 0.9, 0.35)       # 이동 범위 (파란색 반투명)
const COLOR_ATTACK: Color = Color(0.9, 0.2, 0.2, 0.35)      # 공격 범위 (빨간색 반투명)
const COLOR_DEPLOY: Color = Color(0.2, 0.9, 0.3, 0.35)      # 배치 가능 (초록색 반투명)
const COLOR_GRID_LINE: Color = Color(1.0, 1.0, 1.0, 0.15)   # 그리드 선

# ── Wang 타일셋 상수 ──

## Wang 타일 16종: "NW NE SW SE" 코너 조합 → 스프라이트시트 Rect2
## 키 형식: 각 코너가 lower("L") 또는 upper("U"), 순서: NW+NE+SW+SE
## 모든 타일셋이 동일한 4×4(128×128) 레이아웃을 공유하므로 하드코딩 가능
const WANG_ATLAS: Dictionary = {
	"LLLL": Rect2( 64,  32, 32, 32),  # wang_0  — 전체 lower (순수 하위 지형)
	"LLLU": Rect2( 96,  32, 32, 32),  # wang_1
	"LLUL": Rect2( 64,  64, 32, 32),  # wang_2
	"LLUU": Rect2( 32,  64, 32, 32),  # wang_3
	"LULL": Rect2( 64,   0, 32, 32),  # wang_4
	"LULU": Rect2( 96,  64, 32, 32),  # wang_5
	"LUUL": Rect2(  0,  32, 32, 32),  # wang_6
	"LUUU": Rect2( 96,  96, 32, 32),  # wang_7
	"ULLL": Rect2( 32,  32, 32, 32),  # wang_8
	"ULLU": Rect2( 64,  96, 32, 32),  # wang_9
	"ULUL": Rect2( 32,   0, 32, 32),  # wang_10
	"ULUU": Rect2(  0,  64, 32, 32),  # wang_11
	"UULL": Rect2( 96,   0, 32, 32),  # wang_12
	"UULU": Rect2(  0,   0, 32, 32),  # wang_13
	"UUUL": Rect2( 32,  96, 32, 32),  # wang_14
	"UUUU": Rect2(  0,  96, 32, 32),  # wang_15 — 전체 upper (순수 상위 지형)
}

## 타일셋 페어 정의: (lower 지형, upper 지형, PNG 경로)
## 렌더링 순서 = 레이어 순서 (앞쪽이 아래, 뒤쪽이 위에 표시됨)
const TILESET_PAIRS: Array = [
	# irhen 지역 (초원 기반 전환)
	{"lower": "plains",       "upper": "road",          "png": "res://assets/tilesets/irhen/IRH-01.png"},
	{"lower": "plains",       "upper": "ruins",         "png": "res://assets/tilesets/irhen/IRH-02.png"},
	{"lower": "plains",       "upper": "ashen_land",    "png": "res://assets/tilesets/irhen/IRH-03.png"},
	# silvaren 지역 (숲 기반 전환)
	{"lower": "plains",       "upper": "forest",        "png": "res://assets/tilesets/silvaren/SIL-01.png"},
	{"lower": "forest",       "upper": "shallow_water", "png": "res://assets/tilesets/silvaren/SIL-03.png"},
	# crowfel 지역 (산악 전환)
	{"lower": "plains",       "upper": "mountain",      "png": "res://assets/tilesets/crowfel/CRO-01.png"},
	{"lower": "mountain",     "upper": "wall",          "png": "res://assets/tilesets/crowfel/CRO-02.png"},
	# harben 지역 (농지 전환)
	{"lower": "plains",       "upper": "village",       "png": "res://assets/tilesets/harben/HAR-01.png"},
	# ashen-sea 지역 (화산/황무지 전환)
	{"lower": "ashen_land",   "upper": "lava",          "png": "res://assets/tilesets/ashen-sea/ASH-01.png"},
	# belmar 지역 (해안 전환)
	{"lower": "deep_water",   "upper": "shallow_water", "png": "res://assets/tilesets/belmar/BEL-02.png"},
	{"lower": "shallow_water","upper": "sand",          "png": "res://assets/tilesets/belmar/BEL-03.png"},
]

## 타일셋 PNG로 커버되는 지형 타입 (나머지는 폴백 ColorRect 사용)
const TILESET_COVERED: Array = [
	"plains", "road", "ruins", "ashen_land", "forest", "shallow_water",
	"mountain", "wall", "village", "lava", "deep_water", "sand",
]

# ── 시그널 ──

## 유닛 클릭 시 발생
signal unit_clicked(unit: BattleUnit)
## 빈 셀 클릭 시 발생
signal cell_clicked(cell: Vector2i)
## 배치 완료 시 발생
signal deployment_confirmed(deployed_units: Array)

# ── 멤버 변수 ──

## 그리드 시스템
var grid: GridSystem = GridSystem.new()

## 현재 로드된 맵 데이터
var _map_data: Dictionary = {}

## 유닛 매핑: {Vector2i: BattleUnit}
var units: Dictionary = {}

## 유닛 ID → BattleUnit 매핑 (빠른 조회용)
var _units_by_id: Dictionary = {}

## 그리드 오버레이 표시 여부
var _grid_visible: bool = false

## 현재 하이라이트 중인 셀 목록 (타입별)
var _highlighted_cells: Dictionary = {
	"move": [],
	"attack": [],
	"deploy": [],
}

# ── 노드 참조 ──

## 카메라
var _camera: Camera2D = null

## 지형 레이어 (추후 TileMapLayer로 교체 예정, 현재 Node2D placeholder)
var _terrain_layer: Node2D = null

## 장식 레이어 (추후 TileMapLayer로 교체 예정, 현재 Node2D placeholder)
var _deco_layer: Node2D = null

## 하이라이트 레이어 (Node2D로 draw 기반)
var _highlight_layer: Node2D = null

## 유닛 컨테이너
var _units_container: Node2D = null

## 그리드 오버레이 (Node2D로 draw 기반)
var _grid_overlay: Node2D = null

## 전투 UI (CanvasLayer, placeholder)
var _battle_ui: CanvasLayer = null

# ── 초기화 ──

func _ready() -> void:
	_find_child_nodes()
	# 그리드 시스템에 유닛 정보 콜백 연결
	grid.set_unit_info_callback(_get_unit_info_at)

## 자식 노드 참조 취득
func _find_child_nodes() -> void:
	if has_node("Camera2D"):
		_camera = get_node("Camera2D") as Camera2D
	if has_node("TerrainLayer"):
		_terrain_layer = get_node("TerrainLayer") as Node2D
	if has_node("DecoLayer"):
		_deco_layer = get_node("DecoLayer") as Node2D
	if has_node("HighlightLayer"):
		_highlight_layer = get_node("HighlightLayer") as Node2D
	if has_node("Units"):
		_units_container = get_node("Units") as Node2D
	if has_node("GridOverlay"):
		_grid_overlay = get_node("GridOverlay") as Node2D
	if has_node("BattleUI"):
		_battle_ui = get_node("BattleUI") as CanvasLayer

func _process(delta: float) -> void:
	_handle_camera_input(delta)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_left_click(mb.global_position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_handle_mouse_hover(mm.global_position)
	elif event.is_action_pressed("toggle_grid"):
		_toggle_grid()

# ── 맵 로드 ──

## 맵 데이터를 로드하고 지형을 구성한다
## @param battle_id 전투 ID (예: "battle_01")
func load_map(battle_id: String) -> void:
	var dm: Node = get_node("/root/DataManager")
	_map_data = dm.get_map(battle_id)
	if _map_data.is_empty():
		push_error("[BattleMap] 맵 데이터 없음: %s" % battle_id)
		return

	var size_data: Dictionary = _map_data.get("map_size", {})
	var map_w: int = size_data.get("width", 20)
	var map_h: int = size_data.get("height", 16)

	# 타일 데이터 구성 (terrain_layout 기반)
	# 현재 맵 JSON에는 tiles 2D 배열이 없으므로 기본 "plains"로 채운다
	# 추후 맵 에디터에서 실제 타일 배열을 포함하면 그것을 사용
	var tiles: Array = _build_tiles_array(map_w, map_h)

	grid.setup_map(tiles, Vector2i(map_w, map_h))

	# 카메라 제한 설정
	_setup_camera_limits(map_w, map_h)

	# 지형 시각화 (ColorRect 기반 — 타일셋이 없는 동안 placeholder)
	_render_terrain(tiles, map_w, map_h)

	# 장식 오브젝트 렌더링 (나무, 바위, 우물 등)
	_render_objects()

	# 적 유닛 배치
	_spawn_enemies()

	print("[BattleMap] 맵 로드 완료: %s (%dx%d)" % [battle_id, map_w, map_h])

## 타일 2D 배열 구성. 맵 데이터에 tiles가 있으면 사용, 없으면 기본값 생성
## @param w 맵 너비
## @param h 맵 높이
## @returns tiles[y][x] = terrain_type 형태의 2D 배열
func _build_tiles_array(w: int, h: int) -> Array:
	# 맵 데이터에 tiles 필드가 있으면 직접 사용
	if _map_data.has("tiles"):
		return _map_data["tiles"]

	# 없으면 기본 plains로 채움
	var tiles: Array = []
	for y: int in range(h):
		var row: Array = []
		for x: int in range(w):
			row.append("plains")
		tiles.append(row)
	return tiles

## 카메라 제한 설정
## @param map_w 맵 너비 (타일 단위)
## @param map_h 맵 높이 (타일 단위)
func _setup_camera_limits(map_w: int, map_h: int) -> void:
	if _camera == null:
		return
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = map_w * GridSystem.TILE_SIZE
	_camera.limit_bottom = map_h * GridSystem.TILE_SIZE
	# 카메라 초기 위치: 맵 중앙
	_camera.position = Vector2(
		map_w * GridSystem.TILE_SIZE / 2.0,
		map_h * GridSystem.TILE_SIZE / 2.0
	)

## 지형 렌더링 — Wang 타일셋 오토타일링으로 픽셀아트 표시
## 1) 베이스 레이어: plains 셀 → IRH-01 wang_0 (순수 초원)
## 2) Wang 레이어: 각 타일셋 페어에 따라 upper 지형 및 전환 타일 렌더
## 3) 폴백: 타일셋 미정의 지형은 ColorRect
## @param tiles 지형 타입 2D 배열
## @param w 맵 너비 (타일)
## @param h 맵 높이 (타일)
func _render_terrain(tiles: Array, w: int, h: int) -> void:
	if _terrain_layer:
		for child: Node in _terrain_layer.get_children():
			child.queue_free()

	var terrain_node: Node2D = _terrain_layer if _terrain_layer else self
	var tex_cache: Dictionary = {}  # PNG 경로 → Texture2D 캐시

	# 맵에 실제로 존재하는 지형 타입 수집 (미사용 페어 건너뛰기 최적화)
	var present: Dictionary = {}
	for row: Array in tiles:
		for t in row:
			present[t] = true

	# ── 베이스 레이어: 전체 맵을 IRH-01 초원으로 채움 ──
	# 오버레이 타일의 하위 지형(잔디) 영역이 투명하므로, 모든 셀에 기본 잔디를 깔아
	# 어떤 지형이든 하위 지형 부분이 일관된 베이스 잔디로 자연스럽게 보인다.
	var plains_tex: Texture2D = _get_cached_tex("res://assets/tilesets/irhen/IRH-01.png", tex_cache)
	for y: int in range(h):
		for x: int in range(w):
			_place_wang_sprite(terrain_node, plains_tex, Rect2(64, 32, 32, 32), x, y)

	# ── 폴백 레이어: 타일셋 미정의 지형 → ColorRect ──
	for y: int in range(h):
		for x: int in range(w):
			var t: String = tiles[y][x] if y < tiles.size() and x < tiles[y].size() else "plains"
			if not TILESET_COVERED.has(t):
				var fallback := ColorRect.new()
				fallback.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
				fallback.position = Vector2(x * GridSystem.TILE_SIZE, y * GridSystem.TILE_SIZE)
				fallback.color = _get_terrain_color(t)
				fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
				terrain_node.add_child(fallback)

	# ── Wang 오버레이 레이어: 타일셋 페어별 upper/전환 타일 렌더 ──
	# 오버레이 텍스처는 하위 지형(잔디) 픽셀이 투명화되어 있어,
	# 여러 페어가 동일 셀에 적층돼도 베이스 잔디와 자연스럽게 합성된다.
	for pair: Dictionary in TILESET_PAIRS:
		var lo: String = pair["lower"]
		var up: String = pair["upper"]

		# 이 맵에 관련 지형이 하나도 없으면 스킵
		if not present.has(lo) and not present.has(up):
			continue

		# 하위 지형 픽셀이 투명 처리된 오버레이 텍스처 사용
		var tex: Texture2D = _get_overlay_tex(pair["png"], tex_cache)

		for y: int in range(h):
			for x: int in range(w):
				var t: String = tiles[y][x] if y < tiles.size() and x < tiles[y].size() else "plains"
				if t != lo and t != up:
					continue

				# 4개 코너값 계산: 꼭짓점을 공유하는 셀 중 upper가 있으면 upper
				var nw: bool = _corner_upper(tiles, x, y, -1, -1, w, h, up)
				var ne_c: bool = _corner_upper(tiles, x, y, +1, -1, w, h, up)
				var sw: bool = _corner_upper(tiles, x, y, -1, +1, w, h, up)
				var se: bool = _corner_upper(tiles, x, y, +1, +1, w, h, up)

				var key: String = (("U" if nw else "L") + ("U" if ne_c else "L")
						+ ("U" if sw else "L") + ("U" if se else "L"))
				var region: Rect2 = WANG_ATLAS.get(key, Rect2(64, 32, 32, 32))

				# lower 셀인데 모든 코너가 lower면 베이스 레이어로 충분 → 스킵
				if t == lo and key == "LLLL":
					continue

				_place_wang_sprite(terrain_node, tex, region, x, y)

## Wang 타일 Sprite2D를 지형 레이어에 추가
## @param parent 부모 노드
## @param tex 스프라이트시트 텍스처
## @param region 타일 영역 Rect2
## @param x 그리드 X 좌표
## @param y 그리드 Y 좌표
func _place_wang_sprite(parent: Node2D, tex: Texture2D, region: Rect2, x: int, y: int) -> void:
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = region
	atlas.filter_clip = true  # 아틀라스 인접 타일 픽셀 블리드 방지
	var sprite := Sprite2D.new()
	sprite.texture = atlas
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 픽셀아트 최근접 필터
	sprite.position = Vector2(x * GridSystem.TILE_SIZE, y * GridSystem.TILE_SIZE)
	parent.add_child(sprite)

## 텍스처 캐시에서 반환 (없으면 load 후 저장)
## @param path 리소스 경로
## @param cache 캐시 딕셔너리
## @returns Texture2D
func _get_cached_tex(path: String, cache: Dictionary) -> Texture2D:
	if not cache.has(path):
		cache[path] = load(path) as Texture2D
	return cache[path]

## 오버레이 텍스처 캐시에서 반환 (없으면 로드 후 저장)
## 사전 처리된 {NAME}_ov.png 파일을 로드한다.
## _ov.png 는 scripts/tools/make_tileset_overlays.py 로 생성된 오프라인 처리 파일이며,
## wang_0/wang_15 공간 기준 마스킹으로 하위 지형 픽셀이 정확하게 투명화되어 있다.
## @param path 원본 타일셋 PNG 경로 (res://.../{NAME}.png)
## @param cache 캐시 딕셔너리
## @returns Texture2D (하위 지형 픽셀 투명)
func _get_overlay_tex(path: String, cache: Dictionary) -> Texture2D:
	var overlay_key: String = path + "_ov"
	if not cache.has(overlay_key):
		# {NAME}.png → {NAME}_ov.png
		var ov_path: String = path.replace(".png", "_ov.png")
		if ResourceLoader.exists(ov_path):
			cache[overlay_key] = load(ov_path) as Texture2D
		else:
			# _ov.png 없으면 원본 사용 (fallback, 시각적 품질 저하)
			push_warning("[BattleMap] 오버레이 파일 없음 (make_tileset_overlays.py 실행 필요): %s" % ov_path)
			cache[overlay_key] = load(path) as Texture2D
	return cache[overlay_key]

## Wang 오토타일링 코너 판정: 꼭짓점을 공유하는 4개 셀 검사
## 4셀 검사가 Wang 표준이며 인접 타일 간 꼭짓점값 일치(이음매 없는 연결)를 보장한다.
## OOB 셀은 경계 셀로 클램핑하여 상위 지형이 맵 가장자리에서 자연스럽게 연장되도록 한다.
## @param dx -1(왼쪽) 또는 +1(오른쪽)
## @param dy -1(위) 또는 +1(아래)
## @returns 해당 코너가 upper 지형인지 여부
func _corner_upper(tiles: Array, x: int, y: int, dx: int, dy: int,
		w: int, h: int, upper_t: String) -> bool:
	# 꼭짓점을 공유하는 4개 셀: (x,y), (x+dx,y), (x,y+dy), (x+dx,y+dy)
	# OOB는 경계 셀로 클램핑 → 지형이 맵 밖으로 자연스럽게 연장되어 경계 잘림 방지
	for cy: int in [y, y + dy]:
		for cx: int in [x, x + dx]:
			var clamped_cx: int = clampi(cx, 0, w - 1)
			var clamped_cy: int = clampi(cy, 0, h - 1)
			if clamped_cy < tiles.size() and clamped_cx < tiles[clamped_cy].size():
				if tiles[clamped_cy][clamped_cx] == upper_t:
					return true
	return false

## 맵 장식 오브젝트 렌더링 (나무, 바위, 우물 등)
## 맵 데이터의 "objects" 배열을 읽어 _deco_layer에 Sprite2D로 배치한다.
## 오브젝트 타입명은 _resolve_prop_path()로 실제 props 폴더 경로로 변환된다.
## 이미지 하단이 타일 하단에 정렬되어 자연스러운 depth sorting 효과가 생긴다.
func _render_objects() -> void:
	var objects: Array = _map_data.get("objects", [])
	if objects.is_empty():
		return

	var obj_node: Node2D = _deco_layer if _deco_layer else self
	# 기존 오브젝트 제거
	if _deco_layer:
		for child: Node in _deco_layer.get_children():
			child.queue_free()

	var obj_cache: Dictionary = {}
	var ts: int = GridSystem.TILE_SIZE

	for obj: Dictionary in objects:
		var obj_type: String = obj.get("type", "")
		var pos: Array = obj.get("position", [0, 0])
		var obj_x: int = pos[0] as int
		var obj_y: int = pos[1] as int

		var tex_path: String = _resolve_prop_path(obj_type)
		if tex_path.is_empty():
			push_warning("[BattleMap] 알 수 없는 오브젝트 타입: %s" % obj_type)
			continue
		if not ResourceLoader.exists(tex_path):
			push_warning("[BattleMap] 프랍 파일 없음: %s" % tex_path)
			continue

		if not obj_cache.has(tex_path):
			obj_cache[tex_path] = load(tex_path) as Texture2D
		var tex: Texture2D = obj_cache[tex_path]
		if tex == null:
			continue

		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# 오브젝트 하단을 타일 하단에 정렬 (높이가 타일보다 큰 오브젝트도 자연스럽게 보임)
		var obj_h: int = tex.get_height()
		sprite.position = Vector2(
			obj_x * ts,
			obj_y * ts + ts - obj_h
		)
		# 타입별 z_index 적용: 저층 오브젝트가 고층(나무 등) 뒤에 그려지도록
		sprite.z_index = _get_prop_z_index(obj_type)
		obj_node.add_child(sprite)

## 오브젝트 타입별 z_index를 반환한다.
## 저층(바위/우물)이 고층(나무/기둥) 뒤에 그려지도록 레이어를 분리한다.
## @param obj_type 오브젝트 타입명
## @returns z_index 값 (0=지면, 10=저층, 20=중층, 30=고층, 40=구조물)
static func _get_prop_z_index(obj_type: String) -> int:
	const Z_GROUND:    int = 0   # 지면 장식 (바닥 밀착)
	const Z_LOW:       int = 10  # 저층: 바위, 우물, 통, 장작
	const Z_MID:       int = 20  # 중층: 큰 바위, 덤불, 울타리, 작은 동상
	const Z_HIGH:      int = 30  # 고층: 나무, 기둥, 큰 동상, 결계석, 제단
	const Z_STRUCTURE: int = 40  # 구조물: 다리, 문, 함정

	match obj_type:
		# ── 지면 장식 ──
		"wildflower", "ash_mist", "rune_floor":
			return Z_GROUND
		# ── 저층 ──
		"rock_small", "rock", "stump", "burnt_stump", "fallen_log", \
		"campfire", "well", "barrel", "crate", "rope_anchor", "lantern", \
		"wildflower":
			return Z_LOW
		# ── 중층 ──
		"rock_medium", "rock_large", "bush_small", "bush", "bush_large", \
		"fence", "dock", "mushroom", "roots", "fissure", "ash_crystal", \
		"statue_small":
			return Z_MID
		# ── 고층 ──
		"tree_small", "tree_large", "tree_oak", "pine", "ancient_tree", \
		"dead_tree", "pillar", "village_square", "shop", "house", \
		"farmhouse", "ward_pillar", "ward_stone_active", "altar", \
		"ember_throne", "statue_large":
			return Z_HIGH
		# ── 구조물 ──
		"bridge_intact", "bridge_broken", "iron_gate", "gate_intact", \
		"trap_hidden":
			return Z_STRUCTURE
		_:
			return Z_LOW  # 기본값: 저층

## 오브젝트 타입명을 실제 파일 경로로 변환한다.
## props 폴더의 지역별/공용 에셋을 타입명으로 참조할 수 있게 한다.
## @param obj_type 오브젝트 타입명 (예: "tree_oak", "well")
## @returns 리소스 경로 문자열. 알 수 없는 타입이면 빈 문자열 반환.
static func _resolve_prop_path(obj_type: String) -> String:
	const PROP_MAP: Dictionary = {
		# ── common ──
		"tree_small":    "res://assets/props/common/P01_tree_small.png",
		"tree_large":    "res://assets/props/common/P02_tree_large.png",
		"tree_oak":      "res://assets/props/common/P02_tree_large.png",
		"pine":          "res://assets/props/common/P03_pine.png",
		"rock_small":    "res://assets/props/common/P04_rock_small.png",
		"rock":          "res://assets/props/common/P04_rock_small.png",
		"rock_medium":   "res://assets/props/common/P05_rock_medium.png",
		"rock_large":    "res://assets/props/common/P06_rock_large.png",
		"bush_small":    "res://assets/props/common/P07_bush_small.png",
		"bush":          "res://assets/props/common/P07_bush_small.png",
		"bush_large":    "res://assets/props/common/P08_bush_large.png",
		"wildflower":    "res://assets/props/common/P09_wildflower.png",
		"fallen_log":    "res://assets/props/common/P10_fallen_log.png",
		# ── irhen ──
		"farmhouse":     "res://assets/props/irhen/P11_farmhouse.png",
		"well":          "res://assets/props/irhen/P12_well.png",
		"fence":         "res://assets/props/irhen/P13_fence.png",
		"village_square":"res://assets/props/irhen/P14_village_square.png",
		# ── belmar ──
		"dock":          "res://assets/props/belmar/P15_dock.png",
		"crate":         "res://assets/props/belmar/P16_crate.png",
		"rope_anchor":   "res://assets/props/belmar/P17_rope_anchor.png",
		"lantern":       "res://assets/props/belmar/P18_lantern.png",
		"shop":          "res://assets/props/belmar/P19_shop.png",
		"house":         "res://assets/props/belmar/P20_house.png",
		# ── silvaren ──
		"ancient_tree":  "res://assets/props/silvaren/P21_ancient_tree.png",
		"mushroom":      "res://assets/props/silvaren/P22_mushroom.png",
		"roots":         "res://assets/props/silvaren/P23_roots.png",
		"ward_pillar":   "res://assets/props/silvaren/P24_ward_pillar.png",
		# ── harben ──
		"hay_bale":      "res://assets/props/harben/P25_hay_bale.png",
		"windmill":      "res://assets/props/harben/P26_windmill.png",
		"farm_cart":     "res://assets/props/harben/P27_farm_cart.png",
		# ── crowfel ──
		"tent":          "res://assets/props/crowfel/P28_tent.png",
		"barricade":     "res://assets/props/crowfel/P29_barricade.png",
		"weapon_rack":   "res://assets/props/crowfel/P30_weapon_rack.png",
		"watchtower":    "res://assets/props/crowfel/P31_watchtower.png",
		# ── ascalon ──
		"castle_wall":   "res://assets/props/ascalon/P32_castle_wall.png",
		"palace_pillar": "res://assets/props/ascalon/P33_palace_pillar.png",
		"banner":        "res://assets/props/ascalon/P34_banner.png",
		"iron_gate":     "res://assets/props/ascalon/P35_iron_gate.png",
		"ember_throne":  "res://assets/props/ascalon/P36_ember_throne.png",
		# ── ashen-sea ──
		"dead_tree":     "res://assets/props/ashen-sea/P37_dead_tree.png",
		"burnt_stump":   "res://assets/props/ashen-sea/P37_dead_tree.png",
		"ash_crystal":   "res://assets/props/ashen-sea/P38_ash_crystal.png",
		"fissure":       "res://assets/props/ashen-sea/P39_fissure.png",
		"ash_mist":      "res://assets/props/ashen-sea/P40_mist.png",
		# ── special ──
		"ward_stone_active":   "res://assets/props/special/S01_ward_stone_active.png",
		"ward_stone_inactive": "res://assets/props/special/S02_ward_stone_inactive.png",
		"altar":               "res://assets/props/special/S03_altar.png",
		"trap_hidden":         "res://assets/props/special/S04_trap_hidden.png",
		"trap_triggered":      "res://assets/props/special/S05_trap_triggered.png",
		"gate_intact":         "res://assets/props/special/S06_gate_intact.png",
		"gate_broken":         "res://assets/props/special/S07_gate_broken.png",
		"bridge_intact":       "res://assets/props/special/S08_bridge_intact.png",
		"bridge_broken":       "res://assets/props/special/S09_bridge_broken.png",
	}
	return PROP_MAP.get(obj_type, "")

## 지형 타입별 폴백 색상 반환 (타일셋 미정의 지형용)
## @param terrain_type 지형 타입
## @returns 색상
func _get_terrain_color(terrain_type: String) -> Color:
	match terrain_type:
		"plains":       return Color(0.45, 0.65, 0.30)
		"forest":       return Color(0.20, 0.45, 0.15)
		"mountain":     return Color(0.55, 0.50, 0.45)
		"shallow_water":return Color(0.30, 0.55, 0.80)
		"deep_water":   return Color(0.15, 0.30, 0.65)
		"bridge":       return Color(0.55, 0.45, 0.30)
		"road":         return Color(0.60, 0.55, 0.45)
		"ruins":        return Color(0.50, 0.50, 0.45)
		"sand":         return Color(0.80, 0.75, 0.55)
		"lava":         return Color(0.85, 0.25, 0.10)
		"barrier_stone":return Color(0.50, 0.60, 0.70)
		"ashen_land":   return Color(0.40, 0.38, 0.35)
		"wall":         return Color(0.35, 0.35, 0.35)
		"fortress":     return Color(0.55, 0.55, 0.60)
		"village":      return Color(0.60, 0.50, 0.35)
		"throne":       return Color(0.70, 0.55, 0.25)
		_:              return Color(0.45, 0.65, 0.30)

# ── 적 유닛 배치 ──

## 맵 데이터의 enemy_placements를 기반으로 적 유닛 스폰
func _spawn_enemies() -> void:
	var dm: Node = get_node("/root/DataManager")
	var placements: Array = _map_data.get("enemy_placements", [])

	for i: int in range(placements.size()):
		var placement: Dictionary = placements[i]
		var enemy_id: String = placement.get("enemy_id", "")
		var enemy_level: int = placement.get("level", 1)
		var pos: Array = placement.get("position", [0, 0])
		var spawn_cell := Vector2i(pos[0] as int, pos[1] as int)

		var enemy_data: Dictionary = dm.get_enemy(enemy_id)
		if enemy_data.is_empty():
			push_warning("[BattleMap] 적 데이터 없음: %s" % enemy_id)
			continue

		# 고유 유닛 ID 생성 (같은 적 다수 배치 지원)
		var uid: String = "%s_%d" % [enemy_id, i]
		spawn_unit(enemy_data, spawn_cell, "enemy", uid, enemy_level)

# ── 유닛 관리 ──

## 유닛을 스폰한다
## @param unit_data 캐릭터 또는 적 데이터 Dictionary
## @param spawn_cell 배치할 셀 좌표
## @param unit_team 팀 ("player" 또는 "enemy")
## @param uid 고유 유닛 ID (없으면 데이터의 id 사용)
## @param unit_level 유닛 레벨
## @returns 생성된 BattleUnit
func spawn_unit(unit_data: Dictionary, spawn_cell: Vector2i, unit_team: String, uid: String = "", unit_level: int = 1) -> BattleUnit:
	var unit := _create_battle_unit_instance()
	if uid.is_empty():
		uid = unit_data.get("id", "unit_%d" % units.size())
	unit.unit_id = uid

	if unit_team == "player":
		unit.init_from_character(unit_data, unit_level)
	else:
		unit.init_from_enemy(unit_data, unit_level)

	unit.cell = spawn_cell
	unit.position = GridSystem.cell_to_world(spawn_cell)

	if _units_container:
		_units_container.add_child(unit)
	else:
		add_child(unit)

	units[spawn_cell] = unit
	_units_by_id[uid] = unit

	return unit

## BattleUnit 인스턴스 생성. 씬 파일이 있으면 인스턴스, 없으면 코드로 구성
## @returns BattleUnit 노드
func _create_battle_unit_instance() -> BattleUnit:
	var scene_path := "res://scenes/battle/battle_unit.tscn"
	if ResourceLoader.exists(scene_path):
		var scene: PackedScene = load(scene_path)
		return scene.instantiate() as BattleUnit
	else:
		# 씬 파일 없이 코드로 구성 (fallback)
		return _build_battle_unit_manually()

## BattleUnit을 코드로 수동 구성 (씬 파일 없을 때 fallback)
## @returns 구성된 BattleUnit
func _build_battle_unit_manually() -> BattleUnit:
	var unit := BattleUnit.new()

	# AnimatedSprite2D (placeholder)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite"
	unit.add_child(sprite)

	# HP바
	var health_bar := ProgressBar.new()
	health_bar.name = "HealthBar"
	health_bar.custom_minimum_size = Vector2(28, 4)
	health_bar.position = Vector2(-14, -20)
	health_bar.size = Vector2(28, 4)
	health_bar.show_percentage = false
	unit.add_child(health_bar)

	# 상태이상 아이콘 컨테이너
	var status_icons := HBoxContainer.new()
	status_icons.name = "StatusIcons"
	status_icons.position = Vector2(-14, -28)
	unit.add_child(status_icons)

	# 선택 표시
	var selection := Sprite2D.new()
	selection.name = "SelectionIndicator"
	selection.visible = false
	unit.add_child(selection)

	return unit

## 지정 셀의 유닛 조회
## @param cell 셀 좌표
## @returns BattleUnit 또는 null
func get_unit_at(cell: Vector2i) -> BattleUnit:
	return units.get(cell, null)

## ID로 유닛 조회
## @param uid 유닛 ID
## @returns BattleUnit 또는 null
func get_unit_by_id(uid: String) -> BattleUnit:
	return _units_by_id.get(uid, null)

## 셀에 유닛이 있는지 확인
## @param cell 셀 좌표
## @returns 점유되어 있으면 true
func is_cell_occupied(cell: Vector2i) -> bool:
	return units.has(cell)

## 유닛 제거
## @param cell 셀 좌표
func remove_unit(cell: Vector2i) -> void:
	if units.has(cell):
		var unit: BattleUnit = units[cell]
		_units_by_id.erase(unit.unit_id)
		units.erase(cell)
		unit.queue_free()

## 유닛 이동 (셀 매핑 갱신)
## @param from_cell 이전 셀
## @param to_cell 이동 후 셀
func move_unit(from_cell: Vector2i, to_cell: Vector2i) -> void:
	if not units.has(from_cell):
		return
	var unit: BattleUnit = units[from_cell]
	units.erase(from_cell)
	units[to_cell] = unit

## 유닛 정보 콜백 (GridSystem에서 사용)
## @param cell 셀 좌표
## @returns {team: String} 또는 null
func _get_unit_info_at(cell: Vector2i) -> Variant:
	if units.has(cell):
		var unit: BattleUnit = units[cell]
		return {"team": unit.team}
	return null

# ── 하이라이트 표시 ──

## 이동 범위 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_movement_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["move"] = cells
	_redraw_highlights()

## 공격 범위 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_attack_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["attack"] = cells
	_redraw_highlights()

## 배치 가능 셀 하이라이트 표시
## @param cells 하이라이트할 셀 배열
func show_deploy_range(cells: Array[Vector2i]) -> void:
	_highlighted_cells["deploy"] = cells
	_redraw_highlights()

## 모든 하이라이트 제거
func clear_highlights() -> void:
	_highlighted_cells["move"] = []
	_highlighted_cells["attack"] = []
	_highlighted_cells["deploy"] = []
	_redraw_highlights()

## 하이라이트 레이어 다시 그리기
func _redraw_highlights() -> void:
	if _highlight_layer == null:
		return
	# 기존 하이라이트 제거
	for child: Node in _highlight_layer.get_children():
		child.queue_free()

	# 이동 범위
	var move_cells: Array = _highlighted_cells.get("move", [])
	for cell_pos: Vector2i in move_cells:
		_add_highlight_rect(cell_pos, COLOR_MOVE)

	# 공격 범위
	var atk_cells: Array = _highlighted_cells.get("attack", [])
	for cell_pos: Vector2i in atk_cells:
		_add_highlight_rect(cell_pos, COLOR_ATTACK)

	# 배치 가능
	var dep_cells: Array = _highlighted_cells.get("deploy", [])
	for cell_pos: Vector2i in dep_cells:
		_add_highlight_rect(cell_pos, COLOR_DEPLOY)

## 하이라이트 셀 ColorRect 추가
## @param cell_pos 셀 좌표
## @param color 하이라이트 색상
func _add_highlight_rect(cell_pos: Vector2i, color: Color) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(GridSystem.TILE_SIZE, GridSystem.TILE_SIZE)
	rect.position = Vector2(cell_pos.x * GridSystem.TILE_SIZE, cell_pos.y * GridSystem.TILE_SIZE)
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight_layer.add_child(rect)

# ── 그리드 오버레이 ──

## 그리드 표시 토글 (G키)
func _toggle_grid() -> void:
	_grid_visible = not _grid_visible
	if _grid_overlay:
		_grid_overlay.visible = _grid_visible
		if _grid_visible:
			_draw_grid_lines()
		else:
			for child: Node in _grid_overlay.get_children():
				child.queue_free()

## 그리드 선 그리기
func _draw_grid_lines() -> void:
	if _grid_overlay == null:
		return
	# 기존 선 제거
	for child: Node in _grid_overlay.get_children():
		child.queue_free()

	var ts: int = GridSystem.TILE_SIZE
	var w: int = grid.map_size.x * ts
	var h: int = grid.map_size.y * ts

	# 수직선
	for x: int in range(0, grid.map_size.x + 1):
		var line := _create_line(Vector2(x * ts, 0), Vector2(x * ts, h))
		_grid_overlay.add_child(line)

	# 수평선
	for y: int in range(0, grid.map_size.y + 1):
		var line := _create_line(Vector2(0, y * ts), Vector2(w, y * ts))
		_grid_overlay.add_child(line)

## Line2D 노드 생성
## @param from_pos 시작 좌표
## @param to_pos 끝 좌표
## @returns Line2D 노드
func _create_line(from_pos: Vector2, to_pos: Vector2) -> Line2D:
	var line := Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 1.0
	line.default_color = COLOR_GRID_LINE
	return line

# ── 카메라 제어 ──

## 카메라 입력 처리 (WASD / 방향키)
## @param delta 프레임 시간
func _handle_camera_input(delta: float) -> void:
	if _camera == null:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("camera_up"):
		direction.y -= 1
	if Input.is_action_pressed("camera_down"):
		direction.y += 1
	if Input.is_action_pressed("camera_left"):
		direction.x -= 1
	if Input.is_action_pressed("camera_right"):
		direction.x += 1

	if direction != Vector2.ZERO:
		_camera.position += direction.normalized() * CAMERA_SCROLL_SPEED * delta

# ── 입력 처리 ──

## 좌클릭 처리
## @param screen_pos 화면 좌표
func _handle_left_click(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var clicked_cell := GridSystem.world_to_cell(world_pos)

	if not grid.is_within_bounds(clicked_cell):
		return

	# 유닛이 있는 셀 클릭
	if units.has(clicked_cell):
		unit_clicked.emit(units[clicked_cell])
		EventBus.unit_selected.emit(units[clicked_cell].unit_id)
	else:
		cell_clicked.emit(clicked_cell)

## 마우스 호버 처리
## @param screen_pos 화면 좌표
func _handle_mouse_hover(screen_pos: Vector2) -> void:
	var world_pos := _screen_to_world(screen_pos)
	var hovered_cell := GridSystem.world_to_cell(world_pos)

	if grid.is_within_bounds(hovered_cell):
		EventBus.cell_hovered.emit(hovered_cell)

## 화면 좌표 → 월드 좌표 변환 (카메라 고려)
## @param screen_pos 화면 좌표
## @returns 월드 좌표
func _screen_to_world(screen_pos: Vector2) -> Vector2:
	if _camera:
		var viewport := get_viewport()
		if viewport:
			return get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos

# ── 유틸리티 ──

## 팀별 유닛 목록 조회
## @param team_name 팀 이름
## @returns BattleUnit 배열
func get_units_by_team(team_name: String) -> Array[BattleUnit]:
	var result: Array[BattleUnit] = []
	for unit: BattleUnit in units.values():
		if unit.team == team_name:
			result.append(unit)
	return result

## 모든 유닛의 턴 리셋
## @param team_name 리셋할 팀 (빈 문자열이면 전체)
func reset_units_turn(team_name: String = "") -> void:
	for unit: BattleUnit in units.values():
		if team_name.is_empty() or unit.team == team_name:
			unit.reset_turn()
			unit.clear_acted_visual()

## 현재 로드된 맵 데이터를 반환한다 (VictoryConditionChecker 초기화용).
## @returns 맵 데이터 Dictionary
func get_map_data() -> Dictionary:
	return _map_data

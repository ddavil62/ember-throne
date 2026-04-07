## @fileoverview 상점 씬 오케스트레이터. shop_screen.gd에 shop_id와 act를 주입하고
## 월드맵 복귀 처리를 담당한다.
extends Control

# ── 노드 참조 ──

## 실제 상점 화면
@onready var _shop_screen: Control = $ShopScreen

# ── 초기화 ──

func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT

	# GameManager에서 현재 노드 정보 취득
	var gm: Node = get_node("/root/GameManager")
	var dm: Node = get_node("/root/DataManager")
	var node_id: String = gm.current_node_id
	var node_data: Dictionary = dm.world_nodes.get(node_id, {})

	# shop_id는 노드의 region 값을 사용 (belmar 등)
	var shop_id: String = node_data.get("region", "belmar")
	var act: String = "act_%d" % node_data.get("act", 1)

	print("[ShopScene] 상점 초기화: shop_id=%s, act=%s" % [shop_id, act])
	_shop_screen.init(shop_id, act)

	# EventBus 메뉴 닫기 시그널 수신
	var eb: Node = get_node("/root/EventBus")
	eb.menu_closed.connect(_on_menu_closed)

## EventBus에서 메뉴 닫기 시그널 수신
func _on_menu_closed(menu_type: String) -> void:
	if menu_type == "shop":
		_return_to_world_map()

## 월드맵으로 복귀한다.
func _return_to_world_map() -> void:
	var gm: Node = get_node("/root/GameManager")
	gm.transition_to_scene("res://scenes/world/world_map.tscn", 0.3, gm.GameState.WORLD_MAP)

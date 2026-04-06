## @fileoverview 무기/마법 상성 시스템. 검>도끼>창>검 물리 삼각, 화>풍>뇌>화 마법 삼각을 관리한다.
class_name WeaponTriangle
extends RefCounted

# ── 상수 ──

## 무기 상성 삼각 (A > B: A가 B에 유리)
## sword > axe > lance > sword
const WEAPON_TRIANGLE: Dictionary = {
	"sword": "axe",    # 검은 도끼에 유리
	"axe": "lance",    # 도끼는 창에 유리
	"lance": "sword",  # 창은 검에 유리
}

## 마법 상성 삼각 (A > B: A가 B에 유리)
## fire > wind > thunder > fire
const MAGIC_TRIANGLE: Dictionary = {
	"fire": "wind",      # 화염은 풍에 유리
	"wind": "thunder",   # 풍은 뇌에 유리
	"thunder": "fire",   # 뇌는 화염에 유리
}

## 무기 상성 데미지/명중 보정치 (유리 +15%, 불리 -15%)
const WEAPON_ADVANTAGE_MOD: float = 0.15

## 마법 상성 데미지/명중 보정치 (유리 +10%, 불리 -10%)
const MAGIC_ADVANTAGE_MOD: float = 0.10

# ── 무기 상성 판정 ──

## 무기 상성 우열 판정
## @param attacker_type 공격자 무기 타입 (sword, axe, lance 등)
## @param defender_type 방어자 무기 타입
## @returns +1(유리), -1(불리), 0(중립)
static func get_weapon_advantage(attacker_type: String, defender_type: String) -> int:
	if not WEAPON_TRIANGLE.has(attacker_type):
		return 0
	if not WEAPON_TRIANGLE.has(defender_type):
		return 0
	if attacker_type == defender_type:
		return 0
	# 공격자가 방어자에 유리한지 확인
	if WEAPON_TRIANGLE[attacker_type] == defender_type:
		return 1
	# 방어자가 공격자에 유리한지 확인 (공격자 불리)
	if WEAPON_TRIANGLE[defender_type] == attacker_type:
		return -1
	return 0

## 마법 속성 상성 우열 판정
## @param attacker_element 공격자 마법 속성 (fire, wind, thunder 등)
## @param defender_element 방어자 마법 속성
## @returns +1(유리), -1(불리), 0(중립)
static func get_magic_advantage(attacker_element: String, defender_element: String) -> int:
	if not MAGIC_TRIANGLE.has(attacker_element):
		return 0
	if not MAGIC_TRIANGLE.has(defender_element):
		return 0
	if attacker_element == defender_element:
		return 0
	# 공격자가 방어자에 유리한지 확인
	if MAGIC_TRIANGLE[attacker_element] == defender_element:
		return 1
	# 방어자가 공격자에 유리한지 확인 (공격자 불리)
	if MAGIC_TRIANGLE[defender_element] == attacker_element:
		return -1
	return 0

# ── 보정치 계산 ──

## 무기 상성 데미지 배율 반환
## @param attacker_type 공격자 무기 타입
## @param defender_type 방어자 무기 타입
## @returns 1.15(유리), 0.85(불리), 1.0(중립)
static func get_weapon_damage_mod(attacker_type: String, defender_type: String) -> float:
	var advantage: int = get_weapon_advantage(attacker_type, defender_type)
	return 1.0 + advantage * WEAPON_ADVANTAGE_MOD

## 무기 상성 명중 보정 반환
## @param attacker_type 공격자 무기 타입
## @param defender_type 방어자 무기 타입
## @returns 1.15(유리), 0.85(불리), 1.0(중립)
static func get_weapon_hit_mod(attacker_type: String, defender_type: String) -> float:
	var advantage: int = get_weapon_advantage(attacker_type, defender_type)
	return 1.0 + advantage * WEAPON_ADVANTAGE_MOD

## 마법 상성 데미지 배율 반환
## @param attacker_element 공격자 마법 속성
## @param defender_element 방어자 마법 속성
## @returns 1.1(유리), 0.9(불리), 1.0(중립)
static func get_magic_damage_mod(attacker_element: String, defender_element: String) -> float:
	var advantage: int = get_magic_advantage(attacker_element, defender_element)
	return 1.0 + advantage * MAGIC_ADVANTAGE_MOD

## 마법 상성 명중 보정 반환
## @param attacker_element 공격자 마법 속성
## @param defender_element 방어자 마법 속성
## @returns 1.1(유리), 0.9(불리), 1.0(중립)
static func get_magic_hit_mod(attacker_element: String, defender_element: String) -> float:
	var advantage: int = get_magic_advantage(attacker_element, defender_element)
	return 1.0 + advantage * MAGIC_ADVANTAGE_MOD

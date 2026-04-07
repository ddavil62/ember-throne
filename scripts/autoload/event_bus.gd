## @fileoverview 글로벌 시그널 버스. 시스템 간 디커플링된 통신을 제공한다.
class_name EventBusClass
extends Node

# ── 전투 시그널 ──

## 턴 시작 (phase: "player" | "enemy" | "npc", turn_number: int)
signal turn_started(phase: String, turn_number: int)
## 턴 종료
signal turn_ended(phase: String, turn_number: int)
## 유닛 이동 완료
signal unit_moved(unit_id: String, from: Vector2i, to: Vector2i)
## 유닛 행동 완료
signal unit_action_completed(unit_id: String)
## 유닛 사망
signal unit_died(unit_id: String, killer_id: String)
## 데미지 발생
signal damage_dealt(attacker_id: String, defender_id: String, amount: int, is_crit: bool)
## 힐 발생
signal heal_applied(healer_id: String, target_id: String, amount: int)
## 스킬 사용
signal skill_used(caster_id: String, skill_id: String, targets: Array)
## 상태이상 적용
signal status_applied(target_id: String, status_id: String, duration: int)
## 상태이상 해제
signal status_removed(target_id: String, status_id: String)
## 전투 승리
signal battle_won(battle_id: String)
## 전투 패배
signal battle_lost(battle_id: String)
## 전투 조건 충족 (승리 또는 패배)
## is_victory: true=승리, false=패배
## condition_type: 조건 타입 문자열
## reason_ko: 한국어 결과 설명
signal battle_condition_triggered(is_victory: bool, condition_type: String, reason_ko: String)
## 턴 제한 경고 (남은 턴이 2 이하일 때)
signal turn_limit_warning(turns_remaining: int)

# ── 경험치/레벨 시그널 ──

## 경험치 획득
signal exp_gained(unit_id: String, amount: int)
## 레벨업
signal level_up(unit_id: String, new_level: int, stat_gains: Dictionary)

# ── 스토리/진행 시그널 ──

## 씬 시작
signal scene_started(scene_id: String)
## 씬 종료
signal scene_ended(scene_id: String)
## 대화 시작
signal dialogue_started(scene_id: String)
## 대화 종료
signal dialogue_ended(scene_id: String)
## 전직 발생
signal class_changed(unit_id: String, new_class: String)
## 캐릭터 합류
signal character_joined(unit_id: String)
## 월드맵 노드 해금
signal node_unlocked(node_id: String)

# ── UI 시그널 ──

## 유닛 선택
signal unit_selected(unit_id: String)
## 유닛 선택 해제
signal unit_deselected()
## 셀 호버
signal cell_hovered(cell: Vector2i)
## 메뉴 열기/닫기
signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)

# ── 세이브/로드 시그널 ──

## 세이브 완료
signal game_saved(slot: int)
## 로드 완료
signal game_loaded(slot: int)

# ── 오디오 시그널 ──

## BGM 변경 요청
signal bgm_change_requested(track_id: String)
## SFX 재생 요청
signal sfx_play_requested(sfx_id: String)

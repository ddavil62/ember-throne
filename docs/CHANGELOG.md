# Changelog

## [미출시] - 2026-04-09

### Added (Phase 3 — 오디오 파이프라인)
- BGM 16트랙 소싱 (`assets/audio/bgm/`)
  - CC0 14트랙: bgm_title, bgm_worldmap2, bgm_town1/2, bgm_battle1/2, bgm_boss1/2, bgm_tense1/2, bgm_sad1/2, bgm_victory, bgm_ending1
  - CC-BY 3.0 2트랙: bgm_worldmap1, bgm_ending2 (Jonathan Shaw)
- SFX 39종 소싱 (`assets/audio/sfx/`)
  - 출처: Kenney CC0 (RPG Audio, Interface Sounds, Impact Sounds), OGA 80 CC0 RPG SFX
- `scripts/autoload/audio_manager.gd` 대폭 업데이트:
  - MP3 지원 추가
  - BGM 61개 시맨틱 ID → 16개 파일 별칭 테이블 (BGM_ALIASES)
  - SFX 별칭 테이블 (SFX_ALIASES)
  - EventBus 자동 SFX 배선 (damage_dealt, heal_applied, unit_died, level_up, skill_used, gold_gained, game_saved, game_loaded, battle_won)
- `scripts/battle/battle_scene.gd`: 전투 시작 시 맵 JSON bgm 필드로 BGM 자동 전환, 종료 시 페이드아웃
- `assets/audio/AUDIO-CREDITS.md`: 라이선스 귀속 표기 문서

### Changed (Phase 7-B 잔여 수정)
- `scripts/battle/turn_manager.gd`: `start_battle()`에서 `experience_system.reset()`, `ai_controller.reset()`, `status_manager.clear_all_effects()` 호출 추가
- `scripts/battle/ai/ai_controller.gd`: `reset()` 메서드 추가
- `scripts/battle/combat_calculator.gd`: `force_crit` 파라미터 추가
- `scripts/battle/skill_executor.gd`: `guaranteed_crit` 조건 파싱 (`_check_guaranteed_crit`, `target_hp_below_N` 동적 파싱)

### Added (Phase 8-4 — 빌드 파이프라인)
- `.github/workflows/build.yml`: Windows/Linux/macOS 3플랫폼 자동 빌드
  - 트리거: main push (빌드만), `v*` 태그 push (빌드+Release), workflow_dispatch
  - chickensoft-games/setup-godot@v2, Godot 4.6.2-stable

### Added (Phase 8-2 — 스토어 설명)
- `docs/STEAM-STORE.md`: Steam 스토어 페이지용 숏/롱 디스크립션 (한/영), 핵심 특징 7개, 태그 10개

#### 참고
- Phase 3 리포트: `.claude/specs/2026-04-08-ember-throne-audio-pipeline-report.md` (해당 시)
- Phase 7-B 리포트: `.claude/specs/2026-04-06-ember-throne-turn-battle-logic-report.md`
- Phase 8-4 리포트: `.claude/specs/2026-04-08-ember-throne-build-pipeline-report.md` (해당 시)

## [미출시] - 2026-04-08

### Added (Phase 6 — Steam 플랫폼 통합)
- `scripts/autoload/steam_manager.gd` (신규): GodotSteam 래퍼 싱글톤
  - `Steam.init()` + graceful fallback (`steam_available=false`일 때 모든 호출 no-op)
  - 업적 15개 트리거 연결 (act1~3_clear, ending_a/b, full_party, no_death_clear, hard_mode, all_cg 등)
  - Steam Cloud read/write 세이브 미러링
  - `_process()`에서 `Steam.run_callbacks()` 호출
- `scripts/ui/demo_end_screen.gd` (신규): DEMO_MODE 종료 화면 (위시리스트 안내)
- `scripts/autoload/game_manager.gd`: `DEMO_MODE` 상수 + `check_demo_end()` 분기
- `scripts/autoload/event_bus.gd`: `achievement_unlocked` 시그널 추가
- `scripts/autoload/save_manager.gd`: Steam Cloud 미러링 (로컬 세이브 후 Cloud 동기 쓰기)
- `scripts/ui/options_screen.gd`: 키 리바인드 섹션 + ConfigFile 저장/복원 + `_default_input_events` 캐시
- `scripts/story/story_manager.gd`: `advance_to_act()` 업적/데모 연동, `_get_steam_manager()` 헬퍼
- `project.godot`: SteamManager autoload + 게임패드 이벤트 (D-pad, Left Stick, A/B/Start/LB/RB) + `ui_up/down/left/right` 매핑

#### Phase 6 QA 수정 사항
- story_manager.gd: RefCounted에서 `get_node_or_null` 직접 호출 크래시 -> `_get_steam_manager()` 헬퍼 패턴으로 변경
- options_screen.gd: 키 리바인드 초기화 시 `action_erase_events` 후 빈 배열 반환 버그 -> `_default_input_events` 캐싱으로 수정
- project.godot: `ui_up/down/left/right`에 게임패드 D-pad + Left Stick 매핑 추가

#### Phase 6 알려진 이슈
- Steam App ID 480 (Spacewar) 테스트용 — 실제 ID 발급 후 교체 필요 (LOW)
- Steam Cloud timestamp 비교 미구현 — 로컬 세이브 존재 시 Cloud 무시 (MEDIUM)
- 리바인드 중 ESC 캡처 가능 — 취소 메커니즘 없음 (LOW)

#### 참고
- 스펙: `.claude/specs/2026-04-08-ember-throne-phase6-platform-spec.md`
- 리포트: `.claude/specs/2026-04-08-ember-throne-phase6-platform-report.md`
- QA: `.claude/specs/2026-04-08-ember-throne-phase6-platform-qa.md`
- QA Fix: `.claude/specs/2026-04-08-ember-throne-phase6-qa-fix-report.md`

### Added (Phase 5 — UI 폴리시 7종)
- `scripts/battle/ui/damage_popup.gd` (신규): DamagePopup 팩토리 클래스 — 일반/크리티컬/회복/회피 4종
- `scripts/ui/loading_screen.gd` + `scenes/ui/loading_screen.tscn` (신규): 로딩 화면 CanvasLayer — 팁 + 일러스트 placeholder
- `scripts/ui/bond_banner.gd` (신규): 유대 레벨업 배너 (큐 시스템)
- `scripts/battle/ui/battle_hud.gd`: 미니맵 도트맵 (아군 파랑/적 빨강) + 턴 순서 바 (SPD 내림차순 아이콘) + 대미지 팝업 spawn
- `scripts/battle/turn_manager.gd`: `get_turn_order_units()` API 추가
- `scripts/battle/combat_calculator.gd`: `can_counter()` 반격 판정 메서드 추가
- `scripts/battle/ui/damage_preview.gd`: 반격 가능/불가 행 추가
- `scripts/story/bond_system.gd`: `bond_leveled_up` emit 추가
- `scripts/ui/equipment_screen.gd`: 스탯 비교 개별 빨강/초록 색상

#### Phase 5 QA 수정 사항
- bond_system.gd: `_get_event_bus()` 중복 선언 삭제
- damage_popup.gd: `create_tween()` 호출 시 씬 트리 밖 이슈 -> `_animate()`를 `_ready()`로 이동
- battle_hud.gd: TurnManager 경로 오류 -> 외부 주입 패턴 적용

#### Phase 5 알려진 이슈
- `can_counter()` grid 파라미터 미사용 (LOW)
- `create_miss()` 호출부 없음 (LOW)
- `refresh_minimap()` 매 호출 시 ColorRect 생성/파괴 — 대규모 맵에서 성능 우려 (LOW)

#### 참고
- 스펙: `.claude/specs/2026-04-08-ember-throne-phase5-ui-polish-spec.md`
- 리포트: `.claude/specs/2026-04-08-ember-throne-phase5-ui-polish-report.md`
- QA: `.claude/specs/2026-04-08-ember-throne-phase5-ui-polish-qa.md`

### Added (Phase 4 — 내러티브 완성)
- `scripts/battle/tutorial_overlay.gd` + `scenes/battle/tutorial_overlay.tscn` (신규): 4단계 튜토리얼 오버레이 (이동->공격->스킬->대기) + `is_action_blocked()` API
- `scripts/ui/credits_screen.gd` + `scenes/ui/credits_screen.tscn` (신규): 크레딧 롤 스크롤 + Enter/Space/Esc 스킵 + 타이틀 복귀
- `scripts/battle/battle_scene.gd`: `_init_tutorial()` (튜토리얼 초기화) + 맵 이벤트 런타임 3종 (wave_spawn, dialogue, terrain_change)
- `data/maps/battle_01.json`: tutorial 필드 + events Array 리팩토링
- `scripts/story/story_manager.gd`: 에필로그 -> 크레딧 전환 (`_start_credits()`)
- `scripts/dialogue/dialogue_manager.gd`: `_extract_act()` ending_ prefix 처리
- `data/dialogue/act4.json`: ending_a/b_epilogue 씬 추가 (CG + narration 3건씩)

#### Phase 4 QA 수정 사항
- E-1 (HIGH): 엔딩 분기 시 4-8A/4-8B 씬 미재생 — `_check_ending_branch` 트리거 시점을 4-8A/B 종료로 이동
- E-2 (HIGH): `is_action_blocked` 미호출 — turn_manager에서 호출 로직 추가
- E-3 (MEDIUM): `on_start` 트리거 미처리 — 턴 1에서 on_start 이벤트 확인 로직 추가
- E-4 (MEDIUM): `on_victory` 트리거 미처리 — 승리 시 on_victory 이벤트 핸들러 추가

#### Phase 4 스펙 대비 차이
- credits SCROLL_SPEED: 60(스펙) -> 150(구현), 빠른 스크롤 토글(FAST_SCROLL_SPEED 300) 미구현
- credits FADE_OUT: 1.5s(스펙) -> 1.0s(구현), END_WAIT 2.0s 미구현
- tutorial JSON steps 배열 미포함 — 하드코딩된 STEPS 사용 (기능상 동일)
- CG 이미지 미존재 (ending_a_cg.png, ending_b_cg.png) — 자동 스킵 처리

#### 참고
- 스펙: `.claude/specs/2026-04-08-ember-throne-phase4-narrative-spec.md`
- 리포트: `.claude/specs/2026-04-08-ember-throne-phase4-narrative-report.md`
- QA: `.claude/specs/2026-04-08-ember-throne-phase4-narrative-qa.md`

### Changed (DifficultyManager 싱글톤 최적화)
- `difficulty_manager.gd`: `static var _instance` + `static func get_instance()` 싱글톤 패턴 도입
  - `RefCounted` 기반 유지, 최초 호출 시 1회만 인스턴스 생성
  - 기존 인터페이스(메서드 시그니처) 변경 없음
- `battle_unit.gd`: `DifficultyManager.new()` -> `DifficultyManager.get_instance()` 변경
  - `init_from_enemy()` 호출마다 인스턴스 생성하던 비효율 해소 (Phase 3 QA L1)

## [미출시] - 2026-04-07

### Changed (Phase 3 Hard 난이도 적 스케일링)
- `battle_unit.gd`: `init_from_enemy()`에 `DifficultyManager` 연동
  - `DifficultyManager.new()` 생성 후 `get_enemy_level_bonus()` + `apply_enemy_stats()` 호출
  - Hard: 적 레벨 +1, HP x1.3, ATK x1.2, DEF x1.15, SPD x1.1
  - Normal: 레벨 보너스 0, 배율 1.0 (기존 동작과 수학적 동치)
  - `actual_level` 변수 도입, 스탯 계산 및 `level` 필드에 보정 레벨 사용
  - `apply_enemy_stats()`의 범용 배율(`enemy_stat_multiplier`): Hard 시 mp/matk/mdef/mov에 1.2 배율 적용 (ENEMY_MULTIPLIER_KEYS 외 스탯)

### Added (Phase 3 전투 클리어 보너스 EXP)
- `turn_manager.gd`: `_apply_battle_exp()` 끝에 `rewards.exp_bonus` 처리 블록 추가
  - `battle_map.get_map_data()` -> `rewards.exp_bonus` 조회 (골드 처리와 동일 패턴)
  - `bonus_exp > 0`인 전투에서 승리 시 `_battle_exp_gained` 키의 플레이어 유닛에게 flat EXP 지급
  - `exp_bonus = 0`인 전투에서는 조기 종료 (기존 전투 영향 없음)
- battle JSON 8개 `exp_bonus` 설정 (공식: `difficulty_rating x 5`):
  - battle_21(35), battle_22(35), battle_26(45), battle_29(45), battle_30(40), battle_33(45), battle_34(50), battle_35(50)
  - battle_34/35: `gold=0 + exp_bonus=50` 케이스 (골드 보상 없이 EXP 보너스만 지급)

#### Phase 3 QA LOW 이슈
- L1: `DifficultyManager` 인스턴스가 `init_from_enemy()` 호출마다 생성됨 (RefCounted 기반 즉시 해제, 성능 영향 미미). 장기적으로 싱글톤 또는 BattleScene 레벨 1회 생성 검토
- L2: 보너스 EXP 대상이 `_battle_exp_gained` 키(공격 행동 유닛)로 한정 -- 배치만 하고 공격 미수행 유닛(힐러 등)은 보너스 미수령. 기존 설계 특성이므로 Phase 3 범위 밖

#### 참고
- 스펙: `.claude/specs/2026-04-07-ember-throne-phase3-balance-spec.md`
- 리포트: `.claude/specs/2026-04-07-ember-throne-phase3-report.md`
- QA: `.claude/specs/2026-04-07-ember-throne-phase3-qa.md`

### Added (Phase 2 골드 보상 시스템)
- `party_manager.gd`: `gold: int` 필드, `add_gold()`, `spend_gold()`, `get_gold()` 메서드 추가
- `event_bus.gd`: `gold_gained(amount: int)` 시그널 추가
- `turn_manager.gd`: `_battle_gold_gained` 누적 변수, 적 사망 시 골드 드롭 처리 (공격/반격 양쪽)
- `turn_manager.gd`: `_apply_battle_gold()` 함수 -- 드롭 골드 + `rewards.gold` 합산 후 `PartyManager.add_gold()` 지급
- `save_manager.gd`: 세이브/로드에 `gold` 필드 포함 (`_serialize_game_state()`, `_apply_save_data()`)

#### Phase 2-A 상세
- 적 사망 시 `defender._source_data.get("gold_reward", {})` 직접 접근 (불필요한 DataManager 재조회 회피)
- 반격 사망 시에도 동일 골드 누적 로직 적용 (스펙 미명시, 일관성 위해 추가)
- `gold` 직렬화는 `party_manager.serialize()`(Array 반환)가 아닌 `save_manager.gd`에서 직접 처리 (기존 아키텍처 적합)
- `add_gold()`: amount <= 0 가드 포함
- `gold_reward.max = 0`인 적(보스 등)은 `if g_max > 0` 조건으로 골드 드롭 안 함

### Changed (Phase 2 캐릭터 합류 레벨 갱신)
- `story_manager.gd` CHARACTER_JOINS 전면 재편 (LEVEL-DESIGN.md Section 4 기준):
  - kael(1-1 Lv1), seria(1-4 Lv1), grid(1-5 Lv2), rinen(1-6 Lv2)
  - roc/nael(2-1 Lv6), drana(2-9 Lv10), voldt(2-10 Lv11)
  - irene(3-1 Lv13), hazel(3-12 Lv18), cyr(3-14 Lv18), elmira(4-5 Lv25)
- 캐릭터 JSON `join_level` 갱신 5건: roc(5->6), nael(5->6), drana(9->10), voldt(10->11), irene(12->13)
- 나머지 7인(kael, seria, grid, rinen, hazel, cyr, elmira)은 기존 값 일치로 미변경
- `party_manager.gd` `add_character()`: 초기 EXP를 0으로 설정 (스펙의 누적 EXP 공식 대신 -- `exp`가 "잔여 경험치" 방식이므로 누적값 설정 시 연쇄 레벨업 버그 발생)

#### Phase 2 QA MEDIUM 이슈 (후속 작업 필요)
- M1: `spend_gold()` 음수 amount 미검증 -- 현재 호출부 없어 즉시 위험 없음, 상점 구현 시 `if amount <= 0: return false` 가드 추가 필요
- M2: `init_default_party()`가 seria/rinen을 1-1에서 합류시키지만 CHARACTER_JOINS는 1-4/1-6 -- 기획 확인 후 정리 필요

#### 참고
- 스펙: `.claude/specs/2026-04-07-ember-throne-phase2-balance-spec.md`
- 리포트: `.claude/specs/2026-04-07-ember-throne-phase2-2a-report.md`, `.claude/specs/2026-04-07-ember-throne-phase2-2b-report.md`
- QA: `.claude/specs/2026-04-07-ember-throne-phase2-balance-qa.md`

### Changed (Phase 1 레벨 밸런스)
- 35개 battle JSON enemy_placements 적 레벨을 LEVEL-DESIGN.md 기준으로 갱신
  (Act 2: Lv7~13, Act 3: Lv14~22, Act 4: Lv22~28 범위로 상향)
- party_manager.gd EXP 공식 통합: `100+(level-1)*10` → `level*100`
  (experience_system.gd와 동일 공식, LEVEL-DESIGN.md 기준에 맞춤)
- 벤치 유닛 EXP 활성화: 비참전 파티원이 참전 유닛 평균 50% EXP 획득
  (PartyManager 연동, gain_exp() 경로로 레벨업 자동 처리)
- tests/verify_battle_levels.js: battle JSON 레벨 자동 검증 스크립트 추가 (회귀 테스트용)

#### Phase 1 상세
- battle JSON 30개 수정, 5개(01, 17, 33, 34, 35)는 이미 목표 범위 일치로 미변경
- 399적 전수 레벨 조정 (보스: 상한값, 미니보스: 조건부 상한/상한-1, support: 중간값, 일반: 균등 분포)
- 스펙 대비 변경: 미니보스 레벨 할당을 보스 유무에 따라 조건부로 변경 (보스 없는 전투에서 미니보스가 상한값 담당)
- 벤치 유닛 조회: 스펙의 `GameManager.get_party_members()` 대신 `_get_party_manager().party` 직접 접근으로 구현
- QA MEDIUM 2건(사망 유닛 벤치 EXP 수령, 사망 유닛 참전 EXP 소실)은 후속 작업으로 분리

#### 참고
- 스펙: `.claude/specs/2026-04-07-ember-throne-phase1-level-balance-spec.md`
- 리포트: `.claude/specs/2026-04-07-ember-throne-phase1-1a-report.md`, `.claude/specs/2026-04-07-ember-throne-phase1-1bc-report.md`
- QA: `.claude/specs/2026-04-07-ember-throne-phase1-level-balance-qa.md`

### Added
- VictoryConditionChecker: JSON 기반 데이터 드리븐 승리/패배 조건 시스템
  - 6가지 조건 타입: rout, escape, survive/survive_turns, unit_death, turn_limit_exceeded, unit_hp_threshold
  - EventBus 시그널 연동 (unit_died, unit_moved, turn_started, damage_dealt)
  - 조건별 커스텀 한국어 결과 메시지
  - _active 플래그로 중복 전투 종료 시그널 방지

### Changed
- TurnManager: VictoryConditionChecker를 자식 노드로 통합, 기존 check_battle_end() 제거, BATTLE_END 상태 보호 가드 추가
- BattleMap: check_battle_end() 메서드 제거, get_map_data() 추가
- BattleResult: show_result()에 condition_type/reason_ko 파라미터 추가, 조건별 한국어 메시지 표시
- EventBus: battle_condition_triggered, turn_limit_warning 시그널 추가
- BattleScene: battle_condition_triggered 시그널 연결

### Fixed
- survive vs survive_turns 타입명 불일치: 복수 패턴 매칭으로 양쪽 모두 지원 (QA HIGH-2)
- turn_limit: null인 escape 조건에서 타입 체크 누락: typeof() 가드 추가 (QA HIGH-3)
- _complete_action()에서 BATTLE_END 상태 덮어쓰기: 메서드 시작부에 상태 가드 추가 (QA HIGH-1)

### 참고
- 스펙: `.claude/specs/2026-04-07-ember-throne-victory-conditions-spec.md`
- 리포트: `.claude/specs/2026-04-07-ember-throne-victory-conditions-report.md`
- QA: `.claude/specs/2026-04-07-ember-throne-victory-conditions-reqa.md`
- 스펙 대비 추가 변경: battle_scene.gd에 battle_condition_triggered 콜백 추가, defeat_achieved 시그널에 reason_ko 파라미터 추가, 아군 전멸 기본 패배 처리 추가
- MEDIUM 이슈(defeat turn_limit_exceeded의 null 안전성) 미해결 -- 현재 배틀 데이터에 해당 케이스 없음, 별도 작업으로 분리

## 2026-04-07 - 레벨 밸런스 기획서 추가

### 추가
- `docs/LEVEL-DESIGN.md` 생성 (369줄, 8개 섹션)
  - EXP 시스템: `level * 100` 공식 기반 Lv1~30 테이블
  - 막별 권장 레벨: 1막 Lv7, 2막 Lv14, 3막 Lv21, 4막 Lv27
  - 35전 전투 밸런스 시트: 권장 레벨, 적 레벨, EXP/골드 보상, 난이도
  - 12인 캐릭터 합류 레벨 및 전직 시점
  - 유랑 7전 파밍 효율 및 레벨 따라잡기 가이드
  - 골드 흐름 분석: 막별 수입/지출, 부족/여유 구간
  - Normal/Hard 난이도별 권장 레벨 차이 (+2~3)
  - 데미지 검증: 막별 카엘 기본공격/최강스킬, 최종막 딜러 비교
- `docs/GAME-DESIGN.md` 문서 맵에 LEVEL-DESIGN.md 항목 추가

### 참고
- 스펙: `.claude/specs/2026-04-07-ember-throne-stage-level-design-spec.md`
- 리포트: `.claude/specs/2026-04-07-ember-throne-stage-level-design-report.md`
- QA: `.claude/specs/2026-04-07-ember-throne-stage-level-design-qa.md`
- QA에서 4막 EXP 합산 오류(11,500 -> 14,100) 및 유랑 EXP 합산 오류(8,100 -> 5,500) 지적 -- LEVEL-DESIGN.md에 수정 반영 완료
- 캐릭터 합류 레벨 JSON 불일치 5건은 별도 Coder 작업에서 일괄 갱신 예정 (문서가 기획 목표, JSON은 미갱신 상태)

## 2026-04-06 - 프로젝트 초기 구현

### 추가
- 전투 시스템 전체 (턴 관리, 그리드, 전투 계산, AI, VFX, 스킬, 경험치)
- 대화 시스템 (대화창, 선택지, CG 뷰어)
- 스토리 매니저, 전직 시스템, 유대 시스템
- 월드맵, 거점, 상점
- UI 전체 (편성, 인벤토리, 장비, 옵션, 세이브/로드, CG 갤러리)
- 난이도 시스템 (Normal/Hard)
- 기획 문서 11종 (GAME-DESIGN, BATTLE-SYSTEM, CHARACTERS, ENEMIES, ITEMS-EQUIPMENT, MAPS, DIFFICULTY, UI-FLOW, WORLD-PROGRESSION, SKILL-ANIMATIONS, STORY)
- 데이터 JSON: 캐릭터 12종, 적 18종, 전투 맵 35종, 지형, 상점, 난이도, 유대, 월드 노드
- 캐릭터 스프라이트 14종 (8방향), 타일셋 6지역 18종, UI 에셋

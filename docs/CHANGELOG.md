# Changelog

## [미출시] - 2026-04-07

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

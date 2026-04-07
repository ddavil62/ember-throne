# Changelog

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

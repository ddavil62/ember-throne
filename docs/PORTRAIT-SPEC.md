# Ember Throne - 대사 포트레이트 스펙

> 2026-04-06 | 대사 컷씬용 감정별 포트레이트

## 공통 스타일

- **해상도**: 832×1216 (SDXL 세로 비율)
- **프레이밍**: 흉상 (bust shot, chest-up)
- **배경**: 단색 다크 그래디언트 (캐릭터에 따라 톤 변화)
- **화풍**: 세미리얼리스틱 판타지 RPG (컨셉아트 기준)
- **저장 경로**: `assets/portraits/{name}_{emotion}.png`

## 캐릭터별 감정 변형

### 플레이어블 캐릭터 (12인)

| # | 캐릭터 | 감정 변형 | 수량 |
|---|--------|----------|------|
| 1 | 카엘(Kael) | neutral, sad, angry, determined, worried, smile | 6 |
| 2 | 세리아(Seria) | neutral, cold, sad, tender, shocked, smile | 6 |
| 3 | 리넨(Linen) | neutral, confused, scared, sad, determined, gentle-smile | 6 |
| 4 | 로크(Roc) | neutral, angry, grief, determined, hostile | 5 |
| 5 | 나엘(Nael) | neutral, warm-smile, worried, sad, loving | 5 |
| 6 | 그리드(Grid) | neutral, smirk, serious, tender | 4 |
| 7 | 드라나(Drana) | neutral, analytical, shocked, angry, grief | 5 |
| 8 | 볼드(Voldt) | neutral, kind-smile, sad, determined, anguished | 5 |
| 9 | 이렌(Irene) | neutral, cold, determined, rare-smile | 4 |
| 10 | 헤이즐(Hazel) | neutral, stern, conflicted, determined | 4 |
| 11 | 시르(Cyr) | neutral, serene, melancholy, slight-smile | 4 |
| 12 | 엘미라(Elmira) | neutral, dignified, vulnerable, kind | 4 |

**소계: 58장**

### 주요 NPC

| # | 캐릭터 | 감정 변형 | 수량 |
|---|--------|----------|------|
| 13 | 칼드릭(Caldric) | neutral, grief, desperate, vulnerable | 4 |
| 14 | 모르간(Morgan) | neutral, smirk, rage, inhuman | 4 |
| 15 | 톰(Tom) | smile, determined, sacrifice | 3 |
| 16 | 피나(Fina) | happy, scared, brave | 3 |
| 17 | 올가(Olga) | stern, caring, worried | 3 |
| 18 | 에리스(Eris) | gentle, sad, peaceful | 3 |
| 19 | 렌도르(Rendor) | scholarly, guilty, regretful | 3 |
| 20 | 루시드(Lucid) | cold, neutral, surrendered | 3 |
| 21 | 바르톨(Bartol) | sly-smile, neutral | 2 |
| 22 | 아네트(Anette) | eager, worried, determined | 3 |
| 23 | 카렌(Karen) | weak-smile, sick | 2 |
| 24 | 마리나(Marina) | happy, excited | 2 |
| 25 | 재의 군주(Ash Lord) | mysterious | 1 |

**소계: 36장**

---

**총계: 94장**

## 감정별 SD 프롬프트 수식어

| 감정 | 영어 프롬프트 수식어 |
|------|---------------------|
| neutral | calm expression, neutral face |
| smile / warm-smile | warm smile, gentle expression |
| sad / grief | sorrowful expression, teary eyes, downcast gaze |
| angry / rage | furious expression, furrowed brows, clenched jaw |
| determined | resolute gaze, fierce determination, unwavering eyes |
| worried / concerned | worried expression, furrowed brows, anxious eyes |
| shocked / surprised | wide eyes, shocked expression, slightly open mouth |
| cold / stern | cold piercing gaze, stoic expression |
| confused | bewildered expression, uncertain gaze |
| scared | frightened expression, trembling, wide fearful eyes |
| tender / loving | tender gaze, soft expression, loving eyes |
| smirk / sly | sly smirk, knowing expression, one corner of mouth raised |
| anguished | agonized expression, tears streaming, raw grief |
| serene / peaceful | serene expression, peaceful, tranquil gaze |
| melancholy | wistful expression, distant sad eyes |
| vulnerable | fragile expression, guard down, tearful |
| dignified | regal composure, noble bearing |
| analytical | focused calculating gaze, intellectual expression |
| hostile | aggressive scowl, threatening gaze |

## 생성 순서

1. **1차** (주인공 3인): 카엘, 세리아, 리넨 — 18장
2. **2차** (2막 합류): 로크, 나엘, 그리드, 드라나 — 19장
3. **3차** (3막 합류): 볼드, 이렌, 헤이즐, 시르 — 17장
4. **4차** (엘미라 + NPC): 엘미라 + NPC 13종 — 40장

/**
 * @fileoverview Ember Throne 대사 포트레이트 일괄 생성 스크립트
 * SDXL (sd_xl_base_1.0) 모델 사용, 832×1216 세로 비율
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const SD_HOST = '192.168.219.100';
const SD_PORT = 7860;
const OUT_DIR = path.join(__dirname, 'assets', 'portraits');

// ── 공통 설정 ──
const COMMON = {
  negative_prompt: 'blurry, low quality, bad anatomy, deformed, ugly, text, watermark, signature, multiple people, full body, cropped face, out of frame, worst quality, jpeg artifacts, extra fingers, mutated hands',
  steps: 25,
  width: 832,
  height: 1216,
  cfg_scale: 7,
  sampler_name: 'DPM++ 2M Karras',
  n_iter: 1,
};

const STYLE_SUFFIX = 'RPG character portrait, bust shot, dark gradient background, semi-realistic digital painting, fantasy art, detailed face, masterpiece, best quality, dramatic lighting, painterly style';

// ── 캐릭터 정의 ──
const CHARACTERS = {
  // === 1차 배치: 주인공 3인 ===
  kael: {
    base: 'young adult male, black leather jacket, steel shoulder armor on left shoulder, exposed right arm with tribal burn tattoo, undercut brown hair, chin scar, fingerless gloves, strong jaw, handsome rugged face',
    emotions: {
      neutral: 'calm expression, neutral face, steady gaze',
      sad: 'sorrowful expression, downcast gaze, heavy eyes, melancholy',
      angry: 'furious expression, furrowed brows, clenched jaw, burning angry eyes',
      determined: 'resolute fierce gaze, unwavering determination, intense eyes',
      worried: 'worried expression, furrowed brows, anxious concerned eyes',
      smile: 'warm gentle smile, soft kind eyes, relaxed expression',
    },
  },
  seria: {
    base: 'young adult woman, cropped white top with gold trim, asymmetric open long coat modified from temple robe, silver-white layered long hair, purple mystical brand mark near left eye, crystal choker, elegant beautiful face',
    emotions: {
      neutral: 'calm composed expression, analytical gaze',
      cold: 'cold piercing gaze, stoic intellectual expression, guarded',
      sad: 'teary eyes, gentle sorrow, downcast gaze, vulnerable',
      tender: 'soft tender gaze, warmth breaking through her guard, gentle',
      shocked: 'wide shocked eyes, parted lips, stunned expression',
      smile: 'gentle warm smile, guard lowered, beautiful serene expression',
    },
  },
  linen: {
    base: 'androgynous young person, oversized gray and gold hoodie-cloak hybrid, fitted dark inner wear, glowing ember burn scar on one hand, silver-streaked messy black hair partially covering eyes, thin delicate build, mysterious ethereal beauty',
    emotions: {
      neutral: 'blank uncertain expression, quiet gaze',
      confused: 'bewildered expression, tilted head, uncertain puzzled gaze',
      scared: 'frightened wide eyes, trembling, fearful expression',
      sad: 'deep silent sorrow, tears rolling down, downcast eyes',
      determined: 'fierce determination, ember glow in eyes, resolute unwavering',
      'gentle-smile': 'small gentle smile, peaceful warmth, soft eyes',
    },
  },
  // === 2차 배치: 2막 합류 ===
  roc: {
    base: 'young adult male, dark green tactical vest with strap buckles, black compression shirt, leather archery guard on forearm, high ponytail dark hair, green warpaint on face, sharp fierce features, hunter warrior',
    emotions: {
      neutral: 'stoic composed expression, alert watchful gaze',
      angry: 'furious snarling expression, baring teeth, rage in eyes',
      grief: 'agonized grief, tears running, trying not to cry, raw pain',
      determined: 'fierce unwavering determination, burning resolve',
      hostile: 'aggressive threatening scowl, distrustful narrowed eyes',
    },
  },
  nael: {
    base: 'young adult woman, olive green military field jacket with rolled sleeves over white blouse, brown crossbody herb bag, side braid with herb flowers woven in, freckles, warm kind face, healer',
    emotions: {
      neutral: 'gentle calm expression, attentive caring gaze',
      'warm-smile': 'warm radiant smile, bright kind eyes, genuine happiness',
      worried: 'deeply worried expression, furrowed brows, pained empathy',
      sad: 'quiet sadness, glistening eyes, holding back tears',
      loving: 'tender loving gaze, soft adoring expression, blushing slightly',
    },
  },
  grid: {
    base: 'middle-aged rugged male, weathered brown leather trench coat with fur collar, open collar shirt, gold tooth, scar on one ear, salt-and-pepper stubble beard, fingerless gloves, roguish smuggler, drawing of child peeking from chest pocket',
    emotions: {
      neutral: 'casual indifferent expression, guarded cynical gaze',
      smirk: 'sly cynical smirk, one eyebrow raised, knowing look',
      serious: 'dead serious expression, no humor, intense focus',
      tender: 'rare tender expression, soft eyes, guard completely down, fatherly warmth',
    },
  },
  drana: {
    base: 'young adult woman, academy blazer half worn hanging off one shoulder, black turtleneck underneath, round glasses, purple hair in loose bun with quill pen, blue arcane runes floating near left hand, scholarly mage, intelligent beautiful face',
    emotions: {
      neutral: 'composed intellectual expression, thoughtful gaze',
      analytical: 'focused calculating gaze, adjusting glasses, intense study',
      shocked: 'wide horrified eyes behind glasses, hand over mouth, disbelief',
      angry: 'furious trembling expression, arcane runes flaring, betrayed rage',
      grief: 'silent grief, removing glasses to wipe tears, broken composure',
    },
  },
  // === 3차 배치: 3막 합류 ===
  voldt: {
    base: 'older large muscular male, modern geometric full plate armor futuristic knight style, fur collar dark cloak, white braided beard, weary kind face without helmet, massive tower shield, gentle giant warrior',
    emotions: {
      neutral: 'calm steady expression, wise tired eyes',
      'kind-smile': 'warm fatherly smile, gentle kind eyes, reassuring',
      sad: 'deep sorrow weighing down, heavy eyes, aged grief',
      determined: 'iron resolve, unbreakable will, standing firm',
      anguished: 'raw anguish, tears in weathered face, devastated, broken',
    },
  },
  irene: {
    base: 'adult woman, sleek black tactical suit under dark navy long coat, hidden daggers, black gloves, high heel boots, dark hair in tight chignon updo, sharp piercing eyes, elegant dangerous spy assassin aesthetic',
    emotions: {
      neutral: 'calculating cold expression, appraising sharp gaze',
      cold: 'ice cold merciless stare, zero emotion, deadly calm',
      determined: 'fierce quiet determination, burning purpose behind cold eyes',
      'rare-smile': 'rare subtle smile, just a hint of warmth, still sharp',
    },
  },
  hazel: {
    base: 'middle-aged handsome male, dark military dress coat with medals and decorations, white streak in short hair, stern commanding face, riding boots, military general bearing, disciplined posture',
    emotions: {
      neutral: 'stern composed military expression, authoritative gaze',
      stern: 'harsh unyielding stare, jaw set, absolute authority',
      conflicted: 'inner turmoil visible in eyes, wavering resolve, moral struggle',
      determined: 'resolved expression, breaking free of doubt, new conviction',
    },
  },
  cyr: {
    base: 'ancient knight with youthful face, modernized half plate armor tinged gray with ash particles drifting from gaps, heterochromia one silver-gray eye one amber eye, long pale gray-white hair with one strand of original black, worn tattered cloak with faded old kingdom crest, ash crystal on spear tip, ethereal haunting beauty',
    emotions: {
      neutral: 'quiet composed expression, ancient knowing gaze, calm',
      serene: 'peaceful serene expression, transcendent calm, slight distant smile',
      melancholy: 'wistful melancholy, distant longing in mismatched eyes, centuries of solitude',
      'slight-smile': 'subtle warm smile, first genuine warmth in centuries, gentle',
    },
  },
  // === 4차 배치: 엘미라 + NPC ===
  elmira: {
    base: 'mature elegant woman, modern high fashion reinterpretation of white and gold religious robes, elaborate geometric headpiece, long gray hair, gold jewelry, powerful presence, high priestess, regal bearing',
    emotions: {
      neutral: 'composed regal expression, commanding presence',
      dignified: 'noble dignified bearing, imperious calm, absolute authority',
      vulnerable: 'rare vulnerability showing, guard crumbling, human fragility',
      kind: 'warm maternal kindness, gentle understanding, compassionate',
    },
  },
  caldric: {
    base: 'elderly frail male, once grand royal attire now worn and disheveled, tilted crown, dark circles under eyes, thin gaunt build, gold embroidered coat fraying, guilt-ridden old king, haunted expression',
    emotions: {
      neutral: 'weary exhausted expression, weight of crown visible',
      grief: 'overwhelming guilt and grief, hollow eyes, broken king',
      desperate: 'desperate pleading expression, reaching out, last hope',
      vulnerable: 'stripped of royal mask, just a tired guilty father, trembling',
    },
  },
  morgan: {
    base: 'adult male, sharply tailored dark suit style with fantasy elements, slicked back black hair, cold calculating eyes, multiple jeweled rings, dark wine colored high collar coat, dangerous political charisma, handsome villain',
    emotions: {
      neutral: 'cold composed expression, predatory calm, watching',
      smirk: 'cruel satisfied smirk, superiority, enjoying control',
      rage: 'explosive inhuman rage, veins visible, losing composure, terrifying',
      inhuman: 'transformed beyond human, glowing cracks in skin, power corruption, monstrous yet pitiful',
    },
  },
  tom: {
    base: 'young adult male, blacksmith, muscular build, warm smile, leather work apron, bandana on head, soot-stained arms, honest earnest young man, kind face',
    emotions: {
      smile: 'bright warm genuine smile, cheerful loyal friend, sunny',
      determined: 'brave resolute expression, protecting someone, selfless courage',
      sacrifice: 'peaceful acceptance, no regret, last gentle smile, saying goodbye',
    },
  },
  fina: {
    base: '12 year old girl, simple forest-style dress with flower crown, bright innocent wide eyes, barefoot, holding stuffed animal, delicate childlike features, pure innocent child',
    emotions: {
      happy: 'beaming bright smile, sparkling innocent eyes, pure joy',
      scared: 'frightened expression, clutching stuffed animal, wide tearful eyes',
      brave: 'brave determined little face, standing firm despite fear, courageous child',
    },
  },
  olga: {
    base: 'elderly strong woman, practical travel clothes, walking cane, resolute expression, village elder, tough maternal figure, weathered kind face',
    emotions: {
      stern: 'firm authoritative expression, no-nonsense elder, commanding respect',
      caring: 'warm caring maternal expression, protective grandmother',
      worried: 'deeply worried concern, looking into distance, praying for safety',
    },
  },
  eris: {
    base: 'adult beautiful woman, elegant warm-toned simple dress, military wife pendant necklace, beautiful but sad eyes, graceful refined features, gentle beauty',
    emotions: {
      gentle: 'soft gentle expression, quiet beauty, kind warm eyes',
      sad: 'deep sadness, resigned sorrow, beautiful tears',
      peaceful: 'peaceful acceptance, serene final smile, at peace, ethereal',
    },
  },
  rendor: {
    base: 'elderly scholarly male, tweed-style fantasy scholar robe, round spectacles, kind face hiding guilt underneath, stack of research papers, ink-stained fingers, gray chin beard, professor mentor figure',
    emotions: {
      scholarly: 'intellectual focused expression, absorbed in thought, wise',
      guilty: 'guilt-ridden expression, avoiding eye contact, shame visible',
      regretful: 'deep regret and remorse, teary behind glasses, asking forgiveness',
    },
  },
  lucid: {
    base: 'adult male, black leather uniform with high collar, pale gaunt face, silver frame glasses, calm oppressive presence, secret police chief, cold efficient, sharp features',
    emotions: {
      cold: 'ice cold emotionless stare, clinical detachment, terrifying calm',
      neutral: 'composed controlled expression, observing judging',
      surrendered: 'defeated resignation, glasses lowered, first sign of humanity, tired',
    },
  },
  bartol: {
    base: 'middle-aged well-dressed male, fancy vest with monocle, shrewd but fair face, merchant guild leader, portly, well-groomed, calculating but honest',
    emotions: {
      'sly-smile': 'shrewd knowing smile, monocle glinting, businessman charm',
      neutral: 'composed business expression, evaluating, practical',
    },
  },
  anette: {
    base: 'young adult woman, military uniform youthful feminine version, short practical hair, idealistic enthusiastic expression, following her mentor Hazel style but lighter, young captain',
    emotions: {
      eager: 'bright eager enthusiastic expression, ready for action, idealistic fire',
      worried: 'anxious worried expression, questioning, uncertain but caring',
      determined: 'newly found resolve, stepping up, growing conviction',
    },
  },
  karen: {
    base: '14 year old thin pale girl, wrapped in blanket, flower in hair despite illness, sickly complexion, gentle fragile beauty, farm girl',
    emotions: {
      'weak-smile': 'weak but genuine smile despite illness, hopeful, brave little girl',
      sick: 'pale exhausted expression, fever, struggling but enduring',
    },
  },
  marina: {
    base: '7 year old little girl, messy twin tails hair, patched worn clothes, holding crayon drawing, bright energetic child, innocent cute face',
    emotions: {
      happy: 'pure bright happy smile, sparkling eyes, excited child seeing daddy',
      excited: 'overjoyed bouncing excitement, wide amazed eyes, pure childlike wonder',
    },
  },
  ashlord: {
    base: 'abstract ethereal being, humanoid silhouette made of gray ash and fading light, dissolving ashen crown floating above head, inhuman yet majestic, supernatural entity, nature incarnation',
    emotions: {
      mysterious: 'enigmatic unknowable expression, neither hostile nor friendly, ancient beyond comprehension, elemental presence',
    },
  },
};

// ── SD API 호출 ──
function generate(prompt, outputPath) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({
      ...COMMON,
      prompt,
    });
    const req = http.request({
      hostname: SD_HOST, port: SD_PORT,
      path: '/sdapi/v1/txt2img', method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) },
      timeout: 120000,
    }, (res) => {
      let body = '';
      res.on('data', d => body += d);
      res.on('end', () => {
        try {
          const data = JSON.parse(body);
          if (data.images && data.images[0]) {
            fs.writeFileSync(outputPath, Buffer.from(data.images[0], 'base64'));
            resolve(outputPath);
          } else {
            reject(new Error('No image in response'));
          }
        } catch (e) { reject(e); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Timeout')); });
    req.write(payload);
    req.end();
  });
}

// ── 메인 실행 ──
async function main() {
  // 배치 필터 (인자로 전달)
  const batchArg = process.argv[2] || 'all';
  const batchMap = {
    '1': ['kael', 'seria', 'linen'],
    '2': ['roc', 'nael', 'grid', 'drana'],
    '3': ['voldt', 'irene', 'hazel', 'cyr'],
    '4': ['elmira', 'caldric', 'morgan', 'tom', 'fina', 'olga', 'eris', 'rendor', 'lucid', 'bartol', 'anette', 'karen', 'marina', 'ashlord'],
    'all': Object.keys(CHARACTERS),
  };
  const targets = batchMap[batchArg] || batchMap.all;

  fs.mkdirSync(OUT_DIR, { recursive: true });

  let total = 0;
  let done = 0;
  for (const name of targets) {
    total += Object.keys(CHARACTERS[name].emotions).length;
  }

  console.log(`=== Ember Throne Portrait Generator ===`);
  console.log(`Batch: ${batchArg} | Characters: ${targets.length} | Portraits: ${total}`);
  console.log(`Output: ${OUT_DIR}\n`);

  for (const name of targets) {
    const char = CHARACTERS[name];
    for (const [emotion, emotionDesc] of Object.entries(char.emotions)) {
      const prompt = `${char.base}, ${emotionDesc}, ${STYLE_SUFFIX}`;
      const outFile = path.join(OUT_DIR, `${name}_${emotion}.png`);

      // 이미 생성된 파일 스킵
      if (fs.existsSync(outFile)) {
        done++;
        console.log(`[${done}/${total}] SKIP ${name}_${emotion} (already exists)`);
        continue;
      }

      try {
        console.log(`[${done + 1}/${total}] Generating ${name}_${emotion}...`);
        await generate(prompt, outFile);
        done++;
        console.log(`[${done}/${total}] OK ${name}_${emotion}`);
      } catch (err) {
        console.error(`[ERROR] ${name}_${emotion}: ${err.message}`);
        // 에러 시에도 계속 진행
        done++;
      }
    }
  }

  console.log(`\n=== Complete: ${done}/${total} portraits ===`);
}

main().catch(e => console.error('Fatal:', e));

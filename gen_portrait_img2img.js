/**
 * @fileoverview img2img 기반 포트레이트 생성 — 컨셉아트를 레퍼런스로 감정만 변경
 * denoising_strength로 원본 유지도 조절
 */
const http = require('http');
const fs = require('fs');
const path = require('path');

const SD_HOST = '192.168.219.100';
const SD_PORT = 7860;
const OUT_DIR = path.join(__dirname, 'assets', 'portraits');

const STYLE_SUFFIX = 'RPG character portrait, bust shot, dark gradient background, semi-realistic digital painting, fantasy art, detailed face, masterpiece, best quality, dramatic lighting';
const NEGATIVE = 'blurry, low quality, bad anatomy, deformed, ugly, text, watermark, signature, multiple people, full body, cropped face, out of frame, worst quality, jpeg artifacts, extra fingers, mutated hands';

function img2img(baseImagePath, prompt, outputPath, strength = 0.4) {
  return new Promise((resolve, reject) => {
    const imgBase64 = fs.readFileSync(baseImagePath).toString('base64');

    const payload = JSON.stringify({
      init_images: [imgBase64],
      prompt,
      negative_prompt: NEGATIVE,
      denoising_strength: strength,
      steps: 30,
      width: 832,
      height: 1216,
      cfg_scale: 7,
      sampler_name: 'DPM++ 2M Karras',
      n_iter: 1,
      resize_mode: 1, // crop and resize
    });

    const req = http.request({
      hostname: SD_HOST, port: SD_PORT,
      path: '/sdapi/v1/img2img', method: 'POST',
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
            reject(new Error('No image: ' + JSON.stringify(data).slice(0, 200)));
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

// ── 카엘 테스트 ──
const KAEL_EMOTIONS = {
  neutral:    { expr: 'calm expression, neutral face, steady gaze', strength: 0.35 },
  sad:        { expr: 'sorrowful expression, downcast gaze, heavy sad eyes, melancholy', strength: 0.4 },
  angry:      { expr: 'furious expression, furrowed brows, clenched jaw, burning angry eyes', strength: 0.4 },
  determined: { expr: 'resolute fierce gaze, unwavering determination, intense focused eyes', strength: 0.38 },
  worried:    { expr: 'worried expression, furrowed brows, anxious concerned eyes', strength: 0.38 },
  smile:      { expr: 'warm gentle smile, soft kind eyes, relaxed happy expression', strength: 0.4 },
};

const KAEL_BASE = 'young adult male, black leather jacket, steel shoulder armor on left shoulder, exposed right arm with tribal burn tattoo, undercut brown hair, chin scar, fingerless gloves, strong jaw, handsome rugged face';
const CONCEPT_PATH = path.join(__dirname, 'assets', 'concepts', 'kael_v2.png');

async function main() {
  fs.mkdirSync(OUT_DIR, { recursive: true });

  const emotions = Object.entries(KAEL_EMOTIONS);
  console.log(`=== Kael img2img Portrait Test (${emotions.length} emotions) ===\n`);

  for (let i = 0; i < emotions.length; i++) {
    const [emotion, { expr, strength }] = emotions[i];
    const prompt = `${KAEL_BASE}, ${expr}, ${STYLE_SUFFIX}`;
    const outFile = path.join(OUT_DIR, `kael_${emotion}_v2.png`);

    console.log(`[${i + 1}/${emotions.length}] ${emotion} (strength=${strength})...`);
    try {
      await img2img(CONCEPT_PATH, prompt, outFile, strength);
      console.log(`  OK -> ${path.basename(outFile)}`);
    } catch (err) {
      console.error(`  ERROR: ${err.message}`);
    }
  }

  console.log('\nDone!');
}

main().catch(e => console.error('Fatal:', e));

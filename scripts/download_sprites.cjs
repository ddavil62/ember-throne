/**
 * @fileoverview PixelLab에서 스프라이트 ZIP을 다운로드하고 올바른 경로에 추출하는 스크립트.
 * 실행: node ember-throne/scripts/download_sprites.cjs
 * 환경변수: PIXELLAB_API_KEY
 */

const https = require('https');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

// ── 설정 ──

const API_KEY = process.env.PIXELLAB_API_KEY;
if (!API_KEY) {
  console.error('오류: PIXELLAB_API_KEY 환경변수가 설정되지 않았습니다.');
  console.error('  export PIXELLAB_API_KEY="your-api-key"');
  console.error('  또는 secrets/pixellab_api_key.txt에 저장하세요.');
  process.exit(1);
}

const PROJECT_ROOT = path.resolve(__dirname, '..');
const SPRITES_DIR = path.join(PROJECT_ROOT, 'assets', 'sprites');
const ENEMIES_DIR = path.join(SPRITES_DIR, 'enemies');

/** 캐릭터 ID → sprite_id 매핑 */
const CHARACTERS = [
  // 플레이어 캐릭터
  { characterId: '2d110c1d-abb9-4047-bc5c-2fab096c5260', spriteId: 'kael', isEnemy: false },
  { characterId: '06fa9cfc-22cb-4ffd-8e79-edd1aaf3e0f0', spriteId: 'seria', isEnemy: false },
  { characterId: '3ea3ff82-f181-46cc-9964-a095e7302870', spriteId: 'nael', isEnemy: false },
  { characterId: 'b4f0c331-4aaf-473c-8247-1fe8ddd67568', spriteId: 'linen', isEnemy: false },
  { characterId: '7535a1c3-ea5a-45a1-b233-83e276c8bea0', spriteId: 'roc', isEnemy: false },
  { characterId: '5b6ca348-387a-45e0-914f-1e901ad73192', spriteId: 'grid', isEnemy: false },
  { characterId: '2c69aeb0-3c05-49d5-ae8c-37dd6e866189', spriteId: 'drana', isEnemy: false },
  { characterId: '058531bf-9781-44c9-93b0-79084710493f', spriteId: 'voldt', isEnemy: false },
  { characterId: 'e52e2871-501e-4f3d-a407-b238877317c1', spriteId: 'irene', isEnemy: false },
  { characterId: 'b0783189-d3cc-4796-b355-82661c2b1ae1', spriteId: 'hazel', isEnemy: false },
  { characterId: 'e5be3624-967c-4661-8f4d-7b64b023e2c5', spriteId: 'cyr', isEnemy: false },
  { characterId: 'a1f4806f-14e9-4f53-adf6-91154c8b2dfe', spriteId: 'elmira', isEnemy: false },
  // 일반 적
  { characterId: '1daa3d65-b896-49d9-a2c5-f76c7f581d71', spriteId: 'conscript_footsoldier', isEnemy: true },
  { characterId: '50799072-5bb1-435f-9373-e14fe18e47f8', spriteId: 'conscript_spearman', isEnemy: true },
  { characterId: '336ca9c7-7bd9-4b6e-819f-0b79a864a775', spriteId: 'conscript_archer', isEnemy: true },
  { characterId: 'b4636a10-c8cb-4ec8-abdd-b45ae17f93f9', spriteId: 'conscript_cavalry', isEnemy: true },
  { characterId: 'fcbec232-e4a2-4450-b7ef-703af1ce4f43', spriteId: 'kingdom_mage', isEnemy: true },
  { characterId: '82a39fa6-4209-41e4-b2f8-c50fce89df76', spriteId: 'secret_police_spy', isEnemy: true },
  { characterId: '45bb8f9c-1042-4bbb-8696-13e8955fdb64', spriteId: 'secret_police_officer', isEnemy: true },
  { characterId: 'e6a2cfce-21bf-415e-9604-903e6d001f6b', spriteId: 'annette_adjutant', isEnemy: true },
  { characterId: '76d20689-f918-4dbe-ac60-5aa9c964efca', spriteId: 'ash_eagle', isEnemy: true },
  { characterId: '7596ea07-3383-4dfa-8783-3791ef910dd8', spriteId: 'ash_giant', isEnemy: true },
  { characterId: '52c082a1-b169-41ae-95a6-20a987329976', spriteId: 'ash_evil_eye', isEnemy: true },
  { characterId: 'a5f1a7f9-657b-4d96-83fb-c707a79d5d8b', spriteId: 'ash_parasite', isEnemy: true },
  { characterId: '3cbad33d-62b7-4af8-9ea7-e6d4b644052b', spriteId: 'ash_flame', isEnemy: true },
  { characterId: '280645f7-af35-42d8-a60a-906a5fa9fe9e', spriteId: 'ash_wolf', isEnemy: true },
  // 보스
  { characterId: '7a26682e-a7d4-4ae0-953f-2abdcae879d5', spriteId: 'lucid', isEnemy: true },
  { characterId: '28902aae-d9eb-4058-bc36-23bb0412fdb0', spriteId: 'ashen_lord_vanguard', isEnemy: true },
  { characterId: 'd3d635fa-d9db-4b6c-a9af-1bb10567de11', spriteId: 'corrupted_morgan', isEnemy: true },
];

// ── 유틸 함수 ──

/**
 * 스프라이트 저장 경로를 반환한다.
 * @param {string} spriteId
 * @param {boolean} isEnemy
 * @returns {string}
 */
function getSpriteDir(spriteId, isEnemy) {
  if (isEnemy) {
    return path.join(ENEMIES_DIR, spriteId);
  }
  return path.join(SPRITES_DIR, spriteId);
}

/**
 * 이미 다운로드 완료되었는지 확인한다 (rotations/south.png 존재 여부).
 * @param {string} spriteDir
 * @returns {boolean}
 */
function isAlreadyDownloaded(spriteDir) {
  return fs.existsSync(path.join(spriteDir, 'rotations', 'south.png'));
}

/**
 * PixelLab API에서 캐릭터 ZIP을 다운로드한다.
 * @param {string} characterId
 * @returns {Promise<Buffer>}
 */
function downloadZip(characterId) {
  return new Promise((resolve, reject) => {
    const url = `https://api.pixellab.ai/mcp/characters/${characterId}/download`;
    const options = {
      headers: { 'Authorization': `Bearer ${API_KEY}` },
      timeout: 120000,
    };

    https.get(url, options, (res) => {
      if (res.statusCode === 423) {
        reject(new Error('HTTP 423: 아직 처리 중입니다. 잠시 후 재시도하세요.'));
        return;
      }
      if (res.statusCode === 301 || res.statusCode === 302) {
        // 리다이렉트 처리
        https.get(res.headers.location, options, (redirectRes) => {
          const chunks = [];
          redirectRes.on('data', (chunk) => chunks.push(chunk));
          redirectRes.on('end', () => resolve(Buffer.concat(chunks)));
          redirectRes.on('error', reject);
        }).on('error', reject);
        return;
      }
      if (res.statusCode !== 200) {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          const body = Buffer.concat(chunks).toString();
          reject(new Error(`HTTP ${res.statusCode}: ${body.substring(0, 200)}`));
        });
        return;
      }

      const contentType = res.headers['content-type'] || '';
      if (contentType.includes('application/json')) {
        const chunks = [];
        res.on('data', (chunk) => chunks.push(chunk));
        res.on('end', () => {
          reject(new Error('API가 JSON을 반환했습니다 (ZIP이 아님): ' + Buffer.concat(chunks).toString().substring(0, 200)));
        });
        return;
      }

      const chunks = [];
      res.on('data', (chunk) => chunks.push(chunk));
      res.on('end', () => resolve(Buffer.concat(chunks)));
      res.on('error', reject);
    }).on('error', reject);
  });
}

/**
 * ZIP 파일을 지정 디렉토리에 추출한다.
 * @param {Buffer} zipBuffer
 * @param {string} destDir
 */
function extractZip(zipBuffer, destDir) {
  const tmpZip = path.join(destDir, '_tmp_download.zip');
  fs.mkdirSync(destDir, { recursive: true });
  fs.writeFileSync(tmpZip, zipBuffer);

  try {
    // unzip 사용 (Git Bash에 포함)
    execSync(`unzip -o "${tmpZip}" -d "${destDir}"`, { stdio: 'pipe' });
  } catch (e) {
    // PowerShell 폴백
    try {
      execSync(`powershell -Command "Expand-Archive -Force -Path '${tmpZip}' -DestinationPath '${destDir}'"`, { stdio: 'pipe' });
    } catch (e2) {
      throw new Error('ZIP 추출 실패: unzip과 PowerShell 모두 사용 불가');
    }
  } finally {
    if (fs.existsSync(tmpZip)) {
      fs.unlinkSync(tmpZip);
    }
  }
}

// ── 메인 실행 ──

async function main() {
  console.log(`스프라이트 다운로드 시작 (총 ${CHARACTERS.length}종)`);
  console.log('');

  let success = 0;
  let skipped = 0;
  let failed = 0;
  const failures = [];

  for (let i = 0; i < CHARACTERS.length; i++) {
    const { characterId, spriteId, isEnemy } = CHARACTERS[i];
    const idx = `[${i + 1}/${CHARACTERS.length}]`;
    const spriteDir = getSpriteDir(spriteId, isEnemy);

    if (isAlreadyDownloaded(spriteDir)) {
      console.log(`${idx} ${spriteId} - 이미 존재, 건너뜀`);
      skipped++;
      continue;
    }

    console.log(`${idx} ${spriteId} 다운로드 중...`);
    try {
      const zipBuffer = await downloadZip(characterId);
      extractZip(zipBuffer, spriteDir);
      console.log(`${idx} ${spriteId} - 완료`);
      success++;
    } catch (err) {
      console.error(`${idx} ${spriteId} - 실패: ${err.message}`);
      failures.push({ spriteId, error: err.message });
      failed++;
    }

    // API 과부하 방지
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log('');
  console.log('=== 다운로드 결과 ===');
  console.log(`성공: ${success}종`);
  console.log(`건너뜀 (이미 존재): ${skipped}종`);
  console.log(`실패: ${failed}종`);
  if (failures.length > 0) {
    console.log('');
    console.log('실패 목록:');
    for (const f of failures) {
      console.log(`  - ${f.spriteId}: ${f.error}`);
    }
  }
}

main().catch((err) => {
  console.error('치명적 오류:', err);
  process.exit(1);
});

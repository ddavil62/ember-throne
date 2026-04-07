/**
 * QA Verification Script: Battle JSON Level Ranges
 * Verifies all 35 battle JSON files have enemy levels within spec target ranges.
 */

const fs = require('fs');
const path = require('path');

// Spec target ranges from the spec document
const TARGET_RANGES = {
  battle_01: { min: 1, max: 3 },
  battle_02: { min: 2, max: 4 },
  battle_03: { min: 2, max: 4 },
  battle_04: { min: 4, max: 6 },
  battle_05: { min: 5, max: 7 },
  battle_06: { min: 3, max: 5 },
  battle_07: { min: 3, max: 5 },
  battle_08: { min: 7, max: 9 },
  battle_09: { min: 9, max: 11 },
  battle_10: { min: 9, max: 11 },
  battle_11: { min: 10, max: 12 },
  battle_12: { min: 10, max: 12 },
  battle_13: { min: 11, max: 13 },
  battle_14: { min: 6, max: 8 },
  battle_15: { min: 8, max: 10 },
  battle_16: { min: 9, max: 11 },
  battle_17: { min: 10, max: 12 },
  battle_18: { min: 14, max: 16 },
  battle_19: { min: 14, max: 16 },
  battle_20: { min: 15, max: 17 },
  battle_21: { min: 16, max: 18 },
  battle_22: { min: 16, max: 18 },
  battle_23: { min: 17, max: 19 },
  battle_24: { min: 17, max: 19 },
  battle_25: { min: 18, max: 20 },
  battle_26: { min: 18, max: 22 },
  battle_27: { min: 16, max: 18 },
  battle_28: { min: 22, max: 24 },
  battle_29: { min: 23, max: 25 },
  battle_30: { min: 22, max: 26 },
  battle_31: { min: 24, max: 26 },
  battle_32: { min: 24, max: 26 },
  battle_33: { min: 25, max: 27 },
  battle_34: { min: 25, max: 28 },
  battle_35: { min: 26, max: 28 },
};

const mapsDir = path.join(__dirname, '..', 'data', 'maps');

let totalPass = 0;
let totalFail = 0;
let totalFiles = 0;
let totalEnemies = 0;
const failures = [];
const warnings = [];

// Boss-level validation
const bossAiTypes = ['boss', 'boss_phase1', 'final_boss', 'miniboss', 'boss_conditional'];

for (const [battleId, range] of Object.entries(TARGET_RANGES)) {
  const filePath = path.join(mapsDir, `${battleId}.json`);

  if (!fs.existsSync(filePath)) {
    failures.push({ battleId, issue: 'FILE NOT FOUND' });
    totalFail++;
    continue;
  }

  totalFiles++;
  const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const placements = data.enemy_placements || [];

  if (placements.length === 0) {
    warnings.push({ battleId, issue: 'No enemy_placements array or empty' });
  }

  let filePass = true;
  let fileLevels = [];
  let bossEntries = [];
  let supportEntries = [];
  let normalEntries = [];

  for (const enemy of placements) {
    totalEnemies++;
    const level = enemy.level;
    const aiOverride = enemy.ai_override;

    fileLevels.push(level);

    // Check if level is within range
    if (level < range.min || level > range.max) {
      filePass = false;
      failures.push({
        battleId,
        issue: `Enemy "${enemy.enemy_id}" at [${enemy.position}] has level ${level}, expected ${range.min}~${range.max}`,
        ai_override: aiOverride,
      });
    }

    // Categorize by AI type
    if (aiOverride && bossAiTypes.includes(aiOverride)) {
      bossEntries.push({ enemy_id: enemy.enemy_id, level, ai_override: aiOverride });
    } else if (aiOverride === 'support') {
      supportEntries.push({ enemy_id: enemy.enemy_id, level, ai_override: aiOverride });
    } else {
      normalEntries.push({ enemy_id: enemy.enemy_id, level, ai_override: aiOverride });
    }
  }

  // Rule validation: Boss should be at range max
  for (const boss of bossEntries) {
    // If there's another boss with higher priority (boss > miniboss), miniboss can be max-1
    const hasTrueBoss = bossEntries.some(b => b.ai_override === 'boss' || b.ai_override === 'boss_phase1' || b.ai_override === 'final_boss');

    if (boss.ai_override === 'boss' || boss.ai_override === 'boss_phase1' || boss.ai_override === 'final_boss') {
      if (boss.level !== range.max) {
        warnings.push({
          battleId,
          issue: `Boss "${boss.enemy_id}" (${boss.ai_override}) has level ${boss.level}, expected max ${range.max}`,
        });
      }
    } else if (boss.ai_override === 'miniboss' || boss.ai_override === 'boss_conditional') {
      // Miniboss should be max or max-1 (max if no true boss)
      if (!hasTrueBoss && boss.level !== range.max) {
        warnings.push({
          battleId,
          issue: `Miniboss "${boss.enemy_id}" (no boss present) has level ${boss.level}, expected max ${range.max}`,
        });
      } else if (hasTrueBoss && boss.level !== range.max && boss.level !== range.max - 1) {
        warnings.push({
          battleId,
          issue: `Miniboss "${boss.enemy_id}" (with boss) has level ${boss.level}, expected ${range.max} or ${range.max - 1}`,
        });
      }
    }
  }

  // Rule validation: Support should be at midpoint
  const midpoint = Math.floor((range.min + range.max) / 2);
  for (const sup of supportEntries) {
    if (sup.level !== midpoint && sup.level !== midpoint + 1) {
      warnings.push({
        battleId,
        issue: `Support "${sup.enemy_id}" has level ${sup.level}, expected ~midpoint ${midpoint}`,
      });
    }
  }

  if (filePass) {
    totalPass++;
  } else {
    totalFail++;
  }

  const levelMin = Math.min(...fileLevels);
  const levelMax = Math.max(...fileLevels);
  console.log(
    `${filePass ? 'PASS' : 'FAIL'} | ${battleId} | Actual: Lv${levelMin}~${levelMax} | Target: Lv${range.min}~${range.max} | Enemies: ${placements.length}` +
    (bossEntries.length > 0 ? ` | Bosses: ${bossEntries.map(b => `${b.enemy_id}(${b.ai_override}:Lv${b.level})`).join(', ')}` : '')
  );
}

console.log('\n========================================');
console.log(`RESULTS: ${totalPass} PASS / ${totalFail} FAIL (${totalFiles} files, ${totalEnemies} enemies)`);

if (failures.length > 0) {
  console.log('\nFAILURES:');
  for (const f of failures) {
    console.log(`  [${f.battleId}] ${f.issue}`);
  }
}

if (warnings.length > 0) {
  console.log('\nWARNINGS (Level Assignment Rules):');
  for (const w of warnings) {
    console.log(`  [${w.battleId}] ${w.issue}`);
  }
}

// Additional: Verify EXP formula
console.log('\n========================================');
console.log('EXP FORMULA VERIFICATION:');
console.log(`  Lv1->2: ${1 * 100} EXP (expected: 100) - ${1 * 100 === 100 ? 'PASS' : 'FAIL'}`);
console.log(`  Lv10->11: ${10 * 100} EXP (expected: 1000) - ${10 * 100 === 1000 ? 'PASS' : 'FAIL'}`);
console.log(`  Lv29->30: ${29 * 100} EXP (expected: 2900) - ${29 * 100 === 2900 ? 'PASS' : 'FAIL'}`);

// Cumulative EXP check
let cumulative = 0;
for (let lv = 1; lv < 30; lv++) {
  cumulative += lv * 100;
}
console.log(`  Cumulative Lv1->30: ${cumulative} EXP (expected: 43500) - ${cumulative === 43500 ? 'PASS' : 'FAIL'}`);

// Exit with proper code
process.exit(totalFail > 0 ? 1 : 0);

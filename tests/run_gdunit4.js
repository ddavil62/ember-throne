#!/usr/bin/env node
/**
 * @fileoverview Ember Throne gdUnit4 인터랙션 테스트 실행기.
 * gdUnit4 headless runner를 통해 tests/interaction/ 내 테스트를 실행한다.
 *
 * 사용법:
 *   node tests/run_gdunit4.js                          # 전체 인터랙션 테스트
 *   node tests/run_gdunit4.js --filter battle_input    # 특정 파일만
 *   GODOT_PATH=/path/to/godot node tests/run_gdunit4.js
 *
 * 출력:
 *   - 콘솔: PASS/FAIL 요약
 *   - tests/interaction/reports/: gdUnit4 HTML 리포트 (선택)
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PROJECT_DIR = path.join(__dirname, '..');
const INTERACTION_DIR = path.join(__dirname, 'interaction');
const GDUNIT_RUNNER = 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd';

/** 실행 타임아웃 (ms) — 인터랙션 테스트는 씬 로딩이 있어 더 길게 */
const TIMEOUT_MS = 300_000; // 5분

function main() {
	const godot = process.env.GODOT_PATH || 'godot';

	// --filter 옵션 파싱
	const filterIdx = process.argv.indexOf('--filter');
	const filter = filterIdx >= 0 ? process.argv[filterIdx + 1] : null;

	// --report 옵션 (HTML 리포트 경로)
	const reportDir = path.join(INTERACTION_DIR, 'reports');

	console.log('[gdUnit4] ============================================');
	console.log('[gdUnit4] Ember Throne 인터랙션 테스트');
	console.log('[gdUnit4] Godot: %s', godot);
	if (filter) console.log('[gdUnit4] 필터: %s', filter);
	console.log('[gdUnit4] ============================================\n');

	// 리포트 디렉토리 초기화
	fs.mkdirSync(reportDir, { recursive: true });

	// 테스트 경로 목록
	const testFiles = _getTestFiles(filter);
	if (testFiles.length === 0) {
		console.error('[gdUnit4] tests/interaction/ 에서 테스트 파일을 찾을 수 없음');
		process.exit(1);
	}
	console.log('[gdUnit4] 테스트 파일 %d개:', testFiles.length);
	testFiles.forEach(f => console.log('  - %s', path.relative(PROJECT_DIR, f)));
	console.log('');

	// gdUnit4 CLI 실행 인수 구성
	// 참고: https://mikeschulze.github.io/gdUnit4/advanced_testing/cmd/
	const args = [
		'--headless',
		'--path', PROJECT_DIR,
		'-s', GDUNIT_RUNNER,
		'--',
		'--add', 'res://tests/interaction',
		'--report-dir', 'res://tests/interaction/reports',
	];
	if (filter) {
		args.push('--filter', filter);
	}

	console.log('[gdUnit4] Godot 실행 중...\n');
	const result = spawnSync(godot, args, {
		stdio: 'inherit',
		timeout: TIMEOUT_MS,
		cwd: PROJECT_DIR,
	});

	console.log('');
	if (result.error) {
		if (result.error.code === 'ENOENT') {
			console.error('[gdUnit4] Godot를 찾을 수 없습니다.');
			console.error('[gdUnit4] GODOT_PATH 환경변수에 Godot 실행 파일 경로를 지정하세요.');
			console.error('[gdUnit4] 예: GODOT_PATH="C:/Godot/Godot_v4.6.2.exe" node tests/run_gdunit4.js');
		} else if (result.error.code === 'ETIMEDOUT') {
			console.error('[gdUnit4] 타임아웃 (%d초 초과)', TIMEOUT_MS / 1000);
		} else {
			console.error('[gdUnit4] 실행 실패:', result.error.message);
		}
		process.exit(1);
	}

	const exitCode = result.status || 0;
	if (exitCode === 0) {
		console.log('[gdUnit4] === ALL TESTS PASSED ===');
	} else {
		console.log('[gdUnit4] === TESTS FAILED (exit: %d) ===', exitCode);
		// HTML 리포트 안내
		const reportIndex = path.join(reportDir, 'index.html');
		if (fs.existsSync(reportIndex)) {
			console.log('[gdUnit4] 리포트: %s', reportIndex);
		}
	}

	process.exit(exitCode);
}

/**
 * tests/interaction/ 내 *_test.gd 파일 목록을 반환한다.
 * @param {string|null} filter - 파일명 필터 (부분 일치)
 * @returns {string[]} 절대 경로 목록
 */
function _getTestFiles(filter) {
	if (!fs.existsSync(INTERACTION_DIR)) return [];
	return fs.readdirSync(INTERACTION_DIR)
		.filter(f => f.endsWith('_test.gd') || f.startsWith('test_'))
		.filter(f => !filter || f.includes(filter))
		.map(f => path.join(INTERACTION_DIR, f));
}

main();

#!/usr/bin/env node
/**
 * @fileoverview Ember Throne 비주얼 리그레션 테스트 실행기.
 * project.godot에 테스트 autoload를 임시 추가한 뒤 Godot를 실행하고,
 * 완료 후 project.godot를 원본으로 복원한다.
 *
 * 사용법:
 *   node tests/run_visual_tests.js              # 테스트 실행
 *   node tests/run_visual_tests.js --update     # 레퍼런스 이미지 갱신
 *   GODOT_PATH=/path/to/godot node tests/run_visual_tests.js
 */
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PROJECT_DIR = path.join(__dirname, '..');
const PROJECT_GODOT = path.join(PROJECT_DIR, 'project.godot');
const BACKUP = PROJECT_GODOT + '.visual_test_bak';
const REFERENCES_DIR = path.join(PROJECT_DIR, 'tests', 'visual', 'references');
const SCREENSHOTS_DIR = path.join(PROJECT_DIR, 'tests', 'visual', 'screenshots');
const AUTOLOAD_LINE = 'VisualTestRunner="*res://tests/visual/visual_test_runner.gd"';

const updateMode = process.argv.includes('--update');

function main() {
	const godot = process.env.GODOT_PATH || 'godot';

	console.log('[VisualTest] ============================================');
	console.log('[VisualTest] Ember Throne 비주얼 리그레션 테스트');
	console.log('[VisualTest] Godot: %s', godot);
	console.log('[VisualTest] 모드: %s', updateMode ? '레퍼런스 갱신' : '테스트');
	console.log('[VisualTest] ============================================\n');

	// --update: 레퍼런스 초기화
	if (updateMode) {
		if (fs.existsSync(REFERENCES_DIR)) {
			fs.rmSync(REFERENCES_DIR, { recursive: true, force: true });
		}
		fs.mkdirSync(REFERENCES_DIR, { recursive: true });
		console.log('[VisualTest] 레퍼런스 디렉토리 초기화 완료\n');
	}

	// 스크린샷 디렉토리 정리
	if (fs.existsSync(SCREENSHOTS_DIR)) {
		fs.rmSync(SCREENSHOTS_DIR, { recursive: true, force: true });
	}
	fs.mkdirSync(SCREENSHOTS_DIR, { recursive: true });

	// 1. project.godot 백업
	fs.copyFileSync(PROJECT_GODOT, BACKUP);

	let exitCode = 0;
	try {
		// 2. 테스트 autoload 삽입 ([display] 섹션 바로 앞)
		let content = fs.readFileSync(PROJECT_GODOT, 'utf-8');
		const marker = '\n[display]';
		if (!content.includes(marker)) {
			throw new Error('project.godot에서 [display] 섹션을 찾을 수 없음');
		}
		content = content.replace(marker, `\n${AUTOLOAD_LINE}\n${marker}`);
		fs.writeFileSync(PROJECT_GODOT, content);
		console.log('[VisualTest] project.godot에 테스트 autoload 추가 완료');
		console.log('[VisualTest] Godot 실행 중...\n');

		// 3. Godot 실행
		const result = spawnSync(godot, ['--path', PROJECT_DIR], {
			stdio: 'inherit',
			timeout: 120000,
		});

		if (result.error) {
			if (result.error.code === 'ENOENT') {
				console.error('\n[VisualTest] Godot를 찾을 수 없습니다.');
				console.error('[VisualTest] GODOT_PATH 환경변수에 Godot 실행 파일 경로를 지정하세요.');
				console.error('[VisualTest] 예: GODOT_PATH="C:/Godot/Godot_v4.6.2.exe" node tests/run_visual_tests.js');
			} else if (result.error.code === 'ETIMEDOUT') {
				console.error('\n[VisualTest] Godot 실행 타임아웃 (120초 초과)');
			} else {
				console.error('\n[VisualTest] Godot 실행 실패:', result.error.message);
			}
			exitCode = 1;
		} else {
			exitCode = result.status || 0;
		}
	} catch (e) {
		console.error('\n[VisualTest] 오류:', e.message);
		exitCode = 1;
	} finally {
		// 4. project.godot 복원
		if (fs.existsSync(BACKUP)) {
			fs.copyFileSync(BACKUP, PROJECT_GODOT);
			fs.unlinkSync(BACKUP);
			console.log('\n[VisualTest] project.godot 복원 완료');
		}
	}

	// 5. 결과 요약
	console.log('');
	if (exitCode === 0) {
		if (updateMode) {
			console.log('[VisualTest] === 레퍼런스 이미지 갱신 완료 ===');
			_listFiles(REFERENCES_DIR, '레퍼런스');
		} else {
			console.log('[VisualTest] === ALL TESTS PASSED ===');
		}
	} else {
		console.log('[VisualTest] === TESTS FAILED (exit: %d) ===', exitCode);
		_listFiles(SCREENSHOTS_DIR, '스크린샷 (diff 이미지 확인)');
	}

	process.exit(exitCode);
}

/** 디렉토리 내 PNG 파일 목록을 출력한다. */
function _listFiles(dir, label) {
	if (!fs.existsSync(dir)) return;
	const files = fs.readdirSync(dir).filter(f => f.endsWith('.png'));
	if (files.length > 0) {
		console.log('[VisualTest] %s:', label);
		files.forEach(f => console.log('  - %s', path.join(dir, f)));
	}
}

main();

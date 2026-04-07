#!/usr/bin/env node
/**
 * @fileoverview 전투 공격 장면 GIF 캡처 실행기.
 * 1) project.godot에 BattleGifCapture autoload를 임시 추가
 * 2) Godot 실행 → battle_01 오토플레이 → PNG 프레임 저장
 * 3) project.godot 복원
 * 4) ffmpeg 또는 Pillow(Python)로 GIF 조립
 *
 * 사용법:
 *   node tests/run_battle_gif.js
 *   GODOT_PATH="C:/Godot/Godot_v4.6.2.exe" node tests/run_battle_gif.js
 */
const fs   = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const PROJECT_DIR   = path.join(__dirname, '..');
const PROJECT_GODOT = path.join(PROJECT_DIR, 'project.godot');
const BACKUP        = PROJECT_GODOT + '.gif_bak';
const FRAMES_DIR    = path.join(PROJECT_DIR, 'tests', 'gif_capture', 'frames');
const OUTPUT_GIF    = path.join(PROJECT_DIR, 'tests', 'gif_capture', 'battle_attack.gif');
const AUTOLOAD_LINE = 'BattleGifCapture="*res://tests/gif_capture/battle_gif_capture.gd"';
const GODOT_TIMEOUT = 180_000; // 3분

function main() {
	const godot = process.env.GODOT_PATH || 'godot';

	console.log('[BattleGif] ========================================');
	console.log('[BattleGif] Ember Throne 전투 GIF 캡처');
	console.log('[BattleGif] Godot: %s', godot);
	console.log('[BattleGif] ========================================\n');

	// 프레임 디렉토리 정리
	if (fs.existsSync(FRAMES_DIR)) {
		fs.rmSync(FRAMES_DIR, { recursive: true, force: true });
	}
	fs.mkdirSync(FRAMES_DIR, { recursive: true });

	// 1. project.godot 백업
	fs.copyFileSync(PROJECT_GODOT, BACKUP);

	let godotOk = false;
	try {
		// 2. autoload 삽입
		let content = fs.readFileSync(PROJECT_GODOT, 'utf-8');
		const marker = '\n[display]';
		if (!content.includes(marker)) {
			throw new Error('project.godot에서 [display] 섹션을 찾을 수 없음');
		}
		content = content.replace(marker, `\n${AUTOLOAD_LINE}\n${marker}`);
		fs.writeFileSync(PROJECT_GODOT, content);
		console.log('[BattleGif] autoload 추가 완료');
		console.log('[BattleGif] Godot 실행 중 (최대 3분 대기)...\n');

		// 3. Godot 실행
		const result = spawnSync(godot, ['--path', PROJECT_DIR], {
			stdio: 'inherit',
			timeout: GODOT_TIMEOUT,
		});

		if (result.error) {
			if (result.error.code === 'ENOENT') {
				console.error('[BattleGif] Godot를 찾을 수 없습니다.');
				console.error('[BattleGif] GODOT_PATH 환경변수를 설정하세요.');
				console.error('[BattleGif] 예: GODOT_PATH="C:/Godot/Godot_v4.6.2.exe" node tests/run_battle_gif.js');
			} else if (result.error.code === 'ETIMEDOUT') {
				console.error('[BattleGif] Godot 실행 타임아웃 (3분 초과)');
			} else {
				console.error('[BattleGif] Godot 실행 실패:', result.error.message);
			}
			return;
		}

		if (result.status !== 0) {
			console.error('[BattleGif] Godot 비정상 종료 (exit: %d)', result.status);
			return;
		}

		godotOk = true;
	} finally {
		// 4. project.godot 복원
		if (fs.existsSync(BACKUP)) {
			fs.copyFileSync(BACKUP, PROJECT_GODOT);
			fs.unlinkSync(BACKUP);
			console.log('\n[BattleGif] project.godot 복원 완료');
		}
	}

	if (!godotOk) return;

	// 5. 프레임 확인
	const frames = fs.readdirSync(FRAMES_DIR)
		.filter(f => f.endsWith('.png'))
		.sort();

	if (frames.length === 0) {
		console.error('[BattleGif] 캡처된 프레임 없음 — GIF 생성 불가');
		process.exit(1);
	}

	console.log('[BattleGif] 캡처된 프레임: %d장', frames.length);

	// 6. GIF 조립 (ffmpeg 우선, 없으면 Python Pillow)
	const assembled = _assemble_gif_ffmpeg(frames) || _assemble_gif_python(frames);

	if (assembled) {
		console.log('\n[BattleGif] ========================================');
		console.log('[BattleGif] GIF 생성 완료: %s', OUTPUT_GIF);
		console.log('[BattleGif] ========================================');
	} else {
		console.error('[BattleGif] GIF 조립 실패 — PNG 프레임은 %s 에 있습니다', FRAMES_DIR);
		process.exit(1);
	}
}

/** ffmpeg로 GIF 조립 (팔레트 최적화 포함) */
function _assemble_gif_ffmpeg(frames) {
	// ffmpeg 사용 가능 확인
	const check = spawnSync('ffmpeg', ['-version'], { stdio: 'pipe' });
	if (check.error) {
		console.log('[BattleGif] ffmpeg 없음 — Python 시도');
		return false;
	}

	console.log('[BattleGif] ffmpeg로 GIF 조립 중...');

	// 두 패스: 팔레트 생성 → GIF 렌더링
	const palette = path.join(FRAMES_DIR, 'palette.png');
	const input   = path.join(FRAMES_DIR, 'frame_%04d.png');

	// 패스1: 팔레트 생성
	const p1 = spawnSync('ffmpeg', [
		'-y',
		'-framerate', '20',
		'-i', input,
		'-vf', 'scale=640:-1:flags=lanczos,palettegen=stats_mode=full',
		palette,
	], { stdio: 'inherit' });

	if (p1.error || p1.status !== 0) {
		console.error('[BattleGif] ffmpeg 팔레트 생성 실패');
		return false;
	}

	// 패스2: GIF 렌더링
	const p2 = spawnSync('ffmpeg', [
		'-y',
		'-framerate', '20',
		'-i', input,
		'-i', palette,
		'-lavfi', 'scale=640:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=5',
		OUTPUT_GIF,
	], { stdio: 'inherit' });

	if (p2.error || p2.status !== 0) {
		console.error('[BattleGif] ffmpeg GIF 렌더링 실패');
		return false;
	}

	// 팔레트 임시 파일 제거
	if (fs.existsSync(palette)) fs.unlinkSync(palette);
	return true;
}

/** Python Pillow로 GIF 조립 */
function _assemble_gif_python(frames) {
	const check = spawnSync('python', ['--version'], { stdio: 'pipe' });
	if (check.error) {
		console.log('[BattleGif] python 없음 — GIF 조립 불가');
		return false;
	}

	console.log('[BattleGif] Python Pillow로 GIF 조립 중...');

	const script = `
import sys
from pathlib import Path
try:
    from PIL import Image
except ImportError:
    print("Pillow가 설치되어 있지 않습니다. pip install Pillow 를 실행하세요.")
    sys.exit(1)

frames_dir = Path(r"${FRAMES_DIR.replace(/\\/g, '\\\\')}")
output     = r"${OUTPUT_GIF.replace(/\\/g, '\\\\')}"

pngs = sorted(frames_dir.glob("frame_*.png"))
if not pngs:
    print("PNG 프레임 없음")
    sys.exit(1)

imgs = []
for p in pngs:
    img = Image.open(p).convert("RGBA")
    img = img.resize((640, 360), Image.LANCZOS)
    imgs.append(img.convert("P", palette=Image.ADAPTIVE, colors=256))

imgs[0].save(
    output,
    save_all=True,
    append_images=imgs[1:],
    duration=50,   # 20fps
    loop=0,
    optimize=True,
)
print(f"GIF 저장 완료: {output} ({len(imgs)} 프레임)")
`;

	const tmpScript = path.join(FRAMES_DIR, '_make_gif.py');
	fs.writeFileSync(tmpScript, script, 'utf-8');

	const result = spawnSync('python', [tmpScript], { stdio: 'inherit' });
	fs.unlinkSync(tmpScript);

	if (result.error || result.status !== 0) {
		console.error('[BattleGif] Python GIF 조립 실패');
		return false;
	}
	return true;
}

main();

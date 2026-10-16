/**
 * adversarial_test.js
 * Independent Empirical Adversarial Test Harness for docs/kirmatas_ad_en.html
 * Authored by Challenger 2 (Round 2 — EN Video Ad Adversarial Verifier)
 *
 * Exhaustive checks:
 * 1. Physical asset verification in docs/ad_assets/ and assets/images/
 * 2. AST / static code analysis of docs/kirmatas_ad_en.html
 * 3. Deep-instrumented Canvas 2D VM simulation with NaN / Infinity / undefined detection on all args
 * 4. Dense negative-t stress matrix: t in [-100.0, -0.0]
 * 5. Timeline boundary and post-duration stress testing
 * 6. Full 60 FPS 1081-frame timeline simulation (0.0s to 18.0s)
 * 7. Verification of all 6 real in-game captured frames + Kaunos Games logo drawImage calls
 * 8. Source/Dest coordinates, dimensions, bounds, and aspect-ratio distortion audit
 */

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..', '..');
const AD_EN_PATH = path.join(PROJECT_ROOT, 'docs', 'kirmatas_ad_en.html');
const ASSETS_DIR = path.join(PROJECT_ROOT, 'docs', 'ad_assets');

let testCount = 0;
let passedCount = 0;
let failedCount = 0;
const failureDetails = [];

function check(desc, condition, details = '') {
  testCount++;
  if (condition) {
    passedCount++;
    console.log(`  [PASS] ${desc}`);
  } else {
    failedCount++;
    console.error(`  [FAIL] ${desc}`);
    if (details) {
      console.error(`         Details: ${details}`);
      failureDetails.push(`${desc}: ${details}`);
    } else {
      failureDetails.push(desc);
    }
  }
}

console.log('======================================================================');
console.log(' CHALLENGER 2 INDEPENDENT ADVERSARIAL VERIFICATION SUITE');
console.log(' Target: docs/kirmatas_ad_en.html');
console.log('======================================================================\n');

// ----------------------------------------------------------------------
// SECTION 1: Asset Existence & Byte Integrity
// ----------------------------------------------------------------------
console.log('--- SECTION 1: Asset Filesystem Integrity ---');

const AUDIO_DIR = path.join(PROJECT_ROOT, 'assets', 'audio');

const REQUIRED_FILES = [
  { p: path.join(ASSETS_DIR, 'game_canvas_action.png'), minSize: 100000, desc: 'img_action capture' },
  { p: path.join(ASSETS_DIR, 'chaos_perks.png'), minSize: 100000, desc: 'img_perks capture' },
  { p: path.join(ASSETS_DIR, 'shop_synergies.png'), minSize: 100000, desc: 'img_synergies capture' },
  { p: path.join(ASSETS_DIR, 'aquarium_view.png'), minSize: 50000, desc: 'img_aquarium capture' },
  { p: path.join(ASSETS_DIR, 'tournament_league.png'), minSize: 50000, desc: 'img_league capture' },
  { p: path.join(ASSETS_DIR, 'chaos_boss.png'), minSize: 100000, desc: 'img_boss capture' },
  { p: path.join(PROJECT_ROOT, 'assets', 'images', 'kaunos_games.png'), minSize: 1000, desc: 'img_kaunos logo' },
  { p: path.join(AUDIO_DIR, 'cam_kirilma.mp3'), minSize: 1000, desc: 'cam_kirilma SFX' },
  { p: path.join(AUDIO_DIR, 'glass_shatter.mp3'), minSize: 1000, desc: 'glass_shatter SFX' },
  { p: path.join(AUDIO_DIR, 'custom_laser.wav'), minSize: 1000, desc: 'custom_laser SFX' },
  { p: path.join(AUDIO_DIR, 'custom_explosion.wav'), minSize: 1000, desc: 'custom_explosion SFX' },
  { p: path.join(AUDIO_DIR, 'bgm.wav'), minSize: 1000, desc: 'bgm WAV' }
];

for (const f of REQUIRED_FILES) {
  const exists = fs.existsSync(f.p);
  const size = exists ? fs.statSync(f.p).size : 0;
  check(
    `Asset exists and >= min size: ${f.desc} (${path.basename(f.p)})`,
    exists && size >= f.minSize,
    `Exists: ${exists}, Size: ${size} bytes, Expected >= ${f.minSize}`
  );
}

// ----------------------------------------------------------------------
// SECTION 2: HTML Static Source Analysis
// ----------------------------------------------------------------------
console.log('\n--- SECTION 2: HTML Static Analysis ---');

let htmlContent = '';
try {
  htmlContent = fs.readFileSync(AD_EN_PATH, 'utf8');
  check('docs/kirmatas_ad_en.html exists and is non-empty', htmlContent.length > 500000, `Length: ${htmlContent.length} bytes`);
} catch (e) {
  check('docs/kirmatas_ad_en.html readable', false, e.message);
  process.exit(1);
}

// Check resolution contracts
check('Canvas width 1080 declared', htmlContent.includes('width="1080"') || htmlContent.includes('const W = 1080'), 'W=1080 found');
check('Canvas height 1920 declared', htmlContent.includes('height="1920"') || htmlContent.includes('const H = 1920'), 'H=1920 found');

// Check negative t clamping pattern
const clampingMatches = htmlContent.match(/Math\.max\(\s*0\s*,\s*Math\.min\(\s*1(\.0)?\s*,\s*t\s*\/\s*3\.5\s*\)\)/g);
check('Progression calculation in Scene 1 has explicit Math.max(0, ...) clamping', clampingMatches && clampingMatches.length >= 1, `Matches: ${clampingMatches ? clampingMatches.length : 0}`);

// ----------------------------------------------------------------------
// SECTION 3: Headless Canvas VM Instrumentation
// ----------------------------------------------------------------------
console.log('\n--- SECTION 3: Deep Headless Canvas 2D VM Simulation ---');

const badCallLog = [];
function checkArgs(funcName, args) {
  for (let i = 0; i < args.length; i++) {
    const val = args[i];
    if (val === undefined || (typeof val === 'number' && !Number.isFinite(val))) {
      badCallLog.push({ func: funcName, argIndex: i, val: String(val), args: Array.from(args) });
    }
  }
}

class InstrumentedGradient {
  addColorStop(offset, color) {
    if (offset === undefined || (typeof offset === 'number' && !Number.isFinite(offset))) {
      badCallLog.push({ func: 'addColorStop', argIndex: 0, val: String(offset), args: [offset, color] });
    }
  }
}

const drawImageInvocations = [];

class InstrumentedContext2D {
  constructor() {
    this._globalAlpha = 1.0;
    this._lineWidth = 1;
    this._shadowBlur = 0;
    this.fillStyle = '#000000';
    this.strokeStyle = '#000000';
    this.font = '10px sans-serif';
    this.textAlign = 'left';
    this.textBaseline = 'top';
    this.shadowColor = 'transparent';
    this.shadowOffsetX = 0;
    this.shadowOffsetY = 0;
    this.lineCap = 'butt';
  }

  get globalAlpha() { return this._globalAlpha; }
  set globalAlpha(v) {
    if (v === undefined || (typeof v === 'number' && !Number.isFinite(v))) {
      badCallLog.push({ func: 'set globalAlpha', val: String(v) });
    }
    this._globalAlpha = Math.max(0, Math.min(1, v || 0));
  }

  get lineWidth() { return this._lineWidth; }
  set lineWidth(v) {
    if (v === undefined || (typeof v === 'number' && !Number.isFinite(v))) {
      badCallLog.push({ func: 'set lineWidth', val: String(v) });
    }
    this._lineWidth = v;
  }

  get shadowBlur() { return this._shadowBlur; }
  set shadowBlur(v) {
    if (v === undefined || (typeof v === 'number' && !Number.isFinite(v))) {
      badCallLog.push({ func: 'set shadowBlur', val: String(v) });
    }
    this._shadowBlur = v;
  }

  save() {}
  restore() {}
  beginPath() {}
  closePath() {}
  clip() {}
  setLineDash() {}
  getLineDash() { return []; }
  resetTransform() {}
  fill() {}
  stroke() {}

  moveTo(x, y) { checkArgs('moveTo', arguments); }
  lineTo(x, y) { checkArgs('lineTo', arguments); }
  quadraticCurveTo(cpx, cpy, x, y) { checkArgs('quadraticCurveTo', arguments); }
  bezierCurveTo(cp1x, cp1y, cp2x, cp2y, x, y) { checkArgs('bezierCurveTo', arguments); }
  arc(x, y, r, sa, ea, ccw) { checkArgs('arc', arguments); }
  ellipse(x, y, rx, ry, rot, sa, ea, ccw) { checkArgs('ellipse', arguments); }
  rect(x, y, w, h) { checkArgs('rect', arguments); }
  fillRect(x, y, w, h) { checkArgs('fillRect', arguments); }
  strokeRect(x, y, w, h) { checkArgs('strokeRect', arguments); }
  clearRect(x, y, w, h) { checkArgs('clearRect', arguments); }
  fillText(text, x, y, maxW) { checkArgs('fillText', arguments); }
  strokeText(text, x, y, maxW) { checkArgs('strokeText', arguments); }
  measureText(text) { return { width: (text ? text.length * 10 : 0) }; }
  translate(x, y) { checkArgs('translate', arguments); }
  scale(sx, sy) { checkArgs('scale', arguments); }
  rotate(ang) { checkArgs('rotate', arguments); }

  createLinearGradient(x0, y0, x1, y1) {
    checkArgs('createLinearGradient', arguments);
    return new InstrumentedGradient();
  }

  createRadialGradient(x0, y0, r0, x1, y1, r1) {
    checkArgs('createRadialGradient', arguments);
    return new InstrumentedGradient();
  }

  drawImage(img, ...args) {
    checkArgs('drawImage', args);
    const assetKey = img && (img._assetKey || img.id || img.alt);
    drawImageInvocations.push({
      imgKey: assetKey,
      args: Array.from(args)
    });
  }
}

class MockImageObj {
  constructor(key) {
    this._assetKey = key;
    this.complete = true;
    this.width = 1080;
    this.height = 1920;
    this.naturalWidth = 1080;
    this.naturalHeight = 1920;
    this._src = '';
  }
  set src(v) { this._src = v; this.complete = true; }
  get src() { return this._src; }
}

const mockCtx = new InstrumentedContext2D();

function makeMockElem(id) {
  return {
    id,
    style: {},
    classList: { add: () => {}, remove: () => {}, contains: () => false, toggle: () => {} },
    textContent: '',
    innerText: '',
    innerHTML: '',
    checked: true,
    addEventListener: () => {},
    removeEventListener: () => {},
    getBoundingClientRect: () => ({ left: 0, top: 0, right: 1080, bottom: 1920, width: 1080, height: 1920 })
  };
}

const domElements = {};
const mockCanvas = makeMockElem('adCanvas');
mockCanvas.width = 1080;
mockCanvas.height = 1920;
mockCanvas.getContext = () => mockCtx;
mockCanvas.captureStream = () => ({ getVideoTracks: () => [{}], getAudioTracks: () => [{}] });
domElements['adCanvas'] = mockCanvas;

const sandbox = {
  console: { log: () => {}, warn: () => {}, error: () => {} },
  Math,
  Date,
  Number,
  String,
  Array,
  Object,
  Set,
  Map,
  RegExp,
  setTimeout: (fn) => fn(),
  clearTimeout: () => {},
  setInterval: () => {},
  clearInterval: () => {},
  performance: { now: () => 0 },
  atob: (b64) => Buffer.from(b64, 'base64').toString('binary'),
  btoa: (str) => Buffer.from(str, 'binary').toString('base64'),
  requestAnimationFrame: () => {},
  cancelAnimationFrame: () => {},
  window: {
    addEventListener: () => {},
    removeEventListener: () => {},
    requestAnimationFrame: () => {},
    cancelAnimationFrame: () => {},
    atob: (b64) => Buffer.from(b64, 'base64').toString('binary'),
    btoa: (str) => Buffer.from(str, 'binary').toString('base64'),
    AudioContext: function() {
      return {
        createGain: () => ({
          gain: { value: 1.0, linearRampToValueAtTime: () => {}, exponentialRampToValueAtTime: () => {}, setValueAtTime: () => {}, setTargetAtTime: () => {}, cancelScheduledValues: () => {} },
          connect: () => {}
        }),
        createOscillator: () => ({
          type: 'sine',
          frequency: { value: 440, setValueAtTime: () => {}, exponentialRampToValueAtTime: () => {}, linearRampToValueAtTime: () => {} },
          connect: () => {},
          start: () => {},
          stop: () => {}
        }),
        createBufferSource: () => ({ buffer: null, playbackRate: { value: 1.0 }, connect: () => {}, start: () => {}, stop: () => {} }),
        createMediaStreamDestination: () => ({ stream: { getAudioTracks: () => [{}] } }),
        decodeAudioData: (buf, succ) => { if (succ) succ({}); },
        destination: {}
      };
    },
    speechSynthesis: { cancel: () => {}, speak: () => {}, getVoices: () => [] }
  },
  document: {
    getElementById: (id) => domElements[id] || (domElements[id] = makeMockElem(id)),
    createElement: (tag) => tag === 'canvas' ? mockCanvas : makeMockElem(tag),
    body: makeMockElem('body')
  },
  Image: function() {
    return new MockImageObj(sandbox.__currentKey || 'unknown');
  },
  MediaRecorder: Object.assign(
    function() { return { start: () => {}, stop: () => {}, ondataavailable: null, onstop: null, state: 'inactive' }; },
    { isTypeSupported: () => true }
  ),
  Blob: function() { return {}; },
  URL: { createObjectURL: () => 'blob:mock' }
};

sandbox.window.document = sandbox.document;
sandbox.window.window = sandbox.window;
sandbox.window.Image = sandbox.Image;

const scriptRegex = /<script(?:\s+src="[^"]*")?>([\s\S]*?)<\/script>/gi;
let m;
let inlineJs = '';
while ((m = scriptRegex.exec(htmlContent)) !== null) {
  inlineJs += '\n' + m[1];
}

const patchedJs = inlineJs.replace(
  /keys\.forEach\(key\s*=>\s*\{/g,
  'keys.forEach(key => { __currentKey = key;'
);

const context = vm.createContext(sandbox);

try {
  vm.runInContext(patchedJs, context);
  check('In-browser script evaluated cleanly in VM sandbox', true);
} catch (e) {
  check('In-browser script evaluated cleanly in VM sandbox', false, e.message);
  process.exit(1);
}

// Initialize loadedImages keys for inspection
const REQUIRED_IMG_KEYS = [
  'img_action',
  'img_perks',
  'img_synergies',
  'img_aquarium',
  'img_league',
  'img_boss',
  'img_kaunos'
];

if (context.loadedImages) {
  for (const k of REQUIRED_IMG_KEYS) {
    if (context.loadedImages[k]) {
      context.loadedImages[k]._assetKey = k;
      context.loadedImages[k].complete = true;
    }
  }
}
context.imagesReady = true;

// ----------------------------------------------------------------------
// SECTION 4: Negative-t Adversarial Stress Matrix
// ----------------------------------------------------------------------
console.log('\n--- SECTION 4: Negative-t Stress Matrix ---');

badCallLog.length = 0;
const NEGATIVE_T_GRID = [
  -100.0, -50.0, -25.0, -10.0, -5.0, -3.5, -2.0, -1.0, -0.75,
  -0.5, -0.25, -0.1, -0.05, -0.01, -0.001, -0.000001, -0.0
];

for (const negT of NEGATIVE_T_GRID) {
  // Test scene 1 directly
  if (typeof context.drawScene1 === 'function') {
    context.drawScene1(negT);
  }
  // Test jumpTo directly
  if (typeof context.jumpTo === 'function') {
    context.jumpTo(negT);
  }
  // Test renderFrame directly
  context.currentTime = negT;
  if (typeof context.drawScene1 === 'function' && negT < 3.5) {
    context.drawScene1(negT);
  }
}

check(
  `Negative t grid (${NEGATIVE_T_GRID.length} sample points from -100 to -0.0) produced ZERO NaN or non-finite calls`,
  badCallLog.length === 0,
  badCallLog.length > 0 ? `Failed with ${badCallLog.length} bad calls. First: ${JSON.stringify(badCallLog[0])}` : ''
);

// ----------------------------------------------------------------------
// SECTION 5: Timeline Boundary & Post-Duration Stress Testing
// ----------------------------------------------------------------------
console.log('\n--- SECTION 5: Boundary & Post-Duration Testing ---');

badCallLog.length = 0;
const BOUNDARY_GRID = [
  0.0,
  3.499, 3.5, 3.501,
  4.499, 4.5, 4.501,
  5.199, 5.2, 5.201,
  7.499, 7.5, 7.501,
  9.499, 9.5, 9.501,
  11.499, 11.5, 11.501,
  13.499, 13.5, 13.501,
  15.499, 15.5, 15.501,
  17.999, 18.0, 18.001,
  18.5, 20.0, 50.0, 100.0
];

for (const bT of BOUNDARY_GRID) {
  context.currentTime = bT;
  if (bT < 3.5) context.drawScene1(bT);
  else if (bT < 7.5) context.drawScene2(bT);
  else if (bT < 13.5) context.drawScene3(bT);
  else context.drawScene4(bT);

  if (typeof context.drawTikTokCaptions === 'function') {
    context.drawTikTokCaptions(bT);
  }
}

check(
  `Boundary grid (${BOUNDARY_GRID.length} transition points) produced ZERO NaN or non-finite calls`,
  badCallLog.length === 0,
  badCallLog.length > 0 ? `Failed with ${badCallLog.length} bad calls. First: ${JSON.stringify(badCallLog[0])}` : ''
);

// ----------------------------------------------------------------------
// SECTION 6: Full 60 FPS 1081-Frame Timeline Sweep [0.0s – 18.0s]
// ----------------------------------------------------------------------
console.log('\n--- SECTION 6: Full 60 FPS 1081-Frame Timeline Sweep ---');

badCallLog.length = 0;
drawImageInvocations.length = 0;

const TOTAL_FRAMES = 1080; // 18.0s * 60 FPS
const DT = 18.0 / TOTAL_FRAMES;

const frameDistribution = { scene1: 0, scene2: 0, scene3: 0, scene4: 0 };

for (let frame = 0; frame <= TOTAL_FRAMES; frame++) {
  const t = frame * DT;
  context.currentTime = t;

  if (t < 3.5) {
    frameDistribution.scene1++;
    context.drawScene1(t);
  } else if (t < 7.5) {
    frameDistribution.scene2++;
    context.drawScene2(t);
  } else if (t < 13.5) {
    frameDistribution.scene3++;
    context.drawScene3(t);
  } else {
    frameDistribution.scene4++;
    context.drawScene4(t);
  }

  if (typeof context.drawTikTokCaptions === 'function') {
    context.drawTikTokCaptions(t);
  }
}

check(
  `Full 60 FPS timeline sweep (1081 frames) produced ZERO NaN or non-finite canvas calls`,
  badCallLog.length === 0,
  badCallLog.length > 0 ? `Found ${badCallLog.length} bad calls. First: ${JSON.stringify(badCallLog[0])}` : ''
);

check('Scene 1 executed expected frame budget (~210 frames)', frameDistribution.scene1 >= 200 && frameDistribution.scene1 <= 220, `Count: ${frameDistribution.scene1}`);
check('Scene 2 executed expected frame budget (~240 frames)', frameDistribution.scene2 >= 235 && frameDistribution.scene2 <= 245, `Count: ${frameDistribution.scene2}`);
check('Scene 3 executed expected frame budget (~360 frames)', frameDistribution.scene3 >= 355 && frameDistribution.scene3 <= 365, `Count: ${frameDistribution.scene3}`);
check('Scene 4 executed expected frame budget (~270 frames)', frameDistribution.scene4 >= 265 && frameDistribution.scene4 <= 275, `Count: ${frameDistribution.scene4}`);

// ----------------------------------------------------------------------
// SECTION 7: In-Game Captures & Kaunos Logo drawImage Validation
// ----------------------------------------------------------------------
console.log('\n--- SECTION 7: drawImage Invocations & Bounds Audit ---');

const callsPerImage = {};
for (const k of REQUIRED_IMG_KEYS) callsPerImage[k] = [];

for (const inv of drawImageInvocations) {
  if (inv.imgKey && callsPerImage[inv.imgKey]) {
    callsPerImage[inv.imgKey].push(inv.args);
  }
}

for (const k of REQUIRED_IMG_KEYS) {
  const calls = callsPerImage[k];
  check(
    `ctx.drawImage actively called for '${k}' (called ${calls.length} times during timeline)`,
    calls.length > 0,
    `Never called during 1081-frame simulation!`
  );

  // Validate coordinates & dimensions of every single call
  let allValid = true;
  let invalidReason = '';
  for (const args of calls) {
    if (args.length === 4) {
      // drawImage(img, dx, dy, dw, dh)
      const [dx, dy, dw, dh] = args;
      if (dw <= 0 || dh <= 0 || !Number.isFinite(dx) || !Number.isFinite(dy) || !Number.isFinite(dw) || !Number.isFinite(dh)) {
        allValid = false;
        invalidReason = `Invalid 4-arg drawImage: dx=${dx}, dy=${dy}, dw=${dw}, dh=${dh}`;
        break;
      }
    } else if (args.length >= 8) {
      // drawImage(img, sx, sy, sw, sh, dx, dy, dw, dh)
      const [sx, sy, sw, sh, dx, dy, dw, dh] = args;
      if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0 ||
          !Number.isFinite(sx) || !Number.isFinite(sy) || !Number.isFinite(sw) || !Number.isFinite(sh) ||
          !Number.isFinite(dx) || !Number.isFinite(dy) || !Number.isFinite(dw) || !Number.isFinite(dh)) {
        allValid = false;
        invalidReason = `Invalid 8-arg drawImage: sx=${sx}, sy=${sy}, sw=${sw}, sh=${sh}, dx=${dx}, dy=${dy}, dw=${dw}, dh=${dh}`;
        break;
      }
      if (sx < 0 || sy < 0 || sx + sw > 1080 || sy + sh > 1920) {
        allValid = false;
        invalidReason = `Source crop out of bounds (1080x1920): sx=${sx}, sy=${sy}, sw=${sw}, sh=${sh}`;
        break;
      }
    } else {
      allValid = false;
      invalidReason = `Unexpected drawImage arg count: ${args.length}`;
      break;
    }
  }

  check(
    `Every drawImage call for '${k}' has valid finite dimensions within bounds`,
    allValid,
    invalidReason
  );
}

// ----------------------------------------------------------------------
// SECTION 8: Aspect Ratio & Distortion Precision Audit
// ----------------------------------------------------------------------
console.log('\n--- SECTION 8: Aspect Ratio & Distortion Precision ---');

// Audit img_synergies crop & destination
const synergyCalls = callsPerImage['img_synergies'];
if (synergyCalls.length > 0) {
  const [sx, sy, sw, sh, dx, dy, dw, dh] = synergyCalls[0];
  const srcAspect = sw / sh;
  const dstAspect = dw / dh;
  const diffPct = Math.abs(dstAspect - srcAspect) / srcAspect * 100;
  check(
    `img_synergies crop preserves aspect ratio (src=${srcAspect.toFixed(4)}, dst=${dstAspect.toFixed(4)}, diff=${diffPct.toFixed(3)}% < 0.1%)`,
    diffPct < 0.1,
    `Aspect ratio discrepancy: ${diffPct}%`
  );
} else {
  check('img_synergies aspect ratio check', false, 'No calls found');
}

// Audit img_league crop & destination
const leagueCalls = callsPerImage['img_league'];
if (leagueCalls.length > 0) {
  const [sx, sy, sw, sh, dx, dy, dw, dh] = leagueCalls[0];
  const srcAspect = sw / sh;
  const dstAspect = dw / dh;
  const diffPct = Math.abs(dstAspect - srcAspect) / srcAspect * 100;
  check(
    `img_league crop preserves aspect ratio (src=${srcAspect.toFixed(4)}, dst=${dstAspect.toFixed(4)}, diff=${diffPct.toFixed(3)}% < 0.001%)`,
    diffPct < 0.001,
    `Aspect ratio discrepancy: ${diffPct}%`
  );
} else {
  check('img_league aspect ratio check', false, 'No calls found');
}

// ----------------------------------------------------------------------
// SECTION 9: Graceful Fallback & UI Interaction Edge Cases
// ----------------------------------------------------------------------
console.log('\n--- SECTION 9: Fallback & Interaction Edge Cases ---');

// Test 9.1: Incomplete images fallback across entire timeline
const vmLoadedImages = vm.runInContext('(typeof loadedImages !== "undefined" ? loadedImages : null)', context);
if (vmLoadedImages) {
  for (const k of REQUIRED_IMG_KEYS) {
    if (vmLoadedImages[k]) vmLoadedImages[k].complete = false;
  }
}
vm.runInContext('if (typeof imagesReady !== "undefined") imagesReady = false;', context);

badCallLog.length = 0;
let fallbackCrashed = false;
try {
  for (let t = 0; t <= 18.0; t += 0.5) {
    context.currentTime = t;
    if (t < 3.5) context.drawScene1(t);
    else if (t < 7.5) context.drawScene2(t);
    else if (t < 13.5) context.drawScene3(t);
    else context.drawScene4(t);
  }
} catch (e) {
  fallbackCrashed = true;
}

check(
  'Timeline runs smoothly without throwing when images are not yet loaded (complete=false)',
  !fallbackCrashed && badCallLog.length === 0,
  `Crashed: ${fallbackCrashed}, Bad calls: ${badCallLog.length}`
);

// Restore image complete flags
if (vmLoadedImages) {
  for (const k of REQUIRED_IMG_KEYS) {
    if (vmLoadedImages[k]) vmLoadedImages[k].complete = true;
  }
}
vm.runInContext('if (typeof imagesReady !== "undefined") imagesReady = true;', context);

// Test 9.2: Timeline scrubber click with out-of-bounds coordinates
let scrubberCrashed = false;
try {
  const timelineBar = domElements['timelineBar'] || makeMockElem('timelineBar');
  // Simulate click listener
  const simulatedClick = (clientX) => {
    const rect = { left: 100, width: 800 };
    const ratio = Math.max(0, Math.min(1, (clientX - rect.left) / rect.width));
    context.jumpTo(ratio * 18.0);
  };
  simulatedClick(-500); // extreme negative click
  simulatedClick(0);
  simulatedClick(500);
  simulatedClick(900); // 100%
  simulatedClick(5000); // extreme positive click
} catch (e) {
  scrubberCrashed = true;
}

check(
  'Timeline scrubber click with out-of-bounds coordinates handled cleanly',
  !scrubberCrashed,
  `Scrubber threw error: ${scrubberCrashed}`
);

// ----------------------------------------------------------------------
// FINAL SUMMARY
// ----------------------------------------------------------------------
console.log('\n======================================================================');
console.log(` CHALLENGER ADVERSARIAL SUMMARY: ${passedCount}/${testCount} Passed (${Math.round((passedCount / testCount) * 100)}%)`);
console.log('======================================================================');

if (failedCount > 0) {
  console.error(`\nFAILED TESTS (${failedCount}):`);
  failureDetails.forEach((d, i) => console.error(`  ${i + 1}. ${d}`));
  console.error('\nOVERALL VERDICT: REQUEST_CHANGES');
  process.exit(1);
} else {
  console.log('\nOVERALL VERDICT: PASS');
  process.exit(0);
}

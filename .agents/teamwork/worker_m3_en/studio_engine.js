// Kırmataş English Promo Video Studio Engine (1080x1920 60 FPS)
const canvas = document.getElementById('adCanvas');
const ctx = canvas.getContext('2d', { alpha: false });
const W = 1080, H = 1920;
const DURATION = 18.0;

let currentTime = 0;
let isPlaying = true;
let isMuted = false;
let isRecording = false;
let lastFrameTime = performance.now();
let lastSpokenScene = -1;

// Image elements map
const loadedImages = {};
let imagesReady = false;

function initImages() {
  const keys = Object.keys(IMAGE_ASSETS);
  let loadedCount = 0;
  keys.forEach(key => {
    const img = new Image();
    img.onload = () => {
      loadedCount++;
      if (loadedCount === keys.length) imagesReady = true;
    };
    img.onerror = () => {
      console.warn('Failed to load image asset: ' + key);
      loadedCount++;
      if (loadedCount === keys.length) imagesReady = true;
    };
    img.src = IMAGE_ASSETS[key];
    loadedImages[key] = img;
  });
}

// -------------------------------------------------------------
// Web Audio API Pipeline & Ducking Engine
// -------------------------------------------------------------
let audioCtx = null;
let audioDest = null;
let masterGain = null;
let sfxGain = null;
let voiceGain = null;
let bgmGain = null;

const audioBuffers = {};
let audioReady = false;

function initAudio() {
  if (audioCtx) return;
  const AC = window.AudioContext || window.webkitAudioContext;
  if (!AC) return;
  audioCtx = new AC();
  audioDest = audioCtx.createMediaStreamDestination();

  masterGain = audioCtx.createGain();
  masterGain.gain.value = 1.0;
  masterGain.connect(audioCtx.destination);
  masterGain.connect(audioDest);

  sfxGain = audioCtx.createGain();
  sfxGain.gain.value = 0.85;
  sfxGain.connect(masterGain);

  voiceGain = audioCtx.createGain();
  voiceGain.gain.value = 1.0;
  voiceGain.connect(masterGain);

  bgmGain = audioCtx.createGain();
  bgmGain.gain.value = 0.35;
  bgmGain.connect(masterGain);

  // Decode all base64 audio assets into native AudioBuffers
  const audioKeys = Object.keys(AUDIO_ASSETS);
  let decoded = 0;
  audioKeys.forEach(key => {
    const dataUri = AUDIO_ASSETS[key];
    const base64 = dataUri.split(',')[1];
    const binary = atob(base64);
    const len = binary.length;
    const bytes = new Uint8Array(len);
    for (let i = 0; i < len; i++) bytes[i] = binary.charCodeAt(i);
    audioCtx.decodeAudioData(bytes.buffer, (buffer) => {
      audioBuffers[key] = buffer;
      decoded++;
      if (decoded === audioKeys.length) audioReady = true;
    }, (err) => {
      console.warn('Error decoding ' + key, err);
      decoded++;
    });
  });
}

// Dynamic BGM Ducking (Drops BGM volume by 71% during active narration)
function duckBgm(active) {
  if (!audioCtx || !bgmGain) return;
  const now = audioCtx.currentTime;
  const target = active ? 0.10 : 0.35;
  bgmGain.gain.cancelScheduledValues(now);
  bgmGain.gain.linearRampToValueAtTime(target, now + 0.18);
}

function playSoundBuffer(key, gainNode = sfxGain, playbackRate = 1.0) {
  if (isMuted || !audioCtx) return;
  if (audioCtx.state === 'suspended') audioCtx.resume();
  const buffer = audioBuffers[key];
  if (!buffer) return;
  const source = audioCtx.createBufferSource();
  source.buffer = buffer;
  source.playbackRate.value = playbackRate;
  source.connect(gainNode || masterGain);
  source.start();
}

function playTone(freq, type, duration, vol = 0.12, slideTo = null, targetGain = sfxGain) {
  if (isMuted || !audioCtx) return;
  if (audioCtx.state === 'suspended') audioCtx.resume();
  const osc = audioCtx.createOscillator();
  const gain = audioCtx.createGain();
  osc.type = type;
  osc.frequency.setValueAtTime(freq, audioCtx.currentTime);
  if (slideTo) {
    osc.frequency.exponentialRampToValueAtTime(slideTo, audioCtx.currentTime + duration);
  }
  gain.gain.setValueAtTime(vol, audioCtx.currentTime);
  gain.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + duration);
  osc.connect(gain);
  gain.connect(targetGain || masterGain);
  osc.start();
  osc.stop(audioCtx.currentTime + duration);
}

function playSubBass(freq = 42, duration = 0.8) {
  playTone(freq, 'sine', duration, 0.40, freq * 0.4);
}

// Synthwave / Phonk BGM Sequencer
let lastBeatIdx = -1;
function updateBgmBeat(t) {
  if (isMuted || !audioCtx) return;
  const bpm = 128;
  const beatInterval = 60 / bpm; // ~0.46875s
  const currentBeat = Math.floor(t / beatInterval);
  if (currentBeat !== lastBeatIdx && t >= 0.2) {
    lastBeatIdx = currentBeat;
    const beatInBar = currentBeat % 8;
    
    // Kick drum on 0, 2, 4, 6
    if (beatInBar % 2 === 0) {
      playTone(110, 'sine', 0.15, 0.25, 30, bgmGain);
    }
    // Snare / clap on 2, 6
    if (beatInBar === 2 || beatInBar === 6) {
      playTone(220, 'triangle', 0.12, 0.18, 60, bgmGain);
    }
    // Synth bassline arpeggio notes
    const bassNotes = [55, 55, 65.4, 73.4, 55, 82.4, 73.4, 65.4];
    const freq = bassNotes[beatInBar];
    playTone(freq, 'sawtooth', 0.22, 0.12, freq * 0.98, bgmGain);
  }
}

// -------------------------------------------------------------
// English Voiceover & Timed Captions
// -------------------------------------------------------------
const sceneVoiceovers = [
  {
    start: 0.1,
    end: 3.4,
    text: "Drop an iron marble from space? 25,000 miles per hour at 5,000 degrees!",
    words: [
      { w: "Drop", t: 0.1 }, { w: "an", t: 0.35 }, { w: "iron", t: 0.55 }, { w: "marble", t: 0.85 },
      { w: "from", t: 1.2 }, { w: "space?", t: 1.45 }, { w: "25,000", t: 1.85 }, { w: "mph", t: 2.3 },
      { w: "at", t: 2.55 }, { w: "5,000°!", t: 2.75 }
    ],
    bufferKey: "voice_scene1"
  },
  {
    start: 3.5,
    end: 7.3,
    text: "Impact crater? No! The Cosmic Paddle intercepts it with a thirty-fireball corner hit!",
    words: [
      { w: "Impact", t: 3.6 }, { w: "crater?", t: 3.9 }, { w: "NO!", t: 4.3 }, { w: "The", t: 4.65 },
      { w: "Cosmic", t: 4.85 }, { w: "Paddle", t: 5.15 }, { w: "catches", t: 5.45 }, { w: "it", t: 5.75 },
      { w: "with", t: 5.95 }, { w: "30", t: 6.2 }, { w: "FIREBALLS!", t: 6.55 }
    ],
    bufferKey: "voice_scene2"
  },
  {
    start: 7.5,
    end: 13.2,
    text: "Screen-clearing Ultimate lightning, deep 3-card Roguelike perks, and a zen aquarium to unwind.",
    words: [
      { w: "Screen-clearing", t: 7.6 }, { w: "ULTIMATE", t: 8.2 }, { w: "lightning,", t: 8.8 },
      { w: "deep", t: 9.4 }, { w: "3-card", t: 9.8 }, { w: "ROGUELIKE", t: 10.3 }, { w: "perks,", t: 11.0 },
      { w: "and", t: 11.4 }, { w: "a", t: 11.6 }, { w: "zen", t: 11.85 }, { w: "AQUARIUM!", t: 12.3 }
    ],
    bufferKey: "voice_scene3"
  },
  {
    start: 13.5,
    end: 17.8,
    text: "Can you survive the Wave-10 Chaos Boss? Download Kirmatas free on Google Play today!",
    words: [
      { w: "Can", t: 13.6 }, { w: "you", t: 13.8 }, { w: "survive", t: 14.1 }, { w: "the", t: 14.4 },
      { w: "WAVE-10", t: 14.7 }, { w: "CHAOS", t: 15.2 }, { w: "BOSS?", t: 15.6 },
      { w: "DOWNLOAD", t: 16.1 }, { w: "FREE", t: 16.6 }, { w: "NOW!", t: 17.0 }
    ],
    bufferKey: "voice_scene4"
  }
];

function triggerVoiceoverForScene(sceneIdx) {
  if (isMuted || !document.getElementById('ttsToggle').checked) return;
  const vo = sceneVoiceovers[sceneIdx];
  if (!vo) return;
  document.getElementById('voText').textContent = `"${vo.text}"`;

  duckBgm(true);

  if (audioBuffers[vo.bufferKey]) {
    playSoundBuffer(vo.bufferKey, voiceGain, 1.0);
    setTimeout(() => { duckBgm(false); }, (vo.end - vo.start) * 1000);
  } else if ('speechSynthesis' in window) {
    window.speechSynthesis.cancel();
    const u = new SpeechSynthesisUtterance(vo.text);
    u.lang = 'en-US';
    u.rate = 1.25;
    u.pitch = 1.02;
    u.onend = () => duckBgm(false);
    window.speechSynthesis.speak(u);
  }
}

// -------------------------------------------------------------
// Simulation Particles, Bricks & Geometry Pools
// -------------------------------------------------------------
const stars = [];
for (let i = 0; i < 150; i++) {
  stars.push({
    x: Math.random() * W,
    y: Math.random() * H,
    r: Math.random() < 0.6 ? 1.5 : (Math.random() < 0.85 ? 2.5 : 4.0),
    speed: 0.5 + Math.random() * 2.5,
    layer: Math.floor(Math.random() * 3),
    twinkle: Math.random() * Math.PI * 2
  });
}

const bricks = [];
const balls = [];
const particles = [];
const coins = [];
const shockwaves = [];
const floatingTexts = [];

function initSimulationEntities() {
  bricks.length = 0;
  balls.length = 0;
  particles.length = 0;
  coins.length = 0;
  shockwaves.length = 0;
  floatingTexts.length = 0;

  const cols = 7, rows = 8;
  const padX = 70, startY = 400;
  const bw = (W - padX * 2 - (cols - 1) * 16) / cols;
  const bh = 54;
  const palette = ['#00f5d4', '#ff2a85', '#fee440', '#9b5de5', '#00bbf9', '#ff6b00'];

  for (let r = 0; r < rows; r++) {
    for (let c = 0; c < cols; c++) {
      bricks.push({
        x: padX + c * (bw + 16),
        y: startY + r * (bh + 16),
        w: bw,
        h: bh,
        color: palette[(r + c) % palette.length],
        alive: true,
        hp: r < 2 ? 3 : (r < 5 ? 2 : 1),
        isDynamite: (r === 3 && (c === 2 || c === 4)),
        isArmored: (r === 1 && (c === 1 || c === 5))
      });
    }
  }

  // 30 Fireballs for Scene 2 explosion
  for (let i = 0; i < 30; i++) {
    const angle = -Math.PI * 0.15 - (i / 29) * (Math.PI * 0.70);
    const speed = 22 + Math.random() * 12;
    balls.push({
      x: 540 + (Math.random() - 0.5) * 60,
      y: 1420 - Math.random() * 40,
      vx: Math.cos(angle) * speed,
      vy: Math.sin(angle) * speed,
      r: 16,
      trail: [],
      isFireball: true
    });
  }
}

initSimulationEntities();

function spawnExplosion(x, y, color, count = 18) {
  for (let i = 0; i < count; i++) {
    const a = Math.random() * Math.PI * 2;
    const sp = 5 + Math.random() * 20;
    particles.push({
      x, y,
      vx: Math.cos(a) * sp,
      vy: Math.sin(a) * sp,
      size: 6 + Math.random() * 14,
      color,
      alpha: 1.0,
      decay: 0.02 + Math.random() * 0.03
    });
  }
  if (Math.random() < 0.6) {
    coins.push({
      x, y,
      vx: (Math.random() - 0.5) * 8,
      vy: -8 - Math.random() * 8,
      alpha: 1.0,
      rot: 0
    });
  }
}

function spawnShockwave(x, y, color = '#00f5d4', maxR = 220) {
  shockwaves.push({ x, y, r: 10, maxR, color, alpha: 1.0 });
}

function spawnFloatingText(x, y, text, color = '#ffd700', isLarge = false) {
  floatingTexts.push({ x, y, text, color, isLarge, alpha: 1.0, vy: -3.5 });
}

function drawRoundedRect(x, y, w, h, r) {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.lineTo(x + w - r, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + r);
  ctx.lineTo(x + w, y + h - r);
  ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
  ctx.lineTo(x + r, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - r);
  ctx.lineTo(x, y + r);
  ctx.quadraticCurveTo(x, y, x + r, y);
  ctx.closePath();
}

// -------------------------------------------------------------
// SCENE 1: The Curiosity Hook (0.0s – 3.5s)
// Kurzgesagt Vector Earth, 25,000 mph Marble, Mach 32 Bow Shock
// -------------------------------------------------------------
function drawScene1(t) {
  // Deep Cosmic Background
  const bgGrad = ctx.createLinearGradient(0, 0, 0, H);
  bgGrad.addColorStop(0.0, '#030712');
  bgGrad.addColorStop(0.5, '#070f22');
  bgGrad.addColorStop(1.0, '#0b1636');
  ctx.fillStyle = bgGrad;
  ctx.fillRect(0, 0, W, H);

  // Parallax Starfield
  for (let s of stars) {
    const starY = (s.y + t * s.speed * 60) % H;
    const tw = 0.5 + 0.5 * Math.sin(t * 4 + s.twinkle);
    ctx.fillStyle = s.layer === 2 ? `rgba(255,255,255,${0.9 * tw})` : (s.layer === 1 ? `rgba(147,197,253,${0.7 * tw})` : `rgba(96,165,250,${0.4 * tw})`);
    ctx.beginPath();
    ctx.arc(s.x, starY, s.r, 0, Math.PI * 2);
    ctx.fill();
  }

  // Vector Earth Curvature with 5-stage Atmospheric Limb Gradient
  const earthCenterY = 2450;
  const earthRadius = 1350;
  const earthGrad = ctx.createRadialGradient(540, earthCenterY, earthRadius * 0.82, 540, earthCenterY, earthRadius + 140);
  earthGrad.addColorStop(0.0, '#0f172a');
  earthGrad.addColorStop(0.70, '#1e1b4b');
  earthGrad.addColorStop(0.85, '#4338ca');
  earthGrad.addColorStop(0.93, '#38bdf8');
  earthGrad.addColorStop(0.98, '#00f5d4');
  earthGrad.addColorStop(1.0, 'rgba(0, 245, 212, 0)');

  ctx.fillStyle = earthGrad;
  ctx.beginPath();
  ctx.arc(540, earthCenterY, earthRadius + 140, 0, Math.PI * 2);
  ctx.fill();

  // Continents curvature
  ctx.save();
  ctx.beginPath();
  ctx.arc(540, earthCenterY, earthRadius, 0, Math.PI * 2);
  ctx.clip();
  ctx.fillStyle = '#064e3b';
  ctx.beginPath();
  ctx.ellipse(420, 1420, 260, 160, -0.2, 0, Math.PI * 2);
  ctx.fill();
  ctx.beginPath();
  ctx.ellipse(720, 1480, 220, 130, 0.3, 0, Math.PI * 2);
  ctx.fill();
  ctx.restore();

  // Orbiting Vector Satellite at Top Left (t < 1.8)
  if (t < 2.0) {
    const satAlpha = Math.max(0, 1.0 - (t - 1.2) * 1.5);
    ctx.save();
    ctx.globalAlpha = satAlpha;
    const satX = 220 - t * 40;
    const satY = 320 + t * 25;
    
    // Solar Panels
    ctx.fillStyle = '#3b82f6';
    ctx.strokeStyle = '#60a5fa';
    ctx.lineWidth = 3;
    drawRoundedRect(satX - 110, satY - 20, 70, 40, 4);
    ctx.fill(); ctx.stroke();
    drawRoundedRect(satX + 40, satY - 20, 70, 40, 4);
    ctx.fill(); ctx.stroke();

    // Satellite Core
    ctx.fillStyle = '#e2e8f0';
    ctx.strokeStyle = '#94a3b8';
    ctx.lineWidth = 4;
    drawRoundedRect(satX - 35, satY - 25, 70, 50, 6);
    ctx.fill(); ctx.stroke();

    // Antenna & Dish
    ctx.strokeStyle = '#cbd5e1';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(satX, satY + 25);
    ctx.lineTo(satX, satY + 55);
    ctx.stroke();
    ctx.beginPath();
    ctx.arc(satX, satY + 65, 18, Math.PI * 1.2, Math.PI * 1.8);
    ctx.stroke();

    // Flashing Cyan LED Beacon
    if (Math.sin(t * 12) > 0) {
      ctx.fillStyle = '#00f5d4';
      ctx.shadowColor = '#00f5d4';
      ctx.shadowBlur = 15;
      ctx.beginPath();
      ctx.arc(satX - 25, satY - 20, 5, 0, Math.PI * 2);
      ctx.fill();
      ctx.shadowBlur = 0;
    }

    // Mini Astronaut silhouette releasing marble
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(satX + 15, satY + 35, 10, 0, Math.PI * 2); // helmet
    ctx.fill();
    ctx.fillStyle = '#fbbf24'; // visor
    ctx.beginPath();
    ctx.arc(satX + 18, satY + 35, 5, 0, Math.PI * 2);
    ctx.fill();

    ctx.restore();
  }

  // Fe-56 Chrome Marble Trajectory (0.5 oz / 14g)
  // Accelerates rapidly as t progresses
  const prog = Math.min(1.0, t / 3.5);
  const marbleY = 320 + Math.pow(prog, 2.4) * 1200;
  const marbleX = 220 + Math.sin(prog * Math.PI * 0.7) * 80 + prog * 240; // centers toward 540
  const marbleR = 20 + prog * 32;

  // Supersonic Plasma Bow Shock (active when t > 1.2)
  if (t > 1.2) {
    const shockIntensity = Math.min(1.0, (t - 1.2) / 1.8);
    ctx.save();
    ctx.globalAlpha = shockIntensity;

    // Outer flame envelope
    const flameGrad = ctx.createRadialGradient(marbleX, marbleY, marbleR * 0.8, marbleX, marbleY - marbleR * 2.5, marbleR * 5.0);
    flameGrad.addColorStop(0.0, '#ffffff');
    flameGrad.addColorStop(0.25, '#00f5d4');
    flameGrad.addColorStop(0.65, '#f43f5e');
    flameGrad.addColorStop(1.0, 'rgba(255, 85, 0, 0)');

    ctx.fillStyle = flameGrad;
    ctx.beginPath();
    ctx.moveTo(marbleX - marbleR * 2.8, marbleY - marbleR * 3.5);
    ctx.quadraticCurveTo(marbleX, marbleY + marbleR * 1.8, marbleX + marbleR * 2.8, marbleY - marbleR * 3.5);
    ctx.lineTo(marbleX + marbleR * 1.8, marbleY - marbleR * 4.5);
    ctx.quadraticCurveTo(marbleX, marbleY + marbleR * 0.5, marbleX - marbleR * 1.8, marbleY - marbleR * 4.5);
    ctx.closePath();
    ctx.fill();

    // Detached Mach Shock Rings expanding backwards
    for (let rIdx = 0; rIdx < 4; rIdx++) {
      const ringOffset = ((t * 8 + rIdx * 2.2) % 6) * 35;
      const ringAlpha = Math.max(0, 1.0 - ringOffset / 200) * shockIntensity;
      ctx.strokeStyle = `rgba(0, 245, 212, ${ringAlpha})`;
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.ellipse(marbleX, marbleY - ringOffset, marbleR * 1.6 + ringOffset * 0.4, marbleR * 0.6 + ringOffset * 0.15, 0, 0, Math.PI * 2);
      ctx.stroke();
    }

    ctx.restore();
  }

  // Chrome Fe-56 Iron Marble Sphere
  const chromeGrad = ctx.createRadialGradient(
    marbleX - marbleR * 0.35, marbleY - marbleR * 0.35, marbleR * 0.1,
    marbleX, marbleY, marbleR
  );
  chromeGrad.addColorStop(0.0, '#ffffff');
  chromeGrad.addColorStop(0.25, '#e2e8f0');
  chromeGrad.addColorStop(0.55, '#94a3b8');
  chromeGrad.addColorStop(0.85, '#475569');
  chromeGrad.addColorStop(1.0, '#0f172a');

  ctx.save();
  ctx.shadowColor = t > 1.2 ? '#00f5d4' : '#ffffff';
  ctx.shadowBlur = t > 1.2 ? 30 : 15;
  ctx.fillStyle = chromeGrad;
  ctx.beginPath();
  ctx.arc(marbleX, marbleY, marbleR, 0, Math.PI * 2);
  ctx.fill();
  ctx.shadowBlur = 0;

  // Specular Star Glint Flare
  const glintAngle = t * 3.0;
  const glintLen = marbleR * (1.2 + 0.3 * Math.sin(t * 6));
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
  ctx.lineWidth = 3;
  for (let a = 0; a < 4; a++) {
    const ang = glintAngle + a * (Math.PI / 4);
    ctx.beginPath();
    ctx.moveTo(marbleX - marbleR * 0.35 - Math.cos(ang) * glintLen, marbleY - marbleR * 0.35 - Math.sin(ang) * glintLen);
    ctx.lineTo(marbleX - marbleR * 0.35 + Math.cos(ang) * glintLen, marbleY - marbleR * 0.35 + Math.sin(ang) * glintLen);
    ctx.stroke();
  }
  ctx.restore();

  // Fe-56 Callout Pill at Start (0.0s – 1.5s)
  if (t < 1.8) {
    const tagAlpha = Math.min(1.0, Math.max(0, 1.0 - (t - 1.2) * 2));
    ctx.save();
    ctx.globalAlpha = tagAlpha;
    ctx.fillStyle = 'rgba(15, 23, 42, 0.85)';
    ctx.strokeStyle = '#00f5d4';
    ctx.lineWidth = 2;
    drawRoundedRect(marbleX + 40, marbleY - 40, 240, 64, 12);
    ctx.fill(); ctx.stroke();
    
    ctx.fillStyle = '#00f5d4';
    ctx.font = 'bold 24px Rajdhani, sans-serif';
    ctx.fillText('Fe-56 IRON MARBLE', marbleX + 55, marbleY - 14);
    ctx.fillStyle = '#94a3b8';
    ctx.font = '18px Rajdhani, sans-serif';
    ctx.fillText('MASS: 0.5 oz (14g) • ORBIT', marbleX + 55, marbleY + 12);
    ctx.restore();
  }

  // HUD: Speedometer Gauge (0 -> 25,000 mph) & Thermometer (0 -> 5,000°F)
  drawSpeedAndTempHUD(t);
}

function drawSpeedAndTempHUD(t) {
  const speedProg = Math.min(1.0, Math.pow(Math.max(0, (t - 0.6) / 2.8), 2.2));
  const currentSpeed = Math.floor(speedProg * 25000);
  const tempProg = Math.min(1.0, Math.pow(Math.max(0, (t - 1.0) / 2.4), 2.0));
  const currentTemp = Math.floor(tempProg * 5000);

  // Speedometer Arc Gauge (Top Right)
  const gx = 840, gy = 260, gr = 95;
  ctx.save();
  ctx.fillStyle = 'rgba(11, 15, 26, 0.85)';
  ctx.strokeStyle = 'rgba(0, 245, 212, 0.3)';
  ctx.lineWidth = 3;
  ctx.beginPath();
  ctx.arc(gx, gy, gr + 25, 0, Math.PI * 2);
  ctx.fill(); ctx.stroke();

  // Background arc
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.15)';
  ctx.lineWidth = 14;
  ctx.lineCap = 'round';
  ctx.beginPath();
  ctx.arc(gx, gy, gr, Math.PI * 0.75, Math.PI * 2.25);
  ctx.stroke();

  // Active glowing speed arc
  const sweepAngle = Math.PI * 0.75 + speedProg * (Math.PI * 1.5);
  const arcGrad = ctx.createLinearGradient(gx - gr, gy, gx + gr, gy);
  arcGrad.addColorStop(0.0, '#00f5d4');
  arcGrad.addColorStop(0.7, '#38bdf8');
  arcGrad.addColorStop(1.0, '#f43f5e');
  ctx.strokeStyle = arcGrad;
  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 15;
  ctx.beginPath();
  ctx.arc(gx, gy, gr, Math.PI * 0.75, sweepAngle);
  ctx.stroke();
  ctx.shadowBlur = 0;

  // Speedometer Labels
  ctx.textAlign = 'center';
  ctx.fillStyle = '#00f5d4';
  ctx.font = '900 34px Rajdhani, sans-serif';
  ctx.fillText(currentSpeed.toLocaleString() + ' MPH', gx, gy + 8);
  ctx.fillStyle = '#94a3b8';
  ctx.font = 'bold 16px Rajdhani, sans-serif';
  ctx.fillText('VELOCITY: MACH ' + (speedProg * 32.5).toFixed(1), gx, gy + 34);
  ctx.restore();

  // Thermometer Bar Gauge (Top Left)
  const tx = 110, ty = 210, tw = 40, th = 170;
  ctx.save();
  ctx.fillStyle = 'rgba(11, 15, 26, 0.85)';
  ctx.strokeStyle = 'rgba(244, 63, 94, 0.3)';
  ctx.lineWidth = 3;
  drawRoundedRect(tx - 15, ty - 20, tw + 185, th + 40, 16);
  ctx.fill(); ctx.stroke();

  // Thermo track
  ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
  drawRoundedRect(tx, ty, tw, th, tw / 2);
  ctx.fill();

  // Thermo liquid fill
  const fillH = th * tempProg;
  const thermoGrad = ctx.createLinearGradient(tx, ty + th, tx, ty);
  thermoGrad.addColorStop(0.0, '#38bdf8');
  thermoGrad.addColorStop(0.5, '#fbbf24');
  thermoGrad.addColorStop(1.0, '#ff0055');
  ctx.fillStyle = thermoGrad;
  drawRoundedRect(tx, ty + (th - fillH), tw, fillH, tw / 2);
  ctx.fill();

  // Bulb
  ctx.beginPath();
  ctx.arc(tx + tw / 2, ty + th + 5, tw * 0.75, 0, Math.PI * 2);
  ctx.fill();

  // Temperature Labels
  ctx.textAlign = 'left';
  ctx.fillStyle = tempProg > 0.6 ? '#f43f5e' : '#fbbf24';
  ctx.font = '900 32px Rajdhani, sans-serif';
  ctx.fillText(currentTemp.toLocaleString() + '°F', tx + tw + 20, ty + 50);
  ctx.fillStyle = '#cbd5e1';
  ctx.font = 'bold 16px Rajdhani, sans-serif';
  ctx.fillText('ENTRY HEAT SHIELD', tx + tw + 20, ty + 80);
  ctx.fillStyle = '#94a3b8';
  ctx.font = '14px Rajdhani, sans-serif';
  ctx.fillText('ALT: ' + Math.max(0, Math.floor((1 - speedProg) * 220000)).toLocaleString() + ' FT', tx + tw + 20, ty + 105);
  ctx.restore();
}

// -------------------------------------------------------------
// SCENE 2: The Unexpected Cosmic Pivot (3.5s – 7.5s)
// Cloud Plunge, Joe's Diner, 4.5s Slow-Mo Corner Hit, 30 Fireballs
// -------------------------------------------------------------
let sfxTriggeredScene2Snap = false;
let sfxTriggeredScene2Explode = false;

function drawScene2(t) {
  // Stratocumulus Cloud Plunge (t: 3.5 – 4.5)
  const plungeT = Math.min(1.0, (t - 3.5) / 1.0);
  
  // Metropolitan Night Sky Gradient
  const skyGrad = ctx.createLinearGradient(0, 0, 0, H);
  skyGrad.addColorStop(0.0, '#0a0e1a');
  skyGrad.addColorStop(0.5, '#111827');
  skyGrad.addColorStop(1.0, '#1e293b');
  ctx.fillStyle = skyGrad;
  ctx.fillRect(0, 0, W, H);

  // Distant City Skyline Silhouettes with Glowing Windows
  drawMetropolitanSkyline(t);

  // Joe's Corner Diner Storefront at Bottom (t < 5.4)
  if (t < 5.5) {
    drawJoesCornerDiner(t);
  }

  // Clouds parting downwards
  if (plungeT < 1.0) {
    ctx.save();
    ctx.globalAlpha = 1.0 - plungeT;
    ctx.fillStyle = '#e2e8f0';
    // Puffy cloud masses
    ctx.beginPath();
    ctx.ellipse(320, 300 - plungeT * 500, 340, 180, 0, 0, Math.PI * 2);
    ctx.ellipse(780, 420 - plungeT * 500, 400, 220, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // MATRIX SLOW-MO SNAP AT t = 4.5s
  const isSlowMo = (t >= 4.45 && t < 5.3);
  if (t >= 4.5 && !sfxTriggeredScene2Snap) {
    sfxTriggeredScene2Snap = true;
    playSoundBuffer('sfx_cam_kirilma', sfxGain);
    playSoundBuffer('sfx_custom_bounce', sfxGain);
    playSubBass(40, 1.2);
    spawnShockwave(540 + 190, 1420, '#ffd700', 380);
    spawnFloatingText(540, 1260, '⚡ SUPER CORNER HIT!', '#ffd700', true);
  }

  // White flash overlay at snap
  if (t >= 4.5 && t < 4.75) {
    const flashAlpha = (1.0 - (t - 4.5) / 0.25) * 0.85;
    ctx.fillStyle = `rgba(255, 255, 255, ${flashAlpha})`;
    ctx.fillRect(0, 0, W, H);
  }

  // Meteor approaching paddle
  if (t < 4.5) {
    const meteorProgress = (t - 3.5) / 1.0;
    const mx = 540 + meteorProgress * 190;
    const my = 400 + Math.pow(meteorProgress, 2.0) * 1020;
    
    // Meteor ball
    ctx.save();
    ctx.shadowColor = '#ff5500';
    ctx.shadowBlur = 40;
    const mGrad = ctx.createRadialGradient(mx, my, 5, mx, my, 35);
    mGrad.addColorStop(0.0, '#ffffff');
    mGrad.addColorStop(0.3, '#ffcc00');
    mGrad.addColorStop(0.7, '#ff3300');
    mGrad.addColorStop(1.0, '#660000');
    ctx.fillStyle = mGrad;
    ctx.beginPath();
    ctx.arc(mx, my, 35, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Kırmataş Cosmic Legendary Paddle
  drawCosmicPaddle(t);

  // AFTER IMPACT: 30 Fireballs & Brick Wall Obliteration (t >= 5.2)
  if (t >= 5.2) {
    if (!sfxTriggeredScene2Explode) {
      sfxTriggeredScene2Explode = true;
      playSoundBuffer('sfx_custom_explosion', sfxGain);
      spawnFloatingText(540, 850, '🔥 30x FIREBALLS!', '#ff6b00', true);
      spawnFloatingText(540, 750, '💥 45 COMBO!', '#00f5d4', false);
    }

    // Draw 7x8 Authentic Brick Wall
    drawBrickWall(t);

    // Update & Draw 30 Projectile Fireballs
    draw30Fireballs(t);
  }

  // Draw active particles & shockwaves
  updateAndDrawFX();
}

function drawMetropolitanSkyline(t) {
  ctx.save();
  // Far skyscraper silhouettes
  ctx.fillStyle = '#0f172a';
  const buildingsFar = [
    { x: 40, w: 120, h: 650 },
    { x: 190, w: 140, h: 780 },
    { x: 360, w: 160, h: 890 },
    { x: 550, w: 130, h: 720 },
    { x: 710, w: 180, h: 840 },
    { x: 920, w: 120, h: 690 }
  ];
  for (let b of buildingsFar) {
    ctx.fillRect(b.x, H - b.h, b.w, b.h);
    // Spire
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(b.x + b.w / 2, H - b.h);
    ctx.lineTo(b.x + b.w / 2, H - b.h - 80);
    ctx.stroke();
    // Spire blinking light
    if (Math.sin(t * 5 + b.x) > 0) {
      ctx.fillStyle = '#f43f5e';
      ctx.beginPath();
      ctx.arc(b.x + b.w / 2, H - b.h - 80, 4, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  // Near buildings with warm yellow & cyan illuminated window grids
  ctx.fillStyle = '#1e293b';
  const buildingsNear = [
    { x: 0, w: 180, h: 520 },
    { x: 210, w: 200, h: 580 },
    { x: 440, w: 220, h: 480 },
    { x: 690, w: 190, h: 540 },
    { x: 910, w: 170, h: 510 }
  ];
  for (let b of buildingsNear) {
    ctx.fillRect(b.x, H - b.h, b.w, b.h);
    // Window grid
    for (let wy = H - b.h + 40; wy < H - 180; wy += 45) {
      for (let wx = b.x + 25; wx < b.x + b.w - 25; wx += 35) {
        if ((wx + wy) % 3 !== 0) {
          ctx.fillStyle = (wx % 2 === 0) ? 'rgba(253, 224, 71, 0.75)' : 'rgba(56, 189, 248, 0.65)';
          ctx.fillRect(wx, wy, 18, 24);
        }
      }
    }
  }
  ctx.restore();
}

function drawJoesCornerDiner(t) {
  ctx.save();
  const dinerY = 1450;
  // Diner Roof & Front Facade
  ctx.fillStyle = '#334155';
  ctx.strokeStyle = '#475569';
  ctx.lineWidth = 6;
  drawRoundedRect(160, dinerY, 760, 360, 24);
  ctx.fill(); ctx.stroke();

  // Striped Awning (Red & White retro diner)
  const awningY = dinerY + 40;
  const stripeW = 760 / 16;
  for (let s = 0; s < 16; s++) {
    ctx.fillStyle = (s % 2 === 0) ? '#e11d48' : '#f8fafc';
    ctx.fillRect(160 + s * stripeW, awningY, stripeW, 55);
  }

  // Illuminated Neon Storefront Sign: JOE'S CORNER DINER (EST. 1984)
  ctx.fillStyle = 'rgba(15, 23, 42, 0.9)';
  ctx.strokeStyle = '#00f5d4';
  ctx.lineWidth = 4;
  drawRoundedRect(220, dinerY - 70, 640, 95, 18);
  ctx.fill(); ctx.stroke();

  ctx.textAlign = 'center';
  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 20;
  ctx.fillStyle = '#00f5d4';
  ctx.font = '900 42px Rajdhani, sans-serif';
  ctx.fillText("JOE'S CORNER DINER", 540, dinerY - 22);
  ctx.shadowBlur = 0;

  ctx.fillStyle = '#fbbf24';
  ctx.font = 'bold 20px Rajdhani, sans-serif';
  ctx.fillText("EST. 1984 • 24/7 BEST COFFEE & PANCAKES", 540, dinerY + 8);

  // Diner Windows with Warm Interior Glow
  ctx.fillStyle = 'rgba(254, 240, 138, 0.85)';
  drawRoundedRect(200, dinerY + 120, 320, 160, 12);
  ctx.fill();
  drawRoundedRect(560, dinerY + 120, 320, 160, 12);
  ctx.fill();

  // Street Corner Lamppost
  ctx.strokeStyle = '#64748b';
  ctx.lineWidth = 8;
  ctx.beginPath();
  ctx.moveTo(110, dinerY + 340);
  ctx.lineTo(110, dinerY - 30);
  ctx.arc(140, dinerY - 30, 30, Math.PI, Math.PI * 1.5);
  ctx.stroke();

  // Lamp Light Cone
  ctx.fillStyle = 'rgba(253, 224, 71, 0.35)';
  ctx.beginPath();
  ctx.moveTo(140, dinerY - 30);
  ctx.lineTo(60, dinerY + 340);
  ctx.lineTo(240, dinerY + 340);
  ctx.closePath();
  ctx.fill();

  ctx.restore();
}

function drawCosmicPaddle(t) {
  // Paddle sweeps in to intercept at (540 + 190) on corner hit
  const paddleTargetX = 540;
  const paddleY = 1420;
  const pw = 240, ph = 38;
  
  // Ease in paddle
  const pProg = Math.min(1.0, Math.max(0, (t - 3.8) / 0.65));
  const easeX = paddleTargetX + (1.0 - Math.pow(1.0 - pProg, 3.0)) * 60;

  ctx.save();
  // Cosmic Glow Aura
  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 35;

  // Multi-stop Cosmic Gradient (#00f5d4 -> #ec4899 -> #f59e0b)
  const padGrad = ctx.createLinearGradient(easeX - pw / 2, paddleY, easeX + pw / 2, paddleY);
  padGrad.addColorStop(0.0, '#00f5d4');
  padGrad.addColorStop(0.4, '#a855f7');
  padGrad.addColorStop(0.7, '#ec4899');
  padGrad.addColorStop(1.0, '#f59e0b');

  ctx.fillStyle = padGrad;
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 4;
  drawRoundedRect(easeX - pw / 2, paddleY - ph / 2, pw, ph, ph / 2);
  ctx.fill(); ctx.stroke();
  ctx.shadowBlur = 0;

  // Crystal Core Inset
  ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
  drawRoundedRect(easeX - pw / 2 + 15, paddleY - 4, pw - 30, 8, 4);
  ctx.fill();

  // Outer corner indicator marking the 0.88 hit offset point
  const cornerHitPointX = easeX + pw / 2 * 0.88;
  if (t >= 4.4 && t < 5.4) {
    ctx.fillStyle = '#ffd700';
    ctx.shadowColor = '#ffd700';
    ctx.shadowBlur = 25;
    ctx.beginPath();
    ctx.arc(cornerHitPointX, paddleY, 14, 0, Math.PI * 2);
    ctx.fill();
    ctx.shadowBlur = 0;
  }
  ctx.restore();
}

function drawBrickWall(t) {
  ctx.save();
  for (let b of bricks) {
    if (!b.alive) continue;
    ctx.fillStyle = b.color;
    ctx.strokeStyle = '#ffffff';
    ctx.lineWidth = 2.5;
    drawRoundedRect(b.x, b.y, b.w, b.h, 10);
    ctx.fill(); ctx.stroke();

    // Specular top highlight
    ctx.fillStyle = 'rgba(255, 255, 255, 0.4)';
    drawRoundedRect(b.x + 4, b.y + 4, b.w - 8, b.h * 0.35, 6);
    ctx.fill();

    // Dynamite or Armor Badge
    if (b.isDynamite) {
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 22px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('💣', b.x + b.w / 2, b.y + b.h / 2 + 8);
    } else if (b.isArmored) {
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 22px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText('🛡️', b.x + b.w / 2, b.y + b.h / 2 + 8);
    }
  }
  ctx.restore();
}

function draw30Fireballs(t) {
  const dt = 1 / 60;
  for (let ball of balls) {
    // Record trail
    ball.trail.push({ x: ball.x, y: ball.y });
    if (ball.trail.length > 8) ball.trail.shift();

    // Update position
    ball.x += ball.vx * 1.25;
    ball.y += ball.vy * 1.25;

    // Bounce off left/right walls
    if (ball.x < 40 || ball.x > W - 40) {
      ball.vx *= -1;
      ball.x = Math.max(40, Math.min(W - 40, ball.x));
    }
    // Bounce off ceiling
    if (ball.y < 350) {
      ball.vy *= -1;
      ball.y = 350;
    }

    // Check collision against bricks
    for (let b of bricks) {
      if (!b.alive) continue;
      if (ball.x + ball.r > b.x && ball.x - ball.r < b.x + b.w &&
          ball.y + ball.r > b.y && ball.y - ball.r < b.y + b.h) {
        b.hp--;
        if (b.hp <= 0) {
          b.alive = false;
          spawnExplosion(b.x + b.w / 2, b.y + b.h / 2, b.color, 24);
          if (b.isDynamite) {
            // Blow neighboring bricks
            for (let nb of bricks) {
              if (nb.alive && Math.hypot(nb.x - b.x, nb.y - b.y) < 180) {
                nb.alive = false;
                spawnExplosion(nb.x + nb.w / 2, nb.y + nb.h / 2, nb.color, 16);
              }
            }
          }
        }
        ball.vy *= -1;
        break;
      }
    }

    // Render Fireball Trail
    ctx.save();
    for (let trIdx = 0; trIdx < ball.trail.length; trIdx++) {
      const tr = ball.trail[trIdx];
      const trAlpha = (trIdx + 1) / ball.trail.length;
      ctx.fillStyle = `rgba(255, 107, 0, ${trAlpha * 0.7})`;
      ctx.beginPath();
      ctx.arc(tr.x, tr.y, ball.r * (0.4 + 0.6 * trAlpha), 0, Math.PI * 2);
      ctx.fill();
    }

    // Render Fireball Head
    ctx.shadowColor = '#ff3d00';
    ctx.shadowBlur = 25;
    const fGrad = ctx.createRadialGradient(ball.x, ball.y, 2, ball.x, ball.y, ball.r);
    fGrad.addColorStop(0.0, '#ffffff');
    fGrad.addColorStop(0.3, '#ffd700');
    fGrad.addColorStop(0.7, '#ff5500');
    fGrad.addColorStop(1.0, '#b71c1c');
    ctx.fillStyle = fGrad;
    ctx.beginPath();
    ctx.arc(ball.x, ball.y, ball.r, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }
}

// -------------------------------------------------------------
// SCENE 3: Real In-Game Footage Showcase (7.5s – 13.5s)
// Action Ulti (7.5-9.5), Chaos Perks (9.5-11.5), Eco Aquarium (11.5-13.5)
// -------------------------------------------------------------
let sfxTriggeredUlti = false;
let sfxTriggeredPerk = false;
let sfxTriggeredAqua = false;

function drawScene3(t) {
  // Clear backdrop
  ctx.fillStyle = '#060a12';
  ctx.fillRect(0, 0, W, H);

  if (t < 9.5) {
    // Window 1: Real GameCanvas Action & Ulti Wipe (7.5s – 9.5s)
    drawRealGameplayWindow(t);
  } else if (t < 11.5) {
    // Window 2: Chaos Mode 3-Card Roguelike Perks & Synergies (9.5s – 11.5s)
    drawChaosPerksWindow(t);
  } else {
    // Window 3: Eco-Tank Aquarium & Weekly League #1 (11.5s – 13.5s)
    drawAquariumLeagueWindow(t);
  }

  updateAndDrawFX();
}

function drawRealGameplayWindow(t) {
  if (loadedImages.img_action && loadedImages.img_action.complete) {
    ctx.drawImage(loadedImages.img_action, 0, 0, W, H);
  } else {
    // High-fidelity fallback
    drawBrickWall(t);
    drawCosmicPaddle(t);
  }

  if (t >= 7.6 && !sfxTriggeredUlti) {
    sfxTriggeredUlti = true;
    playSoundBuffer('sfx_custom_laser', sfxGain);
    spawnShockwave(540, 960, '#00f5d4', 450);
    spawnFloatingText(540, 520, '⚡ ULTIMATE LIGHTNING READY!', '#ffd700', true);
  }

  // Live 60 FPS Ulti Lightning Arc across screen
  const lt = (t - 7.5);
  ctx.save();
  ctx.strokeStyle = '#00f5d4';
  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 30;
  ctx.lineWidth = 8;
  ctx.beginPath();
  let lx = 100, ly = 450;
  ctx.moveTo(lx, ly);
  while (lx < W - 100) {
    lx += 60 + Math.random() * 40;
    ly += (Math.random() - 0.5) * 120;
    ctx.lineTo(lx, ly);
  }
  ctx.stroke();

  // White inner filament
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 3;
  ctx.stroke();
  ctx.shadowBlur = 0;

  // Ulti Callout Banner HUD
  const pulse = 1.0 + 0.08 * Math.sin(t * 14);
  ctx.save();
  ctx.translate(540, 420);
  ctx.scale(pulse, pulse);
  ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
  ctx.strokeStyle = '#ffd700';
  ctx.lineWidth = 4;
  drawRoundedRect(-360, -45, 720, 90, 20);
  ctx.fill(); ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#ffd700';
  ctx.font = '900 36px Rajdhani, sans-serif';
  ctx.fillText('⚡ ULTIMATE READY! DOUBLE TAP!', 0, 10);
  ctx.restore();

  ctx.restore();
}

function drawChaosPerksWindow(t) {
  if (t >= 9.6 && !sfxTriggeredPerk) {
    sfxTriggeredPerk = true;
    playTone(660, 'sine', 0.25, 0.35, 880);
    spawnFloatingText(540, 480, '👑 COSMIC LEGENDARY SET ACTIVE!', '#f59e0b', true);
  }

  // Draw real chaos perks frame
  if (loadedImages.img_perks && loadedImages.img_perks.complete) {
    ctx.drawImage(loadedImages.img_perks, 0, 0, W, H);
  }

  // Synergy badge overlay from shop_synergies
  ctx.save();
  const subT = t - 9.5;
  const slideY = Math.min(1.0, subT * 3.0);
  const badgeY = 1380 - (1.0 - slideY) * 200;

  ctx.fillStyle = 'rgba(15, 23, 42, 0.95)';
  ctx.strokeStyle = '#f59e0b';
  ctx.lineWidth = 4;
  drawRoundedRect(120, badgeY, 840, 130, 24);
  ctx.fill(); ctx.stroke();

  ctx.textAlign = 'center';
  ctx.fillStyle = '#f59e0b';
  ctx.font = '900 36px Rajdhani, sans-serif';
  ctx.fillText('👑 COSMIC LEGENDARY SET SYNERGY', 540, badgeY + 48);
  ctx.fillStyle = '#e2e8f0';
  ctx.font = 'bold 24px Rajdhani, sans-serif';
  ctx.fillText('+15% Score Multiplier • +15% Gold Multiplier', 540, badgeY + 92);
  ctx.restore();
}

function drawAquariumLeagueWindow(t) {
  if (t >= 11.6 && !sfxTriggeredAqua) {
    sfxTriggeredAqua = true;
    playTone(523.25, 'sine', 0.2, 0.2, 659.25);
    spawnFloatingText(540, 450, '🐠 ZEN ECO-TANK & TOURNAMENT #1', '#38bdf8', true);
  }

  // Draw real aquarium view
  if (loadedImages.img_aquarium && loadedImages.img_aquarium.complete) {
    ctx.drawImage(loadedImages.img_aquarium, 0, 0, W, H);
  }

  // Live Swimming Fish Sprites Wagging
  drawSwimmingFishSprites(t);

  // Tournament League Overlay Card at Bottom
  ctx.save();
  const cardY = 1320;
  ctx.fillStyle = 'rgba(15, 23, 42, 0.92)';
  ctx.strokeStyle = '#38bdf8';
  ctx.lineWidth = 4;
  drawRoundedRect(140, cardY, 800, 180, 24);
  ctx.fill(); ctx.stroke();

  ctx.textAlign = 'left';
  ctx.fillStyle = '#ffd700';
  ctx.font = '900 38px Rajdhani, sans-serif';
  ctx.fillText('🏆 WEEKLY LEAGUE: #1 COSMIC EMPEROR', 180, cardY + 58);
  ctx.fillStyle = '#94a3b8';
  ctx.font = '24px Rajdhani, sans-serif';
  ctx.fillText('Score: 1,482,900 PTS • Tier 7 Promotion Zone', 180, cardY + 102);
  ctx.fillStyle = '#00f5d4';
  ctx.font = 'bold 22px Rajdhani, sans-serif';
  ctx.fillText('✦ Claim Season Title & Avatar Frame', 180, cardY + 140);
  ctx.restore();
}

function drawSwimmingFishSprites(t) {
  ctx.save();
  // 3 swimming fishes wagging tails
  const fishes = [
    { x: 320 + Math.sin(t * 1.5) * 140, y: 720 + Math.cos(t * 1.2) * 40, col: '#ff4d4d', sz: 42, name: 'Arowana' },
    { x: 740 - Math.sin(t * 1.8) * 160, y: 880 + Math.sin(t * 1.4) * 35, col: '#00d2ff', sz: 36, name: 'Discus' },
    { x: 500 + Math.cos(t * 1.3) * 120, y: 1040 + Math.sin(t * 1.6) * 30, col: '#ffd700', sz: 32, name: 'Angel' }
  ];

  for (let f of fishes) {
    const wag = Math.sin(t * 10) * 12;
    ctx.fillStyle = f.col;
    // Body ellipse
    ctx.beginPath();
    ctx.ellipse(f.x, f.y, f.sz, f.sz * 0.55, 0, 0, Math.PI * 2);
    ctx.fill();
    // Tail
    ctx.beginPath();
    ctx.moveTo(f.x - f.sz * 0.8, f.y);
    ctx.lineTo(f.x - f.sz * 1.5, f.y - f.sz * 0.6 + wag);
    ctx.lineTo(f.x - f.sz * 1.5, f.y + f.sz * 0.6 + wag);
    ctx.closePath();
    ctx.fill();
    // Eye
    ctx.fillStyle = '#ffffff';
    ctx.beginPath();
    ctx.arc(f.x + f.sz * 0.5, f.y - f.sz * 0.15, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = '#000000';
    ctx.beginPath();
    ctx.arc(f.x + f.sz * 0.6, f.y - f.sz * 0.15, 2.5, 0, Math.PI * 2);
    ctx.fill();

    // Rising Air Bubbles
    if (Math.random() < 0.25) {
      particles.push({
        x: f.x + f.sz * 0.8,
        y: f.y,
        vx: (Math.random() - 0.5) * 1.5,
        vy: -3 - Math.random() * 3,
        size: 4 + Math.random() * 6,
        color: '#67e8f9',
        alpha: 0.85,
        decay: 0.015
      });
    }
  }
  ctx.restore();
}

// -------------------------------------------------------------
// SCENE 4: Wave-10 Chaos Boss & Kaunos Games CTA (13.5s – 18.0s)
// -------------------------------------------------------------
let sfxTriggeredBossAlarm = false;
let sfxTriggeredBossShatter = false;

function drawScene4(t) {
  if (t < 15.5) {
    // 13.5s – 15.5s: Wave-10 Chaos Boss Encounter
    drawWave10BossEncounter(t);
  } else {
    // 15.5s – 18.0s: Kaunos Games High-Converting End Card
    drawKaunosGamesEndCard(t);
  }

  updateAndDrawFX();
}

function drawWave10BossEncounter(t) {
  if (loadedImages.img_boss && loadedImages.img_boss.complete) {
    ctx.drawImage(loadedImages.img_boss, 0, 0, W, H);
  } else {
    ctx.fillStyle = '#0f172a';
    ctx.fillRect(0, 0, W, H);
  }

  // Boss Warning Klaxon Alarm at t = 13.5s
  if (t >= 13.5 && !sfxTriggeredBossAlarm) {
    sfxTriggeredBossAlarm = true;
    playTone(440, 'sawtooth', 0.35, 0.35, 587);
    spawnShockwave(540, 750, '#f43f5e', 450);
  }

  // Animated Hazard Warning Banner
  const hazardStripeOffset = (t * 80) % 40;
  ctx.save();
  ctx.fillStyle = '#dc2626';
  ctx.fillRect(0, 240, W, 85);
  // Stripes
  ctx.fillStyle = '#000000';
  for (let sx = -40 + hazardStripeOffset; sx < W + 40; sx += 40) {
    ctx.beginPath();
    ctx.moveTo(sx, 240);
    ctx.lineTo(sx + 20, 240);
    ctx.lineTo(sx, 325);
    ctx.lineTo(sx - 20, 325);
    ctx.closePath();
    ctx.fill();
  }

  ctx.textAlign = 'center';
  ctx.fillStyle = '#ffffff';
  ctx.font = '900 38px Rajdhani, sans-serif';
  ctx.fillText('⚠️ WARNING: WAVE-10 CHAOS BOSS DETECTED! ⚠️', 540, 295);
  ctx.restore();

  // Boss Armor Shatter Composite Explosion at t = 14.8s
  if (t >= 14.8 && !sfxTriggeredBossShatter) {
    sfxTriggeredBossShatter = true;
    playSoundBuffer('sfx_custom_explosion', sfxGain);
    playSoundBuffer('sfx_glass_shatter', sfxGain);
    spawnExplosion(540, 750, '#f43f5e', 45);
    spawnExplosion(540, 750, '#ffd700', 35);
    spawnShockwave(540, 750, '#ffffff', 550);
    spawnFloatingText(540, 680, 'BOSS DEFEATED! +500 GOLD +5 PEARLS', '#ffd700', true);
  }
}

function drawKaunosGamesEndCard(t) {
  // Premium Obsidian Backdrop with Warm Amber Rays
  const endGrad = ctx.createRadialGradient(540, 960, 100, 540, 960, 1100);
  endGrad.addColorStop(0.0, '#1e1b4b');
  endGrad.addColorStop(0.4, '#0f172a');
  endGrad.addColorStop(1.0, '#030712');
  ctx.fillStyle = endGrad;
  ctx.fillRect(0, 0, W, H);

  // Floating Golden Particle Sparks
  for (let s of stars.slice(0, 40)) {
    const py = (s.y - (t - 15.5) * 45) % H;
    ctx.fillStyle = 'rgba(245, 176, 65, 0.65)';
    ctx.beginPath();
    ctx.arc(s.x, py < 0 ? py + H : py, s.r * 1.5, 0, Math.PI * 2);
    ctx.fill();
  }

  // Official Studio Logo: assets/images/kaunos_games.png
  if (loadedImages.img_kaunos && loadedImages.img_kaunos.complete) {
    const logoW = 380;
    const logoH = 380 * (loadedImages.img_kaunos.height / loadedImages.img_kaunos.width);
    ctx.drawImage(loadedImages.img_kaunos, 540 - logoW / 2, 420, logoW, logoH);
  } else {
    // Fallback Logo Emblem
    ctx.save();
    ctx.fillStyle = '#00f5d4';
    ctx.font = '900 68px Rajdhani, sans-serif';
    ctx.textAlign = 'center';
    ctx.fillText('KAUNOS GAMES', 540, 560);
    ctx.restore();
  }

  // Title & Brand
  ctx.save();
  ctx.textAlign = 'center';
  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 25;
  ctx.fillStyle = '#ffffff';
  ctx.font = '900 84px Rajdhani, sans-serif';
  ctx.fillText('KIRMATAŞ', 540, 890);
  ctx.shadowBlur = 0;

  ctx.fillStyle = '#00f5d4';
  ctx.font = 'bold 36px Rajdhani, sans-serif';
  ctx.fillText('THE ULTIMATE BRICK BREAKER', 540, 945);

  // 5-Star Rating Badge
  ctx.fillStyle = '#fbbf24';
  ctx.font = 'bold 36px Rajdhani, sans-serif';
  ctx.fillText('★★★★★ 4.9 RATING • 100K+ PLAYERS', 540, 1020);

  // 4 Feature Pills
  const features = ['ROGUELIKE PERKS', 'ZEN ECO-TANK', 'WEEKLY LEAGUE', 'ZERO FORCED ADS'];
  const pillW = 220, pillH = 50, startPX = 100;
  for (let pIdx = 0; pIdx < 4; pIdx++) {
    const px = (pIdx % 2 === 0) ? 290 : 790;
    const py = 1100 + Math.floor(pIdx / 2) * 65;
    ctx.fillStyle = 'rgba(30, 41, 59, 0.85)';
    ctx.strokeStyle = '#38bdf8';
    ctx.lineWidth = 2.5;
    drawRoundedRect(px - pillW / 2, py - pillH / 2, pillW, pillH, 14);
    ctx.fill(); ctx.stroke();
    ctx.fillStyle = '#f1f5f9';
    ctx.font = 'bold 20px Rajdhani, sans-serif';
    ctx.fillText(features[pIdx], px, py + 7);
  }

  // Large High-Converting CTA Button: DOWNLOAD FREE ON GOOGLE PLAY
  const pulse = 1.0 + 0.05 * Math.sin(t * 8);
  const btnY = 1360;
  ctx.save();
  ctx.translate(540, btnY);
  ctx.scale(pulse, pulse);

  const btnGrad = ctx.createLinearGradient(-380, 0, 380, 0);
  btnGrad.addColorStop(0.0, '#00f5d4');
  btnGrad.addColorStop(0.5, '#3b82f6');
  btnGrad.addColorStop(1.0, '#ec4899');

  ctx.shadowColor = '#00f5d4';
  ctx.shadowBlur = 35;
  ctx.fillStyle = btnGrad;
  drawRoundedRect(-400, -65, 800, 130, 32);
  ctx.fill();
  ctx.shadowBlur = 0;

  // Inner border
  ctx.strokeStyle = '#ffffff';
  ctx.lineWidth = 4;
  drawRoundedRect(-392, -57, 784, 114, 26);
  ctx.stroke();

  ctx.fillStyle = '#030712';
  ctx.font = '900 46px Rajdhani, sans-serif';
  ctx.fillText('DOWNLOAD FREE ON GOOGLE PLAY', 0, 14);
  ctx.restore();

  // Bottom tagline
  ctx.fillStyle = '#94a3b8';
  ctx.font = '22px Rajdhani, sans-serif';
  ctx.fillText('Free to Play • Offline Compatible • Satisfying Physics', 540, 1500);

  ctx.restore();
}

// -------------------------------------------------------------
// DYNAMIC TIKTOK / REELS CAPTIONS (Lower Third y = 1600)
// Word-by-Word Timing, Active Word Highlight (#00F5D4), 1.2x Bounce
// -------------------------------------------------------------
function drawTikTokCaptions(t) {
  // Find active voiceover scene
  let activeScene = null;
  for (let sc of sceneVoiceovers) {
    if (t >= sc.start && t <= sc.end + 0.3) {
      activeScene = sc;
      break;
    }
  }
  if (!activeScene) return;

  // Render centered caption box at y = 1600
  const boxY = 1620;
  ctx.save();
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.font = '900 56px Rajdhani, "Montserrat", sans-serif';

  // Measure full line width
  const words = activeScene.words;
  let totalW = 0;
  const wordWidths = words.map(item => {
    const w = ctx.measureText(item.w + ' ').width;
    totalW += w;
    return w;
  });

  // Frosted Pill Backdrop Box
  const padX = 40, padY = 24;
  ctx.fillStyle = 'rgba(3, 7, 18, 0.82)';
  ctx.strokeStyle = 'rgba(0, 245, 212, 0.6)';
  ctx.lineWidth = 3.5;
  drawRoundedRect(540 - (totalW + padX) / 2, boxY - 45 - padY / 2, totalW + padX, 90 + padY, 26);
  ctx.fill(); ctx.stroke();

  // Draw word by word with active bounce and glow
  let curX = 540 - totalW / 2;
  for (let i = 0; i < words.length; i++) {
    const item = words[i];
    const nextT = (i < words.length - 1) ? words[i + 1].t : activeScene.end;
    const isActive = (t >= item.t && t < nextT);

    ctx.save();
    if (isActive) {
      // 1.2x Bounce punch
      const wordProgress = Math.min(1.0, (t - item.t) / (nextT - item.t));
      const bounce = 1.0 + 0.22 * Math.sin(wordProgress * Math.PI);
      ctx.translate(curX + wordWidths[i] / 2, boxY);
      ctx.scale(bounce, bounce);
      ctx.translate(-(curX + wordWidths[i] / 2), -boxY);

      // Neon Cyan Glow & Highlight
      ctx.shadowColor = '#00f5d4';
      ctx.shadowBlur = 20;
      ctx.fillStyle = '#00f5d4';
    } else {
      ctx.fillStyle = '#ffffff';
    }

    // Heavy 14px Black Outline for TikTok Readability
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 14;
    ctx.lineJoin = 'round';
    ctx.miterLimit = 2;
    ctx.strokeText(item.w, curX + wordWidths[i] / 2, boxY);
    ctx.fillText(item.w, curX + wordWidths[i] / 2, boxY);
    ctx.restore();

    curX += wordWidths[i];
  }

  ctx.restore();
}

// -------------------------------------------------------------
// Particle & FX Engine (Object Pooling & Recycling)
// -------------------------------------------------------------
function updateAndDrawFX() {
  // Shockwaves
  for (let i = shockwaves.length - 1; i >= 0; i--) {
    const sw = shockwaves[i];
    sw.r += 12;
    sw.alpha = Math.max(0, 1.0 - sw.r / sw.maxR);
    if (sw.alpha <= 0) {
      shockwaves.splice(i, 1);
      continue;
    }
    ctx.save();
    ctx.strokeStyle = sw.color;
    ctx.lineWidth = 6 * sw.alpha;
    ctx.globalAlpha = sw.alpha;
    ctx.beginPath();
    ctx.arc(sw.x, sw.y, sw.r, 0, Math.PI * 2);
    ctx.stroke();
    ctx.restore();
  }

  // Particles
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i];
    p.x += p.vx;
    p.y += p.vy;
    p.vy += 0.35; // gravity
    p.alpha -= p.decay || 0.025;
    if (p.alpha <= 0) {
      particles.splice(i, 1);
      continue;
    }
    ctx.save();
    ctx.globalAlpha = p.alpha;
    ctx.fillStyle = p.color;
    ctx.beginPath();
    ctx.arc(p.x, p.y, p.size, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
  }

  // Gold Coins
  for (let i = coins.length - 1; i >= 0; i--) {
    const c = coins[i];
    c.x += c.vx;
    c.y += c.vy;
    c.vy += 0.45;
    c.rot = (c.rot || 0) + 0.2;
    c.alpha -= 0.015;
    if (c.alpha <= 0 || c.y > H) {
      coins.splice(i, 1);
      continue;
    }
    ctx.save();
    ctx.globalAlpha = c.alpha;
    ctx.fillStyle = '#ffd700';
    ctx.strokeStyle = '#b45309';
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.ellipse(c.x, c.y, 14, 14 * Math.abs(Math.sin(c.rot)), 0, 0, Math.PI * 2);
    ctx.fill(); ctx.stroke();
    ctx.restore();
  }

  // Floating Combat Text
  for (let i = floatingTexts.length - 1; i >= 0; i--) {
    const ft = floatingTexts[i];
    ft.y += ft.vy;
    ft.alpha -= 0.018;
    if (ft.alpha <= 0) {
      floatingTexts.splice(i, 1);
      continue;
    }
    ctx.save();
    ctx.globalAlpha = ft.alpha;
    ctx.textAlign = 'center';
    ctx.font = ft.isLarge ? '900 48px Rajdhani, sans-serif' : 'bold 32px Rajdhani, sans-serif';
    ctx.strokeStyle = '#000000';
    ctx.lineWidth = 10;
    ctx.strokeText(ft.text, ft.x, ft.y);
    ctx.fillStyle = ft.color;
    ctx.fillText(ft.text, ft.x, ft.y);
    ctx.restore();
  }
}

// -------------------------------------------------------------
// MASTER RENDER LOOP (60 FPS)
// -------------------------------------------------------------
function renderFrame(now) {
  const dt = (now - lastFrameTime) / 1000;
  lastFrameTime = now;

  if (isPlaying) {
    currentTime += dt;
    if (currentTime >= DURATION) {
      if (isRecording) {
        finishRecording();
      }
      currentTime = 0;
      resetSceneState();
    }
  }

  // Update background synth audio beat
  updateBgmBeat(currentTime);

  // Check scene voiceover triggers
  const currentSceneIdx = currentTime < 3.5 ? 0 : (currentTime < 7.5 ? 1 : (currentTime < 13.5 ? 2 : 3));
  if (currentSceneIdx !== lastSpokenScene) {
    lastSpokenScene = currentSceneIdx;
    triggerVoiceoverForScene(currentSceneIdx);
  }

  // Render appropriate scene
  if (currentTime < 3.5) {
    drawScene1(currentTime);
  } else if (currentTime < 7.5) {
    drawScene2(currentTime);
  } else if (currentTime < 13.5) {
    drawScene3(currentTime);
  } else {
    drawScene4(currentTime);
  }

  // Render TikTok / Reels timed captions over all scenes
  drawTikTokCaptions(currentTime);

  // Update UI scrubber & time displays
  updateUI();

  requestAnimationFrame(renderFrame);
}

function resetSceneState() {
  sfxTriggeredScene2Snap = false;
  sfxTriggeredScene2Explode = false;
  sfxTriggeredUlti = false;
  sfxTriggeredPerk = false;
  sfxTriggeredAqua = false;
  sfxTriggeredBossAlarm = false;
  sfxTriggeredBossShatter = false;
  lastBeatIdx = -1;
  lastSpokenScene = -1;
  initSimulationEntities();
}

function updateUI() {
  const timeDisplay = document.getElementById('timeDisplay');
  const pctDisplay = document.getElementById('pctDisplay');
  const progressFill = document.getElementById('progressFill');

  const formattedTime = (currentTime < 10 ? '0' : '') + currentTime.toFixed(1) + 's / 18.0s';
  timeDisplay.textContent = formattedTime;
  const pct = Math.min(100, (currentTime / DURATION) * 100);
  pctDisplay.textContent = Math.floor(pct) + '%';
  progressFill.style.width = pct + '%';

  // Highlight active scene button
  const currentScene = currentTime < 3.5 ? 0 : (currentTime < 7.5 ? 1 : (currentTime < 13.5 ? 2 : 3));
  for (let i = 0; i < 4; i++) {
    const btn = document.getElementById('sceneBtn' + i);
    if (i === currentScene) {
      btn.classList.add('ring-2', 'ring-cyan-400', 'bg-slate-800');
    } else {
      btn.classList.remove('ring-2', 'ring-cyan-400', 'bg-slate-800');
    }
  }

  // Export progress update
  if (isRecording) {
    const exportFill = document.getElementById('exportProgressFill');
    exportFill.style.width = pct + '%';
    const exportLabel = document.getElementById('exportLabel');
    exportLabel.textContent = `🔴 Recording... ${Math.floor(pct)}% (${(currentTime).toFixed(1)}s / 18.0s)`;
  }
}

// -------------------------------------------------------------
// Interactive Controls & Scene Seeking
// -------------------------------------------------------------
function togglePlay() {
  initAudio();
  isPlaying = !isPlaying;
  document.getElementById('playIcon').textContent = isPlaying ? '⏸' : '▶';
  document.getElementById('playLabel').textContent = isPlaying ? 'Pause' : 'Play';
}

function restartVideo() {
  initAudio();
  currentTime = 0;
  resetSceneState();
  isPlaying = true;
  document.getElementById('playIcon').textContent = '⏸';
  document.getElementById('playLabel').textContent = 'Pause';
}

function jumpTo(sec) {
  initAudio();
  currentTime = sec;
  resetSceneState();
  lastSpokenScene = -1;
}

function toggleMute() {
  isMuted = !isMuted;
  document.getElementById('muteBtn').textContent = isMuted ? '🔇 Audio OFF' : '🔊 Audio ON';
  if (isMuted && 'speechSynthesis' in window) window.speechSynthesis.cancel();
}

canvas.addEventListener('click', togglePlay);
document.getElementById('timelineBar').addEventListener('click', (e) => {
  const rect = e.currentTarget.getBoundingClientRect();
  const ratio = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
  jumpTo(ratio * DURATION);
});

// -------------------------------------------------------------
// ONE-CLICK 1080x1920 60 FPS WEBM EXPORTER
// Merges canvas.captureStream(60) + audioDest.stream tracks
// -------------------------------------------------------------
let mediaRecorder = null;
let recordedChunks = [];

function exportWebMVideo() {
  if (isRecording) return;
  initAudio();
  isRecording = true;
  recordedChunks = [];

  const exportBtn = document.getElementById('exportBtn');
  const exportLabel = document.getElementById('exportLabel');
  const recIndicator = document.getElementById('recIndicator');
  const progressContainer = document.getElementById('exportProgressBarContainer');

  recIndicator.classList.remove('hidden');
  progressContainer.classList.remove('hidden');
  exportBtn.classList.add('animate-pulse');

  // Merged MediaStream (Video + Mixed Audio)
  const videoStream = canvas.captureStream(60);
  const audioTracks = (audioDest && audioDest.stream) ? audioDest.stream.getAudioTracks() : [];
  const exportStream = new MediaStream([
    ...videoStream.getVideoTracks(),
    ...audioTracks
  ]);

  // Codec Priority: VP9 12 Mbps + Opus
  const mimeType = MediaRecorder.isTypeSupported('video/webm;codecs=vp9,opus')
    ? 'video/webm;codecs=vp9,opus'
    : (MediaRecorder.isTypeSupported('video/webm;codecs=vp9')
      ? 'video/webm;codecs=vp9'
      : 'video/webm');

  mediaRecorder = new MediaRecorder(exportStream, {
    mimeType,
    videoBitsPerSecond: 12000000 // 12 Mbps broadcast quality
  });

  mediaRecorder.ondataavailable = (e) => {
    if (e.data && e.data.size > 0) recordedChunks.push(e.data);
  };

  mediaRecorder.onstop = () => {
    const blob = new Blob(recordedChunks, { type: 'video/webm' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'kirmatas_ad_en.webm';
    document.body.appendChild(a);
    a.click();
    a.remove();

    exportLabel.textContent = '✅ Video Downloaded! Click to Record Again';
    exportBtn.classList.remove('animate-pulse');
    recIndicator.classList.add('hidden');
    progressContainer.classList.add('hidden');
    isRecording = false;
  };

  // Restart from t = 0 and record exactly 18.0s
  restartVideo();
  mediaRecorder.start(250);
}

function finishRecording() {
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
  }
}

// Initial kickoff
initImages();
requestAnimationFrame(renderFrame);

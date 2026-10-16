const fs = require('fs');
const crypto = require('crypto');

function sha256(buf) {
  return crypto.createHash('sha256').update(buf).digest('hex');
}

function entropy(buf) {
  const freqs = new Array(256).fill(0);
  for (let i = 0; i < buf.length; i++) freqs[buf[i]]++;
  let ent = 0;
  for (let i = 0; i < 256; i++) {
    if (freqs[i] > 0) {
      const p = freqs[i] / buf.length;
      ent -= p * Math.log2(p);
    }
  }
  return ent;
}

console.log('=== 1. VERIFYING PNG ASSETS IN docs/ad_assets/ ===');
const pngFiles = [
  'aquarium_view.png',
  'chaos_boss.png',
  'chaos_perks.png',
  'game_canvas_action.png',
  'shop_synergies.png',
  'tournament_league.png'
];

const pngData = {};
pngFiles.forEach(f => {
  const p = 'docs/ad_assets/' + f;
  const b = fs.readFileSync(p);
  const hash = sha256(b);
  const ent = entropy(b);
  const w = b.readUInt32BE(16);
  const h = b.readUInt32BE(20);
  console.log(`${f}: ${w}x${h}, ${b.length} bytes, SHA256: ${hash.substring(0, 16)}..., Entropy: ${ent.toFixed(3)}`);
  pngData[f] = { b, hash, ent, w, h };
});

console.log('\n=== 2. VERIFYING ORIGINAL AUDIO ASSETS IN assets/audio/ ===');
const audioFiles = [
  'cam_kirilma.mp3',
  'glass_shatter.mp3',
  'custom_laser.wav',
  'custom_explosion.wav',
  'custom_bounce.wav',
  'bgm.wav'
];

audioFiles.forEach(f => {
  const p = 'assets/audio/' + f;
  if (fs.existsSync(p)) {
    const b = fs.readFileSync(p);
    console.log(`${f}: ${b.length} bytes, SHA256: ${sha256(b).substring(0, 16)}...`);
  } else {
    console.log(`${f}: NOT FOUND in assets/audio/`);
  }
});

console.log('\n=== 3. VERIFYING BASE64 IN ad_data_tr.js ===');
const vm = require('vm');
const trCtx = { window: {} };
vm.runInContext(fs.readFileSync('docs/ad_assets/ad_data_tr.js', 'utf8'), vm.createContext(trCtx));
const trAssets = trCtx.window.AD_ASSETS;

console.log(`ad_data_tr.js has ${Object.keys(trAssets).length} assets.`);
for (const [k, uri] of Object.entries(trAssets)) {
  const commaIdx = uri.indexOf(',');
  const b64 = uri.substring(commaIdx + 1);
  const buf = Buffer.from(b64, 'base64');
  const h = sha256(buf);
  console.log(`  TR Asset '${k}': ${buf.length} bytes, SHA256: ${h.substring(0, 16)}...`);
}

console.log('\n=== 4. VERIFYING BASE64 IN kirmatas_ad_en.html ===');
const enHtml = fs.readFileSync('docs/kirmatas_ad_en.html', 'utf8');
const enImgMatch = enHtml.match(/const\s+IMAGE_ASSETS\s*=\s*\{([\s\S]*?)\};/);
const enAudMatch = enHtml.match(/const\s+AUDIO_ASSETS\s*=\s*\{([\s\S]*?)\};/);

function parseJsObject(str) {
  const obj = {};
  const re = /'([^']+)'\s*:\s*'([^']+)'/g;
  let m;
  while ((m = re.exec(str)) !== null) {
    obj[m[1]] = m[2];
  }
  return obj;
}

const enImages = parseJsObject(enImgMatch[1]);
const enAudios = parseJsObject(enAudMatch[1]);
console.log(`kirmatas_ad_en.html has ${Object.keys(enImages).length} images, ${Object.keys(enAudios).length} audios.`);

for (const [k, uri] of Object.entries(enImages)) {
  const b64 = uri.substring(uri.indexOf(',') + 1);
  const buf = Buffer.from(b64, 'base64');
  console.log(`  EN Image '${k}': ${buf.length} bytes, SHA256: ${sha256(buf).substring(0, 16)}...`);
}

for (const [k, uri] of Object.entries(enAudios)) {
  const b64 = uri.substring(uri.indexOf(',') + 1);
  const buf = Buffer.from(b64, 'base64');
  console.log(`  EN Audio '${k}': ${buf.length} bytes, SHA256: ${sha256(buf).substring(0, 16)}...`);
}

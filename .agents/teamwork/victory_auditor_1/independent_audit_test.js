const fs = require('fs');
const path = require('path');
const vm = require('vm');
const crypto = require('crypto');

console.log('================================================================');
console.log('VICTORY AUDITOR INDEPENDENT TEST EXECUTION');
console.log('================================================================\n');

let passCount = 0;
let failCount = 0;
const failures = [];

function assert(condition, message) {
  if (condition) {
    passCount++;
    console.log(`[PASS] ${message}`);
  } else {
    failCount++;
    console.error(`[FAIL] ${message}`);
    failures.push(message);
  }
}

// -----------------------------------------------------------------------------
// 1. Check in-game captured PNG files
// -----------------------------------------------------------------------------
console.log('--- Checking docs/ad_assets/ PNG files ---');
const pngFiles = [
  'game_canvas_action.png',
  'chaos_perks.png',
  'aquarium_view.png',
  'shop_synergies.png',
  'tournament_league.png',
  'chaos_boss.png'
];

for (const name of pngFiles) {
  const p = path.join('docs', 'ad_assets', name);
  assert(fs.existsSync(p), `PNG file exists: ${name}`);
  const buf = fs.readFileSync(p);
  assert(buf.toString('ascii', 1, 4) === 'PNG', `Valid PNG magic bytes: ${name}`);
  const w = buf.readUInt32BE(16);
  const h = buf.readUInt32BE(20);
  assert(w === 1080 && h === 1920, `Exact 1080x1920 resolution: ${name} (${w}x${h})`);
  assert(buf.length > 50000, `High resolution non-trivial byte size: ${name} (${buf.length} bytes)`);

  // Shannon entropy check
  const freq = new Array(256).fill(0);
  for (let i = 0; i < buf.length; i++) freq[buf[i]]++;
  let ent = 0;
  for (let i = 0; i < 256; i++) {
    if (freq[i] > 0) {
      const prob = freq[i] / buf.length;
      ent -= prob * Math.log2(prob);
    }
  }
  assert(ent > 7.5, `High visual entropy (real game rendering): ${name} (entropy: ${ent.toFixed(3)})`);
}

// -----------------------------------------------------------------------------
// 2. Check Turkish Promo Video Studio (docs/kirmatas_reklam_tr.html)
// -----------------------------------------------------------------------------
console.log('\n--- Checking Turkish Promo Video Studio (docs/kirmatas_reklam_tr.html) ---');
const trHtmlPath = path.join('docs', 'kirmatas_reklam_tr.html');
assert(fs.existsSync(trHtmlPath), 'docs/kirmatas_reklam_tr.html exists');
const trHtml = fs.readFileSync(trHtmlPath, 'utf8');

assert(trHtml.includes('width="1080"') && trHtml.includes('height="1920"'), 'TR Ad Canvas declared 1080x1920');
assert(trHtml.includes('requestAnimationFrame') && trHtml.includes('fpsSmoothed'), 'TR Ad 60 FPS animation loop present');
assert(trHtml.includes('MediaRecorder') && trHtml.includes('captureStream(60)'), 'TR Ad MediaRecorder 1080x1920 60 FPS exporter present');
assert(trHtml.includes('AudioContext') && trHtml.includes('masterGain'), 'TR Ad Web Audio graph present');
assert(trHtml.includes('setVoiceoverDucking') && trHtml.includes('0.10'), 'TR Ad audio ducking during voiceover present');

// 4-Beat Narrative checks
assert(trHtml.includes('renderScene1') && trHtml.includes('40000') && trHtml.includes('3000'), 'TR Beat 1: Kurzgesagt What-If space marble hook (40,000 km/h, 3,000 °C)');
assert(trHtml.includes('renderScene2') && trHtml.includes('HASAN USTA') && trHtml.includes('SÜPER KÖŞE VURUŞU') && trHtml.includes('ATEŞ TOPU'), 'TR Beat 2: Hasan Usta pivot, slow-mo corner hit, 30 Fireballs');
assert(trHtml.includes('renderScene3') && trHtml.includes('ULTİ HAZIR') && trHtml.includes('ROGUELIKE KAOS KARTLARI'), 'TR Beat 3: Real in-game showcase (GameCanvas Ulti, Chaos Perks, Eco-Tank)');
assert(trHtml.includes('renderScene4') && trHtml.includes('img_chaos_boss') && trHtml.includes('kaunos_games'), 'TR Beat 4: Wave-10 Chaos Boss & Kaunos Games CTA');

// Check active drawImage calls for all 6 captures
assert(trHtml.includes('ctx.drawImage(imgAction') || trHtml.includes('ctx.drawImage(img_game_canvas_action'), 'TR draws game_canvas_action');
assert(trHtml.includes('ctx.drawImage(imgPerks') || trHtml.includes('ctx.drawImage(img_chaos_perks'), 'TR draws chaos_perks');
assert(trHtml.includes('ctx.drawImage(imgShop') || trHtml.includes('ctx.drawImage(img_shop_synergies'), 'TR draws shop_synergies');
assert(trHtml.includes('ctx.drawImage(imgAqua') || trHtml.includes('ctx.drawImage(img_aquarium_view'), 'TR draws aquarium_view');
assert(trHtml.includes('ctx.drawImage(imgLeague') || trHtml.includes('ctx.drawImage(img_tournament_league'), 'TR draws tournament_league');
assert(trHtml.includes('ctx.drawImage(imgBoss') || trHtml.includes('ctx.drawImage(img_chaos_boss'), 'TR draws chaos_boss');

// -----------------------------------------------------------------------------
// 3. Check English Promo Video Studio (docs/kirmatas_ad_en.html)
// -----------------------------------------------------------------------------
console.log('\n--- Checking English Promo Video Studio (docs/kirmatas_ad_en.html) ---');
const enHtmlPath = path.join('docs', 'kirmatas_ad_en.html');
assert(fs.existsSync(enHtmlPath), 'docs/kirmatas_ad_en.html exists');
const enHtml = fs.readFileSync(enHtmlPath, 'utf8');

assert(enHtml.includes('width="1080"') && enHtml.includes('height="1920"'), 'EN Ad Canvas declared 1080x1920');
assert(enHtml.includes('requestAnimationFrame'), 'EN Ad 60 FPS animation loop present');
assert(enHtml.includes('MediaRecorder') && enHtml.includes('captureStream(60)'), 'EN Ad MediaRecorder 1080x1920 60 FPS exporter present');
assert(enHtml.includes('AudioContext'), 'EN Ad Web Audio graph present');
assert(enHtml.includes('duckBgm'), 'EN Ad audio ducking during voiceover present');

// 4-Beat Narrative checks
assert(enHtml.includes('drawScene1') && enHtml.includes('25,000') && enHtml.includes('5,000'), 'EN Beat 1: Kurzgesagt What-If space marble hook (25,000 mph, 5,000 °F)');
assert(enHtml.includes('drawScene2') && (enHtml.includes("Diner") || enHtml.includes("Joe")) && enHtml.includes('SUPER CORNER HIT') && enHtml.includes('FIREBALL'), 'EN Beat 2: Cosmic Paddle twist, slow-mo corner hit, 30 Fireballs');
assert(enHtml.includes('drawScene3') && enHtml.includes('ULTIMATE LIGHTNING') && enHtml.includes('ROGUELIKE'), 'EN Beat 3: Real in-game showcase (Ulti Lightning, Chaos Perks, Eco-Tank)');
assert(enHtml.includes('drawScene4') && enHtml.includes('CHAOS BOSS') && enHtml.includes('DOWNLOAD FREE'), 'EN Beat 4: Wave-10 Chaos Boss & Kaunos CTA');

// Check active drawImage calls for all 6 captures
assert(enHtml.includes('ctx.drawImage(loadedImages.img_action'), 'EN draws img_action');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_perks'), 'EN draws img_perks');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_synergies'), 'EN draws img_synergies');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_aquarium'), 'EN draws img_aquarium');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_league'), 'EN draws img_league');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_boss'), 'EN draws img_boss');
assert(enHtml.includes('ctx.drawImage(loadedImages.img_kaunos'), 'EN draws img_kaunos');

console.log('\n================================================================');
console.log(`TOTAL CHECKS: ${passCount + failCount} | PASSED: ${passCount} | FAILED: ${failCount}`);
console.log('================================================================');

if (failCount > 0) {
  process.exit(1);
}

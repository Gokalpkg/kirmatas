const fs = require('fs');
const crypto = require('crypto');

const enHtml = fs.readFileSync('docs/kirmatas_ad_en.html', 'utf8');
const trData = fs.readFileSync('docs/ad_assets/ad_data_tr.js', 'utf8');

const map = {
  'action': { en: 'img_action', tr: 'game_canvas_action', file: 'docs/ad_assets/game_canvas_action.png' },
  'perks': { en: 'img_perks', tr: 'chaos_perks', file: 'docs/ad_assets/chaos_perks.png' },
  'synergies': { en: 'img_synergies', tr: 'shop_synergies', file: 'docs/ad_assets/shop_synergies.png' },
  'aquarium': { en: 'img_aquarium', tr: 'aquarium_view', file: 'docs/ad_assets/aquarium_view.png' },
  'league': { en: 'img_league', tr: 'tournament_league', file: 'docs/ad_assets/tournament_league.png' },
  'boss': { en: 'img_boss', tr: 'chaos_boss', file: 'docs/ad_assets/chaos_boss.png' },
  'kaunos': { en: 'img_kaunos', tr: 'kaunos_games', file: 'assets/images/kaunos_games.png' }
};

console.log('=== Image Asset Integrity Check ===');
for (let id in map) {
  const item = map[id];
  const fileBuf = fs.readFileSync(item.file);
  const fileB64 = fileBuf.toString('base64');
  const fileHash = crypto.createHash('sha256').update(fileBuf).digest('hex');

  const enHasIt = enHtml.includes(fileB64.substring(0, 100));
  const trHasIt = trData.includes(fileB64.substring(0, 100));

  console.log(id.padEnd(10), '| File size:', fileBuf.length, '| SHA256:', fileHash.substring(0, 16), '| In EN?', enHasIt, '| In TR?', trHasIt);
}

const audioMap = {
  'cam_kirilma': { file: 'assets/audio/cam_kirilma.mp3' },
  'glass_shatter': { file: 'assets/audio/glass_shatter.mp3' },
  'custom_laser': { file: 'assets/audio/custom_laser.wav' },
  'custom_explosion': { file: 'assets/audio/custom_explosion.wav' },
  'custom_bounce': { file: 'assets/audio/custom_bounce.wav' },
  'voice_tr_scene1': { file: 'docs/ad_assets/voice_tr_scene1.wav' },
  'voice_tr_scene2': { file: 'docs/ad_assets/voice_tr_scene2.wav' },
  'voice_tr_scene3': { file: 'docs/ad_assets/voice_tr_scene3.wav' },
  'voice_tr_scene4': { file: 'docs/ad_assets/voice_tr_scene4.wav' },
  'voice_en_scene1': { file: 'docs/ad_assets/voice_en_scene1.wav' },
  'voice_en_scene2': { file: 'docs/ad_assets/voice_en_scene2.wav' },
  'voice_en_scene3': { file: 'docs/ad_assets/voice_en_scene3.wav' },
  'voice_en_scene4': { file: 'docs/ad_assets/voice_en_scene4.wav' }
};

console.log('\n=== Audio Asset Integrity Check ===');
for (let id in audioMap) {
  const item = audioMap[id];
  const fileBuf = fs.readFileSync(item.file);
  const fileB64 = fileBuf.toString('base64');
  const fileHash = crypto.createHash('sha256').update(fileBuf).digest('hex');

  const inEN = enHtml.includes(fileB64.substring(0, 80));
  const inTR = trData.includes(fileB64.substring(0, 80));
  console.log(id.padEnd(18), '| Size:', fileBuf.length, '| SHA256:', fileHash.substring(0, 16), '| In EN?', inEN, '| In TR?', inTR);
}

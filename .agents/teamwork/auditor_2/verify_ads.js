const fs = require('fs');

const tr = fs.readFileSync('docs/kirmatas_reklam_tr.html', 'utf8');
const en = fs.readFileSync('docs/kirmatas_ad_en.html', 'utf8');

function checkFeatures(code, label) {
  console.log('=== Checking ' + label + ' ===');
  const checks = [
    ['Canvas 1080x1920', /(?:1080[\s\S]{1,50}1920|width\s*=\s*['"]?1080['"]?[\s\S]{1,50}height\s*=\s*['"]?1920)/],
    ['Scene 1 function/render', /(?:renderScene1|drawScene1)/],
    ['Scene 2 function/render', /(?:renderScene2|drawScene2)/],
    ['Scene 3 function/render', /(?:renderScene3|drawScene3)/],
    ['Scene 4 function/render', /(?:renderScene4|drawScene4)/],
    ['Speedometer 40,000 km/h or 25,000 mph', /(?:40,?000|25,?000)/],
    ['Thermometer 3,000 C or 5,000 F', /(?:3,?000|5,?000)/],
    ['Super Corner Hit', /(?:SÜPER KÖŞE VURUŞU|SUPER CORNER HIT)/],
    ['Hasan Usta or Diner pivot', /(?:Hasan Usta|Kumru|Diner|Joe)/i],
    ['30 Fireballs or particles', /(?:30|fireballs|fireball)/i],
    ['drawImage for game_canvas_action', /(?:game_canvas_action|img_action)/],
    ['drawImage for chaos_perks', /(?:chaos_perks|img_perks)/],
    ['drawImage for aquarium_view', /(?:aquarium_view|img_aquarium)/],
    ['drawImage for shop_synergies', /(?:shop_synergies|img_synergies)/],
    ['drawImage for tournament_league', /(?:tournament_league|img_league)/],
    ['drawImage for chaos_boss', /(?:chaos_boss|img_boss)/],
    ['drawImage for kaunos_games', /(?:kaunos_games|img_kaunos)/],
    ['Web Audio AudioContext', /(?:AudioContext|webkitAudioContext)/],
    ['MediaRecorder webm export', /(?:MediaRecorder|video\/webm)/],
    ['Captions system', /(?:captions|renderCaptions|subtitles)/i]
  ];

  let passed = 0;
  checks.forEach(([name, regex]) => {
    const match = regex.test(code);
    console.log(name + ': ' + (match ? 'PASS' : 'FAIL'));
    if (match) passed++;
  });
  console.log(`Summary: ${passed} / ${checks.length} passed.`);
}

checkFeatures(tr, 'TR Ad (kirmatas_reklam_tr.html)');
checkFeatures(en, 'EN Ad (kirmatas_ad_en.html)');

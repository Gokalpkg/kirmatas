const fs = require('fs');

function inspectStudio(filePath, name) {
  console.log('=== Inspecting ' + name + ' (' + filePath + ') ===');
  const content = fs.readFileSync(filePath, 'utf8');
  console.log('Size:', content.length, 'bytes');

  const checks = [
    ['Canvas element 1080x1920', /<canvas[^>]*width=["']1080["'][^>]*height=["']1920["']/i],
    ['Duration is 18.0s', /const\s+DURATION\s*=\s*18/i],
    ['Scene 1 function / logic', /scene1|drawScene1|renderScene1/i],
    ['Scene 2 function / logic', /scene2|drawScene2|renderScene2/i],
    ['Scene 3 function / logic', /scene3|drawScene3|renderScene3/i],
    ['Scene 4 function / logic', /scene4|drawScene4|renderScene4/i],
    ['Speedometer (40,000 km/h or 25,000 mph)', /(40[.,]?000\s*km\/h|25[.,]?000\s*mph)/i],
    ['Thermometer (3,000 C or 5,000 F)', /(3[.,]?000\s*°?C|5[.,]?000\s*°?F)/i],
    ['Cosmic Paddle / Super Corner Hit', /(SÜPER KÖŞE VURUŞU|SUPER CORNER HIT)/i],
    ['30 Fireballs', /(30.*fireball|30.*ateş|30x\s*ATEŞ)/i],
    ['Wave 10 Chaos Boss', /(boss|wave.*10|chaos_boss)/i],
    ['Kaunos CTA end card', /(kaunos_games|HEMEN ÜCRETSİZ İNDİR|Download Kirmatas free)/i],
    ['Web Audio API context', /(AudioContext|webkitAudioContext)/i],
    ['Audio ducking', /(duck|duckBgm|gainNode)/i],
    ['MediaRecorder WebM export', /MediaRecorder|captureStream|webm/i],
    ['Subtitles / TikTok captions', /(caption|subtitle|wordHighlight|drawCaptions)/i],
  ];

  let passed = 0;
  for (const [desc, re] of checks) {
    const match = re.test(content);
    console.log('  [' + (match ? 'PASS' : 'FAIL') + '] ' + desc);
    if (match) passed++;
  }
  console.log('Passed ' + passed + ' / ' + checks.length + ' structural checks.');
}

inspectStudio('docs/kirmatas_reklam_tr.html', 'Turkish Studio');
console.log('');
inspectStudio('docs/kirmatas_ad_en.html', 'English Studio');

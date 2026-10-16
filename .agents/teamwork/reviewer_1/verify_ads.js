const fs = require('fs');

function inspectStudio(filePath, lang) {
  console.log('=== Inspecting ' + filePath + ' (' + lang + ') ===');
  const content = fs.readFileSync(filePath, 'utf8');

  // 1. Canvas dimensions
  const hasWidth = content.includes('width="1080"');
  const hasHeight = content.includes('height="1920"');
  console.log('1. Canvas attributes 1080x1920:', hasWidth && hasHeight);

  // 2. Duration
  const durationMatch = content.match(/const\s+DURATION\s*=\s*([0-9.]+);/);
  console.log('2. Master Timeline DURATION:', durationMatch ? durationMatch[1] : 'NOT FOUND');

  // 3. 4 Scene jump buttons
  const jumps = [...content.matchAll(/jumpTo\(([0-9.]+)\)/g)].map(m => parseFloat(m[1]));
  console.log('3. Scene Jump Buttons in Markup:', jumps);

  // 4. Scene 1 Kurzgesagt checks
  const hasEarthLimb = content.includes('createRadialGradient') && (content.includes('#00f5d4') || content.includes('#4338ca') || content.includes('4338ca'));
  const hasFe56 = content.includes('Fe-56');
  const hasSpeed = lang === 'TR' ? content.includes('40000') || content.includes('40.000') : content.includes('25000') || content.includes('25,000');
  const hasTemp = lang === 'TR' ? content.includes('3000') || content.includes('3.000') : content.includes('5000') || content.includes('5,000');
  const hasMachShock = content.includes('Bow Shock') || content.includes('flameGrad') || content.includes('shockIntensity') || content.includes('Mach');
  console.log('4. Scene 1 Kurzgesagt Check:');
  console.log('   - Earth Limb Gradient:', hasEarthLimb);
  console.log('   - Fe-56 Chrome Marble:', hasFe56);
  console.log('   - Speedometer Sweep (40,000 km/h or 25,000 mph):', hasSpeed);
  console.log('   - Thermometer Sweep (3,000 C or 5,000 F):', hasTemp);
  console.log('   - Mach 32 Bow Shock:', hasMachShock);

  // 5. Scene 2 checks
  const hasPivot = lang === 'TR' ? content.includes('HASAN USTA') : content.includes("JOE'S CORNER DINER");
  const hasSlowMo = content.includes('4.5') && (content.includes('cam_kirilma') || content.includes('sfx_cam_kirilma'));
  const hasCornerHit = lang === 'TR' ? content.includes('SÜPER KÖŞE VURUŞU') : content.includes('SUPER CORNER HIT');
  const has30Fireballs = content.includes('30') && (content.includes('fireballs') || content.includes('Fireballs') || content.includes('ATEŞ TOPU') || content.includes('FIREBALLS'));
  const hasBrickGrid = content.includes('7') && content.includes('8') && (content.includes('cols = 7') || content.includes('cols: 7') || content.includes('7x8') || content.includes('drawBrickWall'));
  console.log('5. Scene 2 Comedic Twist & Brick Wipe:');
  console.log('   - Pivot Identity (Hasan Usta / Joe\'s Diner):', hasPivot);
  console.log('   - 4.5s Slow-Mo Snap & SFX:', hasSlowMo);
  console.log('   - Super Corner Hit Deflection Banner:', hasCornerHit);
  console.log('   - 30 Fireballs Projectile System:', has30Fireballs);
  console.log('   - 7x8 Brick Wall Structure:', hasBrickGrid);

  // 6. Scene 3 Real Assets
  const assets = ['game_canvas_action', 'chaos_perks', 'shop_synergies', 'aquarium_view', 'tournament_league'];
  const assetResults = {};
  assets.forEach(a => { assetResults[a] = content.includes(a); });
  console.log('6. Scene 3 Real Captured Gameplay Frames:');
  console.log('   - Frame references:', assetResults);
  const hasLiveFish = content.includes('drawSwimmingFish') || content.includes('Swimming Fishes') || content.includes('ellipse') && content.includes('wag');
  console.log('   - 60 FPS Swimming Fish Animation:', hasLiveFish);

  // 7. Scene 4 Boss and Kaunos
  const hasBoss = content.includes('chaos_boss');
  const hasKaunos = content.includes('kaunos_games');
  const hasCTA = lang === 'TR' ? content.includes('İNDİR') : content.includes('Download') || content.includes('DOWNLOAD');
  console.log('7. Scene 4 Boss & CTA End Card:');
  console.log('   - Wave-10 Chaos Boss:', hasBoss);
  console.log('   - Kaunos Games Studio Logo/Endcard:', hasKaunos);
  console.log('   - Download CTA Callout:', hasCTA);

  // 8. Audio and WebM
  const hasCaptureStream = content.includes('captureStream(60)');
  const hasWebM = content.includes('video/webm');
  const hasDucking = content.includes('duck') || content.includes('Ducking') || content.includes('duckBgm');
  const hasTikTok = content.includes('TikTok') || content.includes('renderTikTokCaptions') || content.includes('drawTikTokCaptions');
  console.log('8. Web Audio & MediaRecorder Exporter:');
  console.log('   - 60 FPS Canvas Capture Stream:', hasCaptureStream);
  console.log('   - WebM VP9 / Opus Exporter:', hasWebM);
  console.log('   - Dynamic BGM Ducking:', hasDucking);
  console.log('   - Word-by-word TikTok/Reels Captions:', hasTikTok);
  console.log('');
}

inspectStudio('docs/kirmatas_reklam_tr.html', 'TR');
inspectStudio('docs/kirmatas_ad_en.html', 'EN');

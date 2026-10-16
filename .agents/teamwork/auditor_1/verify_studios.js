const fs = require('fs');
const vm = require('vm');

function verifyStudioFile(filePath, lang) {
  console.log(`\n============================================================`);
  console.log(` AUDITING DELIVERABLE: ${filePath} (${lang.toUpperCase()})`);
  console.log(`============================================================`);

  if (!fs.existsSync(filePath)) {
    console.error(`FATAL: File does not exist: ${filePath}`);
    return false;
  }

  const html = fs.readFileSync(filePath, 'utf8');
  console.log(`File size: ${html.length.toLocaleString()} bytes`);

  // 1. Extract script and evaluate syntax
  const scriptRegex = /<script(?:\s+src="([^"]*)")?>([\s\S]*?)<\/script>/gi;
  let match;
  let scriptCount = 0;
  let inlineJs = '';
  const externalScripts = [];

  while ((match = scriptRegex.exec(html)) !== null) {
    scriptCount++;
    if (match[1]) {
      externalScripts.push(match[1]);
    } else {
      inlineJs += '\n' + match[2];
    }
  }

  console.log(`Found ${scriptCount} script tags (${externalScripts.length} external, ${inlineJs.length.toLocaleString()} inline JS chars).`);
  if (externalScripts.length > 0) {
    console.log(`External scripts referenced:`, externalScripts);
    for (const ext of externalScripts) {
      const extPath = filePath.replace(/[^\/\\]+$/, ext);
      if (fs.existsSync(extPath)) {
        console.log(`  -> Verified external script exists: ${extPath} (${fs.statSync(extPath).size} bytes)`);
      } else {
        console.error(`  -> ERROR: Referenced external script does not exist: ${extPath}`);
      }
    }
  }

  // Check JavaScript syntax
  try {
    new vm.Script(inlineJs, { filename: filePath });
    console.log(`[PASS] JavaScript syntax parsed cleanly with 0 syntax errors.`);
  } catch (e) {
    console.error(`[FAIL] JavaScript syntax error:`, e.message);
    return false;
  }

  // 2. Feature / Narrative requirement audits
  const auditPoints = [
    {
      name: 'Canvas 1080x1920',
      test: () => /<canvas[^>]*width=["']1080["'][^>]*height=["']1920["']/i.test(html),
      details: 'HTML5 Canvas must be declared with width 1080 and height 1920'
    },
    {
      name: 'Total Duration 18.0s',
      test: () => /const\s+DURATION\s*=\s*18(\.0)?;/i.test(inlineJs),
      details: 'Master timeline duration must be exactly 18.0s'
    },
    {
      name: 'Scene 1: Space Hook (0.0s – 3.5s)',
      test: () => {
        const hasTime = /(0(\.0)?\s*<=?\s*t|<=\s*3\.5|currentTime\s*<\s*3\.5)/i.test(inlineJs);
        const hasSpeed = /(40[.,]?000\s*km\/h|25[.,]?000\s*mph)/i.test(inlineJs);
        const hasTemp = /(3[.,]?000\s*°?C|5[.,]?000\s*°?F)/i.test(inlineJs);
        const hasMarble = /(marble|fe-56|iron|bilye)/i.test(inlineJs);
        return hasTime && hasSpeed && hasTemp && hasMarble;
      },
      details: 'Fe-56 iron marble, atmospheric entry, speedometer (40,000 km/h or 25,000 mph), heat gauge (3,000 C or 5,000 F)'
    },
    {
      name: 'Scene 2: Hasan Usta / Metropolitan Pivot (3.5s – 7.5s)',
      test: () => {
        const hasTime = /(3\.5\s*<=?\s*t|<=\s*7\.5|currentTime\s*<\s*7\.5)/i.test(inlineJs);
        const hasHit = /(SÜPER KÖŞE VURUŞU|SUPER CORNER HIT)/i.test(inlineJs);
        const hasFireballs = /(30.*fireball|30.*ateş|30x\s*ATEŞ)/i.test(inlineJs);
        const hasPaddle = /(paddle|Cosmic|Legendary)/i.test(inlineJs);
        return hasTime && hasHit && hasFireballs && hasPaddle;
      },
      details: 'Matrix slow-mo at 4.5s, Cosmic Paddle deflection, corner hit callout, 30 fireballs wall wipe'
    },
    {
      name: 'Scene 3: Real In-Game Footage Showcase (7.5s – 13.5s)',
      test: () => {
        const hasTime = /(7\.5\s*<=?\s*t|<=\s*13\.5|currentTime\s*<\s*13\.5)/i.test(inlineJs);
        const hasAction = /(img_action|game_canvas_action)/i.test(inlineJs);
        const hasPerks = /(img_perks|chaos_perks)/i.test(inlineJs);
        const hasAquarium = /(img_aquarium|aquarium_view)/i.test(inlineJs);
        const hasSynergies = /(img_synergies|shop_synergies)/i.test(inlineJs);
        const hasLeague = /(img_league|tournament_league)/i.test(inlineJs);
        return hasTime && hasAction && hasPerks && hasAquarium && hasSynergies && hasLeague;
      },
      details: 'Transitions through all captured gameplay frames (action, perks, synergies, aquarium, league) with live particle overlays'
    },
    {
      name: 'Scene 4: Wave-10 Chaos Boss & Kaunos CTA (13.5s – 18.0s)',
      test: () => {
        const hasTime = /(13\.5\s*<=?\s*t|currentTime\s*<=\s*18\.0)/i.test(inlineJs);
        const hasBoss = /(img_boss|chaos_boss|Wave 10|Kaos Boss)/i.test(inlineJs);
        const hasCta = /(kaunos_games|img_kaunos|cta|HEMEN ÜCRETSİZ İNDİR|Download Kirmatas free)/i.test(inlineJs);
        return hasTime && hasBoss && hasCta;
      },
      details: 'Wave-10 Chaos Boss encounter, boss warning alarm, armor shatter, Kaunos Games end card and store CTA'
    },
    {
      name: 'Web Audio API & Dynamic Ducking',
      test: () => {
        const hasCtx = /(AudioContext|webkitAudioContext)/i.test(inlineJs);
        const hasDucking = /(duck|duckBgm|gain\.setValueAtTime|gain\.linearRampToValueAtTime)/i.test(inlineJs);
        const hasSFX = /(cam_kirilma|glass_shatter|custom_laser|custom_explosion|custom_bounce)/i.test(inlineJs);
        return hasCtx && hasDucking && hasSFX;
      },
      details: 'Audio graph with master/sfx/bgm/voice gains, dynamic ducking during voiceover, and authentic SFX buffers'
    },
    {
      name: 'Dynamic Word-Highlight TikTok/Reels Subtitles',
      test: () => {
        const hasCaptions = /(caption|subtitle|wordHighlight|drawCaptions|drawTikTokCaptions)/i.test(inlineJs);
        const hasWords = /(words|highlight|activeWord|bounce)/i.test(inlineJs);
        return hasCaptions && hasWords;
      },
      details: 'Word-by-word timed animated subtitles with active highlight and bounce effect'
    },
    {
      name: 'Interactive Studio Controls & Scrubber',
      test: () => {
        const hasScrub = /(handleScrub|scrubber|timeline|range)/i.test(html);
        const hasPlayPause = /(togglePlay|btn-play|playPause)/i.test(html);
        const hasJump = /(jumpTo|jumpScene|0\.0s|3\.5s|7\.5s|13\.5s)/i.test(html);
        return hasScrub && hasPlayPause && hasJump;
      },
      details: 'Interactive playback scrubber, play/pause toggle, and 4 scene jump buttons'
    },
    {
      name: '1080x1920 60 FPS WebM HD Exporter',
      test: () => {
        const hasCaptureStream = /captureStream\s*\(\s*60\s*\)/i.test(inlineJs);
        const hasMediaRecorder = /new\s+MediaRecorder/i.test(inlineJs);
        const hasAudioDest = /(createMediaStreamDestination|audioDest\.stream)/i.test(inlineJs);
        const hasDownload = /(download|createObjectURL|exportWebMVideo)/i.test(inlineJs);
        return hasCaptureStream && hasMediaRecorder && hasAudioDest && hasDownload;
      },
      details: 'Canvas 60fps stream + Audio destination stream mixed into MediaRecorder with automatic WebM file download'
    }
  ];

  let passedAll = true;
  for (const ap of auditPoints) {
    const res = ap.test();
    console.log(`[${res ? 'PASS' : 'FAIL'}] ${ap.name}`);
    if (!res) {
      console.error(`       Failure reason: Failed condition for "${ap.details}"`);
      passedAll = false;
    }
  }

  return passedAll;
}

const trOk = verifyStudioFile('docs/kirmatas_reklam_tr.html', 'Turkish');
const enOk = verifyStudioFile('docs/kirmatas_ad_en.html', 'English');

console.log(`\n============================================================`);
console.log(`FINAL DELIVERABLE VERIFICATION RESULT: ${trOk && enOk ? 'ALL PASS' : 'FAILURES DETECTED'}`);
console.log(`============================================================\n`);

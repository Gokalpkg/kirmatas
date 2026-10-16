const fs = require('fs');

const tr = fs.readFileSync('docs/kirmatas_reklam_tr.html', 'utf8');
const en = fs.readFileSync('docs/kirmatas_ad_en.html', 'utf8');

function inspectDetails(code, label) {
  console.log(`\n=================== DEEP INSPECTION: ${label} ===================`);
  
  // 1. Scene lengths and function signatures
  const sceneFuncs = code.match(/function\s+(?:render|draw)Scene\d[^\{]+\{/g) || code.match(/(?:render|draw)Scene\d\s*=\s*function[^\{]+\{/g);
  console.log('Scene functions found:', sceneFuncs);

  // 2. Look for drawImage calls
  const drawImageMatches = code.match(/ctx\.drawImage\([^\)]+\)/g);
  console.log(`drawImage calls count: ${drawImageMatches ? drawImageMatches.length : 0}`);
  if (drawImageMatches) {
    drawImageMatches.forEach(m => console.log('  -> ' + m));
  }

  // 3. Audio Graph
  const audioContext = code.match(/new\s+(?:window\.)?(?:AudioContext|webkitAudioContext)\(\)/g);
  const gainNodes = code.match(/createGain\(\)/g);
  const bufferSources = code.match(/createBufferSource\(\)/g);
  console.log(`Audio nodes: AudioContext: ${audioContext ? audioContext.length : 0}, createGain: ${gainNodes ? gainNodes.length : 0}, createBufferSource: ${bufferSources ? bufferSources.length : 0}`);

  // 4. Particle systems
  const particlePush = code.match(/particles\.push\([^\)]+\)/g) || code.match(/createParticles|spawnParticles|particles/g);
  console.log(`Particle mentions: ${particlePush ? particlePush.length : 0}`);

  // 5. MediaRecorder pipeline
  const mediaRecorder = code.match(/new\s+MediaRecorder\([^\)]+\)/g);
  const captureStream = code.match(/captureStream\([^\)]*\)/g);
  const downloadLink = code.match(/download\s*=|createElement\(['"]a['"]\)/g);
  console.log(`MediaRecorder: ${mediaRecorder ? mediaRecorder.length : 0}, captureStream: ${captureStream ? captureStream.length : 0}, download elements: ${downloadLink ? downloadLink.length : 0}`);

  // 6. Check for dummy returns or facades (e.g., return; at top of render)
  const emptyScene1 = /(?:render|draw)Scene1[^{]*\{\s*(?:return|(?:\/\/[^\n]*\n\s*)*return)/.test(code);
  const emptyScene2 = /(?:render|draw)Scene2[^{]*\{\s*(?:return|(?:\/\/[^\n]*\n\s*)*return)/.test(code);
  const emptyScene3 = /(?:render|draw)Scene3[^{]*\{\s*(?:return|(?:\/\/[^\n]*\n\s*)*return)/.test(code);
  const emptyScene4 = /(?:render|draw)Scene4[^{]*\{\s*(?:return|(?:\/\/[^\n]*\n\s*)*return)/.test(code);
  console.log(`Empty scene facade check: Scene 1 empty: ${emptyScene1}, Scene 2 empty: ${emptyScene2}, Scene 3 empty: ${emptyScene3}, Scene 4 empty: ${emptyScene4}`);
}

inspectDetails(tr, 'TR Ad');
inspectDetails(en, 'EN Ad');

const fs = require('fs');

function analyzeCode(filePath, name) {
  console.log('=== Deep Analysis of ' + name + ' (' + filePath + ') ===');
  const content = fs.readFileSync(filePath, 'utf8');

  // Check for TODOs, FIXMEs, or stubbed functions
  const todos = content.match(/\/\/\s*(TODO|FIXME|stub|mock|placeholder)/gi);
  console.log('TODO/stub comments:', todos ? todos.length : 0);

  // Check for empty functions
  const emptyFuncs = content.match(/function\s+\w+\s*\([^)]*\)\s*\{\s*\}/g);
  console.log('Empty functions:', emptyFuncs ? emptyFuncs.length : 0);

  // Check scene functions line lengths
  const sceneMatches = [
    ['Scene 1', /function\s+(render|draw)Scene1[\s\S]*?(?=function\s+(render|draw)Scene2|\n\s*function\s+[a-zA-Z0-9_]+\s*\()/],
    ['Scene 2', /function\s+(render|draw)Scene2[\s\S]*?(?=function\s+(render|draw)Scene3|\n\s*function\s+[a-zA-Z0-9_]+\s*\()/],
    ['Scene 3', /function\s+(render|draw)Scene3[\s\S]*?(?=function\s+(render|draw)Scene4|\n\s*function\s+[a-zA-Z0-9_]+\s*\()/],
    ['Scene 4', /function\s+(render|draw)Scene4[\s\S]*?(?=function\s+[a-zA-Z0-9_]+\s*\(|\n\s*\/\*|\n\s*\/\/|$)/]
  ];

  for (const [sName, regex] of sceneMatches) {
    const match = content.match(regex);
    if (match) {
      const lines = match[0].split('\n').length;
      console.log(sName + ' logic lines: ' + lines);
      // check for canvas operations
      const ctxOps = (match[0].match(/ctx\.(fillRect|strokeRect|arc|beginPath|lineTo|moveTo|bezierCurveTo|drawImage|fillText|save|restore)/g) || []).length;
      console.log('  -> Canvas 2D render operations in ' + sName + ': ' + ctxOps);
    } else {
      console.log(sName + ': NOT FOUND using standard regex');
    }
  }

  // Check particle system
  const particleMatch = content.match(/particles|spawnShards|Particle/i);
  console.log('Particle system detected:', !!particleMatch);

  // Check exporter logic
  const exportMatch = content.match(/new\s+MediaRecorder\s*\(\s*stream/i);
  console.log('MediaRecorder stream initialization:', !!exportMatch);

  const captureStreamMatch = content.match(/captureStream\s*\(\s*60\s*\)/i);
  console.log('canvas.captureStream(60):', !!captureStreamMatch);

  const audioStreamMatch = content.match(/audioDest\.stream|createMediaStreamDestination/i);
  console.log('Audio destination stream attached:', !!audioStreamMatch);
}

analyzeCode('docs/kirmatas_reklam_tr.html', 'Turkish Studio');
console.log('');
analyzeCode('docs/kirmatas_ad_en.html', 'English Studio');

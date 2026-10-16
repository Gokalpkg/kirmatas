const fs = require('fs');

function inspectScenes(filePath, isTR) {
  const content = fs.readFileSync(filePath, 'utf8');
  console.log(`\n=================== FILE: ${filePath} (${isTR ? 'TR' : 'EN'}) ===================`);
  
  const prefix = isTR ? 'renderScene' : 'drawScene';
  for (let i = 1; i <= 4; i++) {
    const fnName = prefix + i;
    const startIdx = content.indexOf(`function ${fnName}`);
    if (startIdx === -1) {
      console.log(`Function ${fnName} NOT FOUND!`);
      continue;
    }
    // Find matching brace or next function
    const nextFnName = i < 4 ? `${prefix}${i + 1}` : (isTR ? 'renderCaptions' : 'drawCaptions');
    const endIdx = content.indexOf(`function ${nextFnName}`, startIdx);
    const body = endIdx !== -1 ? content.substring(startIdx, endIdx) : content.substring(startIdx, startIdx + 3000);
    console.log(`\n--- ${fnName} (length: ${body.length} chars) ---`);
    console.log('Sample operations:');
    const ops = [
      'ctx.beginPath', 'ctx.arc', 'ctx.fill', 'ctx.stroke', 'ctx.drawImage',
      'ctx.fillText', 'ctx.createLinearGradient', 'ctx.createRadialGradient',
      'ctx.rotate', 'ctx.translate', 'ctx.save', 'ctx.restore', 'speed', 'temp'
    ];
    ops.forEach(op => {
      const count = (body.match(new RegExp(op.replace('.', '\\.'), 'g')) || []).length;
      console.log(`  ${op}: ${count}`);
    });
  }
}

inspectScenes('docs/kirmatas_reklam_tr.html', true);
inspectScenes('docs/kirmatas_ad_en.html', false);

const fs = require('fs');
const vm = require('vm');

function createMockContext() {
  const drawCalls = [];
  const imageDraws = [];
  let fillStyle = '#000';
  let strokeStyle = '#000';

  const mockGradient = {
    addColorStop: () => {}
  };

  const ctx = {
    canvas: { width: 1080, height: 1920 },
    save: () => drawCalls.push('save'),
    restore: () => drawCalls.push('restore'),
    beginPath: () => drawCalls.push('beginPath'),
    closePath: () => drawCalls.push('closePath'),
    clip: () => drawCalls.push('clip'),
    ellipse: () => drawCalls.push('ellipse'),
    arc: (x, y, r) => drawCalls.push(`arc(${x.toFixed(1)},${y.toFixed(1)},${r.toFixed(1)})`),
    rect: (x, y, w, h) => drawCalls.push(`rect(${w.toFixed(1)}x${h.toFixed(1)})`),
    fill: () => drawCalls.push('fill'),
    stroke: () => drawCalls.push('stroke'),
    clearRect: () => drawCalls.push('clearRect'),
    fillRect: (x, y, w, h) => drawCalls.push(`fillRect(${x},${y},${w},${h})`),
    strokeRect: (x, y, w, h) => drawCalls.push(`strokeRect(${x},${y},${w},${h})`),
    fillText: (text, x, y) => drawCalls.push(`fillText("${text}",${x.toFixed(1)},${y.toFixed(1)})`),
    strokeText: (text, x, y) => drawCalls.push(`strokeText("${text}",${x.toFixed(1)},${y.toFixed(1)})`),
    measureText: (text) => ({ width: (text || '').length * 10 }),
    createLinearGradient: () => mockGradient,
    createRadialGradient: () => mockGradient,
    translate: (x, y) => drawCalls.push(`translate(${x.toFixed(1)},${y.toFixed(1)})`),
    rotate: (a) => drawCalls.push(`rotate(${a.toFixed(2)})`),
    scale: (sx, sy) => drawCalls.push(`scale(${sx.toFixed(2)},${sy.toFixed(2)})`),
    moveTo: (x, y) => drawCalls.push('moveTo'),
    lineTo: (x, y) => drawCalls.push('lineTo'),
    quadraticCurveTo: () => drawCalls.push('quadraticCurveTo'),
    bezierCurveTo: () => drawCalls.push('bezierCurveTo'),
    drawImage: (img, ...args) => {
      const src = img ? (img.src || img.name || img._id || 'unknown') : 'null';
      drawCalls.push(`drawImage(${src.substring(0, 30)})`);
      imageDraws.push({ src: src.substring(0, 40), args });
    },
    set fillStyle(val) { fillStyle = val; },
    get fillStyle() { return fillStyle; },
    set strokeStyle(val) { strokeStyle = val; },
    get strokeStyle() { return strokeStyle; },
    set lineWidth(val) {},
    get lineWidth() { return 1; },
    set globalAlpha(val) {},
    get globalAlpha() { return 1.0; },
    set font(val) {},
    get font() { return '20px sans-serif'; },
    set textAlign(val) {},
    get textAlign() { return 'center'; },
    set textBaseline(val) {},
    get textBaseline() { return 'middle'; },
    set shadowColor(val) {},
    set shadowBlur(val) {},
    set shadowOffsetX(val) {},
    set shadowOffsetY(val) {}
  };

  return { ctx, drawCalls, imageDraws };
}

function simulateTR() {
  console.log('\n=== SIMULATING TR AD TIMELINE (kirmatas_reklam_tr.html) ===');
  const code = fs.readFileSync('docs/kirmatas_reklam_tr.html', 'utf8');
  const jsMatch = code.match(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/i);
  const js = jsMatch[1];

  const { ctx, drawCalls, imageDraws } = createMockContext();
  
  // Set up mock window and document
  const mockDoc = {
    getElementById: (id) => ({
      addEventListener: () => {},
      style: {},
      value: '0',
      innerText: '',
      innerHTML: '',
      getContext: () => ctx,
      width: 1080,
      height: 1920
    }),
    querySelectorAll: () => [],
    createElement: () => ({
      addEventListener: () => {},
      style: {},
      getContext: () => ctx
    })
  };

  const mockWindow = {
    AudioContext: function() {
      return {
        createGain: () => ({ gain: { value: 1, setValueAtTime: () => {} }, connect: () => {} }),
        createMediaStreamDestination: () => ({ stream: {} }),
        createBufferSource: () => ({ connect: () => {}, start: () => {}, stop: () => {} }),
        decodeAudioData: (b, cb) => cb && cb({}),
        currentTime: 0,
        destination: {}
      };
    },
    AD_ASSETS: {},
    requestAnimationFrame: () => {},
    innerWidth: 1920,
    innerHeight: 1080,
    addEventListener: () => {}
  };

  // Pre-populate mock images
  const ctxSandbox = {
    window: mockWindow,
    document: mockDoc,
    console: console,
    Image: function() {
      this.src = '';
      this.width = 1080;
      this.height = 1920;
      this.naturalWidth = 1080;
      this.naturalHeight = 1920;
      this.complete = true;
      this._id = 'img_' + Math.random().toString(36).substring(2, 6);
    },
    Audio: function() {
      this.play = () => Promise.resolve();
      this.pause = () => {};
    },
    performance: { now: () => Date.now() },
    requestAnimationFrame: () => {},
    setTimeout: () => {},
    clearTimeout: () => {},
    setInterval: () => {},
    clearInterval: () => {}
  };

  // Load ad_data_tr.js into sandbox window.AD_ASSETS
  const trDataCode = fs.readFileSync('docs/ad_assets/ad_data_tr.js', 'utf8');
  vm.runInNewContext(trDataCode, ctxSandbox);

  // Run the ad script
  vm.runInNewContext(js, ctxSandbox);

  console.log('Script loaded successfully. Testing timeline scrubbing...');

  const timeSamples = [0.0, 1.0, 2.5, 3.5, 4.0, 4.5, 5.5, 7.5, 8.5, 10.0, 12.0, 13.5, 15.0, 17.5, 18.0];
  const imagesDrawnSet = new Set();

  timeSamples.forEach(t => {
    drawCalls.length = 0;
    imageDraws.length = 0;
    // Call renderFrame or specific scene render
    try {
      if (t < 3.5) ctxSandbox.renderScene1(t);
      else if (t < 7.5) ctxSandbox.renderScene2(t);
      else if (t < 13.5) ctxSandbox.renderScene3(t);
      else ctxSandbox.renderScene4(t);

      imageDraws.forEach(img => {
        // Find which asset it matches
        imagesDrawnSet.add(img.src);
      });

      console.log(`  t = ${t.toFixed(1)}s: OK (${drawCalls.length} draw calls, ${imageDraws.length} image draws)`);
    } catch(err) {
      console.error(`  t = ${t.toFixed(1)}s: ERROR`, err.message);
    }
  });

  console.log(`TR Image assets drawn across timeline: ${imagesDrawnSet.size}`);
  imagesDrawnSet.forEach(s => console.log('    - ' + s));
}

function simulateEN() {
  console.log('\n=== SIMULATING EN AD TIMELINE (kirmatas_ad_en.html) ===');
  const code = fs.readFileSync('docs/kirmatas_ad_en.html', 'utf8');
  const jsMatch = code.match(/<script(?![^>]*src=)[^>]*>([\s\S]*?)<\/script>/i);
  const js = jsMatch[1];

  const { ctx, drawCalls, imageDraws } = createMockContext();

  const mockDoc = {
    getElementById: (id) => ({
      addEventListener: () => {},
      style: {},
      value: '0',
      innerText: '',
      innerHTML: '',
      getContext: () => ctx,
      width: 1080,
      height: 1920
    }),
    querySelectorAll: () => [],
    createElement: () => ({
      addEventListener: () => {},
      style: {},
      getContext: () => ctx
    })
  };

  const mockWindow = {
    AudioContext: function() {
      return {
        createGain: () => ({ gain: { value: 1, setValueAtTime: () => {} }, connect: () => {} }),
        createMediaStreamDestination: () => ({ stream: {} }),
        createBufferSource: () => ({ connect: () => {}, start: () => {}, stop: () => {} }),
        decodeAudioData: (b, cb) => cb && cb({}),
        currentTime: 0,
        destination: {}
      };
    },
    requestAnimationFrame: () => {},
    innerWidth: 1920,
    innerHeight: 1080,
    addEventListener: () => {}
  };

  const ctxSandbox = {
    window: mockWindow,
    document: mockDoc,
    console: console,
    Image: function() {
      this.src = '';
      this.width = 1080;
      this.height = 1920;
      this.naturalWidth = 1080;
      this.naturalHeight = 1920;
      this.complete = true;
      this._id = 'img_' + Math.random().toString(36).substring(2, 6);
    },
    Audio: function() {
      this.play = () => Promise.resolve();
      this.pause = () => {};
    },
    performance: { now: () => Date.now() },
    requestAnimationFrame: () => {},
    setTimeout: () => {},
    clearTimeout: () => {},
    setInterval: () => {},
    clearInterval: () => {}
  };

  // Run the EN ad script
  vm.runInNewContext(js, ctxSandbox);

  console.log('Script loaded successfully. Testing timeline scrubbing...');

  const timeSamples = [0.0, 1.0, 2.5, 3.5, 4.0, 4.5, 5.5, 7.5, 8.5, 10.0, 12.0, 13.5, 15.0, 17.5, 18.0];
  const imagesDrawnSet = new Set();

  timeSamples.forEach(t => {
    drawCalls.length = 0;
    imageDraws.length = 0;
    try {
      if (t < 3.5) ctxSandbox.drawScene1(t);
      else if (t < 7.5) ctxSandbox.drawScene2(t);
      else if (t < 13.5) ctxSandbox.drawScene3(t);
      else ctxSandbox.drawScene4(t);

      imageDraws.forEach(img => {
        imagesDrawnSet.add(img.src);
      });

      console.log(`  t = ${t.toFixed(1)}s: OK (${drawCalls.length} draw calls, ${imageDraws.length} image draws)`);
    } catch(err) {
      console.error(`  t = ${t.toFixed(1)}s: ERROR`, err.message);
    }
  });

  console.log(`EN Image assets drawn across timeline: ${imagesDrawnSet.size}`);
  imagesDrawnSet.forEach(s => console.log('    - ' + s));
}

simulateTR();
simulateEN();

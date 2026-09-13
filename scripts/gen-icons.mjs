import fs from 'fs';
import path from 'path';
import zlib from 'zlib';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');

function crc32(buf) {
  return zlib.crc32(buf) >>> 0;
}

function chunk(tag, data) {
  const t = Buffer.from(tag);
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([t, data])));
  return Buffer.concat([len, t, data, crc]);
}

function writePng(file, w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    raw[y * (w * 4 + 1)] = 0;
    rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 6;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]);
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, png);
}

function mix(a, b, t) {
  return (a + (b - a) * t) | 0;
}

function drawIcon(size) {
  const px = Buffer.alloc(size * size * 4);
  const setp = (x, y, r, g, b, a = 255) => {
    if (x < 0 || y < 0 || x >= size || y >= size) return;
    const i = (y * size + x) * 4;
    px[i] = r; px[i + 1] = g; px[i + 2] = b; px[i + 3] = a;
  };
  for (let y = 0; y < size; y++) {
    const t = y / Math.max(1, size - 1);
    for (let x = 0; x < size; x++) setp(x, y, mix(26, 15, t), mix(26, 15, t), mix(46, 30, t));
  }
  const colors = [[255,82,82],[255,152,0],[255,215,64],[105,240,174],[64,196,255],[179,136,255]];
  const gap = Math.max(1, (size / 48) | 0);
  const brickH = Math.max(3, (size / 10) | 0);
  const brickW = Math.max(6, (size / 5) | 0);
  const top = (size * 0.18) | 0;
  const left = (size * 0.14) | 0;
  let idx = 0;
  for (let r = 0; r < 2; r++) {
    for (let c = 0; c < 3; c++) {
      const x0 = left + c * (brickW + gap);
      const y0 = top + r * (brickH + gap);
      const [cr, cg, cb] = colors[idx++ % colors.length];
      for (let y = y0; y < y0 + brickH; y++) {
        const hl = y < y0 + brickH * 0.35 ? 1 : 0.82;
        for (let x = x0; x < x0 + brickW; x++) setp(x, y, (cr * hl) | 0, (cg * hl) | 0, (cb * hl) | 0);
      }
    }
  }
  const cx = (size / 2) | 0;
  const cy = (size * 0.58) | 0;
  const rad = Math.max(4, (size / 10) | 0);
  for (let y = cy - rad; y <= cy + rad; y++) {
    for (let x = cx - rad; x <= cx + rad; x++) {
      if ((x - cx) ** 2 + (y - cy) ** 2 <= rad * rad) setp(x, y, 255, 255, 255);
    }
  }
  const pw = (size * 0.42) | 0;
  const ph = Math.max(3, (size / 16) | 0);
  const px0 = ((size - pw) / 2) | 0;
  const py0 = (size * 0.78) | 0;
  for (let y = py0; y < py0 + ph; y++) {
    for (let x = px0; x < px0 + pw; x++) {
      const t = (x - px0) / Math.max(1, pw);
      setp(x, y, mix(64, 124, t), mix(196, 77, t), mix(255, 255, t));
    }
  }
  return px;
}

writePng(path.join(root, 'www', 'icon-192.png'), 192, 192, drawIcon(192));
writePng(path.join(root, 'www', 'icon-512.png'), 512, 512, drawIcon(512));
const dens = { 'mipmap-mdpi': 48, 'mipmap-hdpi': 72, 'mipmap-xhdpi': 96, 'mipmap-xxhdpi': 144, 'mipmap-xxxhdpi': 192 };
const res = path.join(root, 'android', 'app', 'src', 'main', 'res');
for (const [folder, s] of Object.entries(dens)) {
  const img = drawIcon(s);
  writePng(path.join(res, folder, 'ic_launcher.png'), s, s, img);
  writePng(path.join(res, folder, 'ic_launcher_round.png'), s, s, img);
  writePng(path.join(res, folder, 'ic_launcher_foreground.png'), s, s, img);
}
console.log('icons ok');

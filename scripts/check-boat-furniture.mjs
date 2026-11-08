// Builds every boat furniture item (src/shared/BoatFurnitureModels/<Id>.luau) with
// Shared.BoatFurniture's real kit in a small Roblox mock, checks each one against
// its catalog Size box and part cap, and can render PNG contact sheets.
//   node scripts/check-boat-furniture.mjs [--only Id,Id] [--render <outDir>]
// Panels: top-left front (the item's -Z face), top-right top-down (front at the
// top), bottom-left right side (+X face, front on the right), bottom-right front
// three-quarter from above.
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SHARED = join(ROOT, 'src', 'shared');
const read = (path) => readFileSync(path, 'utf8').replace(/\r\n/g, '\n');
const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const OUT = flag('--render') ? resolve(flag('--render')) : null;
const catalog = read(join(SHARED, 'BoatFurniture.luau'));
const order = [...catalog.match(/BoatFurniture\.Order = \{([\s\S]*?)\n\}/)[1].matchAll(/"(\w+)"/g)].map((m) => m[1]);
const only = flag('--only') ? flag('--only').split(',').map((s) => s.trim()).filter(Boolean) : order;
for (const id of only) if (!order.includes(id)) throw new Error(id + ' is not in BoatFurniture.Order');

const builders = only
  .map((id) => {
    const path = join(SHARED, 'BoatFurnitureModels', id + '.luau');
    if (!existsSync(path)) return 'MISSING["' + id + '"] = true';
    return [
      'do',
      '\tlocal ok, built = pcall(function()',
      read(path),
      'end)',
      '\tif ok then BoatFurniture.builders["' + id + '"] = built else LOAD_ERRORS["' + id + '"] = tostring(built) end',
      'end',
    ].join('\n');
  })
  .join('\n');

const bundle = [
  read(join(ROOT, 'scripts', 'boat-furniture-mock.luau')),
  'local BoatFurniture = (function()\n' + catalog + '\nend)()',
  'local MISSING, LOAD_ERRORS = {}, {}',
  'local IDS = { ' + only.map((id) => '"' + id + '"').join(', ') + ' }',
  builders,
  read(join(ROOT, 'scripts', 'boat-furniture-dump.luau')),
].join('\n');
const work = mkdtempSync(join(tmpdir(), 'boat-furniture-'));
let output;
try {
  writeFileSync(join(work, 'build.luau'), bundle);
  output = execFileSync(process.env.LUTE ?? 'lute', ['run', join(work, 'build.luau')], {
    encoding: 'utf8',
    maxBuffer: 1 << 30,
  });
} finally {
  rmSync(work, { recursive: true, force: true });
}

const sizes = {};
for (const m of catalog.matchAll(/\n\t(\w+) = \{[^}]*?Size = \{ ([\d.]+), ([\d.]+), ([\d.]+) \}/g)) {
  sizes[m[1]] = [+m[2], +m[3], +m[4]];
}
const MAX_PARTS = +catalog.match(/MAX_PARTS = (\d+)/)[1];
const TOLERANCE = 0.06;
const RESERVED = /^(Hull|Bilge|Bottom|Bow|Transom|Seat|DriverSeat|Rower)/;

// World-space half extents of a part along x, y and z.
function extent(part) {
  const [R, U, Z] = part.r;
  if (part.s === 'sphere') {
    const r = Math.min(...part.z) / 2;
    return [r, r, r];
  }
  if (part.s === 'cylinder') {
    const r = Math.min(part.z[1], part.z[2]) / 2;
    const len = part.z[0] / 2;
    return [0, 1, 2].map((i) => Math.abs(R[i]) * len + r * Math.sqrt(Math.max(0, 1 - R[i] * R[i])));
  }
  const half = part.z.map((v) => v / 2);
  return [0, 1, 2].map((i) => Math.abs(R[i]) * half[0] + Math.abs(U[i]) * half[1] + Math.abs(Z[i]) * half[2]);
}

// Unit shapes as triangles in part-local space (-0.5..0.5 on each axis).
const box = (() => {
  const t = [];
  const faces = [
    [[1, 0, 0], [0, 1, 0], [0, 0, 1]],
    [[-1, 0, 0], [0, 0, 1], [0, 1, 0]],
    [[0, 1, 0], [0, 0, 1], [1, 0, 0]],
    [[0, -1, 0], [1, 0, 0], [0, 0, 1]],
    [[0, 0, 1], [1, 0, 0], [0, 1, 0]],
    [[0, 0, -1], [0, 1, 0], [1, 0, 0]],
  ];
  for (const [n, u, v] of faces) {
    const c = (a, b) => n.map((x, i) => x * 0.5 + u[i] * a * 0.5 + v[i] * b * 0.5);
    t.push([c(-1, -1), c(1, -1), c(1, 1)], [c(-1, -1), c(1, 1), c(-1, 1)]);
  }
  return t;
})();
// Roblox wedge: full height at +Z, sloping down to the bottom edge at -Z.
const wedge = (() => {
  const p = (x, y, z) => [x * 0.5, y * 0.5, z * 0.5];
  const t = [];
  for (const x of [-1, 1]) t.push([p(x, -1, -1), p(x, -1, 1), p(x, 1, 1)]);
  const quad = (a, b, c, d) => t.push([a, b, c], [a, c, d]);
  quad(p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1));
  quad(p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1));
  quad(p(-1, -1, -1), p(-1, 1, 1), p(1, 1, 1), p(1, -1, -1));
  return t;
})();
const sphere = (() => {
  const t = [];
  const S = 12;
  const at = (i, j) => {
    const th = (i / S) * Math.PI;
    const ph = (j / (S * 2)) * Math.PI * 2;
    return [0.5 * Math.sin(th) * Math.cos(ph), 0.5 * Math.cos(th), 0.5 * Math.sin(th) * Math.sin(ph)];
  };
  for (let i = 0; i < S; i++)
    for (let j = 0; j < S * 2; j++) {
      t.push([at(i, j), at(i + 1, j), at(i + 1, j + 1)], [at(i, j), at(i + 1, j + 1), at(i, j + 1)]);
    }
  return t;
})();
// Cylinders run along X; the round section uses the smaller of Y and Z.
const cylinder = (() => {
  const t = [];
  const S = 20;
  const ring = (j) => [Math.cos((j / S) * Math.PI * 2) * 0.5, Math.sin((j / S) * Math.PI * 2) * 0.5];
  for (let j = 0; j < S; j++) {
    const [a, b] = ring(j);
    const [c, d] = ring(j + 1);
    t.push([[-0.5, a, b], [0.5, a, b], [0.5, c, d]], [[-0.5, a, b], [0.5, c, d], [-0.5, c, d]]);
    t.push([[0.5, 0, 0], [0.5, a, b], [0.5, c, d]], [[-0.5, 0, 0], [-0.5, c, d], [-0.5, a, b]]);
  }
  return t;
})();
const SHAPES = { block: box, wedge, sphere, cylinder };

const hexRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const norm = (a) => {
  const l = Math.hypot(...a) || 1;
  return a.map((x) => x / l);
};

function worldTriangles(parts) {
  const out = [];
  for (const part of parts) {
    const alpha = 1 - (part.t ?? 0);
    if (alpha < 0.15) continue;
    let size = part.z;
    if (part.s === 'cylinder') {
      const d = Math.min(size[1], size[2]);
      size = [size[0], d, d];
    }
    const [R, U, Z] = part.r;
    const color = hexRgb(part.c);
    for (const tri of SHAPES[part.s] ?? box) {
      const w = tri.map((v) => {
        const l = [v[0] * size[0], v[1] * size[1], v[2] * size[2]];
        return [0, 1, 2].map((i) => part.p[i] + R[i] * l[0] + U[i] * l[1] + Z[i] * l[2]);
      });
      out.push({ w, color, alpha, neon: part.m === 'Neon' });
    }
  }
  return out;
}

const PANEL = 360;
const LIGHT = norm([0.4, 0.8, 0.5]);

function renderPanel(tris, right, up, img, ox, oy, W) {
  const up2 = norm(sub(up, right.map((x) => x * (up[0] * right[0] + up[1] * right[1] + up[2] * right[2]))));
  const fwd = cross(right, up2);
  const proj = (p) => [
    p[0] * right[0] + p[1] * right[1] + p[2] * right[2],
    p[0] * up2[0] + p[1] * up2[1] + p[2] * up2[2],
    p[0] * fwd[0] + p[1] * fwd[1] + p[2] * fwd[2],
  ];
  let [minX, minY, maxX, maxY] = [Infinity, Infinity, -Infinity, -Infinity];
  const pts = tris.map((t) => t.w.map(proj));
  for (const t of pts)
    for (const [x, y] of t) {
      minX = Math.min(minX, x); maxX = Math.max(maxX, x);
      minY = Math.min(minY, y); maxY = Math.max(maxY, y);
    }
  const scale = (PANEL * 0.86) / Math.max(maxX - minX, maxY - minY, 1e-3);
  const cx = (minX + maxX) / 2;
  const cy = (minY + maxY) / 2;
  const depth = new Float32Array(PANEL * PANEL).fill(-Infinity);
  tris.forEach((tri, k) => {
    const n = norm(cross(sub(tri.w[1], tri.w[0]), sub(tri.w[2], tri.w[0])));
    const shade = tri.neon ? 1.15 : 0.45 + 0.55 * Math.abs(n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]);
    const s = pts[k].map(([x, y, z]) => [(x - cx) * scale + PANEL / 2, PANEL / 2 - (y - cy) * scale, z]);
    const x0 = Math.max(0, Math.floor(Math.min(s[0][0], s[1][0], s[2][0])));
    const x1 = Math.min(PANEL - 1, Math.ceil(Math.max(s[0][0], s[1][0], s[2][0])));
    const y0 = Math.max(0, Math.floor(Math.min(s[0][1], s[1][1], s[2][1])));
    const y1 = Math.min(PANEL - 1, Math.ceil(Math.max(s[0][1], s[1][1], s[2][1])));
    const area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
    if (Math.abs(area) < 1e-9) return;
    for (let y = y0; y <= y1; y++)
      for (let x = x0; x <= x1; x++) {
        const px = x + 0.5, py = y + 0.5;
        const a = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
        const b = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
        const c = 1 - a - b;
        if (a < 0 || b < 0 || c < 0) continue;
        // Larger z is nearer the camera (fwd points out of the screen).
        const z = a * s[0][2] + b * s[1][2] + c * s[2][2];
        const i = y * PANEL + x;
        if (z <= depth[i]) continue;
        depth[i] = z;
        const o = ((oy + y) * W + ox + x) * 3;
        for (let ch = 0; ch < 3; ch++) {
          const v = Math.min(255, tri.color[ch] * shade);
          img[o + ch] = tri.alpha >= 1 ? v : img[o + ch] * (1 - tri.alpha) + v * tri.alpha;
        }
      }
  });
}

function png(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const len = Buffer.alloc(4);
    len.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const sum = Buffer.alloc(4);
    sum.writeUInt32BE(crc(body));
    return Buffer.concat([len, body, sum]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8;
  ihdr[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(raw)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

// Views as [right axis, up axis]; renderPanel's camera sits along right x up.
// The item's front is -Z.
const quarter = norm([0.55, 0.45, -0.7]);
const quarterRight = norm(cross([0, 1, 0], quarter));
const ITEM_VIEWS = [
  ['front', [-1, 0, 0], [0, 1, 0]],
  ['top', [1, 0, 0], [0, 0, -1]],
  ['right side', [0, 0, -1], [0, 1, 0]],
  ['three-quarter', quarterRight, cross(quarter, quarterRight)],
];

const failures = [];
let checked = 0;
if (OUT) mkdirSync(OUT, { recursive: true });
for (const line of output.split('\n')) {
  if (!line.startsWith('{"id"')) {
    if (line.trim()) console.log(line);
    continue;
  }
  const item = JSON.parse(line);
  const problems = [];
  if (item.error) problems.push(item.error);
  const parts = item.parts ?? [];
  const size = sizes[item.id];
  if (!size) problems.push('no Size in the catalog');
  if (!item.error || item.parts) {
    if (parts.length < 3) problems.push('only ' + parts.length + ' parts (need at least 3)');
    if (parts.length > MAX_PARTS) problems.push(parts.length + ' parts (cap ' + MAX_PARTS + ')');
    if (item.lights > 1) problems.push(item.lights + ' lights (max 1)');
    let minY = Infinity;
    for (const part of parts) {
      if (RESERVED.test(part.n)) problems.push('part name "' + part.n + '" is reserved for hulls/seats');
      const e = extent(part);
      minY = Math.min(minY, part.p[1] - e[1]);
      if (!size) continue;
      const box = [size[0] / 2, size[1], size[2] / 2];
      const over = [];
      if (part.p[0] + e[0] > box[0] + TOLERANCE || part.p[0] - e[0] < -box[0] - TOLERANCE) over.push('X');
      if (part.p[1] + e[1] > box[1] + TOLERANCE || part.p[1] - e[1] < -TOLERANCE) over.push('Y');
      if (part.p[2] + e[2] > box[2] + TOLERANCE || part.p[2] - e[2] < -box[2] - TOLERANCE) over.push('Z');
      if (over.length) {
        problems.push(
          '"' + part.n + '" leaves the Size box on ' + over.join('/') +
            ' (centre ' + part.p.map((v) => v.toFixed(2)).join(', ') +
            ', half extents ' + e.map((v) => v.toFixed(2)).join(', ') + ')',
        );
      }
    }
    if (parts.length && minY > 0.15) problems.push('floats: lowest part is ' + minY.toFixed(2) + ' studs above the floor');
  }
  checked++;
  const summary = item.id + ': ' + parts.length + ' parts, ' + (item.lights ?? 0) + ' light, ' + (item.fires ?? 0) + ' fire';
  if (problems.length) {
    failures.push(item.id);
    console.log('FAIL ' + summary);
    for (const p of [...new Set(problems)]) console.log('   - ' + p);
  } else {
    console.log('ok   ' + summary);
  }
  if (OUT && parts.length) {
    const tris = worldTriangles(parts);
    const W = PANEL * 2;
    const H = PANEL * 2;
    const img = Buffer.alloc(W * H * 3);
    for (let i = 0; i < W * H; i++) img.set([58, 92, 118], i * 3);
    ITEM_VIEWS.forEach(([, right, up], v) =>
      renderPanel(tris, right, up, img, (v % 2) * PANEL, Math.floor(v / 2) * PANEL, W),
    );
    writeFileSync(join(OUT, item.id + '.png'), png(W, H, img));
  }
}
if (OUT) console.log('renders in ' + OUT + ' (front, top, right side, three-quarter)');
if (failures.length) {
  console.log(failures.length + ' of ' + checked + ' items failed: ' + failures.join(', '));
  process.exit(1);
}
console.log('All ' + checked + ' boat furniture items passed.');

// Top-down PNG of the parts check-company-islands.mjs dumps with --preview: one tile per
// dumped island (the wild one, the owned village, then a few more wild ones), three a row. Painter's order by height,
// blocks and wedges filled as the convex hull of their corners seen from above.
import { writeFile } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';

const SCALE = 2; // pixels per stud
const HALF = 185; // studs either side of the island centre, local -Z (the docks) at the bottom
const COLUMNS = 3;
const SIZE = HALF * 2 * SCALE;

function hull(points) {
  points.sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cross = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lower = [], upper = [];
  for (const p of points) {
    while (lower.length >= 2 && cross(lower.at(-2), lower.at(-1), p) <= 0) lower.pop();
    lower.push(p);
  }
  for (const p of points.slice().reverse()) {
    while (upper.length >= 2 && cross(upper.at(-2), upper.at(-1), p) <= 0) upper.pop();
    upper.push(p);
  }
  return lower.slice(0, -1).concat(upper.slice(0, -1));
}

function fill(image, width, [ox, oy], polygon, color) {
  let minY = Infinity, maxY = -Infinity;
  for (const [, y] of polygon) { minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  for (let y = Math.max(0, Math.floor(minY)); y <= Math.min(SIZE - 1, Math.ceil(maxY)); y++) {
    const row = y + oy;
    const xs = [];
    for (let i = 0; i < polygon.length; i++) {
      const [x1, y1] = polygon[i], [x2, y2] = polygon[(i + 1) % polygon.length];
      if ((y1 <= y + 0.5) !== (y2 <= y + 0.5)) xs.push(x1 + (y + 0.5 - y1) * (x2 - x1) / (y2 - y1));
    }
    xs.sort((a, b) => a - b);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(SIZE, Math.round(xs[i + 1])); x++) {
        const at = (row * width + ox + x) * 3;
        image[at] = color[0]; image[at + 1] = color[1]; image[at + 2] = color[2];
      }
    }
  }
}

function png(width, height, rgb) {
  const rows = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) rgb.copy(rows, y * (width * 3 + 1) + 1, y * width * 3, (y + 1) * width * 3);
  const table = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = buffer => {
    let c = 0xffffffff;
    for (const byte of buffer) c = table[(c ^ byte) & 0xff] ^ (c >>> 8);
    return (c ^ 0xffffffff) >>> 0;
  };
  const chunk = (type, data) => {
    const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    const sum = Buffer.alloc(4); sum.writeUInt32BE(crc(body));
    return Buffer.concat([length, body, sum]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0); header.writeUInt32BE(height, 4);
  header[8] = 8; header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header),
    chunk('IDAT', deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]);
}

// lines: "@P <tag> <W|B> px py pz rx ry rz ux uy uz bx by bz sx sy sz r g b", island-local.
export async function renderPreview(lines, path) {
  const tags = [...new Set(lines.map(line => line.trim().split(/\s+/)[1]))];
  const width = SIZE * Math.min(COLUMNS, tags.length), height = SIZE * Math.ceil(tags.length / COLUMNS);
  const image = Buffer.alloc(width * height * 3);
  for (let i = 0; i < image.length; i += 3) { image[i] = 38; image[i + 1] = 74; image[i + 2] = 96; }
  const parts = lines.map(line => {
    const [, tag, kind, ...n] = line.trim().split(/\s+/);
    const v = n.map(Number);
    return { tag, kind, p: v.slice(0, 3), r: v.slice(3, 6), u: v.slice(6, 9), b: v.slice(9, 12), s: v.slice(12, 15), c: v.slice(15, 18) };
  });
  const corners = part => {
    const { p, r, u, b, s } = part;
    const local = part.kind === 'W'
      ? [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, 1]]
      : [[-1, -1, -1], [-1, -1, 1], [-1, 1, -1], [-1, 1, 1], [1, -1, -1], [1, -1, 1], [1, 1, -1], [1, 1, 1]];
    return local.map(([x, y, z]) => [0, 1, 2].map(k => p[k] + r[k] * x * s[0] / 2 + u[k] * y * s[1] / 2 + b[k] * z * s[2] / 2));
  };
  for (const part of parts) part.points = corners(part), part.top = Math.max(...part.points.map(q => q[1]));
  parts.sort((a, b) => a.top - b.top);
  for (const part of parts) {
    const tile = tags.indexOf(part.tag);
    const offset = [(tile % COLUMNS) * SIZE, Math.floor(tile / COLUMNS) * SIZE];
    // Island-local +X to the right, -Z (towards Gullhaven) at the bottom of the picture.
    const polygon = hull(part.points.map(q => [(q[0] + HALF) * SCALE, (HALF - q[2]) * SCALE]));
    const light = Math.min(1.15, 0.7 + Math.max(0, part.top) / 60);
    fill(image, width, offset, polygon, part.c.map(c => Math.min(255, Math.round(c * 255 * light))));
  }
  await writeFile(path, png(width, height, image));
}

// A low, three-quarter view from the sea in front of each island (local -Z, where the
// boats come in), as a z-buffered render of every face, lit from one side. Parts under
// the water plane are hidden, as they mostly are in game.
const VIEW_W = 640, VIEW_H = 400;
const WEDGE_FACES = [
  [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1]], [[1, -1, -1], [1, 1, 1], [1, -1, 1]],
  [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]], [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],
  [[-1, -1, -1], [-1, 1, 1], [1, 1, 1], [1, -1, -1]],
];
const BOX_FACES = [
  [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]], [[1, -1, -1], [1, 1, -1], [1, 1, 1], [1, -1, 1]],
  [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]], [[-1, 1, -1], [-1, 1, 1], [1, 1, 1], [1, 1, -1]],
  [[-1, -1, -1], [-1, 1, -1], [1, 1, -1], [1, -1, -1]], [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],
];
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const dot = (a, b) => a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
const crossV = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const unit = a => { const l = Math.hypot(...a) || 1; return a.map(v => v / l); };

export async function renderView(lines, path) {
  const tags = [...new Set(lines.map(line => line.trim().split(/\s+/)[1]))];
  const width = VIEW_W * Math.min(COLUMNS, tags.length), height = VIEW_H * Math.ceil(tags.length / COLUMNS);
  const image = Buffer.alloc(width * height * 3);
  const depth = new Float32Array(width * height).fill(Infinity);
  const eye = [-150, 70, -330], target = [0, 22, 10];
  const forward = unit(sub(target, eye)), right = unit(crossV(forward, [0, 1, 0])), up = crossV(right, forward);
  const light = unit([-0.6, 0.75, -0.35]), focal = VIEW_W * 0.95;
  const sky = [[54, 72, 82], [150, 132, 112]], sea = [32, 72, 82];
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const row = y % VIEW_H, at = (y * width + x) * 3;
      // Horizon where the view ray runs level.
      const level = dot(forward, [0, 1, 0]) * focal - (row - VIEW_H / 2) * dot(up, [0, 1, 0]);
      const t = Math.min(1, Math.max(0, row / (VIEW_H * 0.55)));
      const colour = level > 0 ? sky[0].map((c, k) => c + (sky[1][k] - c) * t) : sea;
      image[at] = colour[0]; image[at + 1] = colour[1]; image[at + 2] = colour[2];
    }
  }
  const project = q => {
    const d = sub(q, eye), z = dot(d, forward);
    return [VIEW_W / 2 + dot(d, right) / z * focal, VIEW_H / 2 - dot(d, up) / z * focal, z];
  };
  const triangle = (tile, a, b, c, colour) => {
    const ox = (tile % COLUMNS) * VIEW_W, oy = Math.floor(tile / COLUMNS) * VIEW_H;
    const [pa, pb, pc] = [a, b, c].map(project);
    if (pa[2] < 1 || pb[2] < 1 || pc[2] < 1) return;
    const area = (pb[0] - pa[0]) * (pc[1] - pa[1]) - (pc[0] - pa[0]) * (pb[1] - pa[1]);
    if (Math.abs(area) < 1e-6) return;
    const x0 = Math.max(0, Math.floor(Math.min(pa[0], pb[0], pc[0]))), x1 = Math.min(VIEW_W - 1, Math.ceil(Math.max(pa[0], pb[0], pc[0])));
    const y0 = Math.max(0, Math.floor(Math.min(pa[1], pb[1], pc[1]))), y1 = Math.min(VIEW_H - 1, Math.ceil(Math.max(pa[1], pb[1], pc[1])));
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        const px = x + 0.5, py = y + 0.5;
        const w0 = ((pb[0] - px) * (pc[1] - py) - (pc[0] - px) * (pb[1] - py)) / area;
        const w1 = ((pc[0] - px) * (pa[1] - py) - (pa[0] - px) * (pc[1] - py)) / area;
        const w2 = 1 - w0 - w1;
        if (w0 < 0 || w1 < 0 || w2 < 0) continue;
        const z = w0 * pa[2] + w1 * pb[2] + w2 * pc[2];
        const index = (y + oy) * width + x + ox;
        if (z >= depth[index]) continue;
        depth[index] = z;
        // Distance haze toward the sky colour.
        const haze = Math.min(0.6, Math.max(0, (z - 250) / 900));
        const at = index * 3;
        for (let k = 0; k < 3; k++) image[at + k] = Math.round(colour[k] * (1 - haze) + sky[1][k] * haze);
      }
    }
  };
  for (const line of lines) {
    const [, tag, kind, ...n] = line.trim().split(/\s+/);
    const v = n.map(Number);
    const p = v.slice(0, 3), r = v.slice(3, 6), u = v.slice(6, 9), b = v.slice(9, 12), s = v.slice(12, 15), c = v.slice(15, 18);
    const tile = tags.indexOf(tag);
    const corner = ([x, y, z]) => [0, 1, 2].map(k => p[k] + r[k] * x * s[0] / 2 + u[k] * y * s[1] / 2 + b[k] * z * s[2] / 2);
    for (const face of kind === 'W' ? WEDGE_FACES : BOX_FACES) {
      const q = face.map(corner);
      // Clip at the waterline crudely: faces wholly under it are dropped.
      if (Math.max(...q.map(point => point[1])) < 0) continue;
      let normal = unit(crossV(sub(q[1], q[0]), sub(q[2], q[0])));
      if (dot(normal, sub(q[0], eye)) > 0) normal = normal.map(x => -x);
      const shade = 0.42 + 0.68 * Math.max(0, dot(normal, light));
      const colour = c.map(x => Math.min(255, x * 255 * shade));
      for (let i = 1; i + 1 < q.length; i++) {
        // Lift points under the sea to the surface so half-sunk faces end at the waterline.
        triangle(tile, ...[q[0], q[i], q[i + 1]].map(point => point[1] < 0 ? [point[0], 0, point[2]] : point), colour);
      }
    }
  }
  await writeFile(path, png(width, height, image));
}

// Top-down PNG of the parts check-company-islands.mjs dumps with --preview: the wild
// island on the left, the owned village on the right. Painter's order by height,
// blocks and wedges filled as the convex hull of their corners seen from above.
import { writeFile } from 'node:fs/promises';
import { deflateSync } from 'node:zlib';

const SCALE = 4; // pixels per stud
const HALF = 140; // studs either side of the island centre, local -Z (the docks) at the bottom
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

function fill(image, width, offset, polygon, color) {
  let minY = Infinity, maxY = -Infinity;
  for (const [, y] of polygon) { minY = Math.min(minY, y); maxY = Math.max(maxY, y); }
  for (let y = Math.max(0, Math.floor(minY)); y <= Math.min(SIZE - 1, Math.ceil(maxY)); y++) {
    const xs = [];
    for (let i = 0; i < polygon.length; i++) {
      const [x1, y1] = polygon[i], [x2, y2] = polygon[(i + 1) % polygon.length];
      if ((y1 <= y + 0.5) !== (y2 <= y + 0.5)) xs.push(x1 + (y + 0.5 - y1) * (x2 - x1) / (y2 - y1));
    }
    xs.sort((a, b) => a - b);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      for (let x = Math.max(0, Math.round(xs[i])); x < Math.min(SIZE, Math.round(xs[i + 1])); x++) {
        const at = (y * width + offset + x) * 3;
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
  const tags = ['Wild', 'Village'];
  const width = SIZE * tags.length;
  const image = Buffer.alloc(width * SIZE * 3);
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
    const offset = tags.indexOf(part.tag) * SIZE;
    if (offset < 0) continue;
    // Island-local +X to the right, -Z (towards Gullhaven) at the bottom of the picture.
    const polygon = hull(part.points.map(q => [(q[0] + HALF) * SCALE, (HALF - q[2]) * SCALE]));
    const light = Math.min(1.15, 0.7 + Math.max(0, part.top) / 60);
    fill(image, width, offset, polygon, part.c.map(c => Math.min(255, Math.round(c * 255 * light))));
  }
  await writeFile(path, png(width, SIZE, image));
}

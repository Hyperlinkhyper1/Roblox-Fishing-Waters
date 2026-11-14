import {readFile,writeFile} from 'node:fs/promises';
import {deflateSync} from 'node:zlib';
const parts=JSON.parse(await readFile('.tmp/parliament-parts.json','utf8'));
const sub = (a, b) => a.map((n, i) => n - b[i]);
const dot = (a, b) => a.reduce((n, v, i) => n + v * b[i], 0);
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const unit = a => { const length = Math.hypot(...a) || 1; return a.map(v => v / length); };
const box = [];
for (const [normal, u, v] of [
  [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 0, 1], [0, 1, 0]],
  [[0, 1, 0], [0, 0, 1], [1, 0, 0]], [[0, -1, 0], [1, 0, 0], [0, 0, 1]],
  [[0, 0, 1], [1, 0, 0], [0, 1, 0]], [[0, 0, -1], [0, 1, 0], [1, 0, 0]],
]) {
  const at = (x, y) => normal.map((n, i) => (n + u[i] * x + v[i] * y) / 2);
  box.push([at(-1, -1), at(1, -1), at(1, 1)], [at(-1, -1), at(1, 1), at(-1, 1)]);
}
const cylinder = [];
for (let i = 0; i < 24; i++) {
  const point = (x, j) => [x / 2, Math.cos(j * Math.PI / 12) / 2, Math.sin(j * Math.PI / 12) / 2];
  const a = point(-1, i), b = point(1, i), c = point(1, i + 1), d = point(-1, i + 1);
  cylinder.push([a, b, c], [a, c, d], [[.5, 0, 0], c, b], [[-.5, 0, 0], a, d]);
}
const sphere = [];
for (let i = 0; i < 12; i++) for (let j = 0; j < 24; j++) {
  const point = (a, b) => [Math.sin(a * Math.PI / 12) * Math.cos(b * Math.PI / 12) / 2, Math.cos(a * Math.PI / 12) / 2, Math.sin(a * Math.PI / 12) * Math.sin(b * Math.PI / 12) / 2];
  sphere.push([point(i, j), point(i + 1, j), point(i + 1, j + 1)], [point(i, j), point(i + 1, j + 1), point(i, j + 1)]);
}
const wedge = [];
const w = (x, y, z) => [x / 2, y / 2, z / 2];
for (const x of [-1, 1]) wedge.push([w(x, -1, -1), w(x, -1, 1), w(x, 1, 1)]);
for (const quad of [
  [w(-1, -1, -1), w(1, -1, -1), w(1, -1, 1), w(-1, -1, 1)],
  [w(-1, -1, 1), w(1, -1, 1), w(1, 1, 1), w(-1, 1, 1)],
  [w(-1, -1, -1), w(-1, 1, 1), w(1, 1, 1), w(1, -1, -1)],
]) wedge.push(quad.slice(0, 3), [quad[0], quad[2], quad[3]]);
const shapes = { block: box, cylinder, sphere, wedge };
function triangles(selected) {
  return selected.flatMap(part => {
    const size = [...part.size];
    if (part.shape === 'cylinder') size[1] = size[2] = Math.min(size[1], size[2]);
    const transform = v => part.position.map((p, i) => p + part.axes.reduce((s, axis, j) => s + axis[i] * v[j] * size[j], 0));
    return (shapes[part.shape] || box).map(tri => ({ points: tri.map(transform), color: part.color, alpha: 1 - part.transparency, neon: part.material.endsWith('.Neon') }));
  }).filter(tri => tri.alpha > .01);
}

const width = 1800, height = 1180;
const image = Buffer.alloc(width * height * 3);
for (let i = 0; i < image.length; i += 3) image.set([225, 223, 214], i);
const light = unit([-.35, .85, .6]);
function render(selected, rect, eye, minXClip = -Infinity) {
  const [ox, oy, panelWidth, panelHeight] = rect;
  const towardEye = unit(eye), right = unit(cross([0, 1, 0], towardEye)), up = unit(cross(towardEye, right));
  const project = p => [dot(p, right), dot(p, up), dot(p, towardEye)];
  const all = triangles(selected).flatMap(tri => {
    if (!Number.isFinite(minXClip)) return [tri];
    const polygon = [];
    for (let i = 0; i < tri.points.length; i++) {
      const a = tri.points[i], b = tri.points[(i + 1) % tri.points.length];
      const insideA = a[0] >= minXClip, insideB = b[0] >= minXClip;
      if (insideA) polygon.push(a);
      if (insideA !== insideB) {
        const t = (minXClip - a[0]) / (b[0] - a[0]);
        polygon.push(a.map((v, index) => v + (b[index] - v) * t));
      }
    }
    return polygon.slice(2).map((p, index) => ({ ...tri, points: [polygon[0], polygon[index + 1], p] }));
  });
  const projected = all.map(tri => tri.points.map(project));
  const points = projected.flat();
  const minX = Math.min(...points.map(p => p[0])), maxX = Math.max(...points.map(p => p[0]));
  const minY = Math.min(...points.map(p => p[1])), maxY = Math.max(...points.map(p => p[1]));
  const scale = Math.min((panelWidth - 70) / (maxX - minX), (panelHeight - 70) / (maxY - minY));
  const cx = (minX + maxX) / 2, cy = (minY + maxY) / 2;
  const depth = new Float32Array(panelWidth * panelHeight).fill(-Infinity);
  const records = all.map((tri, index) => ({ tri, screen: projected[index].map(([x, y, z]) => [(x - cx) * scale + panelWidth / 2, panelHeight / 2 - (y - cy) * scale, z]) }));
  const opaque = records.filter(({ tri }) => tri.alpha >= .999);
  const glass = records.filter(({ tri }) => tri.alpha < .999).sort((a, b) => a.screen.reduce((s, p) => s + p[2], 0) - b.screen.reduce((s, p) => s + p[2], 0));
  for (const { tri, screen: s } of [...opaque, ...glass]) {
    const normal = unit(cross(sub(tri.points[1], tri.points[0]), sub(tri.points[2], tri.points[0])));
    // Two-sided shading also accommodates the small wedge mesh's end faces.
    const shade = tri.neon ? 1.12 : .56 + .44 * Math.abs(dot(normal, light));
    const color = tri.color.map(v => Math.min(255, Math.round(v * shade)));
    const area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
    if (Math.abs(area) < .000001) continue;
    const x0 = Math.max(0, Math.floor(Math.min(...s.map(p => p[0])))), x1 = Math.min(panelWidth - 1, Math.ceil(Math.max(...s.map(p => p[0]))));
    const y0 = Math.max(0, Math.floor(Math.min(...s.map(p => p[1])))), y1 = Math.min(panelHeight - 1, Math.ceil(Math.max(...s.map(p => p[1]))));
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + .5, py = y + .5;
      const a = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
      const b = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
      const c = 1 - a - b;
      if (a < 0 || b < 0 || c < 0) continue;
      const z = a * s[0][2] + b * s[1][2] + c * s[2][2], index = y * panelWidth + x;
      if (z <= depth[index] + .000001) continue;
      if (tri.alpha >= .999) depth[index] = z;
      const offset = ((oy + y) * width + ox + x) * 3;
      for (let channel = 0; channel < 3; channel++) image[offset + channel] = Math.round(color[channel] * tri.alpha + image[offset + channel] * (1 - tri.alpha));
    }
  }
}

render(parts,[0,0,width,530],[.75,.55,1]);
const roof=/Roof|Rooflight|SolarPanel|Atrium|Facade|Canopy|Entrance|VerticalSunFin|Foundation|Lobby|Indoor|Reception|Security|HallBench|ParliamentSign|VisitorPasses|EntryMat|RecessedLight|OpenChamberDoor|OakDoorJamb|DoorLintel|CouncilFloor|CouncilSeats/i;
let main=parts.filter(p=>p.position[0]<25 && p.position[2]<22 && !roof.test(p.name));
main=main.filter(p=>p.name!=='RearWall').concat([{...parts.find(p=>p.name==='RearWall'),size:[94,32,1],position:[-23,16,-61.5]}, {...parts.find(p=>p.name==='Foundation'),size:[94,1,83],position:[-23,-.5,-20]}]);
render(main,[0,540,900,640],[.28,1.05,1]);
let council=parts.filter(p=>p.position[0]>27 && p.position[2]<22 && !/Roof|Rooflight|SolarPanel|VerticalSunFin|DoorLintel|OpenChamberDoor|OakDoorJamb|ParliamentSign/.test(p.name));
council=council.filter(p=>p.name!=='RearWall' && p.name!=='CouncilFloor').concat([{...parts.find(p=>p.name==='RearWall'),size:[44,30,1],position:[48,15,-61.5]}, {...parts.find(p=>p.name==='Foundation'),size:[44,1,83],position:[48,-.5,-20]}]);
render(council,[900,540,900,640],[-.6,.9,1]);

function png(w, h, rgb) {
  const rows = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) rgb.copy(rows, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  const crcTable = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const chunk = (type, data) => {
    const length = Buffer.alloc(4); length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type), data]);
    let crc = 0xffffffff;
    for (const byte of body) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
    const sum = Buffer.alloc(4); sum.writeUInt32BE((crc ^ 0xffffffff) >>> 0);
    return Buffer.concat([length, body, sum]);
  };
  const header = Buffer.alloc(13); header.writeUInt32BE(w); header.writeUInt32BE(h, 4); header[8] = 8; header[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', header), chunk('IDAT', deflateSync(rows)), chunk('IEND', Buffer.alloc(0))]);
}

await writeFile('.tmp/parliament-preview.png',png(width,height,image));

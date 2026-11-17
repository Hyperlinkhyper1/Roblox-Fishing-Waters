import { execFileSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { deflateSync } from 'node:zlib';
import { freezerRuntime } from '../scripts/freezer-test-runtime.mjs';
const ROOT=process.cwd();
const OUT=resolve(ROOT,'.tmp/blackhole-fish-preview-smooth');
mkdirSync(OUT,{recursive:true});
const ids=['VoidlightAngler','EclipseRay','Riftmaw','SingularitySerpent'];
const exporter=String.raw`
local function vectorJson(value)
 return string.format("[%.9g,%.9g,%.9g]", value.X, value.Y, value.Z)
end
local function exportPreview(id)
 local model = assert(FishModels.create(id), id .. ": missing builder")
 local parts, swatches = {}, {}
 local spec = FishModels.loft(id)
 for _, part in model:GetDescendants() do
  if not part:IsA("BasePart") then continue end
  local swatch = part:GetAttribute("LoftSwatch")
  if swatch and not swatches[swatch] then swatches[swatch] = part.Color end
  if spec and part:GetAttribute("LoftFallback") then continue end
  local mesh = part:FindFirstChildOfClass("SpecialMesh")
  local shape = if mesh and mesh.MeshType == "Sphere" then "sphere" elseif part.ClassName == "WedgePart" then "wedge" else "block"
  local color, frame = part.Color, part.CFrame
  local hex = string.format("#%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
  table.insert(parts, string.format('{"s":"%s","p":%s,"z":%s,"r":[%s,%s,%s],"c":"%s","t":%.9g,"m":"%s"}', shape, vectorJson(part.Position), vectorJson(part.Size), vectorJson(frame.RightVector), vectorJson(frame.UpVector), vectorJson(frame.ZVector), hex, part.Transparency, tostring(part.Material)))
 end

 if spec then
  local bands = {
   { 0, 0.34, "Back", "Back", 0 }, { 0.34, 0.42, "Back", "Side", 0.35 },
   { 0.42, 0.48, "Back", "Side", 0.7 }, { 0.48, 0.62, "Side", "Side", 0 },
   { 0.62, 0.68, "Side", "Belly", 0.35 }, { 0.68, 0.74, "Side", "Belly", 0.7 },
   { 0.74, 1, "Belly", "Belly", 0 },
  }
  for _, band in bands do
   local a, c = swatches[band[3]], swatches[band[4]]
   local color = a:Lerp(c, band[5])
   local hex = string.format("#%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
   local function tri(p, q, r)
    table.insert(parts, string.format('{"s":"tri","w":[%s,%s,%s],"c":"%s","t":0}', vectorJson(p), vectorJson(q), vectorJson(r), hex))
   end
   local steps = math.max(2, math.ceil((band[2] - band[1]) * 28))
   for _, side in { -1, 1 } do
    for step = 0, steps - 1 do
     local a0 = side * math.pi * (band[1] + (band[2] - band[1]) * step / steps)
     local a1 = side * math.pi * (band[1] + (band[2] - band[1]) * (step + 1) / steps)
     for index = 1, #spec.rings - 1 do
      local r0, r1 = spec.rings[index], spec.rings[index + 1]
      local p, q = FishModels.loftPoint(r0, a0) * 4, FishModels.loftPoint(r0, a1) * 4
      local r, s = FishModels.loftPoint(r1, a0) * 4, FishModels.loftPoint(r1, a1) * 4
      tri(p, r, s)
      tri(p, s, q)
     end
     local first, last = spec.rings[1], spec.rings[#spec.rings]
     tri(Vector3.new(first.x + 0.006, (first.top + first.bottom) / 2, 0) * 4, FishModels.loftPoint(first, a0) * 4, FishModels.loftPoint(first, a1) * 4)
     tri(Vector3.new(last.x - 0.004, (last.top + last.bottom) / 2, 0) * 4, FishModels.loftPoint(last, a0) * 4, FishModels.loftPoint(last, a1) * 4)
    end
   end
  end
 end

 print(string.format('{"id":"%s","variants":{"Normal":{"parts":[%s],"boundsSize":%s}}}',id, table.concat(parts,","), vectorJson(model:GetAttribute("BoundsSize"))))
end
` + ids.map(id=>'exportPreview("'+id+'")').join('\n');
const runtime=(await freezerRuntime()).replace('return Packing, FishModels', exporter+'\nreturn Packing, FishModels');
const target=join(OUT,'preview.luau');
writeFileSync(target,runtime);
const output=execFileSync('C:/Users/ayden/.lute/bin/lute.exe',['run',target],{encoding:'utf8',maxBuffer:1<<28});
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
    if (part.s === "tri") { out.push({w:part.w, color:hexRgb(part.c), alpha, neon:false}); continue; }
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

// Orthographic views: [right axis, up axis] in world space; depth = right x up.
const VIEWS = [
  ['side (left flank)', [1, 0, 0], [0, 1, 0]],
  ['top (looking down)', [1, 0, 0], [0, 0, -1]],
  ['front (head on)', [0, 0, -1], [0, 1, 0]],
  ['three-quarter', norm([1, 0, -0.75]), norm([0.3, 1, 0.4])],
];
const PANEL = 480;
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


const fishes=[];
for(const line of output.split('\n')){
 if(!line.startsWith('{"id"')) continue;
 const fish=JSON.parse(line); const tris=worldTriangles(fish.variants.Normal.parts); fishes.push({id:fish.id,tris});
 const W=PANEL*2,H=PANEL*2,img=Buffer.alloc(W*H*3);
 for(let i=0;i<W*H;i++)img.set([54,57,76],i*3);
 VIEWS.forEach(([,right,up],v)=>renderPanel(tris,right,up,img,(v%2)*PANEL,Math.floor(v/2)*PANEL,W));
 writeFileSync(join(OUT,fish.id+'.png'),png(W,H,img));
 console.log(fish.id+': '+fish.variants.Normal.parts.length+' parts');
}
// Overview titles use a tiny fixed bitmap alphabet to keep this tool dependency-free.
const FONT={A:['01110','10001','10001','11111','10001','10001','10001'],B:['11110','10001','10001','11110','10001','10001','11110'],C:['01111','10000','10000','10000','10000','10000','01111'],D:['11110','10001','10001','10001','10001','10001','11110'],E:['11111','10000','10000','11110','10000','10000','11111'],F:['11111','10000','10000','11110','10000','10000','10000'],G:['01111','10000','10000','10111','10001','10001','01111'],H:['10001','10001','10001','11111','10001','10001','10001'],I:['11111','00100','00100','00100','00100','00100','11111'],J:['00111','00010','00010','00010','10010','10010','01100'],K:['10001','10010','10100','11000','10100','10010','10001'],L:['10000','10000','10000','10000','10000','10000','11111'],M:['10001','11011','10101','10101','10001','10001','10001'],N:['10001','11001','10101','10011','10001','10001','10001'],O:['01110','10001','10001','10001','10001','10001','01110'],P:['11110','10001','10001','11110','10000','10000','10000'],Q:['01110','10001','10001','10001','10101','10010','01101'],R:['11110','10001','10001','11110','10100','10010','10001'],S:['01111','10000','10000','01110','00001','00001','11110'],T:['11111','00100','00100','00100','00100','00100','00100'],U:['10001','10001','10001','10001','10001','10001','01110'],V:['10001','10001','10001','10001','10001','01010','00100'],W:['10001','10001','10001','10101','10101','10101','01010'],X:['10001','10001','01010','00100','01010','10001','10001'],Y:['10001','10001','01010','00100','00100','00100','00100'],Z:['11111','00001','00010','00100','01000','10000','11111']};
const cols=2,cellH=PANEL+34,W=PANEL*cols,H=cellH*2+32,img=Buffer.alloc(W*H*3);
for(let i=0;i<W*H;i++)img.set([54,57,76],i*3);
function label(text,x,y){for(const ch of text.toUpperCase()){const glyph=FONT[ch];if(glyph)for(let row=0;row<7;row++)for(let col=0;col<5;col++)if(glyph[row][col]==='1')for(let dy=0;dy<2;dy++)for(let dx=0;dx<2;dx++)img.set([235,241,245],((y+row*2+dy)*W+x+col*2+dx)*3);x+=12;}}
label('BLACK HOLE EVENT FISH',18,10);
fishes.forEach((fish,i)=>{const x=i%cols*PANEL,y=Math.floor(i/cols)*cellH+32;label(fish.id.replace(/([a-z])([A-Z])/g,'$1 $2'),x+10,y+8);renderPanel(fish.tris,VIEWS[fish.id === "EclipseRay" ? 1 : 3][1],VIEWS[fish.id === "EclipseRay" ? 1 : 3][2],img,x,y+28,W)});
writeFileSync(join(OUT,'overview.png'),png(W,H,img));
writeFileSync(join(OUT,'README.txt'),'Geometry previews from real FishModels builders, loft rings and color bands. Software rendering approximates smooth skins; Studio lighting and mesh behavior are not shown. Species PNG panels: top-left side, top-right top, bottom-left front, bottom-right three-quarter.');
console.log('Generated fallback overview and '+fishes.length+' four-view contact sheets in '+OUT);

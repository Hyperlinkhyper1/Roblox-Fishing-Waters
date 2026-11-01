// Generates turned-star logo options for Simply Voxelworks into <outDir>.
import { writeFileSync, mkdirSync } from "node:fs";
import { join } from "node:path";

const outDir = process.argv[2];
mkdirSync(outDir, { recursive: true });

const f = (n) => (Math.round(n * 100) / 100).toString();
const rot = ([x, y], deg) => {
  const a = (deg * Math.PI) / 180;
  return [x * Math.cos(a) - y * Math.sin(a), x * Math.sin(a) + y * Math.cos(a)];
};
const pts = (list) => list.map(([x, y]) => `${f(x)},${f(y)}`).join(" ");

const C = {
  violet: "#9155FF",
  blue: "#4F78FF",
  cyan: "#22D3EE",
  amber: "#FFB547",
  ink: "#14122B",
};

const grad = (id, x1 = "0", y1 = "0", x2 = "1", y2 = "1", stops = [C.violet, C.blue, C.cyan]) =>
  `<linearGradient id="${id}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">${stops
    .map((c, i) => `<stop offset="${f(i / (stops.length - 1))}" stop-color="${c}"/>`)
    .join("")}</linearGradient>`;

// Concave four-point sparkle. ry = vertical point reach, rx = horizontal, k = waist control.
function sparkle(rx, ry, k) {
  return [
    `M0,${f(-ry)}`,
    `Q${f(k)},${f(-k)} ${f(rx)},0`,
    `Q${f(k)},${f(k)} 0,${f(ry)}`,
    `Q${f(-k)},${f(k)} ${f(-rx)},0`,
    `Q${f(-k)},${f(-k)} 0,${f(-ry)}Z`,
  ].join(" ");
}

// Isometric cube faces centred at (cx, cy) with hex radius r.
function cube(cx, cy, r) {
  const h = r * Math.cos(Math.PI / 6);
  const top = [[cx, cy - r], [cx + h, cy - r / 2], [cx, cy], [cx - h, cy - r / 2]];
  const left = [[cx - h, cy - r / 2], [cx, cy], [cx, cy + r], [cx - h, cy + r / 2]];
  const right = [[cx + h, cy - r / 2], [cx, cy], [cx, cy + r], [cx + h, cy + r / 2]];
  const hex = [[cx, cy - r], [cx + h, cy - r / 2], [cx + h, cy + r / 2], [cx, cy + r], [cx - h, cy + r / 2], [cx - h, cy - r / 2]];
  return { top, left, right, hex };
}

// Outline of a union of unit grid cells as a single path (holes not expected).
function cellsOutline(cells, u) {
  const key = (x, y) => `${x},${y}`;
  const set = new Set(cells.map(([x, y]) => key(x, y)));
  const edges = new Map(); // start -> end, clockwise per cell, shared edges cancel out
  for (const [x, y] of cells) {
    const sides = [
      [[x, y], [x + 1, y], [x, y - 1]],
      [[x + 1, y], [x + 1, y + 1], [x + 1, y]],
      [[x + 1, y + 1], [x, y + 1], [x, y + 1]],
      [[x, y + 1], [x, y], [x - 1, y]],
    ];
    for (const [a, b, n] of sides) if (!set.has(key(...n))) edges.set(key(...a), b);
  }
  const [startKey] = edges.keys();
  let cur = startKey.split(",").map(Number);
  const loop = [cur];
  for (;;) {
    const next = edges.get(key(...cur));
    if (key(...next) === startKey) break;
    loop.push(next);
    cur = next;
  }
  // drop collinear points
  const simple = loop.filter((p, i) => {
    const a = loop[(i - 1 + loop.length) % loop.length];
    const b = loop[(i + 1) % loop.length];
    return (p[0] - a[0]) * (b[1] - p[1]) !== (p[1] - a[1]) * (b[0] - p[0]);
  });
  return "M" + simple.map(([x, y]) => `${f((x - 0.5) * u)},${f((y - 0.5) * u)}`).join(" L") + "Z";
}

const icon = (body, defs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="-120 -120 240 240" width="240" height="240" role="img" aria-label="Simply Voxelworks">
  <title>Simply Voxelworks</title>
  <defs>${defs}</defs>
${body}
</svg>
`;

const designs = {};

// 1 — Nova Cube: tall turned sparkle with an isometric cube sitting in a cut-out at its heart.
{
  const c = cube(0, 0, 21);
  designs["s1-nova-cube"] = icon(
    `  <mask id="m1"><rect x="-120" y="-120" width="240" height="240" fill="#fff"/><polygon points="${pts(cube(0, 0, 28).hex)}" fill="#000"/></mask>
  <path d="${sparkle(78, 112, 7)}" transform="rotate(16)" fill="url(#g1)" mask="url(#m1)"/>
  <polygon points="${pts(c.top)}" fill="${C.amber}"/>
  <polygon points="${pts(c.left)}" fill="#F08A1C"/>
  <polygon points="${pts(c.right)}" fill="#C96A0E"/>`,
    grad("g1"),
  );
}

// 2 — Pixel Spark: sparkle drawn in voxels, turned, with one stray voxel breaking off.
{
  const cells = [];
  for (let x = -3; x <= 3; x++)
    for (let y = -3; y <= 3; y++)
      if (Math.abs(x) + Math.abs(y) <= 2 || x === 0 || y === 0) cells.push([x, y]);
  const u = 26;
  const [sx, sy] = rot([2.6 * u, -2.6 * u], 18);
  const pixelSpark = (gradDef, voxel) =>
    icon(
      `  <path d="${cellsOutline(cells, u)}" transform="rotate(18)" fill="url(#g2)"/>
  <rect x="${f(sx - u / 2)}" y="${f(sy - u / 2)}" width="${u}" height="${u}" transform="rotate(18 ${f(sx)} ${f(sy)})" fill="${voxel}"/>`,
      gradDef,
    );
  designs["s2-pixel-spark"] = pixelSpark(grad("g2"), C.amber);
  // Orange/green palette variants (greens/oranges match the earlier voxel cube options).
  designs["s2b-pixel-spark-green"] = pixelSpark(grad("g2", "0", "0", "1", "1", ["#6DC694", "#34B06A", "#1F8A4C"]), "#F5892A");
  designs["s2c-pixel-spark-orange"] = pixelSpark(grad("g2", "0", "0", "1", "1", ["#FFB347", "#F5892A", "#D9601A"]), "#34B06A");
  designs["s2d-pixel-spark-blend"] = pixelSpark(grad("g2", "0", "1", "1", "0", ["#1F9A55", "#7CC444", "#F5A623", "#F5892A"]), "#34B06A");
}

// 2c refinements — orange pixel spark with a better star: curved stepped silhouette, voxel depth, pixel shine.
{
  const turn = 18;
  const orange = grad("g5", "0", "0", "1", "1", ["#FFC15E", "#F5892A", "#E0661C"]);
  const grid = (r, keep) => {
    const out = [];
    for (let x = -r; x <= r; x++) for (let y = -r; y <= r; y++) if (keep(Math.abs(x), Math.abs(y))) out.push([x, y]);
    return out;
  };
  // Concave sparkle in pixels: cells under the hyperbola |x|·|y| <= k.
  const curved = grid(6, (x, y) => x * y <= 4);
  const classic = grid(3, (x, y) => x + y <= 2 || x === 0 || y === 0);
  const centre = (r) => grid(r, (x, y) => x + y <= r);

  // Star at grid size u; depth extrudes a darker slab along the turned "down" axis.
  const spark = ({ cells, u, depth = 0, shine = [], core = false, voxelAt, voxelSize }) => {
    const d = cellsOutline(cells, u);
    const [vx, vy] = [voxelAt[0] * u, voxelAt[1] * u];
    const vs = voxelSize * u;
    const vrect = (dy, fill) =>
      `<rect x="${f(vx - vs / 2)}" y="${f(vy - vs / 2 + dy)}" width="${f(vs)}" height="${f(vs)}" fill="${fill}"/>`;
    let g = "";
    if (depth) g += `    <path d="${d}" transform="translate(0 ${f(depth)})" fill="#B4500E"/>\n`;
    g += `    <path d="${d}" fill="url(#g5)"/>\n`;
    if (shine.length) g += `    <path d="${cellsOutline(shine, u)}" fill="#FFD37A"/>\n`;
    if (core) g += `    <rect x="${f(-u / 2)}" y="${f(-u / 2)}" width="${f(u)}" height="${f(u)}" fill="#FFF3D6"/>\n`;
    if (depth) g += `    ${vrect(depth, "#1E7A45")}\n`;
    g += `    ${vrect(0, "#34B06A")}`;
    return icon(`  <g transform="rotate(${turn})${depth ? ` translate(0 ${f(-depth / 2)})` : ""}">\n${g}\n  </g>`, orange);
  };

  designs["s2c1-curved"] = spark({ cells: curved, u: 16, voxelAt: [4.5, -4.5], voxelSize: 1.7 });
  designs["s2c2-depth"] = spark({ cells: classic, u: 24, depth: 10, voxelAt: [2.6, -2.6], voxelSize: 1 });
  designs["s2c3-shine"] = spark({ cells: classic, u: 26, shine: centre(1), core: true, voxelAt: [2.6, -2.6], voxelSize: 1 });
  designs["s2c4-depth-shine"] = spark({ cells: classic, u: 24, depth: 10, shine: centre(1), core: true, voxelAt: [2.6, -2.6], voxelSize: 1 });
}

// 3 — Facet Turn: faceted four-point star, light/dark halves give it a spin.
{
  const R = 108;
  const w = 26;
  const turn = 14;
  let body = "";
  for (let i = 0; i < 4; i++) {
    const a = i * 90 + turn;
    const tip = rot([0, -R], a);
    const lft = rot([-w, -w], a);
    const rgt = rot([w, -w], a);
    body += `  <polygon points="${pts([[0, 0], tip, rgt])}" fill="url(#g3a)"/>\n`;
    body += `  <polygon points="${pts([[0, 0], lft, tip])}" fill="url(#g3b)"/>\n`;
  }
  designs["s3-facet-turn"] = icon(
    body.trimEnd(),
    grad("g3a", "0", "0", "1", "1", [C.violet, C.blue]) + grad("g3b", "0", "0", "1", "1", ["#B9A8FF", C.cyan]),
  );
}

// 4 — Spark + Voxel: clean turned sparkle with a tiny cube orbiting its upper right.
{
  const c = cube(64, -66, 20);
  designs["s4-spark-voxel"] = icon(
    `  <path d="${sparkle(80, 96, 8)}" transform="translate(-14 14) rotate(-14)" fill="url(#g4)"/>
  <polygon points="${pts(c.top)}" fill="#FFD27A"/>
  <polygon points="${pts(c.left)}" fill="${C.amber}"/>
  <polygon points="${pts(c.right)}" fill="#E08A16"/>`,
    grad("g4", "0", "1", "1", "0"),
  );
}

for (const [name, svg] of Object.entries(designs)) writeFileSync(join(outDir, `${name}.svg`), svg);

// Preview: each mark on light/dark, as an app tile, and in a wordmark lockup.
const inner = (svg) => svg.replace(/^<svg[^>]*>/, "").replace(/<\/svg>\s*$/, "").replace(/<title>.*?<\/title>/, "");
const uniq = (svg, n) => svg.replace(/id="(\w+)"/g, `id="$1_${n}"`).replace(/url\(#(\w+)\)/g, `url(#$1_${n})`);
let n = 0;
const embed = (name, size, extra = "") => {
  const s = uniq(inner(designs[name]), n++);
  return `<svg viewBox="-120 -120 240 240" width="${size}" height="${size}" ${extra}>${s}</svg>`;
};
const only = process.argv[3];
const rows = Object.keys(designs)
  .filter((name) => !only || name.startsWith(only))
  .map(
    (name) => `<section>
  <h2>${name}.svg</h2>
  <div class="row">
    <div class="tile light">${embed(name, 180)}</div>
    <div class="tile dark">${embed(name, 180)}</div>
    <div class="app">${embed(name, 92)}</div>
    <div class="small">${embed(name, 32)}${embed(name, 20)}</div>
  </div>
  <div class="lockups">
    <div class="lockup light">${embed(name, 64)}<div class="word"><span>Simply</span>Voxelworks</div></div>
    <div class="lockup dark">${embed(name, 64)}<div class="word"><span>Simply</span>Voxelworks</div></div>
  </div>
</section>`,
  )
  .join("\n");
writeFileSync(
  join(outDir, only ? `preview-${only}.html` : "preview.html"),
  `<!doctype html><html><head><meta charset="utf-8"><title>Turned Star Logos</title>
<style>
body{margin:0;padding:32px;background:#ECECF3;font-family:"Segoe UI",Inter,system-ui,sans-serif;color:${C.ink}}
h2{font-size:14px;font-weight:600;margin:0 0 12px;opacity:.6}
section{margin-bottom:40px}
.row,.lockups{display:flex;gap:16px;align-items:center;flex-wrap:wrap}
.lockups{margin-top:16px}
.tile{width:220px;height:220px;border-radius:20px;display:grid;place-items:center}
.light{background:#fff}.dark{background:${C.ink};color:#fff}
.app{width:128px;height:128px;border-radius:30px;background:linear-gradient(160deg,#1E1A3F,#0B0A1A);display:grid;place-items:center;box-shadow:0 8px 24px #0003}
.small{display:flex;gap:12px;align-items:center;background:#fff;padding:16px;border-radius:12px}
.lockup{display:flex;align-items:center;gap:14px;padding:20px 28px;border-radius:16px}
.word{font-size:30px;font-weight:700;letter-spacing:-.02em;line-height:1}
.word span{display:block;font-size:13px;font-weight:600;letter-spacing:.32em;text-transform:uppercase;opacity:.55;margin-bottom:5px}
</style></head><body>
${rows}
</body></html>
`,
);
console.log("wrote", Object.keys(designs).length, "designs to", outDir);

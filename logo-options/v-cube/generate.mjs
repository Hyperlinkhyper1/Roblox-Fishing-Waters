// Simply Voxelworks — "V-cube" mark: an isometric cube; the green and orange side faces form a V.
// Usage: node generate.mjs
import { writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const f = (n) => +n.toFixed(2);

// Isometric hexagon, radius R, centred on (cx, cy)
const R = 80, cx = 100, cy = 118;
const s = (R * Math.sqrt(3)) / 2;
const P = {
  top: [cx, cy - R], ur: [cx + s, cy - R / 2], lr: [cx + s, cy + R / 2],
  bot: [cx, cy + R], ll: [cx - s, cy + R / 2], ul: [cx - s, cy - R / 2], c: [cx, cy],
};

// Inset a convex polygon (clockwise in screen space) by d
function inset(pts, d) {
  const n = pts.length;
  const lines = pts.map((a, i) => {
    const b = pts[(i + 1) % n];
    const dx = b[0] - a[0], dy = b[1] - a[1], len = Math.hypot(dx, dy);
    const nx = -dy / len, ny = dx / len; // inward normal for clockwise winding (y down)
    return [[a[0] + nx * d, a[1] + ny * d], [dx, dy]];
  });
  return lines.map((l1, i) => {
    const l0 = lines[(i - 1 + n) % n];
    const [p, r] = l0, [q, t] = l1;
    const cross = r[0] * t[1] - r[1] * t[0];
    const u = ((q[0] - p[0]) * t[1] - (q[1] - p[1]) * t[0]) / cross;
    return [p[0] + r[0] * u, p[1] + r[1] * u];
  });
}

// Rounded-corner path for a polygon: each corner becomes a quadratic curve of radius-ish r
function rounded(pts, r) {
  const n = pts.length;
  let d = "";
  pts.forEach((p, i) => {
    const a = pts[(i - 1 + n) % n], b = pts[(i + 1) % n];
    const ta = Math.min(r / Math.hypot(a[0] - p[0], a[1] - p[1]), 0.5);
    const tb = Math.min(r / Math.hypot(b[0] - p[0], b[1] - p[1]), 0.5);
    const p1 = [p[0] + (a[0] - p[0]) * ta, p[1] + (a[1] - p[1]) * ta];
    const p2 = [p[0] + (b[0] - p[0]) * tb, p[1] + (b[1] - p[1]) * tb];
    d += `${i ? "L" : "M"}${f(p1[0])},${f(p1[1])} Q${f(p[0])},${f(p[1])} ${f(p2[0])},${f(p2[1])} `;
  });
  return d + "Z";
}

const gap = 4.5, corner = 9;
const left = rounded(inset([P.ul, P.c, P.bot, P.ll], gap), corner);
const right = rounded(inset([P.c, P.ur, P.lr, P.bot], gap), corner);

// Top face: same inset as the sides so every corner lines up into one cube
const top = rounded(inset([P.top, P.ur, P.c, P.ul], gap), corner);

const palette = {
  greenHi: "#4FD889", green: "#22B35E", greenLo: "#178A47",
  orangeHi: "#FFB054", orange: "#FF8A1F", orangeLo: "#E2660F",
  topA: "#9BF0B4", topB: "#FFC56B",
};

function mark(id) {
  return `<defs>
    <linearGradient id="${id}L" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="${palette.greenHi}"/><stop offset="1" stop-color="${palette.greenLo}"/></linearGradient>
    <linearGradient id="${id}R" x1="1" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="${palette.orangeHi}"/><stop offset="1" stop-color="${palette.orangeLo}"/></linearGradient>
    <linearGradient id="${id}T" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${palette.topA}"/><stop offset="1" stop-color="${palette.topB}"/></linearGradient>
  </defs>
  <path d="${left}" fill="url(#${id}L)"/>
  <path d="${right}" fill="url(#${id}R)"/>
  <path d="${top}" fill="url(#${id}T)"/>`;
}

// Content spans roughly y 33..198, x 31..169 — frame it square
const vb = "0 18 200 200";
const svg = (body, attrs = "") =>
  `<svg xmlns="http://www.w3.org/2000/svg" ${attrs} role="img" aria-label="Simply Voxelworks">\n  <title>Simply Voxelworks</title>\n  ${body}\n</svg>\n`;

const files = {
  "mark.svg": svg(mark("m"), `viewBox="${vb}" width="200" height="200"`),
  "app-icon-dark.svg": svg(
    `<rect width="512" height="512" rx="116" fill="#12161A"/>\n  <g transform="translate(256 256) scale(1.9) translate(-100 -118)">${mark("d")}</g>`,
    `viewBox="0 0 512 512" width="512" height="512"`),
  "app-icon-light.svg": svg(
    `<rect width="512" height="512" rx="116" fill="#F6F3EC"/>\n  <g transform="translate(256 256) scale(1.9) translate(-100 -118)">${mark("l")}</g>`,
    `viewBox="0 0 512 512" width="512" height="512"`),
};

for (const [name, content] of Object.entries(files)) writeFileSync(join(here, name), content);

writeFileSync(join(here, "preview.html"), `<!doctype html><meta charset="utf-8"><title>V-cube preview</title>
<style>body{margin:0;padding:32px;display:flex;flex-wrap:wrap;gap:32px;align-items:center;background:#888;font-family:system-ui}
.t{padding:24px;border-radius:16px}.d{background:#12161A}.w{background:#fff}img{display:block}</style>
<div class="t w"><img src="mark.svg" width="240"></div>
<div class="t d"><img src="mark.svg" width="240"></div>
<img src="app-icon-dark.svg" width="240"><img src="app-icon-light.svg" width="240">
<div class="t w" style="display:flex;gap:16px;align-items:end"><img src="mark.svg" width="64"><img src="mark.svg" width="32"><img src="mark.svg" width="16"></div>
<div class="t d" style="display:flex;gap:16px;align-items:end"><img src="app-icon-dark.svg" width="64"><img src="app-icon-dark.svg" width="32"><img src="app-icon-dark.svg" width="16"></div>`);
console.log("wrote", Object.keys(files).join(", "), "+ preview.html");

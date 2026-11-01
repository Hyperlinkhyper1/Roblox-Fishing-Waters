// Builds the final Simply Voxelworks logo set from ../star/s2c4-depth-shine.svg.
// Usage: node build.mjs [path-to-@resvg/resvg-js]   (renderer path optional; without it only SVGs are written)
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
const source = readFileSync(join(here, "../star/s2c4-depth-shine.svg"), "utf8");
const mark = source
  .replace(/^<svg[^>]*>/, "")
  .replace(/<\/svg>\s*$/, "")
  .replace(/<title>.*?<\/title>/, "")
  .trim();

const INK = "#14122B";
const FONT = `'Segoe UI', 'Inter', system-ui, sans-serif`;
const uid = (svg, s) => svg.replace(/id="(\w+)"/g, `id="$1${s}"`).replace(/url\(#(\w+)\)/g, `url(#$1${s})`);

const svg = (w, h, body, viewBox = `0 0 ${w} ${h}`) =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${viewBox}" width="${w}" height="${h}" role="img" aria-label="Simply Voxelworks">
  <title>Simply Voxelworks</title>
${body}
</svg>
`;

// Mark placed with its centre at (cx, cy), scaled so the -100..100 artwork spans `size`.
const place = (cx, cy, size, suffix) =>
  `  <g transform="translate(${cx} ${cy}) scale(${size / 200})">\n    ${uid(mark, suffix)}\n  </g>`;

const lockup = (dark) => {
  const fg = dark ? "#FFFFFF" : INK;
  const bg = dark ? `  <rect width="540" height="200" rx="28" fill="${INK}"/>\n` : "";
  return svg(
    540,
    200,
    `${bg}${place(100, 100, 150, dark ? "d" : "l")}
  <text x="196" y="88" font-family="${FONT}" font-size="22" font-weight="600" letter-spacing="7" fill="${fg}" fill-opacity="0.55">SIMPLY</text>
  <text x="193" y="146" font-family="${FONT}" font-size="60" font-weight="700" letter-spacing="-1.2" fill="${fg}">Voxelworks</text>`,
  );
};

const files = {
  "icon.svg": svg(200, 200, `  ${mark}`, "-100 -100 200 200"),
  "app-icon.svg": svg(
    512,
    512,
    `  <defs><linearGradient id="tile" x1="0" y1="0" x2="0.4" y2="1"><stop offset="0" stop-color="#241F4A"/><stop offset="1" stop-color="#0B0A1A"/></linearGradient></defs>
  <rect width="512" height="512" rx="112" fill="url(#tile)"/>
${place(256, 256, 380, "a")}`,
  ),
  "lockup-light.svg": lockup(false),
  "lockup-dark.svg": lockup(true),
};
for (const [name, content] of Object.entries(files)) writeFileSync(join(here, name), content);

const rendererPath = process.argv[2];
if (rendererPath) {
  const { Resvg } = createRequire(import.meta.url)(rendererPath);
  const png = (name, out, width) => {
    const r = new Resvg(files[name], { fitTo: { mode: "width", value: width }, font: { loadSystemFonts: true } });
    writeFileSync(join(here, out), r.render().asPng());
  };
  png("icon.svg", "icon-1024.png", 1024);
  png("icon.svg", "icon-512.png", 512);
  png("icon.svg", "favicon-64.png", 64);
  png("icon.svg", "favicon-32.png", 32);
  png("app-icon.svg", "app-icon-512.png", 512);
  png("lockup-light.svg", "lockup-light@2x.png", 1080);
  png("lockup-dark.svg", "lockup-dark@2x.png", 1080);
}
console.log("built", Object.keys(files).join(", "), rendererPath ? "+ PNGs" : "");

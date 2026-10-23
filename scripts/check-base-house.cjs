// Execute the production house and prop builders against recording Roblox mocks.
// These checks validate emitted geometry, not Roblox rendering or live physics.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const previewIndex = process.argv.indexOf("--preview");
const previewPath = previewIndex < 0 ? null : process.argv[previewIndex + 1];
if (previewIndex >= 0 && !previewPath) throw new Error("--preview requires an output JSON path");
const read = (name) => fs.readFileSync(path.join(root, name), "utf8");
const primitiveSource = read("scripts/harbour-geometry.luau").split("local CFrame = {}")[0];
const geometryHarness = read("scripts/drydock-geometry.luau");
const mockSource = geometryHarness.split("local function loadLowPoly()")[0];
const geometryHelpers = geometryHarness.slice(
  geometryHarness.indexOf("local EPS = 1e-5"),
  geometryHarness.indexOf("-- Limit construction to the plaza")
);
if (!mockSource.includes("-- SHARED_PRIMITIVES --") || !geometryHelpers.includes("local function overlaps")) {
  throw new Error("Reusable geometry mock hooks changed");
}
let harness = read("scripts/base-house-geometry.luau")
  .replace("-- RECORDING_MOCKS --", () => mockSource.replace("-- SHARED_PRIMITIVES --", () => primitiveSource))
  .replace("-- GEOMETRY_HELPERS --", () => geometryHelpers)
  .replace("false -- EXPORT_PREVIEW --", previewPath ? "true" : "false");
for (const [name, sourcePath] of Object.entries({
  LOWPOLY: "src/server/Map/LowPoly.luau",
  PROPS: "src/server/Map/Props.luau",
  FISHFREEZERGEOMETRY: "src/server/Map/FishFreezerGeometry.luau",
  FISHFREEZER: "src/server/Map/FishFreezer.luau",
  IMPORTEDMODEL: "src/server/Map/ImportedModel.luau",
  SHOPDESKGEOMETRY: "src/server/Map/ShopDeskGeometry.luau",
  CASHREGISTERGEOMETRY: "src/server/Map/CashRegisterGeometry.luau",
  SHOPDESK: "src/server/Map/ShopDesk.luau",
  BASEHOUSE: "src/server/Map/BaseHouse.luau",
})) {
  const source = read(sourcePath).replace(
    /local (\w+) = require\(script\.Parent\.(?:Parent\.)?(\w+)\)/g,
    "local $1 = dependencies.$2"
  );
  const marker = `-- ${name}_SOURCE --`;
  if (!harness.includes(marker)) throw new Error(`Missing ${name} source hook`);
  harness = harness.replace(marker, () => source);
}
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "base-house-"));
const target = path.join(temporary, "test.luau");
try {
  fs.writeFileSync(target, harness);
  const result = spawnSync(process.env.LUTE || "lute.exe", ["run", target], {
    cwd: root,
    encoding: "utf8",
    maxBuffer: 8 * 1024 * 1024,
    timeout: 60000,
  });
  let output = result.stdout || "";
  const previewMatch = output.match(/BASE_HOUSE_JSON_BEGIN\r?\n([\s\S]*?)\r?\nBASE_HOUSE_JSON_END\r?\n?/);
  if (previewMatch) output = output.replace(previewMatch[0], "");
  if (output) process.stdout.write(output);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (previewPath && result.status === 0) {
    if (!previewMatch) throw new Error("Production house preview export was missing");
    const preview = JSON.parse(previewMatch[1]);
    fs.writeFileSync(path.resolve(previewPath), JSON.stringify(preview));
    process.stdout.write(`Actual house geometry exported to ${path.resolve(previewPath)}\n`);
  }
  process.exitCode = result.status ?? 1;
} finally {
  fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}

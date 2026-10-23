// Exercise the production geometry with the project's recording Roblox mock.
// Construction and clearance checks do not prove Studio rendering or physics.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "src/server/FishingBoat.luau"), "utf8").replace(
  'local ab, ac, bc = b - a, c - a, c - b',
  'table.insert(hullTriangles, {name = name, a = a, b = b, c = c})\n\t\tlocal ab, ac, bc = b - a, c - a, c - b',
);
const sharedMock = fs.readFileSync(path.join(__dirname, "shipwright-model.luau"), "utf8")
  .split("local function loadShipwright()")[0]
  .replace('kind == "WedgePart" or kind == "VehicleSeat"', 'kind == "WedgePart" or kind == "VehicleSeat" or kind == "Seat"');
const harness = fs.readFileSync(path.join(__dirname, "fishing-boat-model.luau"), "utf8");
const marker = "-- FISHING_BOAT_SOURCE --";
if (!harness.includes(marker)) throw new Error("Missing FishingBoat harness source marker");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "fishing-boat-model-"));
const target = path.join(temporary, "test.luau");
try {
  fs.writeFileSync(target, sharedMock + harness.replace(marker, () => source));
  const result = spawnSync(process.env.LUTE || "lute.exe", ["run", target], { stdio: "inherit" });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (fs.existsSync(target)) fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}

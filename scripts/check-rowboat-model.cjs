// Execute production Rowboat source against the recording Roblox mock.
// This validates construction, not Roblox rendering or live physics.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "src/server/Rowboat.luau"), "utf8");
const harness = fs.readFileSync(path.join(__dirname, "rowboat-model.luau"), "utf8");
const marker = "-- ROWBOAT_SOURCE --";
if (!harness.includes(marker)) throw new Error("Missing Rowboat harness source marker");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "rowboat-model-"));
const target = path.join(temporary, "test.luau");
try {
  fs.writeFileSync(target, harness.replace(marker, () => source).replace("-- BUOYANCY_SOURCE --", () => {
    const service = fs.readFileSync(path.join(root, "src/server/BoatService.luau"), "utf8");
    const start = service.indexOf("local normal = wave.normal");
    const end = service.indexOf("local direction = flatHeading.LookVector", start);
    if (start < 0 || end < 0) throw new Error("Buoyancy source markers changed");
    return service.slice(start, end);
  }));
  const result = spawnSync(process.env.LUTE || "lute.exe", ["run", target], { stdio: "inherit" });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (fs.existsSync(target)) fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}

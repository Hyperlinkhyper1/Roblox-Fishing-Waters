// Execute production Shipwright source against the recording Roblox mock.
// This validates construction, not Roblox rendering or live physics.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const root = path.resolve(__dirname, "..");
const source = fs.readFileSync(path.join(root, "src/server/Map/Shipwright.luau"), "utf8");
const harness = fs.readFileSync(path.join(__dirname, "shipwright-model.luau"), "utf8");
const marker = "-- SHIPWRIGHT_SOURCE --";
if (!harness.includes(marker)) throw new Error("Missing Shipwright harness source marker");
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "shipwright-model-"));
const target = path.join(temporary, "test.luau");
try {
  fs.writeFileSync(target, harness.replace(marker, () => source));
  const result = spawnSync(process.env.LUTE || "lute.exe", ["run", target], { stdio: "inherit" });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  if (fs.existsSync(target)) fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}

// Exercise the production model with the same Roblox recording mock as the boat tests.
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const root = path.resolve(__dirname, "..");
const mock = fs.readFileSync(path.join(__dirname, "shipwright-model.luau"), "utf8")
  .split("local function loadShipwright()")[0]
  .replace('kind == "WedgePart" or kind == "VehicleSeat"', 'kind == "WedgePart" or kind == "VehicleSeat" or kind == "Seat"');
const source = fs.readFileSync(path.join(root, "src/server/SmallFerry.luau"), "utf8");
const checks = `
local Ferry = (function()
${source}
end)()
for _, anchored in { false, true } do
  local ferry = Ferry.build(CFrame.new(40, 10, -30) * CFrame.Angles(0, math.pi / 2, 0), anchored)
  assert(ferry.PrimaryPart and ferry.PrimaryPart.Name == "HullRoot", "Ferry needs a primary hull root")
  assert(ferry:GetAttribute("PassengerSeats") == 4, "Ferry declares four passenger seats")
  local helm = ferry:FindFirstChild("HelmSeat", true)
  assert(helm and helm:IsA("VehicleSeat") and helm.Disabled == anchored, "Helm is usable on the launched ferry")
  for i = 1, 4 do
    local seat = ferry:FindFirstChild("FerryPassengerSeat" .. i, true)
    assert(seat and seat:IsA("Seat") and seat.Disabled == anchored, "Each passenger has a usable seat")
  end
  for _, part in ferry:GetDescendants() do
    if part:IsA("BasePart") then
      assert(part.Anchored == anchored, "Preview and launched parts share their anchoring state")
      if part ~= ferry.PrimaryPart then
        local weld = part:FindFirstChildOfClass("WeldConstraint")
        assert(weld and weld.Part0 == ferry.PrimaryPart and weld.Part1 == part, "Every part joins the hull assembly")
      end
    end
  end
end
print("Small ferry model: helm, four passenger seats and welded assembly verified (recording mock).")
`;
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), "small-ferry-"));
const target = path.join(temporary, "test.luau");
try {
  fs.writeFileSync(target, mock + checks);
  const result = spawnSync(process.env.LUTE || "lute.exe", ["run", target], { stdio: "inherit" });
  if (result.error) throw result.error;
  process.exitCode = result.status ?? 1;
} finally {
  fs.unlinkSync(target);
  fs.rmdirSync(temporary);
}

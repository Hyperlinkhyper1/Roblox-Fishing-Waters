// Builds the showcase pets (src/shared/PetModels.luau) in the boat furniture Roblox mock, runs a
// minute of their client animation (PetModels.rig / PetModels.step) and checks the rig: part
// count, rest pose, symmetry, every behaviour firing, nothing flying off or turning NaN.
//   node scripts/check-pet-models.mjs [--render <outDir>]
// --render writes PNG sheets of the macaw at rest, mid wing beat and mid squawk: front, right
// side, back and front three-quarter.
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { deflateSync } from 'node:zlib';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const read = (path) => readFileSync(path, 'utf8').replace(/\r\n/g, '\n');
const args = process.argv.slice(2);
const renderAt = args.indexOf('--render');
const OUT = renderAt >= 0 ? resolve(args[renderAt + 1]) : null;

const driver = String.raw`
function instanceMethods.AddTag(self, tag) rawget(self, "_attributes")["__tag_" .. tag] = true end
function instanceMethods.GetAttributes(self) return rawget(self, "_attributes") end
local function num(x) return string.format("%.4f", x) end
local function vec(v) return "[" .. num(v.X) .. "," .. num(v.Y) .. "," .. num(v.Z) .. "]" end
local function dump(model)
	local out = {}
	for _, piece in model:GetDescendants() do
		if piece:IsA("BasePart") then
			local shape = "block"
			if piece:FindFirstChild("SpecialMesh") then shape = "sphere"
			elseif piece.Shape and piece.Shape.Name == "Cylinder" then shape = "cylinder"
			elseif piece.Shape and piece.Shape.Name == "Ball" then shape = "sphere" end
			local c = piece.CFrame
			table.insert(out, '{"n":"' .. piece.Name .. '","s":"' .. shape .. '","z":' .. vec(piece.Size)
				.. ',"p":' .. vec(c.Position) .. ',"r":[' .. vec(c.RightVector) .. "," .. vec(c.UpVector) .. ","
				.. vec(c.ZVector) .. '],"c":"#' .. piece.Color:ToHex() .. '","t":' .. num(piece.Transparency or 0) .. "}")
		end
	end
	return "[" .. table.concat(out, ",") .. "]"
end

local folder = Instance.new("Folder")
local frame = CFrame.new(10, 20, 30) * CFrame.Angles(0, 0.7, 0)
local SCALE = 1.25
local model = PetModels.scarletMacaw(folder, frame, SCALE)
local parts, rest = {}, {}
for _, piece in model:GetDescendants() do
	if piece:IsA("BasePart") then table.insert(parts, piece); rest[piece] = piece.CFrame end
end
print("COUNT " .. #parts .. " " .. tostring(model:GetAttribute("PartCount")) .. " " .. tostring(model:GetAttribute("__tag_" .. PetModels.TAG)))
print("REST " .. dump(model))

-- Symmetry: every part on one side has a mirror twin on the other, in the pet's own frame
local unmatched = 0
for _, a in parts do
	local pa = frame:PointToObjectSpace(a.CFrame.Position)
	if math.abs(pa.X) > 0.01 then
		local found = false
		for _, b in parts do
			local pb = frame:PointToObjectSpace(b.CFrame.Position)
			if b.Name == a.Name and math.abs(pb.X + pa.X) < 0.01 and math.abs(pb.Y - pa.Y) < 0.01 and math.abs(pb.Z - pa.Z) < 0.01 then
				found = true
				break
			end
		end
		if not found then unmatched += 1; print("UNMATCHED " .. a.Name .. " " .. vec(pa)) end
	end
end
print("SYMMETRY " .. unmatched)

local t0 = 1000
local rig = PetModels.rig(model, t0)
print("RIG " .. tostring(rig ~= nil) .. " " .. (rig and #rig.parts or 0) .. " " .. (rig and #rig.lids or 0))

-- Stepping at the rest instant only breathes
local moved, worst = PetModels.step(rig, t0 + 0.01)
local restError = 0
for i, piece in moved do
	restError = math.max(restError, (worst[i].Position - rest[piece].Position).Magnitude)
end
print("RESTERROR " .. num(restError))

-- A minute at 30 fps, applying each frame as BulkMoveTo would
local function find(name)
	for _, piece in rig.parts do if piece.Name == name then return piece end end
end
local tip, jaw, headPart = find("FeatherTip"), find("LowerBeak"), find("Skull")
local tipRest, jawRest, headRest = rest[tip].Position, rest[jaw].Position, rest[headPart].Position
local maxTip, maxJaw, maxHead, maxReach, blinks, nan = 0, 0, 0, 0, 0, false
local wasClosed = false
local snaps = { flap = t0 + 4 + 4.25 / 4.2, squawk = t0 + 2.5 + 0.3 }
local taken = {}
local origin = frame.Position
for k = 1, 30 * 60 do
	local t = t0 + k / 30
	local list, frames = PetModels.step(rig, t)
	for i, piece in list do
		local p = frames[i].Position
		if p.X ~= p.X or p.Y ~= p.Y or p.Z ~= p.Z then nan = true end
		maxReach = math.max(maxReach, (p - origin).Magnitude)
		piece.CFrame = frames[i]
	end
	maxTip = math.max(maxTip, (tip.CFrame.Position - tipRest).Magnitude)
	maxJaw = math.max(maxJaw, (jaw.CFrame.Position - jawRest).Magnitude)
	maxHead = math.max(maxHead, (headPart.CFrame.Position - headRest).Magnitude)
	if rig.lidsClosed and not wasClosed then blinks += 1 end
	wasClosed = rig.lidsClosed
	for name, at in snaps do
		if not taken[name] and t >= at then
			taken[name] = true
			print("POSE_" .. string.upper(name) .. " " .. dump(model))
		end
	end
end
print("MOTION " .. num(maxTip) .. " " .. num(maxJaw) .. " " .. num(maxHead) .. " " .. num(maxReach) .. " " .. blinks .. " " .. tostring(nan))
`;

const bundle = [
  read(join(ROOT, 'scripts', 'boat-furniture-mock.luau')),
  'local PetModels = (function()\n' + read(join(ROOT, 'src', 'shared', 'PetModels.luau')) + '\nend)()',
  driver,
].join('\n');
const work = mkdtempSync(join(tmpdir(), 'pet-models-'));
let output;
try {
  writeFileSync(join(work, 'pets.luau'), bundle);
  output = execFileSync(process.env.LUTE ?? 'lute', ['run', join(work, 'pets.luau')], { encoding: 'utf8', maxBuffer: 1 << 30 });
} finally {
  rmSync(work, { recursive: true, force: true });
}
const line = (key) => output.split('\n').find((l) => l.startsWith(key + ' '))?.slice(key.length + 1).trim();

const failures = [];
const check = (ok, message) => ok || failures.push(message);
const [count, attribute, tagged] = line('COUNT').split(' ');
check(count === attribute, `PartCount attribute ${attribute} does not match the ${count} parts built`);
check(+count <= 200, `${count} parts is more than the 200 a pet may use`);
check(tagged === 'true', 'the macaw is not tagged for ShowcasePets');
check(line('SYMMETRY') === '0', `${line('SYMMETRY')} parts have no mirror twin:\n` + output.split('\n').filter((l) => l.startsWith('UNMATCHED')).join('\n'));
const [rigged, rigParts, lids] = line('RIG').split(' ');
check(rigged === 'true', 'PetModels.rig returned nil for a complete macaw');
check(+lids === 2, `expected 2 eyelids in the rig, found ${lids}`);
check(+rigParts > 0 && +rigParts < +count, `rig moves ${rigParts} of ${count} parts; the legs should stay put`);
check(+line('RESTERROR') < 0.03, `stepping at rest moved a part ${line('RESTERROR')} studs`);
const [tip, jaw, head, reach, blinks, nan] = line('MOTION').split(' ');
check(nan === 'false', 'a posed part went NaN');
check(+tip > 1, `the wing tips moved at most ${tip} studs in a minute: no flaps`);
check(+jaw > 0.04, `the lower beak moved at most ${jaw} studs in a minute: no squawks`);
check(+head > 0.05, `the head moved at most ${head} studs in a minute: no glances`);
check(+reach < 4, `a part reached ${reach} studs from the perch`);
check(+blinks >= 8, `only ${blinks} blinks in a minute`);
check(line('POSE_FLAP') && line('POSE_SQUAWK'), 'missing pose snapshots');

if (OUT) {
  mkdirSync(OUT, { recursive: true });
  for (const [name, key] of [['rest', 'REST'], ['flap', 'POSE_FLAP'], ['squawk', 'POSE_SQUAWK']]) {
    const file = join(OUT, `macaw-${name}.png`);
    writeFileSync(file, sheet(JSON.parse(line(key))));
    console.log('wrote ' + file);
  }
}

if (failures.length) {
  console.error('FAIL\n' + failures.map((f) => '  - ' + f).join('\n'));
  process.exit(1);
}
console.log(`pet models OK: macaw ${count} parts, ${rigParts} animated, wing tip ${(+tip).toFixed(2)} studs, ${blinks} blinks/min`);

// ---------------------------------------------------------------------------------------------
// Software renderer (as in check-boat-furniture.mjs), with SpecialMesh spheres as ellipsoids

function sheet(parts) {
  const sphere = (() => {
    const t = [];
    const S = 16;
    const at = (i, j) => {
      const th = (i / S) * Math.PI;
      const ph = (j / (S * 2)) * Math.PI * 2;
      return [0.5 * Math.sin(th) * Math.cos(ph), 0.5 * Math.cos(th), 0.5 * Math.sin(th) * Math.sin(ph)];
    };
    for (let i = 0; i < S; i++)
      for (let j = 0; j < S * 2; j++) t.push([at(i, j), at(i + 1, j), at(i + 1, j + 1)], [at(i, j), at(i + 1, j + 1), at(i, j + 1)]);
    return t;
  })();
  const box = (() => {
    const t = [];
    for (const [n, u, v] of [
      [[1, 0, 0], [0, 1, 0], [0, 0, 1]], [[-1, 0, 0], [0, 0, 1], [0, 1, 0]], [[0, 1, 0], [0, 0, 1], [1, 0, 0]],
      [[0, -1, 0], [1, 0, 0], [0, 0, 1]], [[0, 0, 1], [1, 0, 0], [0, 1, 0]], [[0, 0, -1], [0, 1, 0], [1, 0, 0]],
    ]) {
      const c = (a, b) => n.map((x, i) => x * 0.5 + u[i] * a * 0.5 + v[i] * b * 0.5);
      t.push([c(-1, -1), c(1, -1), c(1, 1)], [c(-1, -1), c(1, 1), c(-1, 1)]);
    }
    return t;
  })();
  const cylinder = (() => {
    const t = [];
    const S = 16;
    const ring = (j) => [Math.cos((j / S) * Math.PI * 2) * 0.5, Math.sin((j / S) * Math.PI * 2) * 0.5];
    for (let j = 0; j < S; j++) {
      const [a, b] = ring(j);
      const [c, d] = ring(j + 1);
      t.push([[-0.5, a, b], [0.5, a, b], [0.5, c, d]], [[-0.5, a, b], [0.5, c, d], [-0.5, c, d]]);
      t.push([[0.5, 0, 0], [0.5, a, b], [0.5, c, d]], [[-0.5, 0, 0], [-0.5, c, d], [-0.5, a, b]]);
    }
    return t;
  })();
  const SHAPES = { block: box, sphere, cylinder };
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
  const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
  const norm = (a) => { const l = Math.hypot(...a) || 1; return a.map((x) => x / l); };
  const hexRgb = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const tris = [];
  for (const part of parts) {
    if (part.t > 0.85 || part.n === 'Root') continue;
    let size = part.z;
    if (part.s === 'cylinder') size = [size[0], Math.min(size[1], size[2]), Math.min(size[1], size[2])];
    const [R, U, Z] = part.r;
    for (const tri of SHAPES[part.s] ?? box) {
      tris.push({
        color: hexRgb(part.c),
        w: tri.map((v) => {
          const l = [v[0] * size[0], v[1] * size[1], v[2] * size[2]];
          return [0, 1, 2].map((i) => part.p[i] + R[i] * l[0] + U[i] * l[1] + Z[i] * l[2]);
        }),
      });
    }
  }
  // The pet's own axes: the dump's frame turns it 0.7 rad about Y
  const yaw = 0.7;
  const rot = (v) => [v[0] * Math.cos(yaw) + v[2] * Math.sin(yaw), v[1], -v[0] * Math.sin(yaw) + v[2] * Math.cos(yaw)];
  const q = norm(rot([0.6, 0.35, -0.75]));
  const views = [
    [rot([-1, 0, 0]), [0, 1, 0]],
    [rot([0, 0, -1]), [0, 1, 0]],
    [rot([1, 0, 0]), [0, 1, 0]],
    [norm(cross([0, 1, 0], q)), cross(q, norm(cross([0, 1, 0], q)))],
  ];
  const PANEL = 420;
  const W = PANEL * 2, H = PANEL * 2;
  const img = Buffer.alloc(W * H * 3, 236);
  const LIGHT = norm([0.4, 0.8, 0.5]);
  // One shared scale so the poses compare
  const lo = [Infinity, Infinity, Infinity], hi = [-Infinity, -Infinity, -Infinity];
  for (const t of tris)
    for (const p of t.w)
      for (let a = 0; a < 3; a++) {
        lo[a] = Math.min(lo[a], p[a]);
        hi[a] = Math.max(hi[a], p[a]);
      }
  const span = Math.max(hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]);
  const center = [0, 1, 2].map((a) => (lo[a] + hi[a]) / 2);
  views.forEach(([right, up], k) => {
    const up2 = norm(sub(up, right.map((x) => x * (up[0] * right[0] + up[1] * right[1] + up[2] * right[2]))));
    const fwd = cross(right, up2);
    const dot = (p, a) => (p[0] - center[0]) * a[0] + (p[1] - center[1]) * a[1] + (p[2] - center[2]) * a[2];
    const scale = (PANEL * 0.9) / span;
    const ox = (k % 2) * PANEL, oy = Math.floor(k / 2) * PANEL;
    const depth = new Float32Array(PANEL * PANEL).fill(-Infinity);
    for (const tri of tris) {
      const n = norm(cross(sub(tri.w[1], tri.w[0]), sub(tri.w[2], tri.w[0])));
      const shade = 0.45 + 0.55 * Math.abs(n[0] * LIGHT[0] + n[1] * LIGHT[1] + n[2] * LIGHT[2]);
      const s = tri.w.map((p) => [dot(p, right) * scale + PANEL / 2, PANEL / 2 - dot(p, up2) * scale, dot(p, fwd)]);
      const area = (s[1][0] - s[0][0]) * (s[2][1] - s[0][1]) - (s[2][0] - s[0][0]) * (s[1][1] - s[0][1]);
      if (Math.abs(area) < 1e-9) continue;
      const x0 = Math.max(0, Math.floor(Math.min(s[0][0], s[1][0], s[2][0])));
      const x1 = Math.min(PANEL - 1, Math.ceil(Math.max(s[0][0], s[1][0], s[2][0])));
      const y0 = Math.max(0, Math.floor(Math.min(s[0][1], s[1][1], s[2][1])));
      const y1 = Math.min(PANEL - 1, Math.ceil(Math.max(s[0][1], s[1][1], s[2][1])));
      for (let y = y0; y <= y1; y++)
        for (let x = x0; x <= x1; x++) {
          const px = x + 0.5, py = y + 0.5;
          const a = ((s[1][0] - px) * (s[2][1] - py) - (s[2][0] - px) * (s[1][1] - py)) / area;
          const b = ((s[2][0] - px) * (s[0][1] - py) - (s[0][0] - px) * (s[2][1] - py)) / area;
          const c = 1 - a - b;
          if (a < 0 || b < 0 || c < 0) continue;
          const z = a * s[0][2] + b * s[1][2] + c * s[2][2];
          const i = y * PANEL + x;
          if (z <= depth[i]) continue;
          depth[i] = z;
          const o = ((oy + y) * W + ox + x) * 3;
          for (let ch = 0; ch < 3; ch++) img[o + ch] = Math.min(255, tri.color[ch] * shade);
        }
    }
  });
  return png(W, H, img);
}

function png(w, h, rgb) {
  const raw = Buffer.alloc((w * 3 + 1) * h);
  for (let y = 0; y < h; y++) rgb.copy(raw, y * (w * 3 + 1) + 1, y * w * 3, (y + 1) * w * 3);
  const table = Array.from({ length: 256 }, (_, n) => {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    return c >>> 0;
  });
  const crc = (buf) => {
    let c = 0xffffffff;
    for (const b of buf) c = table[(c ^ b) & 0xff] ^ (c >>> 8);
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
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

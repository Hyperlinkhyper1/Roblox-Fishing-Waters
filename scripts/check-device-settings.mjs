// Exercise the production settings module across fresh joins and profile refreshes.
import { readFile, writeFile, mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const folder = await mkdtemp(join(tmpdir(), 'fishing-device-settings-'));
try {
  const source = await readFile(join(root, 'src/client/PlayerSettings.luau'), 'utf8');
  const program = `
local checks = 0
local function check(value, message)
 checks += 1
 assert(value, message)
end
local event = { Connect = function() end }
local attributes = {}
local player = {
 SetAttribute = function(_, key, value) attributes[key] = value end,
 DescendantAdded = event, GetDescendants = function() return {} end,
 CharacterAdded = event,
}
local lighting, groups = {}, {}
local input = {}
local quality, unavailable = 0, false
local soundService = { DescendantAdded = event, GetDescendants = function() return {} end }
-- Streaming map parts must never reach a script callback: only top-level
-- children of workspace are watched, never its descendants.
local workspace = {
 ChildAdded = event, GetChildren = function() return {} end,
 DescendantAdded = { Connect = function() error("Settings must not watch every workspace descendant") end },
}
local services = {
 Lighting = lighting, SoundService = soundService,
 Players = { LocalPlayer = player, PlayerAdded = event, GetPlayers = function() return { player } end },
 UserInputService = input,
}
local game = { GetService = function(_, key) return assert(services[key], key) end }
local Instance = { new = function(class)
 check(class == "SoundGroup", "Settings creates only mixer groups")
 local group = {}
 table.insert(groups, group)
 return group
end }
local function UserSettings()
 if unavailable then error("Quality unavailable") end
 return { GetService = function() return { SavedQualityLevel = { Value = quality } } end }
end
local function fresh()
 ${source}
end
local saved = { Shadows = true, WeatherEffects = true, MasterVolume = 40, MusicVolume = 60, EffectsVolume = 80 }
for _, case in {
 {"phone", true, false, false, 0, false, false},
 {"tablet with controller", true, false, true, 0, false, false},
 {"console", false, false, true, 0, false, true},
 {"computer", false, true, false, 0, true, true},
 {"computer with controller", false, true, true, 0, true, true},
 {"touchscreen computer", true, true, false, 0, true, true},
 {"low graphics computer", false, true, false, 3, false, false},
 {"medium graphics computer", false, true, false, 6, false, true},
 {"high graphics computer", false, true, false, 10, true, true},
 {"high graphics phone", true, false, false, 10, false, false},
} do
 input.TouchEnabled, input.KeyboardEnabled, input.GamepadEnabled, quality = case[2], case[3], case[4], case[5]
 local settings = fresh()
 settings.start()
 check(lighting.GlobalShadows == case[6] and attributes.WeatherEffectsEnabled == case[7], case[1] .. " applies before profile load")
 local count = #groups
 settings.start()
 check(#groups == count, "Repeated startup does not recreate the mixer or reset settings")
 local values = settings.apply(saved)
 check(values.Shadows == case[6] and values.WeatherEffects == case[7], case[1] .. " ignores settings from a previous device")
 check(saved.Shadows and saved.WeatherEffects, "Preset does not mutate the saved profile")
 check(groups[count - 2].Volume == 0.4 and groups[count - 1].Volume == 0.6 and groups[count].Volume == 0.8, "Audio preferences survive automatic optimization")
 check(#settings.description() > 0, "Preset explanation is available")
end
input.TouchEnabled, input.KeyboardEnabled, input.GamepadEnabled, quality = true, false, false, 0
local mobile = fresh()
local values = mobile.apply(saved)
values.Shadows = true
values = mobile.apply(values, "Shadows")
check(lighting.GlobalShadows and values.Shadows, "Manual shadows override applies")
local stale = table.clone(saved)
stale.Shadows = false
values = mobile.apply(stale)
check(values.Shadows and not values.WeatherEffects, "Profile refresh preserves manual and automatic session settings")
values.WeatherEffects = true
mobile.apply(values, "WeatherEffects")
check(attributes.WeatherEffectsEnabled, "Manual weather override applies")
values.MasterVolume = 20
values.Shadows = false
mobile.apply(values, "MasterVolume")
check(lighting.GlobalShadows and groups[#groups - 2].Volume == 0.2, "Audio change cannot reset performance")
values = fresh().apply(saved)
check(not values.Shadows and not values.WeatherEffects, "Rejoin resets manual overrides for the current device")
input.TouchEnabled, input.KeyboardEnabled = false, true
stale.Shadows, stale.WeatherEffects = false, false
values = fresh().apply(stale)
check(values.Shadows and values.WeatherEffects, "Switching from mobile to computer gets a fresh preset")
unavailable = true
values = fresh().apply(saved)
check(values.Shadows and values.WeatherEffects, "Unavailable Roblox quality falls back to device capabilities")
print("Device settings: " .. checks .. " checks passed (recording mocks).")
`;
  const target = join(folder, 'settings.luau');
  await writeFile(target, program);
  const result = spawnSync(process.env.LUTE || 'lute', ['run', target], { cwd: root, encoding: 'utf8', timeout: 30000 });
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Device settings checks failed (${result.status})`);
} finally {
  if (dirname(folder) !== resolve(tmpdir())) throw new Error('Unexpected temporary directory');
  await rm(folder, { recursive: true, force: true });
}

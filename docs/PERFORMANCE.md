# Client performance

Boat effects keep motion smooth while bounding work that does not need to run every frame.

| Work | Previous behavior at 60 FPS | Current behavior |
| --- | --- | --- |
| Audio and rowing boat discovery | Each controller scans the boat folder 60 times/second | At most 4 times/second; folder replacement is detected immediately |
| Wave hull bounds | Full geometry measurement 60 times/second per boat | At most 2 times/second nearby; cached boxes follow root translation and rotation every frame |
| Motor spray settings and water samples | Up to 60 updates/second per boat | At most 20 updates/second, without catch-up bursts |
| Inactive effects | Repeated velocity reads, oar writes, emitter writes and particle clears | Silent engines, resting oars and unchanged emitters stop doing that work |
| Invisible surface ribbons | Continue calculating wave geometry | Skip hull measurements and wave samples underwater and above the surface viewing range |

Newly streamed boats can take up to 0.25 seconds plus one frame to acquire audio/rowing effects. Hull geometry changes, including refits, refresh within 0.5 seconds plus one frame. Root replacement invalidates the cached coordinate frame immediately. Active audio, rowing and wave motion still update every frame. Particle emitters continue simulating between settings updates.

Run the focused checks with `LUTE` pointing to an installed Lute runtime:

```powershell
node scripts/check-boat-audio.mjs
node scripts/check-rowing-animation.mjs
node scripts/check-boat-spray.mjs
node scripts/check-water-waves.mjs
```

Recording mocks verify operation budgets at 30, 60 and 144 FPS, idle behavior, streaming recovery, hull motion/turns, refits and water clearance. These are operation counts, not measured frame-rate gains. Verify rendering, sound and MicroProfiler timings in Roblox Studio with several nearby boats, storm weather, dismount/remount, refits and underwater camera transitions.

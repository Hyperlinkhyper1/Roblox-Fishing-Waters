# Server update notices and redirects

`ServerUpdates` starts before world generation. Live servers register the highest
running `game.PlaceVersion` in a place-scoped DataStore and announce their own
version through MessagingService. Older servers show a persistent **Update
available!** banner with a **Join updated server** button. Existing players can
finish what they are doing; new arrivals, including friend joins, invites, and
teleports, automatically transfer after a short notice.

Transfers explicitly target a recently announced public server running the latest
known version. If no such job is known, or that job repeatedly fails, the service
reserves a fresh server. It never uses ordinary matchmaking, which could choose
the same friend's outdated server. Teleport failures retry with backoff; a
watchdog also catches requests that never complete. A fallback reservation is
shared briefly by players leaving the same server. VIP and reserved job IDs are
never advertised as public targets.

## Publishing

1. Publish this implementation, then restart existing servers once. Servers that
   were already running before installation cannot execute the new code.
2. For subsequent releases, publish the new place version. The first new server
   announces it immediately; older servers also poll the saved version every
   60 seconds if a cross-server message was missed.
3. To notify all old servers immediately without waiting for a new server to
   start, use Creator Dashboard > Configurations > Server management > Restart
   Servers, select **Restart only servers with outdated versions**, and enable
   **Delay server restart**. The service listens for `ServerRestartScheduled`,
   displays the notice, and redirects new arrivals throughout the delay. Roblox
   performs the eventual restart/migration of players who stayed.

Publishing alone does not send a publish event to running Luau code. Until a
new server reports its version or a restart is scheduled, an old server cannot
know a newer version exists. During a simultaneous DataStore/MessagingService
outage, detection waits for recovery. Roblox's initial friend matchmaking cannot
be overridden by game scripts; redirection happens after arrival. Teleport
availability and latency depend on Roblox, so failures retry visibly rather than
promising an instantaneous transfer.

No external HTTP endpoint, API key, version bump, or additional place is needed.
Studio neither registers versions nor teleports to live servers.

## Verification

Run `node scripts/check-server-updates.mjs` for deterministic multi-server tests.
For live verification, keep two accounts in an older server, publish an update,
and start a newer public server (or schedule an outdated-server restart). Check
that existing players see the banner, one can use the button, and the other
account's friend join into the old server automatically transfers. Verify that
saved cash, catches, and builds survive the transfer. Also check phone layout,
VIP-server arrivals, and a full/unavailable target. Real teleports and cross-server
delivery require a published experience in the Roblox client.

References: [release game updates](https://create.roblox.com/docs/projects/update-games),
[teleport between places](https://create.roblox.com/docs/projects/teleport).

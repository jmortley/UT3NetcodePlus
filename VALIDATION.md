# Shock alpha validation — September 22, 2026

Target executable: locally installed Steam UT3, build 3809. Final gameplay package: **91,038 bytes**, SHA-256 `E725AEFCAA18BCA577AFA816CB2FF23EB7815B4F471B905BE3D0DD8A19949545`.

## Results on the packaged build

| Check | Result |
|---|---|
| UT3 UnrealScript compiler | Exit 0; `Success - 0 error(s), 0 warning(s)` |
| Dedicated-server engine suite | **63/63 assertions pass**; no script warnings, accessed-none or error lines |
| Real two-client test, 80 ms outgoing packet lag and 5% loss configured on both ends | **Pass**; measured minimum RTT **183.3 ms**, applied rewind **91.7 ms** for both players |
| Core catch-up in that run | Each player's first **3** cores received **60 ms** of native physics advance; the fourth core hit a wall before the full advance completed |
| Core prediction and matching in that run | Each client created **4** visuals, matched **3** flying cores, retired **1** early-impact visual; **0** residual visuals |
| Beam/core interaction in that run | Both players performed a server-confirmed combo; **42/50 ammo** remained: 4 cores + 1 beam + stock 3-ammo combo surcharge |
| Released firing state in that run | Both server weapons in `Active`, with both pending-fire flags false |
| Real two-client test without packet simulation | **Pass**; same combo, matching, retirement, ammo and released-state results; measured minimum RTT rounded to zero in game time and no catch-up was applied |
| Stock network connection baseline | Two clients connected with ordinary UTDeathmatch and no NetcodePlus mutator or weapon replacement |

The native packet-simulation settings are applied again after each net driver exists. Command-line parsing alone initially printed the settings without establishing the intended final connection behavior. The final test asserts elevated measured RTT, rather than treating a settings log as proof of latency. Five percent is the configured random packet-loss probability, not an independently counted exact loss fraction. Game-time/tick quantization affects the reported RTT.

The clients wait 4.5 seconds after enabling simulation so the eight-sample ping window can turn over. An earlier run used startup samples and correctly applied a conservative 55 ms advance, failing the test's 60 ms cap assertion; that was a test warm-up problem. The no-lag check then exposed a real visual-cleanup race when an assigned core died before its actor update arrived. Shutdown/destruction now retires that ID through the weapon channel, and both final network runs exercise the fix.

## What the engine suite exercises

- Actual DM-Deck Shock weapon and ammo pickup replacement.
- Cylinder intersection and a miss; interpolated moving-body hits while the current body is off the ray.
- A blocking actor taking precedence over a historical target; shootable triggers included exactly once before the blocker and excluded behind it.
- A 100-unit teleport generation change invalidating history immediately and preventing interpolation across the jump; ring wrap and expired-sample rejection; immediate death invalidation.
- A visual metadata request causing no shot and no ammo change; matching only after a stock-authorized core spawn.
- Real server core spawning, contact damage, core/core destruction, beam-triggered combo damage and the stock combo ammo surcharge.
- Cosmetic cores unable to damage, trigger combos, collide with pawns or replicate; handoff restoring the real core's visibility without changing its position.
- Native core catch-up advances 69 units in 60 ms at stock speed, subtracts flight lifetime, respects the 100 ms absolute cap, and cannot run twice or on an old core. Zero settings, unmeasured/stale ping and custom time dilation preserve stock spawn timing.
- Native catch-up stops at a thin world-geometry fixture, dispatches one full stock direct hit, and retains core/core destruction. Short remaining lifetimes cannot become unlimited. Core compensation can remain enabled when beam rewind is disabled.
- A core ending before its visual ID arrives retains its slot and cannot consume the next surviving core's identity. An impact after ID assignment also retires the visual; shutdown plus destruction does not retire it twice. Neither path creates a shot or changes its ammo cost.
- Primary and secondary held-fire shot counts, timestamps and ammo matching stock controls. Twenty release/press pairs per tick do not accelerate either mode. One hundred immediate start/stop pairs produce one shot in each mode.

The synthetic target records damage dispatch without ordinary spawn-protection suppression. The short-teleport test increments the same generation field used by stock `PostTeleport`/`DoTranslocate`; it is not a full live translocator match. Cadence is compared with the stock control's actual timestamps, not an assumption of mathematically exact timer spacing.

## Evidence

- Compiler: `Logs/compile.log.console.txt` (full engine log: `Logs/compile.log`).
- Final engine checks: `Logs/engine-tests.log`.
- Earlier stock baseline: `Logs/network-stock-baseline/20260921-222141-236/`.
- Fresh stock connection baseline: `Logs/network-stock-baseline/20260922-000108-734/`.
- Final real-client lag/loss run: `Logs/network-lag80-loss5/20260921-235929-162/`.
- Final real-client no-simulation run: `Logs/network-lag0-loss0/20260921-235826-841/`.
- The ZIP includes the relevant logs in `Evidence/` and a binary/source hash manifest.

## Diagnostics and limits

The earlier stock baseline reproduces the client-side `UTHUD.PostBeginPlay` accessed-none GRI warning and the online-service errors about voice ownership / starting an uncreated online game. It also reproduces a stock `UTPawn.PlayDying` physics-asset warning in one client. The final lag/loss run includes a `UTDeathMessage.ClientReceive` missing `RelatedPRI_2` warning during client startup, before the automated firing begins; its cause is not established by the gameplay assertions. Raw diagnostics remain in the evidence, and a pass is not a claim of entirely clean client logs. The final runs have no script warnings attributed to NetcodePlusUT3 or NCTests, no critical failure, and no unexpected native error. The full compiler log's stock NetIndex diagnostics were previously reproduced with zero mod packages during the audit.

A fresh stock connection baseline reproduced the HUD/online diagnostics but did not reproduce the `UTDeathMessage` warning. That startup warning remains a documented investigation item rather than being classified as a proven baseline defect. The ZIP includes the fresh baseline logs.

The real-client check uses controlled stationary players, straight core flight, an on-axis combo and a server-only near-muzzle wall fixture. It does not establish fairness against moving remote targets, visual smoothness during normal combat, off-axis high-ping combos, every map/door/portal/vehicle case, reconnect/death/switch stress, demo playback, console aim assist, hardware zero-debounce behavior, or long-session performance. Those remain playtesting/acceptance work for the alpha.

Server projectile-hit rewind, historical combo-core traces and client projectile-hit claims remain absent. This build adds bounded catch-up at server spawn using current collision state, followed by normal projectile simulation. Client prediction remains cosmetic with authoritative matching. No new fire-event authorization protocol was introduced.

The headless client attempt crashed in native rendering initialization. Sandboxed graphical clients reported `D3DERR_NOTAVAILABLE`; the successful real-client checks used approved desktop Direct3D access. All test processes were owned by the scripts and stopped after each run. The installed UT3 engine configuration and UT4 tracked plugin source were not edited, and no installed `UTNetcodePlusUT3.ini` was created by the tests.

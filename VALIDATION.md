# Shock alpha validation — September 21, 2026

Target executable: locally installed Steam UT3, build 3809. Final gameplay package: **81,984 bytes**, SHA-256 `0D442CC3258BC75686390F1FECBA25F78DAAAEB9D23CD5EA6135E31BD4C3577A`.

## Results on the packaged build

| Check | Result |
|---|---|
| UT3 UnrealScript compiler | Exit 0; `Success - 0 error(s), 0 warning(s)` |
| Dedicated-server engine suite | **39/39 assertions pass**; no script warnings, accessed-none or error lines |
| Real two-client test, 80 ms outgoing packet lag and 5% loss configured on both ends | **Pass**; measured minimum RTT **183.3 ms**, applied rewind **91.7 ms** for both players |
| Core prediction and matching in that run | Each client created **3** visuals and matched **3** real server cores; **0** residual visuals |
| Beam/core interaction in that run | Both players performed a server-confirmed combo; **43/50 ammo** remained: 3 cores + 1 beam + stock 3-ammo combo surcharge |
| Released firing state in that run | Both server weapons in `Active`, with both pending-fire flags false |
| Stock network connection baseline | Two clients connected with ordinary UTDeathmatch and no NetcodePlus mutator or weapon replacement |

The native packet-simulation settings are applied again after each net driver exists. Command-line parsing alone initially printed the settings without establishing the intended final connection behavior. The final test asserts elevated measured RTT, rather than treating a settings log as proof of latency. Five percent is the configured random packet-loss probability, not an independently counted exact loss fraction. Game-time/tick quantization affects the reported RTT.

## What the engine suite exercises

- Actual DM-Deck Shock weapon and ammo pickup replacement.
- Cylinder intersection and a miss; interpolated moving-body hits while the current body is off the ray.
- A blocking actor taking precedence over a historical target; shootable triggers included exactly once before the blocker and excluded behind it.
- A 100-unit teleport generation change invalidating history immediately and preventing interpolation across the jump; ring wrap and expired-sample rejection; immediate death invalidation.
- A visual metadata request causing no shot and no ammo change; matching only after a stock-authorized core spawn.
- Real server core spawning, contact damage, core/core destruction, beam-triggered combo damage and the stock combo ammo surcharge.
- Cosmetic cores unable to damage, trigger combos, collide with pawns or replicate; handoff restoring the real core's visibility without changing its position.
- Primary and secondary held-fire shot counts, timestamps and ammo matching stock controls. Twenty release/press pairs per tick do not accelerate either mode. One hundred immediate start/stop pairs produce one shot in each mode.

The synthetic target records damage dispatch without ordinary spawn-protection suppression. The short-teleport test increments the same generation field used by stock `PostTeleport`/`DoTranslocate`; it is not a full live translocator match. Cadence is compared with the stock control's actual timestamps, not an assumption of mathematically exact timer spacing.

## Evidence

- Compiler: `Logs/compile.log.console.txt` (full engine log: `Logs/compile.log`).
- Final engine checks: `Logs/engine-tests.log`.
- Final stock baseline: `Logs/network-stock-baseline/20260921-222141-236/`.
- Final real-client lag/loss run: `Logs/network-lag80-loss5/20260921-222158-020/`.
- The ZIP includes the relevant logs in `Evidence/` and a binary/source hash manifest.

## Diagnostics and limits

The stock baseline reproduces the client-side `UTHUD.PostBeginPlay` accessed-none GRI warning and the online-service errors about voice ownership / starting an uncreated online game. It also reproduces a stock `UTPawn.PlayDying` physics-asset warning in one client. These raw lines remain in the evidence; the successful gameplay assertions are not a claim of entirely clean client logs. The final lag/loss run has no script warnings attributed to NetcodePlusUT3 or NCTests, no critical failure, and no unexpected native error. The full compiler log's stock NetIndex diagnostics were previously reproduced with zero mod packages during the audit.

The real-client check uses controlled stationary players, straight core flight and an on-axis combo. It does not establish fairness against moving remote targets, visual smoothness during normal combat, off-axis high-ping combos, every map/door/portal/vehicle case, reconnect/death/switch stress, demo playback, console aim assist, hardware zero-debounce behavior, or long-session performance. Those remain playtesting/acceptance work for the alpha.

Server projectile hit rewind, catch-up physics and client projectile-hit claims are deliberately absent. Secondary prediction is cosmetic with authoritative matching; stock server projectile gameplay remains decisive. No new fire-event authorization protocol was introduced.

The headless client attempt crashed in native rendering initialization. Sandboxed graphical clients reported `D3DERR_NOTAVAILABLE`; the successful real-client checks used approved desktop Direct3D access. All test processes were owned by the scripts and stopped after each run. The installed UT3 engine configuration and UT4 tracked plugin source were not edited, and no installed `UTNetcodePlusUT3.ini` was created by the tests.

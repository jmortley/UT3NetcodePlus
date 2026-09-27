# Weapon alpha validation — September 27, 2026

Target executable: locally installed Steam UT3, build 3809. Final gameplay package: **197,279 bytes**, SHA-256 `594BA5ACCC72DFB54AD099AFA487610908836CF9A12F42BDEAD6B25AD84AA0F1`.

## Final build results

| Check | Result |
|---|---|
| UnrealScript compiler | 0 errors, 0 warnings |
| Dedicated-server engine suite | 287/287 assertions pass |
| Sniper, 80 ms lag / 5% loss | Both clients: 3 rewind traces, 37/40 ammo, released and idle; real pawn head history available |
| Sniper, no simulation | Both clients: 3 shots, 37/40 ammo, released and idle; no rewind applied |
| Rockets, 80 ms lag / 5% loss | Both clients: 4 projectiles, 60 ms catch-up each, 26/30 ammo, released and idle |
| Rockets, no simulation | Both clients: 4 projectiles, no catch-up, 26/30 ammo, released and idle |
| Flak, 80 ms lag / 5% loss | Both clients: 9 shards + 1 shell, 60 ms catch-up each, 28/30 ammo, released and idle; initial bounce/lifetime/shrink state verified |
| Flak, no simulation | Same counts, ammo, release and initial-state checks; fired projectiles receive no catch-up |
| Shock, 80 ms lag / 5% loss | **FAIL: cosmetic match count**. Clients match 2/3 and 3/3 open-flight cores; both retain 4 visuals, 1 retirement, zero residual visuals, confirmed combo, 42/50 ammo, released and idle |
| Shock, no simulation | Both clients: all 3 open-flight matches, correct combo/ammo/retirement/cleanup/release; no catch-up |
| Stock Flak, 80 ms lag / 5% loss | Both clients: 28/30 ammo, released and idle using the exact stock weapon |
| Stock connection baseline | Two clients connected with ordinary UTDeathmatch and no NetcodePlus mutator |

All four mod lag/loss runs measured minimum RTT **183.3 ms** for both players; the effective hitscan delay is half RTT, **91.7 ms**, within its configured cap. In no-simulation runs, minimum RTT rounded to zero in game time. Shock's three open-flight cores each received 60 ms of advance under lag; its fourth core hit the nearby wall after 16.7 ms of submitted physics.

Nine network cases pass; the strict Shock lag/loss case fails its cosmetic match count in both the regression run and follow-up. Flak's two network cases and stock-Flak control pass. This ZIP was created with the explicit `Make-Package.ps1 -AllowKnownShockVisualMiss` alpha exception, which accepts only the reviewed cosmetic failure signature while requiring the recorded gameplay/ammo/release/cleanup results and client diagnostic checks. The default packager still rejects this failure. `Test-Network.ps1` remains strict, the failed log is packaged unchanged, and `manifest.json` records the exception. This is not an all-tests-pass release.

## Engine verification

The UT3 UnrealScript compiler reports **0 errors and 0 warnings**. The dedicated-server suite passes **287/287 assertions**, with no script warnings, accessed-none or error lines in the engine-test log.

Sniper checks capture the stock pawn's actual skeletal head center, then use deterministic historical samples to exercise body/head classification. Native dispatch produces 140-damage headshots, 70-damage body hits, stock damage types and helmet absorption. A shot cannot combine a historical body with a current-position head. Missing head samples and custom pawns keep native tracing; pass-through callbacks that teleport a victim or clear history reject stale historical damage. A farther unsupported pawn cannot suppress a nearer supported hit merely because its history was registered first. Zoom routing, held fire, rapid input edges, ammo and cadence are compared with stock controls.

Rocket checks exercise native flight distance, world collision, contact damage, life consumption, single-use catch-up, the 100 ms hard cap and stale/zero/scaled-time fallbacks. Grenades bounce through native physics and shorten their original random fuse without rerolling it. One-, two- and three-projectile loads are compared with stock for spread, spiral and grenades; lock-on retains the stock seeking class and target. Timed loading/release and primary input patterns retain stock shot counts, ammo and state transitions. Seeking and spiral modes deliberately receive no catch-up.

Flak checks compare the stock nine-shard primary count and eight spread zones, including deferring all catch-up until every spread draw is complete. Native collision fixtures exercise bounce-to-falling transitions, the last-bounce lifetime extension, owner return hits, mutual shard immunity, contact damage and age-dependent center damage/momentum. Shell checks cover the stock toss/gravity path and five ordinary impact fragments without duplicate catch-up. Both modes are compared against stock under held fire, repeated input and 100 tap pairs. Independent free-flight probes compare naturally ticked stock shards and shells with equal-duration catch-up; this does not establish equivalence for every opaque native tick behavior.

Integration checks cover all four weapons' pickups and ammo, the exact stock default pawn replacement, and profile weapon priorities including UT3's negative-priority fallback. The mutator does not substitute a custom game mode's pawn class. Pickup HUD ammo flashes still use stock class-default comparisons; their presentation with replacement classes has not been fixed in this slice.

The earlier 93 Shock checks are retained. They cover cylinder interpolation and blocking geometry, pass-through impact order, death/teleport/collision eligibility, native core contact and combo damage, catch-up limits and lifetime, early visual retirement, ownership-generation isolation, and stock cadence/ammo under held and rapid input. The previous collision/ownership development reproduced 11 failures before its fixes; that historical log remains included. It is separate from this sniper/rocket implementation.

Synthetic damage sinks avoid spawn-protection suppression. Collision fixtures model deterministic cylinder/pose transitions rather than animated ragdolls. The short-teleport test increments the stock teleport generation field; it is not a live translocator match. Cadence is compared with actual stock-control timestamps.

## Real-client methodology

Each network run starts a dedicated loopback server and two graphical clients. Mod runs use normal replicated player pawns and actual owning-client weapon calls. A test-only UTPlayerController subclass ignores desktop fire commands; the driver calls StartFire/StopFire on the weapon directly, through its inherited client/server firing implementation. This prevents incidental mouse input from contaminating scripted shot counts. Native packet simulation is reapplied after each driver exists. Clients wait 4.5 seconds for the eight-sample ping window to turn over; mod lag tests assert an elevated measured RTT. The configured setting is 80 ms outgoing packet lag and 5% random packet-loss probability at both ends. Five percent is not an independently counted exact loss fraction.

Sniper clients hold primary for 2.8 seconds and report 1.5 seconds after release. Assertions require three shots, 37/40 ammo, idle state and clear pending-fire flags on both ends. Lag runs also require three server rewind traces and a usable head-history sample from the actual network pawn. These shots intentionally miss; damage/headshot correctness is covered by the engine fixtures, not moving remote opponents.

Rocket clients fire one primary shot, then hold alternate for 2.5 seconds to release three spread rockets. Assertions require four server spawns, 26/30 ammo, idle state and clear pending-fire flags. Lag runs require all four shots to receive 60 ms catch-up. Grenades, seeking and spiral modes are covered by the engine comparisons, not the real-client sequence.

Flak clients tap each mode once. Assertions require nine primary shards, one alternate shell, 28/30 ammo, idle state and clear pending-fire flags on both ends. Lag runs require all ten projectiles to receive 60 ms catch-up. The stock-Flak control repeats these input/ammo/release checks with exact stock UTPawn and UTWeap_FlakCannon and no NetcodePlus mutator.

A separate Flak replication fixture creates real NC shard actors only after an owning-client ready RPC. Native catch-up bounces the outer shard once and stops an exhausted center shard. Test-only long lifetimes, frozen movement and a fixed 1.5-second stock shrink timer permit deterministic observation; these settings are not used in gameplay. Clients discover the exact-class actors near replicated fixture coordinates instead of relying on references to temporary projectiles. Assertions inspect actual bounce counts (1/0), owner blocking, bBounce (true/false), lifetime, PHYS_None and the received shrink timer. Reapplying metadata cannot reset these fields or timers. Both clients pass these checks with and without packet simulation. This tests initial state, not later moving client/server bounce reconciliation.

Shock clients create three flying cores, perform a server-confirmed combo, then fire a fourth core into a server-only near-muzzle blocker. Assertions preserve the original matching, retirement, cleanup, 42/50 ammo, release and catch-up requirements. The stock connection baseline uses ordinary UTDeathmatch. The additional StockSniper control uses exact stock UTPawn and UTWeap_SniperRifle without NCMutator, with the same timed input and release assertions.

## Intermittent results retained for investigation

During Flak development, a lag/loss run (`network-flak-lag80-loss5/20260927-131159-191`) received eight additional controller-origin StartFire calls on one client, alongside the two scripted calls. The explicit scripted primary release cleared pending fire immediately; later controller calls set it again. That run's extra shots were contaminated by external input and do not establish a lost-release fault. This prompted the test-only input isolation above. It does not establish the cause of the earlier sniper observation below, whose original logs lack these traces.

The first Flak engine run failed test-fixture assertions because a one-line UnrealScript defaults block left the forced catch-up value unset and the native timing probe counted an extra spawn-frame tick. Multiline initialization and an observed post-spawn baseline corrected the fixtures, retaining their original assertions. Preliminary replication probes also failed to resolve projectile actor references; raw logs are retained in `Evidence/diagnostic-runs/`. Final replication evidence is described above separately.

The first sniper lag/loss run (`network-sniper-lag80-loss5/20260927-081150-282`) failed for one client: four server rewind traces, 36 ammo and client WeaponFiring at report, versus three expected shots. The run lacked release timestamps and pending flags, so its cause is **unestablished**. Subsequent test-only diagnostics log start/stop/report times, weapon identity, pending flags, refire interval/timer and inherited firing traces. The instrumented repeat cleared pending fire immediately on release and passed; the stock-sniper control passed too. Neither pass proves why the earlier run failed. Firing states and RPCs were not changed to make this test pass.

The Shock lag/loss run (`network-lag80-loss5/20260927-081634-684`) failed the visual-match count: clients matched one and two open-flight cores instead of three. Both still had four predicted visuals, one retirement, zero residual visuals, correct ammo, confirmed combos and released firing. Server matching metadata expires after 250 ms and unmatched local visuals after 750 ms. Delayed delivery beyond those windows is plausible, but the original log cannot establish that cause. The strict assertions were retained. A test-only subclass now logs request tuples/times, queue ages, server-assigned identities and client visual availability while calling the same inherited implementation. Its final lag/loss and no-simulation runs passed; they did not reproduce the missing-match condition.

Both failures and the first instrumented/stock comparison runs are copied into `Evidence/diagnostic-runs/` in the ZIP. Later passes do not erase these observations or establish reliability across packet-loss patterns.

The Flak regression matrix reproduced a Shock match miss (`network-lag80-loss5/20260927-131917-116`): one client matched two of three open-flight cores. This time the trace establishes successful server pairing of ID2 after only 36.7 ms, followed by delayed, reordered client actor arrival after ID3. ID2's predicted visual was absent when matching ran. Cadence puts that handoff roughly 850 ms after prediction, beyond the 750 ms visual lifetime; expiration is strongly supported by timing, but the destruction event itself was not logged. This run narrows the failure to client handoff rather than server queue expiry. The follow-up (`20260927-132354-864`) again missed one match. Ammo, combo, release, retirement and cleanup passed in both. The failed logs remain packaged, and the cosmetic limitation remains open.

## Diagnostics and acceptance limits

Stock baselines reproduce client-side UTHUD.PostBeginPlay missing-GRI and online-service voice/start-game diagnostics. A prior stock baseline also reproduced UTPawn.PlayDying's missing PhysicsAssetInstance warning, seen again in the final Shock, sniper and rocket lag/loss runs. A UTDeathMessage.ClientReceive missing RelatedPRI_2 warning appeared in the instrumented sniper repeat and final sniper lag/loss run; its cause is unestablished and it was not reproduced by the stock-sniper control or final connection baseline. Final Flak and stock-Flak runs retain only the shared HUD/online-service diagnostics. Raw logs remain in the evidence. A passed network run is not a claim of entirely clean client logs. NetcodePlusUT3/NCTests script warnings, critical failures and unexpected native errors fail the harness. The installed stock-package NetIndex compiler diagnostics were previously reproduced with zero mod packages during the audit.

The tests do not establish fairness against moving remote targets, visual smoothness in normal combat, off-axis high-ping combos, animated head accuracy, scope UI appearance, every map/door/portal/vehicle case, live ownership/reconnect/death/switch stress, demo playback, console aim assist, physical zero-debounce behavior or long-session/large-player-count performance. Head sampling forces skeletal updates and needs performance measurement in a real match.

Rockets and Flak have bounded authoritative spawn catch-up, without client visual prediction. Seeking and spiral rocket flight remain stock, as does Flak native aiming-help (`bWideCheck`) timing. Shell catch-up ends at impact; its child shards do not consume the unused advance. Initial Flak state replication carries bounce budget, remaining life, owner collision and pending shrink cleanup, but does not reconcile later client/server bounce divergence. Projectile catch-up uses current collision; there are no historical projectile-hit claims or historical combo-core traces. Shock prediction remains cosmetic. No UT4 fire-event authorization/retry protocol was introduced.

The successful graphical tests require approved desktop Direct3D access; headless/sandbox rendering attempts previously failed. Test scripts own and stop their processes, use isolated configuration/search paths, and do not modify the installed UT3 engine configuration or UT4 tracked plugin source. Validation is on Windows build 3809; Linux server execution has not been tested.

## Evidence

- Compiler: `Logs/compile.log.console.txt`; complete engine log: `Logs/compile.log`.
- Engine suite: `Logs/engine-tests.log`.
- Shock lag/loss (**cosmetic failure**): `Logs/network-lag80-loss5/20260927-132354-864/`.
- Shock no simulation: `Logs/network-lag0-loss0/20260927-132053-753/`.
- Sniper lag/loss: `Logs/network-sniper-lag80-loss5/20260927-132118-068/`.
- Sniper no simulation: `Logs/network-sniper-lag0-loss0/20260927-132142-829/`.
- Rockets lag/loss: `Logs/network-rockets-lag80-loss5/20260927-132214-363/`.
- Rockets no simulation: `Logs/network-rockets-lag0-loss0/20260927-132242-058/`.
- Flak lag/loss: `Logs/network-flak-lag80-loss5/20260927-131751-393/`.
- Flak no simulation: `Logs/network-flak-lag0-loss0/20260927-131851-197/`.
- Stock Flak control: `Logs/network-stockflak-lag80-loss5/20260927-132329-363/`.
- Stock connection: `Logs/network-stock-baseline/20260927-132309-266/`.
- Stock sniper control: `Logs/network-stocksniper-lag80-loss5/20260927-081856-630/` (same stock-control source, before the Shock diagnostic subclass was added).
- Earlier failures/comparisons: `Logs/diagnostic-runs/`.
- The ZIP copies final logs into `Evidence/<case>/`, includes the diagnostic runs and the earlier collision/ownership pre-fix reproduction, and records gameplay binary/source SHA-256 hashes in `manifest.json`.

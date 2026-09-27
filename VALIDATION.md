# Weapon alpha validation — September 27, 2026

Target executable: locally installed Steam UT3, build 3809. Final gameplay package: **158,574 bytes**, SHA-256 `DB038651D667723F566850993C3EDA60EB2EF74E90A088BF15DAD8303581C362`.

## Final build results

| Check | Result |
|---|---|
| UnrealScript compiler | 0 errors, 0 warnings |
| Dedicated-server engine suite | 213/213 assertions pass |
| Sniper, 80 ms lag / 5% loss | Both clients: 3 rewind traces, 37/40 ammo, released and idle; real pawn head history available |
| Sniper, no simulation | Both clients: 3 shots, 37/40 ammo, released and idle; no rewind applied |
| Rockets, 80 ms lag / 5% loss | Both clients: 4 projectiles, 60 ms catch-up each, 26/30 ammo, released and idle |
| Rockets, no simulation | Both clients: 4 projectiles, no catch-up, 26/30 ammo, released and idle |
| Shock, 80 ms lag / 5% loss | Both clients: 4 visuals, 3 matches, 1 retirement, zero residual visuals, confirmed combo, 42/50 ammo, released and idle |
| Shock, no simulation | Same matching/combo/ammo/release results, with no catch-up |
| Stock connection baseline | Two clients connected with ordinary UTDeathmatch and no NetcodePlus mutator |

All three final lag/loss runs measured minimum RTT **183.3 ms** for both players; the effective hitscan delay is half RTT, **91.7 ms**, within its configured cap. In no-simulation runs, minimum RTT rounded to zero in game time. Shock's three open-flight cores each received 60 ms of advance under lag; its fourth core hit the nearby wall after 16.7 ms of submitted physics.

These final runs passed. The earlier intermittent failures below remain open observations, not resolved by subsequent passes.

## Engine verification

The UT3 UnrealScript compiler reports **0 errors and 0 warnings**. The dedicated-server suite passes **213/213 assertions**, with no script warnings, accessed-none or error lines in the engine-test log.

Sniper checks capture the stock pawn's actual skeletal head center, then use deterministic historical samples to exercise body/head classification. Native dispatch produces 140-damage headshots, 70-damage body hits, stock damage types and helmet absorption. A shot cannot combine a historical body with a current-position head. Missing head samples and custom pawns keep native tracing; pass-through callbacks that teleport a victim or clear history reject stale historical damage. A farther unsupported pawn cannot suppress a nearer supported hit merely because its history was registered first. Zoom routing, held fire, rapid input edges, ammo and cadence are compared with stock controls.

Rocket checks exercise native flight distance, world collision, contact damage, life consumption, single-use catch-up, the 100 ms hard cap and stale/zero/scaled-time fallbacks. Grenades bounce through native physics and shorten their original random fuse without rerolling it. One-, two- and three-projectile loads are compared with stock for spread, spiral and grenades; lock-on retains the stock seeking class and target. Timed loading/release and primary input patterns retain stock shot counts, ammo and state transitions. Seeking and spiral modes deliberately receive no catch-up.

Integration checks cover all three weapons' pickups and ammo, the exact stock default pawn replacement, and profile weapon priorities including UT3's negative-priority fallback. The mutator does not substitute a custom game mode's pawn class. Pickup HUD ammo flashes still use stock class-default comparisons; their presentation with replacement classes has not been fixed in this slice.

The earlier 93 Shock checks are retained. They cover cylinder interpolation and blocking geometry, pass-through impact order, death/teleport/collision eligibility, native core contact and combo damage, catch-up limits and lifetime, early visual retirement, ownership-generation isolation, and stock cadence/ammo under held and rapid input. The previous collision/ownership development reproduced 11 failures before its fixes; that historical log remains included. It is separate from this sniper/rocket implementation.

Synthetic damage sinks avoid spawn-protection suppression. Collision fixtures model deterministic cylinder/pose transitions rather than animated ragdolls. The short-teleport test increments the stock teleport generation field; it is not a live translocator match. Cadence is compared with actual stock-control timestamps.

## Real-client methodology

Each network run starts a dedicated loopback server and two graphical clients. Mod runs use normal replicated player pawns and actual owning-client weapon calls. Native packet simulation is reapplied after each driver exists. Clients wait 4.5 seconds for the eight-sample ping window to turn over; mod lag tests assert an elevated measured RTT. The configured setting is 80 ms outgoing packet lag and 5% random packet-loss probability at both ends. Five percent is not an independently counted exact loss fraction.

Sniper clients hold primary for 2.8 seconds and report 1.5 seconds after release. Assertions require three shots, 37/40 ammo, idle state and clear pending-fire flags on both ends. Lag runs also require three server rewind traces and a usable head-history sample from the actual network pawn. These shots intentionally miss; damage/headshot correctness is covered by the engine fixtures, not moving remote opponents.

Rocket clients fire one primary shot, then hold alternate for 2.5 seconds to release three spread rockets. Assertions require four server spawns, 26/30 ammo, idle state and clear pending-fire flags. Lag runs require all four shots to receive 60 ms catch-up. Grenades, seeking and spiral modes are covered by the engine comparisons, not the real-client sequence.

Shock clients create three flying cores, perform a server-confirmed combo, then fire a fourth core into a server-only near-muzzle blocker. Assertions preserve the original matching, retirement, cleanup, 42/50 ammo, release and catch-up requirements. The stock connection baseline uses ordinary UTDeathmatch. The additional StockSniper control uses exact stock UTPawn and UTWeap_SniperRifle without NCMutator, with the same timed input and release assertions.

## Intermittent results retained for investigation

The first sniper lag/loss run (`network-sniper-lag80-loss5/20260927-081150-282`) failed for one client: four server rewind traces, 36 ammo and client WeaponFiring at report, versus three expected shots. The run lacked release timestamps and pending flags, so its cause is **unestablished**. Subsequent test-only diagnostics log start/stop/report times, weapon identity, pending flags, refire interval/timer and inherited firing traces. The instrumented repeat cleared pending fire immediately on release and passed; the stock-sniper control passed too. Neither pass proves why the earlier run failed. Firing states and RPCs were not changed to make this test pass.

The Shock lag/loss run (`network-lag80-loss5/20260927-081634-684`) failed the visual-match count: clients matched one and two open-flight cores instead of three. Both still had four predicted visuals, one retirement, zero residual visuals, correct ammo, confirmed combos and released firing. Server matching metadata expires after 250 ms and unmatched local visuals after 750 ms. Delayed delivery beyond those windows is plausible, but the original log cannot establish that cause. The strict assertions were retained. A test-only subclass now logs request tuples/times, queue ages, server-assigned identities and client visual availability while calling the same inherited implementation. Its final lag/loss and no-simulation runs passed; they did not reproduce the missing-match condition.

Both failures and the first instrumented/stock comparison runs are copied into `Evidence/diagnostic-runs/` in the ZIP. Later passes do not erase these observations or establish reliability across packet-loss patterns.

## Diagnostics and acceptance limits

Stock baselines reproduce client-side UTHUD.PostBeginPlay missing-GRI and online-service voice/start-game diagnostics. A prior stock baseline also reproduced UTPawn.PlayDying's missing PhysicsAssetInstance warning, also seen in the final sniper no-simulation and rocket lag/loss runs. A UTDeathMessage.ClientReceive missing RelatedPRI_2 warning appeared in the instrumented sniper repeat and final sniper lag/loss run; its cause is unestablished and it was not reproduced by the stock-sniper control or final connection baseline. Raw logs remain in the evidence. A passed network run is not a claim of entirely clean client logs. NetcodePlusUT3/NCTests script warnings, critical failures and unexpected native errors fail the harness. The installed stock-package NetIndex compiler diagnostics were previously reproduced with zero mod packages during the audit.

The tests do not establish fairness against moving remote targets, visual smoothness in normal combat, off-axis high-ping combos, animated head accuracy, scope UI appearance, every map/door/portal/vehicle case, live ownership/reconnect/death/switch stress, demo playback, console aim assist, physical zero-debounce behavior or long-session/large-player-count performance. Head sampling forces skeletal updates and needs performance measurement in a real match.

Rockets have bounded authoritative spawn catch-up, not client rocket visual prediction. Seeking and spiral flight remain stock. Projectile catch-up uses current collision; there are no historical projectile-hit claims or historical combo-core traces. Shock prediction remains cosmetic. No UT4 fire-event authorization/retry protocol was introduced.

The successful graphical tests require approved desktop Direct3D access; headless/sandbox rendering attempts previously failed. Test scripts own and stop their processes, use isolated configuration/search paths, and do not modify the installed UT3 engine configuration or UT4 tracked plugin source.

## Evidence

- Compiler: `Logs/compile.log.console.txt`; complete engine log: `Logs/compile.log`.
- Engine suite: `Logs/engine-tests.log`.
- Shock lag/loss: `Logs/network-lag80-loss5/20260927-082147-406/`.
- Shock no simulation: `Logs/network-lag0-loss0/20260927-082413-107/`.
- Sniper lag/loss: `Logs/network-sniper-lag80-loss5/20260927-082232-303/`.
- Sniper no simulation: `Logs/network-sniper-lag0-loss0/20260927-082254-781/`.
- Rockets lag/loss: `Logs/network-rockets-lag80-loss5/20260927-082316-959/`.
- Rockets no simulation: `Logs/network-rockets-lag0-loss0/20260927-082346-083/`.
- Stock connection: `Logs/network-stock-baseline/20260927-082436-904/`.
- Stock sniper control: `Logs/network-stocksniper-lag80-loss5/20260927-081856-630/` (same stock-control source, before the Shock diagnostic subclass was added).
- Earlier failures/comparisons: `Logs/diagnostic-runs/`.
- The ZIP copies final logs into `Evidence/<case>/`, includes the diagnostic runs and the earlier collision/ownership pre-fix reproduction, and records gameplay binary/source SHA-256 hashes in `manifest.json`.

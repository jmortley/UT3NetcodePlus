# Weapon alpha validation — October 8, 2026

Target executable: locally installed Steam UT3, build 3809. Final gameplay package: **201,598 bytes**, SHA-256 `4AE92B6467C4A2AAA64F96667C2500D508BDF1E8118C821EFEDFFB11D94EFB80`. Runtime and test source were frozen before compilation and remained unchanged through the final serial validation runs.

## Final candidate results

| Check | Result | Current-build evidence |
|---|---|---|
| Gameplay package size / SHA-256 | 201,598 bytes; hash above | `Build/NetcodePlusUT3.u` |
| UnrealScript compiler | 0 errors, 0 warnings | `Logs/compile.log.console.txt` |
| Dedicated-server engine suite | 394/394 assertions pass | `Logs/engine-tests.log` |
| Shock, 80 ms lag / 5% loss | Both clients: 3 matches, 1 retirement, zero residuals, 42/50 ammo; combo and release pass | `Logs/network-lag80-loss5/20261008-204819-532/` |
| Shock, no simulation | Same matching, combo, ammo, retirement and release checks; no catch-up | `Logs/network-lag0-loss0/20261008-204934-180/` |
| Delayed Shock, 900 ms actor hold / no simulation | Both clients: 3 matches after 750 ms; all ordinary Shock checks pass | `Logs/network-delayed-shock-lag0-loss0/20261008-204909-272/` |
| Delayed Shock, 900 ms actor hold / 80 ms lag / no loss | Both clients: 3 matches after 750 ms; all ordinary Shock checks pass | `Logs/network-delayed-shock-lag80-loss0/20261008-204844-006/` |
| Sniper, 80 ms lag / 5% loss | Both clients: 3 rewinds, 37/40 ammo, released and idle; real pawn head history available | `Logs/network-sniper-lag80-loss5/20261008-204958-087/` |
| Sniper, no simulation | Both clients: 3 shots, 37/40 ammo, released and idle; zero rewinds | `Logs/network-sniper-lag0-loss0/20261008-205020-628/` |
| Rockets, 80 ms lag / 5% loss | Both clients: 4 projectiles, 60 ms catch-up each, 26/30 ammo, released and idle | `Logs/network-rockets-lag80-loss5/20261008-205042-854/` |
| Rockets, no simulation | Same counts, ammo and release; zero catch-up | `Logs/network-rockets-lag0-loss0/20261008-205110-945/` |
| Flak, 80 ms lag / 5% loss | Both clients: 9 shards + 1 shell, 60 ms catch-up each, 28/30 ammo, released and idle; initial state checks pass | `Logs/network-flak-lag80-loss5/20261008-205137-866/` |
| Flak, no simulation | Same counts, ammo, release and initial state checks; fired projectiles receive zero catch-up | `Logs/network-flak-lag0-loss0/20261008-205202-826/` |
| Stock Flak, 80 ms lag / 5% loss | Both clients: 28/30 ammo, released and idle with the exact stock weapon | `Logs/network-stockflak-lag80-loss5/20261008-205227-819/` |
| Stock connection baseline | Two clients connected with ordinary UTDeathmatch and no NetcodePlus mutator | `Logs/network-stock-baseline/20261008-205252-658/` |

All twelve required network cases pass. Ordinary Shock lag/loss also passed two additional consecutive runs (`20261008-204729-504` and `20261008-204754-672`), for fourteen successful runs on this frozen build. The three repeats are retained together under `Logs/diagnostic-runs/shock-handoff-final-repeats/`. These samples do not establish reliability across every loss pattern.

Final delayed-Shock matches occurred at visual ages **851.6–904.9 ms** without simulation and **1,064.5–1,100.0 ms** with lag. All four mod lag/loss cases measured minimum RTT **183.3 ms** on both players; hitscan rewind was **91.7 ms**, within its configured cap. No-simulation RTT rounded to zero in game time. Shock's three open-flight cores received 60 ms of advance under lag, and its fourth hit the near blocker after 16.7 ms of submitted physics.

The packager requires the engine suite and all twelve network cases above to pass, checks ordinary timestamp freshness and client diagnostics, and has no Shock-failure exception. It was also checked to reject source modified after compilation. The final package uses an empty `validationExceptions` array. Historical failed runs remain in its diagnostic evidence; they do not replace final-build acceptance.

## Shock handoff and matching changes

An unmatched local visual now has a finite **1.5-second** lifetime. Its first valid match starts a separate **120 ms** blend and **200 ms** native lifetime watchdog, even if the original unmatched deadline is nearly exhausted. Repeated matching cannot renew the handoff, substitute a different core or hide another core. Destruction restores visibility to the live authoritative core. At most four effects are retained; admitting a newer effect evicts the oldest and restores any core it was hiding. A local effect-spawn failure still sends that shot's cosmetic identity so later identities do not silently shift forward.

The current server queue limits are asymmetric: a stock-authorized shot waits **750 ms** for cosmetic metadata, while metadata that arrives before its shot retains the shorter **250 ms** deadline. Consecutive metadata IDs can arrive together after packet recovery; the former 100 ms arrival-rate rejection has been removed. Owner, controller and generation checks remain required, and each queue holds at most four slots.

Expiration, overflow, a skipped ID or detaching a weapon with pending slots suspends cosmetic matching for that ownership session instead of dropping a slot and continuing FIFO assignment. The suspension is replicated to stop new local predictions; existing valid handoffs may finish. Queued requests are retired, and server catch-up continues. Dropping/reacquiring the weapon or an actual pawn/controller ownership change resets the identity and suspension; an ordinary weapon switch does not. FIFO still assumes corresponding client/server secondary-fire callbacks within those windows. These checks do not establish that correspondence for every possible firing-state divergence.

All of this metadata remains cosmetic. It cannot authorize a shot, alter aim, spend ammo, apply damage or authorize a combo. Stock firing RPCs, state transitions, rate of fire and ammo consumption remain inherited. Delay beyond either finite deadline can still cause a visible fallback to the authoritative core. The change is not an unbounded packet-loss guarantee or a transplant of UT4 fire-event sequencing.

## Verified intermediate results

These October 8 results used the handoff/lifetime changes **before** the new queue deadlines and suspension behavior. They are retained as development evidence, not final-build acceptance.

| Intermediate check | Observed result | Evidence |
|---|---|---|
| Dedicated-server suite | **313/313 assertions pass** | `Logs/diagnostic-runs/shock-handoff-intermediate/engine-tests-313.log` |
| 900 ms actor hold, no simulation | Both clients: three successful late matches, four predictions, one retirement, zero residual visuals, 42 ammo, release and combo checks pass | `Logs/network-delayed-shock-lag0-loss0/20261008-203637-253/` |
| 900 ms actor hold, 80 ms lag / no loss | Both clients: same checks pass | `Logs/network-delayed-shock-lag80-loss0/20261008-203612-889/` |
| Ordinary Shock, 80 ms lag / 5% loss repeat | **FAIL: cosmetic match count**, clients 2/3 and 3/3; gameplay/ammo/release/retirement/cleanup checks pass | `Logs/network-lag80-loss5/20261008-203701-169/` |

The intermediate delayed tests log successful matching after visual ages of approximately **852–905 ms** without simulation and **1,065–1,118 ms** with 80 ms lag, beyond the old 750 ms visual lifetime. The 313-check suite also exercises a real 850 ms metadata delay, a near-expiry match, duplicate matching, native watchdog cleanup with cosmetic Tick disabled, unmatched expiration, stale-identity isolation and four-effect eviction. These results establish bounded handoff behavior for those fixtures; the final 394-check run includes them and the added queue regressions.

The later loss repeat exposes a separate server-side deadline: `server.log` records ID3's queued core at **366.7 ms** old when its metadata arrives, beyond that build's **250 ms** core-slot window. The affected client never matches ID3. Both clients still create four predictions, retire one, clean up all visuals, finish with 42/50 ammo and released firing, and complete the server combo. Increasing the local visual deadline alone did not solve this server queue failure. The revised 750 ms core wait covers that observed delay; the final engine fixtures verify delayed pairing and suspension separately.

## Engine verification scope

The final UT3 compiler reports **0 errors and 0 warnings**. The dedicated-server suite passes **394/394 assertions**, with no script warnings, accessed-none or error lines in the engine-test log. This includes the earlier 287 checks, 26 handoff checks and 81 queue checks.

The timed handoff fixture accepts a visual at **880 ms**. Another match begins at **1.430 seconds**, with **33.3 ms** left on its original lifetime, and completes a **146.7 ms** observed blend beyond that old deadline. Duplicate same/different-core matching cannot renew the lease or hide another core. Native lifetime cleanup restores visibility even when cosmetic Tick is disabled. Unmatched expiration, ownership isolation and four-effect eviction remain bounded.

The queue fixture accepts metadata arriving **403.3 ms** after its stock-authorized core, then correctly identifies the next core. A reciprocal request can precede its core by 200 ms; a 400 ms old request instead suspends matching and cannot claim a later shot. Two stock-spaced shots accept consecutive IDs in one frame, and duplicate replay does not renew or consume slots. Native early impact keeps a placeholder for retirement. Deadline boundaries, both queue overflows, ID gaps, pending-slot detach and inventory reacquisition exercise the fallback and recovery paths. Stock shot counts, ammo and catch-up remain intact while matching is suspended.

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

A separate Flak replication fixture creates real NC shard actors only after an owning-client ready RPC. Native catch-up bounces the outer shard once and stops an exhausted center shard. Test-only long lifetimes, frozen movement and a fixed 1.5-second stock shrink timer permit deterministic observation; these settings are not used in gameplay. Clients discover the exact-class actors near replicated fixture coordinates instead of relying on references to temporary projectiles. Assertions inspect actual bounce counts (1/0), owner blocking, bBounce (true/false), lifetime, PHYS_None and the received shrink timer. Reapplying metadata cannot reset these fields or timers. Both clients pass these checks with and without packet simulation on the final build. This tests initial state, not later moving client/server bounce reconciliation.

Shock clients create three flying cores, perform a server-confirmed combo, then fire a fourth core into a server-only near-muzzle blocker. Assertions preserve the original matching, retirement, cleanup, 42/50 ammo, release and catch-up requirements. The stock connection baseline uses ordinary UTDeathmatch. The additional StockSniper control uses exact stock UTPawn and UTWeap_SniperRifle without NCMutator, with the same timed input and release assertions.

The test-only delayed-Shock projectile withholds authoritative actor replication for 900 ms while native flight and damage continue. Cosmetic metadata still uses the normal path; the test does not delay its RPC to manufacture a match. An early shutdown cancels the replication-release timer. Each client must record three successful same-identity matches whose visual age exceeds 750 ms, plus the ordinary combo/ammo/release/retirement/cleanup results. The driver waits an extra second before the combo so the last delayed core can arrive. The two cases use no simulation or 80 ms lag with **zero configured loss**, isolating actor delay from random retransmission delay. Ordinary Shock retains the separate strict 80 ms / 5% loss case.

## Intermittent results retained for investigation

During Flak development, a lag/loss run (`network-flak-lag80-loss5/20260927-131159-191`) received eight additional controller-origin StartFire calls on one client, alongside the two scripted calls. The explicit scripted primary release cleared pending fire immediately; later controller calls set it again. That run's extra shots were contaminated by external input and do not establish a lost-release fault. This prompted the test-only input isolation above. It does not establish the cause of the earlier sniper observation below, whose original logs lack these traces.

The first Flak engine run failed test-fixture assertions because a one-line UnrealScript defaults block left the forced catch-up value unset and the native timing probe counted an extra spawn-frame tick. Multiline initialization and an observed post-spawn baseline corrected the fixtures, retaining their original assertions. Preliminary replication probes also failed to resolve projectile actor references; raw logs are retained in `Logs/diagnostic-runs/` and the historical package's `Evidence/diagnostic-runs/`. The passing September 27 replication evidence is described separately above.

The first sniper lag/loss run (`network-sniper-lag80-loss5/20260927-081150-282`) failed for one client: four server rewind traces, 36 ammo and client WeaponFiring at report, versus three expected shots. The run lacked release timestamps and pending flags, so its cause is **unestablished**. Subsequent test-only diagnostics log start/stop/report times, weapon identity, pending flags, refire interval/timer and inherited firing traces. The instrumented repeat cleared pending fire immediately on release and passed; the stock-sniper control passed too. Neither pass proves why the earlier run failed. Firing states and RPCs were not changed to make this test pass.

The Shock lag/loss run (`network-lag80-loss5/20260927-081634-684`) failed the visual-match count: clients matched one and two open-flight cores instead of three. Both still created four predicted visuals, retired one, cleaned up all visuals, consumed the correct ammo, confirmed combos and released firing. In that build, server matching queues expired after 250 ms and unmatched local visuals after 750 ms. Delayed delivery beyond those windows was plausible, but the original log cannot establish that cause. The strict assertions were retained. A test-only subclass logs request tuples/times, queue ages, server-assigned identities and client visual availability while calling the inherited implementation. The first instrumented lag/loss and no-simulation runs passed; they did not reproduce the missing-match condition.

These failures and the first instrumented/stock comparison runs were copied into `Evidence/diagnostic-runs/` in the September 27 ZIP. Later passes do not erase these observations or establish reliability across packet-loss patterns.

The Flak regression matrix reproduced a Shock match miss (`network-lag80-loss5/20260927-131917-116`): one client matched two of three open-flight cores. This time the trace establishes successful server pairing of ID2 after only 36.7 ms, followed by delayed, reordered client actor arrival after ID3. ID2's predicted visual was absent when matching ran. Cadence puts that handoff roughly 850 ms after prediction, beyond the old 750 ms visual lifetime; expiration is strongly supported by timing, but the destruction event itself was not logged. This run narrows that failure to client handoff rather than server queue expiry. The follow-up (`20260927-132354-864`) again missed one match. Ammo, combo, release, retirement and cleanup passed in both. The October 8 delayed-actor fixtures exercise the handoff remedy directly; the intermediate October 8 loss run separately establishes the old server queue deadline failure. The combined changes pass the final engine and network cases above, within their stated limits.

## Historical September 27 build

The September 27 gameplay package was **197,279 bytes**, SHA-256 `594BA5ACCC72DFB54AD099AFA487610908836CF9A12F42BDEAD6B25AD84AA0F1`. Its engine suite passed 287 checks. Nine required network cases passed; ordinary Shock lag/loss failed only the strict cosmetic match count in the regression and follow-up runs. The historical ZIP used the explicit `-AllowKnownShockVisualMiss` alpha exception, preserved the failed log and recorded that exception in its manifest. It was not an all-tests-pass release. That exception no longer exists in the current packager.

Sniper passed both network settings with three shots, 37/40 ammo, idle/released firing and clear pending flags; lag additionally recorded three rewinds and usable real-pawn head history. Rockets passed with four projectiles and 26/30 ammo; Flak passed with nine primary shards, one shell and 28/30 ammo, including its initial-state replication checks. Those lag runs advanced each applicable projectile by 60 ms. Shock no-simulation passed all three open-flight matches and its combo/retirement/cleanup checks. The failed Shock lag follow-up matched 2/3 and 3/3 cores while both clients created four visuals, retired one, left zero residuals, completed the combo and finished with 42/50 ammo and released/idle firing. Stock Flak and the two-client stock connection baseline passed.

All four historical mod lag/loss runs measured minimum RTT **183.3 ms** for both players, giving **91.7 ms** effective hitscan delay within the configured cap. No-simulation minimum RTT rounded to zero in game time. Shock's three open-flight cores each received 60 ms of advance under lag; the fourth hit its nearby blocker after 16.7 ms of submitted physics. Current measurements are reported separately with the final results above.

## Diagnostics and acceptance limits

Final clients retain the stock UTHUD.PostBeginPlay missing-GRI and online-service voice/start-game diagnostics. Rockets without simulation also logged UTPawn.PlayDying's missing PhysicsAssetInstance warning; the final stock connection baseline reproduces that same stock function warning. The third Shock lag/loss repeat logged UTDeathMessage.ClientReceive missing RelatedPRI_2 and assignment-through-None warnings. That message-path issue remains unestablished and was not reproduced by the final stock baseline; a related warning was already present in historical sniper runs. Final Flak and stock-Flak runs retain only the shared HUD/online-service diagnostics. Raw logs remain in the evidence. A passed network run is not a claim of entirely clean client logs. No NetcodePlusUT3/NCTests script warnings, critical failures or unexpected native errors were found in the final matrix; those fail the harness. The installed stock-package NetIndex compiler diagnostics were previously reproduced with zero mod packages during the audit.

The tests do not establish fairness against moving remote targets, visual smoothness in normal combat, off-axis high-ping combos, animated head accuracy, scope UI appearance, every map/door/portal/vehicle case, live ownership/reconnect/death/switch stress, demo playback, console aim assist, physical zero-debounce behavior or long-session/large-player-count performance. Head sampling forces skeletal updates and needs performance measurement in a real match.

Rockets and Flak have bounded authoritative spawn catch-up, without client visual prediction. Seeking and spiral rocket flight remain stock, as does Flak native aiming-help (`bWideCheck`) timing. Shell catch-up ends at impact; its child shards do not consume the unused advance. Initial Flak state replication carries bounce budget, remaining life, owner collision and pending shrink cleanup, but does not reconcile later client/server bounce divergence. Projectile catch-up uses current collision; there are no historical projectile-hit claims or historical combo-core traces. Shock prediction remains cosmetic. No UT4 fire-event authorization/retry protocol was introduced.

The successful graphical tests require approved desktop Direct3D access; headless/sandbox rendering attempts previously failed. Test scripts own and stop their processes, use isolated configuration/search paths, and do not modify the installed UT3 engine configuration or UT4 tracked plugin source. Validation is on Windows build 3809; Linux server execution has not been tested.

## Evidence

Final paths, hash and results appear in the first table. Compiler and engine logs are `Logs/compile.log.console.txt`, `Logs/compile.log` and `Logs/engine-tests.log`. The fourteen network runs were executed sequentially after compilation with both source and binaries frozen. Intermediate October 8 paths are listed with their results above; their delayed-actor runs, 313-check engine result and failed random-loss run are also archived under `Logs/diagnostic-runs/shock-handoff-intermediate/`. The final three Shock loss repeats are archived under `Logs/diagnostic-runs/shock-handoff-final-repeats/`.

The following paths belong to the **historical September 27 matrix**, not the current candidate:

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
- Packaging copies accepted final logs into `Evidence/<case>/`, includes retained diagnostic runs and the earlier collision/ownership pre-fix reproduction, and records gameplay binary/source SHA-256 hashes in `manifest.json`. The runtime contains only `NetcodePlusUT3.u`; test classes are supplied as source, with no `NCTests.u` runtime dependency.

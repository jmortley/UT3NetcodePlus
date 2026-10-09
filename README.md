# NetcodePlusUT3 — Weapon alpha

An independently compiled UT3 UnrealScript package covering **Shock, Sniper Rifle, Rocket Launcher and Flak Cannon**. Target: UT3 build 3809. This is a selective UT3 implementation, not full UT4 NetcodePlus parity.

## Included

- Server-side Shock and sniper body rewind, default maximum 150 ms and absolute configuration cap 250 ms. Rewind age comes from a server-timed challenge/reply, with startup and stale-measurement fallbacks.
- Fixed 128-sample history per tracked pawn, with death, possession, vehicle, crouch and stock teleport-generation boundaries. Trace calculations never relocate live pawns.
- Beam rewind only models the active, blocking pawn cylinder. Feign death, recovery, ragdolls and custom collision shapes use current native collision instead of an inaccurate historical standing cylinder; recording resumes with fresh history after an observed unsupported state.
- Current world obstruction and ordered shootable-trigger impacts. Portals, vehicles and non-UTPawn collisions fall back to stock tracing.
- Immediate owner-only core visuals on remote clients. A small visual-ID message matches a predicted visual to a core that stock firing already spawned on the server. The identity travels on the replicated core, avoiding an RPC/actor-arrival race. Unmatched visuals have a finite 1.5-second deadline. A valid match receives a separate 120 ms blend with a 200 ms cleanup deadline, so a near-expiry handoff can finish. Repeated matching cannot renew that deadline or hide another core.
- At most four predicted effects are retained. Rapid firing evicts the oldest effect and restores any authoritative core it was hiding. Cosmetic metadata still travels for each eligible secondary shot, including when its local effect cannot spawn, preserving server shot pairing.
- One-time server core catch-up after a stock-authorized spawn: up to **60 ms by default**, capped at 100 ms. The duration comes from measured half RTT and uses UT3's native projectile physics in bounded steps. Walls, pawn contact and core/core collisions stop flight normally; remaining flight lifetime is reduced by the advance. It adds no shots and does not change flight speed.
- Early impacts and failed spawns keep their shot slot within a 750 ms matching window. Their visual ID retires the corresponding prediction instead of being paired to the next surviving core. Consecutive metadata messages remain valid when packet recovery delivers them together. Shutdown/destruction also retires an already-assigned visual, covering a core that dies before its first actor update reaches the client.
- Cosmetic core identities include a server-issued ownership generation, pawn and controller. Old cores and delayed cleanup cannot consume a later owner's reused visual ID. Inventory removal/reacquisition and observed controller changes invalidate the old session; ordinary weapon switches keep the session and clean up local visuals.
- Stock authoritative collision, splash damage, core/core destruction and Shock combos. Primary and secondary firing RPCs, state transitions, refire intervals and ammo consumption remain inherited.
- Sniper head centers and radii are sampled from the stock skeletal head geometry and interpolated at the same time as the body. A scoped `NCPawn.IsLocationOnHead` override lets stock `TakeHeadShot` retain helmet absorption, damage types and headshot effects. Slow/running shooter scaling, zoom, cadence and ammo rules remain stock. Missing head history and unsupported custom pawns use stock traces.
- Rocket primary, loaded spread and launcher grenades receive at most **60 ms** of measured spawn catch-up by default, with a 100 ms hard cap. Advance starts after stock aiming and load setup. Native physics handles collisions and grenade bounces; grenades consume the corresponding portion of their original fuse. Charging, one/two/three-shot loads, ammo and release states are inherited. Seeking and spiral flight retain stock timing.
- Flak primary advances all nine stock shards after the complete spread has been generated; alternate fire advances the stock shell trajectory. Both use a separate **60 ms** default and 100 ms hard cap. Native collisions, bounce rules, center-shard bonus aging and shell splash remain stock. A shell impact creates five ordinary shards without a second latency advance. Initial replication carries the remaining bounce budget and lifetime to clients.
- Normal weapon pickups, lockers, ammo and default-loadout replacement for all four weapons. Spawned adapters retain the corresponding stock weapon-priority preferences. Other weapons and match rules remain stock.

## Current boundaries

Core compensation combines **visual prediction with authoritative matching and bounded server spawn catch-up**. Catch-up checks the current world and current actors; it does not rewind pawn positions for projectile hits. There are no client projectile-hit claims or historical combo-core traces. Combo detection uses the real server core; a predicted visual cannot cause damage or authorize a combo. A core can still visibly correct during handoff or disagree with the apparent timing of an off-axis combo. Catch-up alone does not solve those cases.

Core catch-up requires a fresh server ping estimate and a newly spawned remote player's core. Local players, bots, stale/unmeasured connections and projectiles with custom time dilation keep stock spawn timing. The core cannot receive a second or delayed catch-up. The default 60 ms window follows the current UT4 plugin's 120 ms RTT prediction cap, implemented through UT3's native physics API.

Stock teleporters and the translocator update `UTPawn.BigTeleportCount`. A custom teleport implementation that only calls `SetLocation` must call `NCRewind.ResetPawnHistory(Pawn)` or maintain that generation itself. The distance heuristic remains only a fallback. Moving doors and other world geometry are tested at their current positions.

The mutator replaces only an exact stock `UTPawn` default with `NCPawn`; it does not replace a custom game mode's pawn class. The adapter changes only the scoped headshot decision and delegates ordinary head tests to stock. Sniper compensation falls back when compatible head history is unavailable, or stock console/aim-assist behavior requires its own trace. Head sampling forces skeletal updates; large-player-count performance and animated-pose accuracy still need playtesting.

Rocket and Flak support currently advance authoritative projectiles at spawn; they do not add client visual prediction or historical projectile-hit claims. Seeking guidance and spiral flock timers are not replayed by the advance, so those rocket modes remain stock. Flak native aiming-help collision (`bWideCheck`) also keeps stock timing. Local/bot shooters and unmeasured/stale connections receive no latency advance. Rocket, Flak and Shock catch-up settings are independent.

Flak catch-up stops when a shell impacts; its child shards start at that impact without receiving the unused advance. It ages shard lifetime before each physics step so native contact damage sees the elapsed center-bonus time. A shard that stops bouncing keeps its stock cleanup timer. Initial state replication corrects the bounce budget, owner collision flag and remaining life; it does not reconcile subsequent client/server bounce divergence. Ordinary client rendering and flight simulation remain inherited.

Matching requests cannot create shots, change aim, move an authoritative core, spend ammo or apply damage. Each matching queue holds at most four slots. A server shot waits up to 750 ms for its metadata; metadata arriving before a shot retains the shorter 250 ms limit. If either deadline expires, a queue overflows, an ID is skipped, or switching weapons clears pending slots, cosmetic matching is suspended for that ownership session. Server catch-up continues, and existing valid handoffs may finish. Prediction resumes only after an actual ownership reset, such as dropping and reacquiring the weapon; an ordinary switch does not reset suspension. This prevents continuing FIFO matching after knowingly discarding a slot. FIFO still assumes corresponding client/server secondary-fire callbacks within those windows; this is not proof of correspondence for every firing-state divergence. Full UT4 fire-event sequencing and retry/authorization machinery have not been transplanted.

Prediction can temporarily fall back to the server core while a new ownership identity replicates. Matching remains ordered within each ownership session. Both endpoints must use this build: the cosmetic metadata RPC signatures differ from the September 22 alpha.

The Shock match failures exposed both a visual deadline shorter than observed authoritative actor arrival and a server queue deadline shorter than a recovered metadata delivery. The bounded handoff and queue changes have dedicated delayed-arrival tests; loss or delay beyond their finite deadlines still falls back to the server core. The original sniper extra-shot observation remains unestablished. Earlier evidence and current limits are preserved in `VALIDATION.md`; this remains a playtesting alpha.

## Build and test

Requires Windows, PowerShell and a licensed UT3 build 3809 installation. Run PowerShell from this directory:

```powershell
.\Build.ps1
.\Test.ps1
.\Test-Network.ps1 -SkipBuild
.\Test-Network.ps1 -SkipBuild -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -DelayedShock
.\Test-Network.ps1 -SkipBuild -DelayedShock -LagMs 80
.\Test-Network.ps1 -SkipBuild -Weapon Sniper
.\Test-Network.ps1 -SkipBuild -Weapon Sniper -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -Weapon StockSniper -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -Weapon Rockets
.\Test-Network.ps1 -SkipBuild -Weapon Rockets -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -Weapon Flak
.\Test-Network.ps1 -SkipBuild -Weapon Flak -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -Weapon StockFlak -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -StockBaseline
```

`Test.ps1` builds both the gameplay package and the separate `NCTests` harness. Network testing requires an interactive Windows desktop with Direct3D access and starts a loopback server plus two hidden client processes. The scripts stop only the processes they start. See `VALIDATION.md` for the tested environment and rendering constraints.

`StockSniper` and `StockFlak` repeat their input sequences with the exact stock weapons and no NetcodePlus mutator. A test-only controller discards desktop fire commands while the driver calls the weapon directly, keeping incidental mouse input out of automated results. Sniper/rocket/Flak network logs include local input times, pending-fire flags and refire timers to help separate input state from replicated ammo updates.

Build/test configuration overrides and logs live in this directory. The scripts use `-nohomedir -noini -noautoiniupdate` rather than editing the installed engine configuration. Pass `-UT3Root` if UT3 is installed elsewhere. Build output is `Build/NetcodePlusUT3.u`; tests are not required at runtime.

`DelayedShock` holds authoritative core replication for 900 ms while native flight and damage continue. It requires three successful matches on each client after the old 750 ms visual deadline, then the same combo, ammo, release, retirement and cleanup results. A separate no-loss 80 ms lag run tests that delay without combining it with unbounded retransmission delays.

After the engine, all four weapons' lag/loss and no-simulation runs, both delayed-Shock cases, stock-Flak control and stock connection baseline pass, run `.\Make-Package.ps1` to create `Dist/NetcodePlusUT3-Weapons-alpha.zip` with source, the gameplay package, validation evidence and a hash manifest. The former Shock-failure packaging exception has been removed; every required case must pass. Generated binaries, local configuration copies and raw logs are ignored by Git. See `VALIDATION.md` for results and remaining playtesting limits.

The installed engine emits pre-existing stock-package NetIndex diagnostics during compilation despite a successful zero-error/zero-warning script compiler summary. Client startup also emits stock HUD/online-service diagnostics; see `VALIDATION.md` for baseline comparisons and actual acceptance results. A compiler success is not a claim that every engine log line is clean.

## Try locally

```powershell
.\Play.ps1
```

This starts a local DM-Deck match using the compiled package and isolated engine search paths. Pick up the Shock Rifle, Sniper Rifle, Rocket Launcher or Flak Cannon normally. Offline play uses stock projectile rendering and no latency rewind, since there is no remote client delay to compensate. To observe predicted cores, connect through a dedicated server.

## Install the packaged alpha

The generated ZIP includes an `UTGame` directory. Merge that directory into your UT3 user-data root, normally `Documents/My Games/Unreal Tournament 3` (use your actual Documents location if Windows redirects it). The package then sits in `UTGame/Published/CookedPC/Script/NetcodePlusUT3.u`, and the menu/settings INI sits in `UTGame/Config/UTNetcodePlusUT3.ini`.

Enable **NetcodePlus UT3 - Weapon Alpha** as a mutator, or append `?mutator=NetcodePlusUT3.NCMutator` to a server map URL. Use this by itself while testing; stacking other weapon/pawn-replacement mutators, including UTComp3's wrappers, has not been validated. Both client and server need the same build. To uninstall, remove these two package-specific files.

Settings are under `[NetcodePlusUT3.NCMutator]`: `MaxRewindSeconds`, `MaxCoreCatchupSeconds`, `MaxRocketCatchupSeconds`, `MaxFlakCatchupSeconds` and `bPredictCores`. Set any catch-up duration to zero to disable that projectile family's server advance. This is independent of hitscan rewind and Shock visual prediction. The ZIP contains complete mod source and build scripts. It does not contain UT3 engine binaries or assets.

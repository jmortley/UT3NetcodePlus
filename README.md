# NetcodePlusUT3 — Shock alpha

An independently compiled UT3 UnrealScript package covering **Shock primary beams, secondary cores and combos**. Target: UT3 build 3809. This is the first selective UT3 implementation, not full UT4 NetcodePlus parity.

## Included

- Server-side primary body rewind, default maximum 150 ms and absolute configuration cap 250 ms. Rewind age comes from a server-timed challenge/reply, with startup and stale-measurement fallbacks.
- Fixed 128-sample history per tracked pawn, with death, possession, vehicle, crouch and stock teleport-generation boundaries. Trace calculations never relocate live pawns.
- Current world obstruction and ordered shootable-trigger impacts. Portals, vehicles and non-UTPawn collisions fall back to stock tracing.
- Immediate owner-only core visuals on remote clients. A small visual-ID message matches a predicted visual to a core that stock firing already spawned on the server. The identity travels on the replicated core, avoiding an RPC/actor-arrival race. Handoff blends over 120 ms; unmatched visuals expire after 750 ms.
- Stock authoritative core movement, collision, splash damage, core/core destruction and Shock combos. Primary and secondary firing RPCs, state transitions, refire intervals and ammo consumption remain inherited.
- Normal Shock weapon pickups, lockers, ammo and default-loadout replacement. Other weapons and match rules remain stock.

## Current boundaries

Core prediction is **visual prediction with authoritative matching**. Server core flight/collisions are not rewound or fast-forwarded. There are no client projectile-hit claims or historical combo-core traces. Combo detection uses the real server core; a predicted visual cannot cause damage or authorize a combo. In difficult latency conditions this conservative version can visibly correct a core's position or disagree with the apparent timing of an off-axis combo. Those are further projectile-compensation tasks, not solved by this alpha.

Stock teleporters and the translocator update `UTPawn.BigTeleportCount`. A custom teleport implementation that only calls `SetLocation` must call `NCRewind.ResetPawnHistory(Pawn)` or maintain that generation itself. The distance heuristic remains only a fallback. Moving doors and other world geometry are tested at their current positions. This Shock slice has no sniper/headshot implementation, console aim-assist validation, or other weapon adapters.

Matching requests cannot create shots, change aim, move an authoritative core, spend ammo or apply damage. Matching queues and their age are bounded. Expired or unmatched metadata falls back to the replicated server core. Full UT4 fire-event sequencing and retry/authorization machinery have not been transplanted.

## Build and test

Requires Windows, PowerShell and a licensed UT3 build 3809 installation. Run PowerShell from this directory:

```powershell
.\Build.ps1
.\Test.ps1
.\Test-Network.ps1 -SkipBuild
.\Test-Network.ps1 -SkipBuild -LagMs 80 -LossPercent 5
.\Test-Network.ps1 -SkipBuild -StockBaseline
```

`Test.ps1` builds both the gameplay package and the separate `NCTests` harness. Network testing requires an interactive Windows desktop with Direct3D access and starts a loopback server plus two hidden client processes. The scripts stop only the processes they start. See `VALIDATION.md` for the tested environment and rendering constraints.

Build/test configuration overrides and logs live in this directory. The scripts use `-nohomedir -noini -noautoiniupdate` rather than editing the installed engine configuration. Pass `-UT3Root` if UT3 is installed elsewhere. Build output is `Build/NetcodePlusUT3.u`; tests are not required at runtime.

After the engine, lag/loss and stock-baseline checks pass, run `.\Make-Package.ps1` to create `Dist/NetcodePlusUT3-Shock-alpha.zip` with source, the gameplay package, validation evidence and a hash manifest. Generated binaries, local configuration copies and raw logs are ignored by Git.

The installed engine emits pre-existing stock-package NetIndex diagnostics during compilation despite a successful zero-error/zero-warning script compiler summary. Client startup also emits stock HUD/online-service diagnostics; see `VALIDATION.md` for baseline comparisons and actual acceptance results. A compiler success is not a claim that every engine log line is clean.

## Try locally

```powershell
.\Play.ps1
```

This starts a local DM-Deck match using the compiled package and isolated engine search paths. Pick up the Shock Rifle normally. Offline play uses stock projectile rendering and no latency rewind, since there is no remote client delay to compensate. To observe predicted cores, connect through a dedicated server.

## Install the packaged alpha

The generated ZIP includes an `UTGame` directory. Merge that directory into your UT3 user-data root, normally `Documents/My Games/Unreal Tournament 3` (use your actual Documents location if Windows redirects it). The package then sits in `UTGame/Published/CookedPC/Script/NetcodePlusUT3.u`, and the menu/settings INI sits in `UTGame/Config/UTNetcodePlusUT3.ini`.

Enable **NetcodePlus UT3 - Shock Alpha** as a mutator, or append `?mutator=NetcodePlusUT3.NCMutator` to a server map URL. Use this by itself while testing; stacking another Shock weapon-replacement mutator, including UTComp3's wrappers, has not been validated. Both client and server need the same build. To uninstall, remove these two package-specific files.

Settings are under `[NetcodePlusUT3.NCMutator]`: `MaxRewindSeconds` and `bPredictCores`. The ZIP contains complete mod source and build scripts. It does not contain UT3 engine binaries or assets.

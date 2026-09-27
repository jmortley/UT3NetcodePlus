// Stock fire states, ammo, cadence, nine-shard spread and alt aiming are retained.
class NCFlakCannon extends UTWeap_FlakCannon;

var NCRewind Rewind;
var array<UTProjectile> PendingFlakShot;
var bool bCollectingFlakShot;
var int SpawnedShardCount, SpawnedShellCount;
var int CaughtUpShardCount, CaughtUpShellCount;
var float LastFlakCatchup;

simulated function PostBeginPlay()
{
    // Preserve profile priorities and stock negative-priority initialization.
    Priority=class'UTWeap_FlakCannon'.default.Priority;
    Super.PostBeginPlay();
}

function RegisterFlak(UTProjectile P)
{
    if (Role != ROLE_Authority || P == None || P.Instigator != Instigator) return;
    if (UTProj_FlakShard(P) != None) SpawnedShardCount++;
    else if (UTProj_FlakShell(P) != None) SpawnedShellCount++;
    // Init must not advance a shard while stock still generates the spread:
    // collision effects can consume randomness used by later shards' aim.
    if (bCollectingFlakShot && PendingFlakShot.Length < 9) PendingFlakShot.AddItem(P);
}

function float FlakDelay()
{
    if (Rewind == None) Rewind=class'NCRewind'.static.Find(self);
    if (Rewind == None) return 0;
    return Rewind.FlakCatchupFor(Instigator);
}

function AdvanceFlak(UTProjectile P, float Seconds)
{
    local float Advanced;
    if (P == None || P.bDeleteMe || P.bShuttingDown) return;
    if (NCFlakShardMain(P) != None) Advanced=NCFlakShardMain(P).AdvanceAtSpawn(Seconds);
    else if (NCFlakShard(P) != None) Advanced=NCFlakShard(P).AdvanceAtSpawn(Seconds);
    else if (NCFlakShell(P) != None) Advanced=NCFlakShell(P).AdvanceAtSpawn(Seconds);
    if (Advanced > 0)
    {
        if (UTProj_FlakShard(P) != None) CaughtUpShardCount++;
        else if (UTProj_FlakShell(P) != None) CaughtUpShellCount++;
        LastFlakCatchup=Advanced;
    }
}

simulated function CustomFire()
{
    local array<UTProjectile> Fired;
    local float Delay;
    local int i;
    if (Role != ROLE_Authority) { Super.CustomFire(); return; }
    PendingFlakShot.Length=0;
    bCollectingFlakShot=true;
    Super.CustomFire();
    bCollectingFlakShot=false;
    Fired=PendingFlakShot;
    PendingFlakShot.Length=0;
    Delay=FlakDelay();
    for (i=0;i<Fired.Length;i++) AdvanceFlak(Fired[i],Delay);
}

simulated function Projectile ProjectileFire()
{
    local vector RealStartLoc;
    local NCFlakShell P;
    // Stock Flak hardcodes its shell class here. Keep its flash, muzzle, and
    // GetAdjustedAim path (including stock alt pitch adjustment) unchanged.
    IncrementFlashCount();
    if (Role == ROLE_Authority)
    {
        RealStartLoc=GetPhysicalFireStartLoc();
        P=Spawn(class'NCFlakShell',,,RealStartLoc);
        if (P != None && !P.bDeleteMe)
        {
            P.Init(vector(GetAdjustedAim(RealStartLoc)));
            AdvanceFlak(P,FlakDelay());
        }
        return P;
    }
    return None;
}

defaultproperties
{
    CenterShardClass=class'NCFlakShardMain'
    WeaponProjectiles(0)=class'NCFlakShard'
    WeaponProjectiles(1)=class'NCFlakShell'
}

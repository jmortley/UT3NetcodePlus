// Stock firing, loading, release, ammo, lock-on and mode switching are inherited.
class NCRocketLauncher extends UTWeap_RocketLauncher;

var NCRewind Rewind;
var array<UTProjectile> PendingRocketLoad;
var bool bCollectingRocketLoad;
// Successful spawns of the NC projectile classes; seeking uses its stock class.
var int SpawnedRocketCount, CaughtUpRocketCount;
var float LastRocketCatchup;

simulated function PostBeginPlay()
{
    // Profiles update stock defaults after child defaults exist. Copy before
    // stock initialization so negative priorities retain its weight fallback.
    Priority=class'UTWeap_RocketLauncher'.default.Priority;
    Super.PostBeginPlay();
}

function RegisterRocket(UTProjectile P)
{
    // Init only records a shot. Seeking/flock setup is still incomplete here.
    if (Role != ROLE_Authority || P == None || P.Instigator != Instigator) return;
    SpawnedRocketCount++;
    if (bCollectingRocketLoad && PendingRocketLoad.Length < MaxLoadCount)
        PendingRocketLoad.AddItem(P);
}

function AdvanceRocket(UTProjectile P, float Seconds)
{
    local float Advanced;
    if (P == None || P.bDeleteMe || P.bShuttingDown) return;
    if (NCRocket(P) != None) Advanced=NCRocket(P).AdvanceAtSpawn(Seconds);
    else if (NCLoadedRocket(P) != None) Advanced=NCLoadedRocket(P).AdvanceAtSpawn(Seconds);
    else if (NCGrenade(P) != None) Advanced=NCGrenade(P).AdvanceAtSpawn(Seconds);
    if (Advanced > 0) { CaughtUpRocketCount++; LastRocketCatchup=Advanced; }
}

function float RocketDelay()
{
    if (Rewind == None) Rewind=class'NCRewind'.static.Find(self);
    if (Rewind == None) return 0;
    return Rewind.RocketCatchupFor(Instigator);
}

simulated function Projectile ProjectileFire()
{
    local Projectile P;
    P=Super.ProjectileFire();
    // Stock ProjectileFire has now assigned Seeking, if applicable.
    if (Role == ROLE_Authority) AdvanceRocket(UTProjectile(P),RocketDelay());
    return P;
}

function FireLoad()
{
    local array<UTProjectile> Fired;
    local float Delay;
    local int i;
    PendingRocketLoad.Length=0;
    bCollectingRocketLoad=true;
    Super.FireLoad();
    bCollectingRocketLoad=false;
    Fired=PendingRocketLoad;
    PendingRocketLoad.Length=0;
    // Flock fields and Seeking are complete only after the whole load returns.
    // Leave spiral timing and native seeking guidance exactly on the stock path.
    if (LoadedFireMode == RFM_Spiral || (LoadedFireMode != RFM_Grenades && bLockedOnTarget)) return;
    Delay=RocketDelay();
    for (i=0;i<Fired.Length;i++) AdvanceRocket(Fired[i],Delay);
}

defaultproperties
{
    WeaponProjectiles(0)=class'NCRocket'
    WeaponProjectiles(1)=class'NCRocket'
    LoadedRocketClass=class'NCLoadedRocket'
    GrenadeClass=class'NCGrenade'
}

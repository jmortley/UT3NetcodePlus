// Advance only native movement of a stock-authorized Flak projectile at spawn.
class NCFlakPhysics extends Object;

struct FlakInitialState
{
    var bool bValid;
    var int Bounces;
    var float RemainingLifeSpan;
    var bool bBlockedByInstigator;
    var bool bBounce;
    // -1 means no timer. A shard stopped before initial replication still needs
    // the stock local shrink timer; net-temporary actors do not stream cleanup.
    var float ShrinkDelay;
};

static function CaptureInitialState(UTProjectile P, out FlakInitialState Snapshot)
{
    local UTProj_FlakShard Shard;
    if (P == None || P.Role != ROLE_Authority || P.bDeleteMe) return;
    Shard=UTProj_FlakShard(P);
    Snapshot.Bounces=-1;
    Snapshot.ShrinkDelay=-1;
    if (Shard != None)
    {
        Snapshot.Bounces=Shard.Bounces;
        if (P.IsTimerActive('StartToShrink'))
            Snapshot.ShrinkDelay=FMax(0.001,P.GetTimerRate('StartToShrink')-P.GetTimerCount('StartToShrink'));
    }
    Snapshot.RemainingLifeSpan=P.LifeSpan;
    Snapshot.bBlockedByInstigator=P.bBlockedByInstigator;
    Snapshot.bBounce=P.bBounce;
    Snapshot.bValid=true;
}

static function bool ApplyInitialState(UTProjectile P, const out FlakInitialState Snapshot)
{
    local UTProj_FlakShard Shard;
    if (P == None || P.Role == ROLE_Authority || P.bDeleteMe || P.bShuttingDown
        || !Snapshot.bValid || Snapshot.RemainingLifeSpan <= 0) return false;
    Shard=UTProj_FlakShard(P);
    if (Shard != None) Shard.Bounces=Snapshot.Bounces;
    P.LifeSpan=Snapshot.RemainingLifeSpan;
    P.bBlockedByInstigator=Snapshot.bBlockedByInstigator;
    P.bBounce=Snapshot.bBounce;
    if (Shard != None && !Shard.bShrinking && P.Physics == PHYS_None && Snapshot.ShrinkDelay >= 0)
        P.SetTimer(FMax(0.001,Snapshot.ShrinkDelay),false,'StartToShrink');
    return true;
}

static function float Advance(UTProjectile P, float Seconds, out byte CatchupState)
{
    local UTProj_FlakShard Shard;
    local float Remaining, Step, Submitted;
    local int i;
    if (P == None || P.Role != ROLE_Authority || CatchupState != 0) return 0;
    CatchupState=1;
    Shard=UTProj_FlakShard(P);
    // Native aiming-help collision is not replayed through script here.
    if (P.bDeleteMe || P.bShuttingDown || P.bWideCheck || P.CustomTimeDilation != 1.0
        || P.WorldInfo.TimeSeconds-P.CreationTime > 0.05 || P.LifeSpan <= 0
        || (Shard == None && UTProj_FlakShell(P) == None)) return 0;
    if (Shard != None)
    {
        if (Shard.bShrinking || (P.Physics != PHYS_Projectile && P.Physics != PHYS_Falling)) return 0;
    }
    else if (P.Physics != PHYS_Falling) return 0;
    Remaining=FMin(FClamp(Seconds,0.0,0.10),FMax(0.0,P.LifeSpan-0.01));
    if (Remaining <= 0.005) return 0;
    for (i=0;i<13 && Remaining > 0.00001;i++)
    {
        if (P.bDeleteMe || P.bShuttingDown || P.LifeSpan <= 0.01) break;
        if (Shard != None)
        {
            // A stock bounce changes Projectile to Falling; continue its sweep.
            // Once stopped/shrinking, leave the stock cleanup timer untouched.
            if (Shard.bShrinking || (P.Physics != PHYS_Projectile && P.Physics != PHYS_Falling)) break;
        }
        else if (P.Physics != PHYS_Falling) break;
        Step=FMin(Remaining,FMin(1.0/120.0,P.LifeSpan-0.01));
        if (Step <= 0) break;
        // Stock shard damage and center bonus read LifeSpan inside collision
        // callbacks. Age first, and preserve any bounce extension/Shutdown life.
        P.LifeSpan=FMax(0.01,P.LifeSpan-Step);
        P.AutonomousPhysics(Step);
        Submitted+=Step;
        Remaining-=Step;
    }
    if (!P.bDeleteMe && !P.bShuttingDown && Submitted > 0)
    {
        P.bNetDirty=true;
        P.bForceNetUpdate=true;
    }
    return Submitted;
}

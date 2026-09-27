// Bounded server-only movement of an already authorized, fully initialized shot.
class NCRocketPhysics extends Object;

static function float Advance(UTProjectile P, float Seconds, out byte CatchupState)
{
    local float Remaining, Step, Submitted, FuseRemaining;
    local int i;
    local bool bGrenade;
    if (P == None || P.Role != ROLE_Authority || CatchupState != 0) return 0;
    CatchupState=1;
    bGrenade=UTProj_Grenade(P) != None;
    if (P.bDeleteMe || P.bShuttingDown || P.CustomTimeDilation != 1.0
        || P.WorldInfo.TimeSeconds-P.CreationTime > 0.05
        || (!bGrenade && P.Physics != PHYS_Projectile)
        || (bGrenade && P.Physics != PHYS_Falling)) return 0;
    // Seeking steering is native; flocking uses a separate timer. Neither is
    // replayed by AutonomousPhysics, so these modes retain stock movement.
    if (UTProj_SeekingRocket(P) != None
        || (UTProj_LoadedRocket(P) != None && UTProj_LoadedRocket(P).FlockIndex != 0)) return 0;
    Remaining=FClamp(Seconds,0.0,0.10);
    if (P.LifeSpan > 0) Remaining=FMin(Remaining,FMax(0.0,P.LifeSpan-0.01));
    if (bGrenade)
    {
        // Preserve the fuse selected by stock PostBeginPlay; never reroll it.
        if (!P.IsTimerActive()) return 0;
        FuseRemaining=P.GetTimerRate()-P.GetTimerCount();
        Remaining=FMin(Remaining,FMax(0.0,FuseRemaining-0.01));
    }
    if (Remaining <= 0.005) return 0;
    for (i=0;i<13 && Remaining > 0.00001;i++)
    {
        if (P.bDeleteMe || P.bShuttingDown
            || (!bGrenade && P.Physics != PHYS_Projectile)
            || (bGrenade && P.Physics != PHYS_Falling)) break;
        Step=FMin(Remaining,1.0/120.0);
        P.AutonomousPhysics(Step);
        Submitted+=Step;
        Remaining-=Step;
        if (!P.bDeleteMe && !P.bShuttingDown && P.LifeSpan > 0)
            P.LifeSpan=FMax(0.01,P.LifeSpan-Step);
    }
    if (!P.bDeleteMe && !P.bShuttingDown)
    {
        if (bGrenade && Submitted > 0) P.SetTimer(FMax(0.01,FuseRemaining-Submitted),false);
        P.bNetDirty=true;
        P.bForceNetUpdate=true;
    }
    return Submitted;
}

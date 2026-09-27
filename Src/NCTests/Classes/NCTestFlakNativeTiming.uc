// Compare opaque stock native ticking with spawn-time physics advancement.
// Free flight only: collision/bounce/damage callbacks have separate tests.
class NCTestFlakNativeTiming extends Info;

var NCTestMutator Tests;
var UTProjectile References[3];
var vector Origins[3];
var vector InitialVelocities[3], InitialAccelerations[3];
var EPhysics InitialPhysics[3];
var float InitialLife[3];
var float StartedAt;
var int Stage, NativeTicks;

function Run(NCTestMutator T)
{
    Tests=T;
}

function Prepare(UTProjectile P)
{
    // Keep native tick and gravity intact. Only exclude actor/world contacts
    // and cosmetic work, identically for both sides of the comparison.
    P.SetCollision(false,false);
    P.bCollideWorld=false;
    P.bSuppressExplosionFX=true;
    P.bSuppressSounds=true;
    P.SetTickGroup(TG_PreAsyncWork);
    P.Init(Normal(vect(1,0,0.1)));
}

function BeginProbe()
{
    local int i;
    local class<UTProjectile> ProjectileClass;
    for (i=0;i<3;i++)
    {
        Origins[i]=vect(0,150000,10000)+vect(0,3000,0)*float(i);
        if (i == 0) ProjectileClass=class'UTProj_FlakShard';
        else if (i == 1) ProjectileClass=class'UTProj_FlakShardMain';
        else ProjectileClass=class'UTProj_FlakShell';
        References[i]=Spawn(ProjectileClass,,,Origins[i]);
        Tests.Check(References[i] != None,"native Flak timing stock setup case " $ i);
        if (References[i] != None)
        {
            Prepare(References[i]);
        }
    }
    Stage=1;
}

function EstablishBaseline()
{
    local int i;
    // Newly spawned actors may receive the current frame's complete native
    // delta after our spawn call. Wait for a completed real tick, then measure
    // from this observed state instead of counting that pre-baseline delta.
    for (i=0;i<3;i++)
    {
        if (References[i] == None || References[i].bDeleteMe) continue;
        Origins[i]=References[i].Location;
        InitialVelocities[i]=References[i].Velocity;
        InitialAccelerations[i]=References[i].Acceleration;
        InitialPhysics[i]=References[i].Physics;
        InitialLife[i]=References[i].LifeSpan;
    }
    StartedAt=WorldInfo.TimeSeconds;
    NativeTicks=0;
    Stage=2;
}

function CompareProbe(float Elapsed)
{
    local int i;
    local UTProjectile P, R;
    local class<UTProjectile> ProjectileClass;
    local vector Origin, PositionError, VelocityError;
    local float Advanced, Age;
    local bool SameBounces;
    Tests.Check(NativeTicks >= 2 && Elapsed >= 0.06 && Elapsed <= 0.10001,
        "native Flak timing spans real ticks within catch-up bound");
    if (Elapsed > 0.10001)
    {
        Cleanup();
        return;
    }
    for (i=0;i<3;i++)
    {
        R=References[i];
        if (R == None || R.bDeleteMe)
        {
            Tests.Check(false,"native Flak timing stock survives free flight case " $ i);
            continue;
        }
        Origin=Origins[i]+vect(0,500,0);
        if (i == 0) ProjectileClass=class'NCFlakShard';
        else if (i == 1) ProjectileClass=class'NCFlakShardMain';
        else ProjectileClass=class'NCFlakShell';
        P=Spawn(ProjectileClass,,,Origin);
        Tests.Check(P != None,"native Flak timing advanced setup case " $ i);
        if (P == None) continue;
        Prepare(P);
        // Begin the new adapter at the same observed flight state. The stock
        // actor itself is never repositioned, manually aged, or physics-stepped.
        P.Velocity=InitialVelocities[i];
        P.Acceleration=InitialAccelerations[i];
        P.SetPhysics(InitialPhysics[i]);
        P.LifeSpan=InitialLife[i];
        Origin=P.Location;
        if (i == 0) Advanced=NCFlakShard(P).AdvanceAtSpawn(Elapsed);
        else if (i == 1) Advanced=NCFlakShardMain(P).AdvanceAtSpawn(Elapsed);
        else Advanced=NCFlakShell(P).AdvanceAtSpawn(Elapsed);
        Age=InitialLife[i]-R.LifeSpan;
        PositionError=(P.Location-Origin)-(R.Location-Origins[i]);
        VelocityError=P.Velocity-R.Velocity;
        SameBounces=true;
        if (i < 2) SameBounces=UTProj_FlakShard(P).Bounces == UTProj_FlakShard(R).Bounces;
        LogInternal("[NCTests] native Flak timing case=" $ i $ " elapsed=" $ Elapsed
            $ " stock-age=" $ Age $ " advanced=" $ Advanced
            $ " position-error=" $ PositionError $ " velocity-error=" $ VelocityError
            $ " life-error=" $ (P.LifeSpan-R.LifeSpan) $ " physics=" $ P.Physics $ "/" $ R.Physics);
        // This is a phase check, not evidence of a movement defect if it fails.
        Tests.Check(Abs(Age-Elapsed)<0.002 && Abs(Advanced-Elapsed)<0.0001
            && P.PhysicsVolume == R.PhysicsVolume,
            "native Flak timing clocks and environment agree case " $ i);
        // Falling uses native frame sizes versus <=1/120s substeps. One world
        // unit allows integration rounding without hiding a missed frame or
        // substantial native speed/gravity behavior over this short interval.
        Tests.Check(VSize(PositionError)<1.0 && VSize(VelocityError)<1.0,
            "native Flak free-flight movement matches physics catch-up case " $ i);
        Tests.Check(Abs(P.LifeSpan-R.LifeSpan)<0.002 && P.Physics == R.Physics && SameBounces,
            "native Flak age physics and bounce budget match catch-up case " $ i);
        P.Destroy();
    }
    Cleanup();
}

function Cleanup()
{
    local int i;
    for (i=0;i<3;i++) if (References[i] != None) References[i].Destroy();
    Destroy();
}

event Tick(float DeltaTime)
{
    if (Tests == None) return;
    if (Stage == 0)
    {
        // Start after the normal projectile tick group, then observe completed
        // stock physics in that same phase on subsequent real engine frames.
        BeginProbe();
        return;
    }
    if (Stage == 1)
    {
        EstablishBaseline();
        return;
    }
    NativeTicks++;
    if (WorldInfo.TimeSeconds-StartedAt >= 0.06)
        CompareProbe(WorldInfo.TimeSeconds-StartedAt);
}

defaultproperties
{
    RemoteRole=ROLE_None
    bAlwaysTick=true
    TickGroup=TG_PostAsyncWork
}

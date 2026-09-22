// Local visual only. It never damages, combos, blocks pawns or replicates.
class NCPredictedCore extends UTProj_ShockBall;

var int VisualId;
var NCShockBall MatchedCore;
var float BlendRemaining;

simulated function MatchTo(NCShockBall Core)
{
    if (Core == None || Core.bDeleteMe || Core.bShuttingDown) { Destroy(); return; }
    MatchedCore=Core;
    BlendRemaining=0.12;
    SetPhysics(PHYS_None);
    bCollideWorld=false;
    Core.SetHidden(true);
}

simulated event Tick(float DeltaTime)
{
    if (MatchedCore != None)
    {
        if (MatchedCore.bDeleteMe || MatchedCore.bShuttingDown) { Destroy(); return; }
        SetLocation(Location+(MatchedCore.Location-Location)*FClamp(DeltaTime/FMax(BlendRemaining,0.001),0.0,1.0));
        BlendRemaining-=DeltaTime;
        if (BlendRemaining <= 0) Destroy();
    }
}

simulated function ProcessTouch(Actor Other, vector HitLocation, vector HitNormal) {}
simulated singular event HitWall(vector HitNormal, Actor Wall, PrimitiveComponent WallComp) { Destroy(); }
simulated function Explode(vector HitLocation, vector HitNormal) { Destroy(); }
function ComboExplosion() {}
event TakeDamage(int Amount, Controller From, vector HitLocation, vector Momentum,
    class<DamageType> Type, optional TraceHitInfo HitInfo, optional Actor Causer) {}

simulated function Destroyed()
{
    if (MatchedCore != None && !MatchedCore.bDeleteMe && !MatchedCore.bShuttingDown) MatchedCore.SetHidden(false);
    Super.Destroyed();
}

defaultproperties
{
    RemoteRole=ROLE_None
    bCollideActors=false
    bBlockActors=false
    bProjTarget=false
    Damage=0
    DamageRadius=0
    MomentumTransfer=0
    ComboDamage=0
    ComboRadius=0
    bSuppressExplosionFX=true
    bSuppressSounds=true
    LifeSpan=0.75
}

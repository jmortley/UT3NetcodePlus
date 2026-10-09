// Local visual only. It never damages, combos, blocks pawns or replicates.
class NCPredictedCore extends UTProj_ShockBall;

var int VisualId;
var int PredictionGeneration;
var Pawn PredictionOwner;
var Controller PredictionController;
var NCShockBall MatchedCore;
var float BlendRemaining;
var bool bHandoffStarted;

simulated function bool MatchTo(NCShockBall Core)
{
    if (bDeleteMe || bShuttingDown || bHandoffStarted || Core == None || Core.bDeleteMe || Core.bShuttingDown) return false;
    bHandoffStarted=true;
    MatchedCore=Core;
    BlendRemaining=0.12;
    // A late valid match gets its full blend, independent of the old deadline.
    // The short watchdog also unhides the real core if visual ticking stalls.
    LifeSpan=0.20;
    SetPhysics(PHYS_None);
    bCollideWorld=false;
    Core.SetHidden(true);
    return true;
}

simulated event Tick(float DeltaTime)
{
    if (bHandoffStarted)
    {
        if (MatchedCore == None || MatchedCore.bDeleteMe || MatchedCore.bShuttingDown) { Destroy(); return; }
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
    // Finite grace for delayed/reordered authoritative actor replication.
    // Retirement, world impacts and weapon cleanup can still end it sooner.
    LifeSpan=1.5
}

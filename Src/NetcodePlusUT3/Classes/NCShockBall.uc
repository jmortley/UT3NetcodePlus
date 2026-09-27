// Stock collision/damage, with a bounded native physics advance at server spawn.
class NCShockBall extends UTProj_ShockBall;

var NCShockRifle PredictionWeapon;
var int VisualId;
var int PredictionGeneration;
var Pawn PredictionOwner;
var Controller PredictionController;
var bool bMatchResolved;
var bool bCatchupResolved;
var bool bVisualRetired;
// Server-only diagnostics: physics time submitted, never a client-supplied value.
var float CatchupSeconds;

replication
{
    if (Role == ROLE_Authority) PredictionWeapon, VisualId, PredictionGeneration, PredictionOwner, PredictionController;
}

// Called only after stock ProjectileFire has authorized, spawned and aimed a core.
// AutonomousPhysics runs the engine's swept projectile movement and touch/wall code.
// It does not tick firing states, timers, or permit another shot.
function float AdvanceAtSpawn(float Seconds)
{
    local float Remaining, Step;
    local int i;
    if (Role != ROLE_Authority || bCatchupResolved) return 0;
    bCatchupResolved=true;
    if (bDeleteMe || bShuttingDown || Physics != PHYS_Projectile
        || WorldInfo.TimeSeconds-CreationTime > 0.05 || CustomTimeDilation != 1.0) return 0;
    Remaining=FClamp(Seconds,0.0,0.10);
    if (LifeSpan > 0) Remaining=FMin(Remaining,FMax(0.0,LifeSpan-0.01));
    if (Remaining <= 0.005) return 0;
    // Explicit bound even if a physics callback changes state or destroys us.
    for (i=0;i<13 && Remaining > 0.00001;i++)
    {
        if (bDeleteMe || bShuttingDown || Physics != PHYS_Projectile) break;
        Step=FMin(Remaining,1.0/120.0);
        AutonomousPhysics(Step);
        CatchupSeconds+=Step;
        Remaining-=Step;
        // Shutdown owns its short replication/FX lifetime after an impact.
        if (!bDeleteMe && !bShuttingDown && LifeSpan > 0) LifeSpan=FMax(0.01,LifeSpan-Step);
    }
    return CatchupSeconds;
}

function SetVisualIdentity(NCShockRifle W, int Id)
{
    if (Role != ROLE_Authority || VisualId != 0 || W == None || W.bDeleteMe || Id <= 0
        || W.PredictionGeneration <= 0 || W.MatchOwner == None || W.MatchController == None
        || W.MatchOwner != W.Instigator || W.MatchController != W.Instigator.Controller
        || Instigator != W.MatchOwner) return;
    PredictionWeapon=W;
    VisualId=Id;
    PredictionGeneration=W.PredictionGeneration;
    PredictionOwner=W.MatchOwner;
    PredictionController=W.MatchController;
    bNetDirty=true;
    bForceNetUpdate=true;
}

function RetireOwnerVisual()
{
    if (!bVisualRetired && PredictionWeapon != None && !PredictionWeapon.bDeleteMe && VisualId > 0
        && PredictionGeneration > 0 && PredictionOwner != None && PredictionController != None
        && PredictionWeapon.PredictionGeneration == PredictionGeneration
        && PredictionWeapon.Instigator == PredictionOwner && PredictionOwner.Controller == PredictionController)
    {
        bVisualRetired=true;
        PredictionWeapon.ClientRetireVisual(VisualId,PredictionGeneration,PredictionOwner,PredictionController);
    }
}

simulated function Shutdown()
{
    // The ID may already be assigned while the core's first actor update is pending.
    // Send cleanup on the existing weapon channel even if that actor never arrives.
    if (Role == ROLE_Authority) RetireOwnerVisual();
    Super.Shutdown();
}

simulated event Destroyed()
{
    if (Role == ROLE_Authority) RetireOwnerVisual();
    Super.Destroyed();
}

simulated event Tick(float DeltaTime)
{
    // The actor, weapon reference and identity may arrive in different updates.
    // Wait for the complete identity instead of passing an unmapped actor in a weapon RPC.
    if (Role < ROLE_Authority && !bMatchResolved && VisualId > 0 && PredictionGeneration > 0
        && PredictionWeapon != None && PredictionOwner != None && PredictionController != None
        && Instigator == PredictionOwner && PredictionOwner.Controller == PredictionController
        && PredictionOwner.IsLocallyControlled())
    {
        PredictionWeapon.MatchVisual(VisualId,PredictionGeneration,PredictionOwner,PredictionController,self);
        bMatchResolved=true;
    }
}

// Stock Start/Stop RPCs, refire states, ammo and charge behavior are inherited.
class NCShockRifle extends UTWeap_ShockRifle;

struct CoreRecord
{
    var NCShockBall Core;
    var float Time;
};
struct VisualRequest
{
    var int Id;
    var float Time;
};
var NCRewind Rewind;
var array<NCPredictedCore> Visuals;
var array<CoreRecord> UnmatchedCores;
var array<VisualRequest> Requests;
var int NextVisualId, LastVisualId;
// Server-issued cosmetic identity; it does not participate in stock firing.
var int PredictionGeneration;
var Pawn MatchOwner;
var Controller MatchController;
var float LastRequestAt;
var bool bPredictionEnabled;
// Local diagnostics: no replication or effect on firing decisions.
var int PredictedVisualCount, MatchedVisualCount, RetiredVisualCount;
var int CaughtUpCoreCount;
var float LastCoreCatchup;

replication
{
    if (bNetInitial && Role == ROLE_Authority) bPredictionEnabled;
    if (Role == ROLE_Authority) PredictionGeneration;
}

simulated function PostBeginPlay()
{
    // Profile settings modify the stock defaults after child defaults exist.
    // Copy before stock initialization so negative priorities keep its fallback.
    Priority=class'UTWeap_ShockRifle'.default.Priority;
    Super.PostBeginPlay();
}

simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
    local ImpactInfo Impact;
    if (Role == ROLE_Authority && CurrentFireMode == 0)
    {
        if (Rewind == None) Rewind=class'NCRewind'.static.Find(self);
        if (Rewind != None && Rewind.TraceShot(self,StartTrace,EndTrace,Impact,ImpactList))
        {
            bWasACombo=UTProj_ShockBall(Impact.HitActor) != None;
            return Impact;
        }
    }
    return Super.CalcWeaponFire(StartTrace,EndTrace,ImpactList);
}

simulated function Projectile ProjectileFire()
{
    local Projectile P;
    local NCPredictedCore Visual;
    local CoreRecord Record;
    local vector Start;
    local float Advanced;
    P=Super.ProjectileFire();
    if (CurrentFireMode != 1 || Instigator == None) return P;
    if (Role == ROLE_Authority)
    {
        CheckMatchOwner();
        if (PlayerController(Instigator.Controller) != None && !Instigator.IsLocallyControlled())
        {
            Record.Core=NCShockBall(P);
            if (Record.Core != None)
            {
                if (Rewind == None) Rewind=class'NCRewind'.static.Find(self);
                if (Rewind != None) Advanced=Record.Core.AdvanceAtSpawn(Rewind.CoreCatchupFor(Instigator));
                if (Advanced > 0) { CaughtUpCoreCount++; LastCoreCatchup=Advanced; }
            }
            Record.Time=WorldInfo.TimeSeconds;
            // Retain even a failed spawn/early impact as a completed shot slot.
            // Its metadata retires its own visual instead of matching the next core.
            UnmatchedCores.AddItem(Record);
            ServiceMatches();
        }
    }
    else if (bPredictionEnabled && PredictionGeneration > 0 && Instigator.Controller != None
        && Instigator.IsLocallyControlled() && !WorldInfo.bWithinDemoPlayback)
    {
        PruneVisuals();
        if (Visuals.Length >= 4) return P;
        Start=GetPhysicalFireStartLoc();
        Visual=Spawn(class'NCPredictedCore',self,,Start);
        if (Visual != None)
        {
            NextVisualId++;
            if (NextVisualId <= 0) NextVisualId=1;
            Visual.VisualId=NextVisualId;
            Visual.PredictionGeneration=PredictionGeneration;
            Visual.PredictionOwner=Instigator;
            Visual.PredictionController=Instigator.Controller;
            Visual.Init(vector(GetAdjustedAim(Start)));
            Visuals.AddItem(Visual);
            PredictedVisualCount++;
            ServerVisual(NextVisualId,Visual.PredictionGeneration,Visual.PredictionOwner,Visual.PredictionController);
        }
    }
    return P;
}

function ResetPredictionIdentity(Pawn NewOwner)
{
    if (Role != ROLE_Authority) return;
    PredictionGeneration++;
    if (PredictionGeneration <= 0) PredictionGeneration=1;
    MatchOwner=NewOwner;
    MatchController=None;
    if (NewOwner != None) MatchController=NewOwner.Controller;
    UnmatchedCores.Length=0;
    Requests.Length=0;
    LastVisualId=0;
    LastRequestAt=-1;
    bNetDirty=true;
    bForceNetUpdate=true;
}

function GivenTo(Pawn NewOwner, bool bDoNotActivate)
{
    // Initialize before stock GivenTo sends its owning-client notification.
    ResetPredictionIdentity(NewOwner);
    Super.GivenTo(NewOwner,bDoNotActivate);
}

function ItemRemovedFromInvManager()
{
    // A drop and reacquisition by the same pawn must still end the old session.
    // DetachWeapon also runs on ordinary weapon switches and is not this boundary.
    ResetPredictionIdentity(None);
    Super.ItemRemovedFromInvManager();
}

function CheckMatchOwner()
{
    if (Role == ROLE_Authority && (MatchOwner != Instigator
        || (Instigator != None && MatchController != Instigator.Controller)
        || (Instigator == None && MatchController != None)))
    {
        ResetPredictionIdentity(Instigator);
    }
}

// Metadata only: this function cannot fire, spawn, move, damage or spend ammo.
reliable server function ServerVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController)
{
    local VisualRequest Request;
    CheckMatchOwner();
    if (!bPredictionEnabled || Generation <= 0 || Generation != PredictionGeneration
        || VisualOwner == None || VisualController == None || VisualOwner != MatchOwner
        || VisualController != MatchController || Instigator == None
        || Instigator.Health <= 0 || Instigator.Weapon != self
        || Id <= LastVisualId || WorldInfo.TimeSeconds-LastRequestAt < 0.1) return;
    LastVisualId=Id;
    LastRequestAt=WorldInfo.TimeSeconds;
    ServiceMatches();
    if (Requests.Length >= 4) return;
    Request.Id=Id;
    Request.Time=WorldInfo.TimeSeconds;
    Requests.AddItem(Request);
    ServiceMatches();
}

function ServiceMatches()
{
    local int i;
    // Also protect direct service calls after a possession/ownership change.
    CheckMatchOwner();
    for (i=UnmatchedCores.Length-1;i>=0;i--)
        if (WorldInfo.TimeSeconds-UnmatchedCores[i].Time > 0.25)
            UnmatchedCores.Remove(i,1);
    for (i=Requests.Length-1;i>=0;i--)
        if (WorldInfo.TimeSeconds-Requests[i].Time > 0.25) Requests.Remove(i,1);
    while (UnmatchedCores.Length > 0 && Requests.Length > 0)
    {
        if (UnmatchedCores[0].Core != None && !UnmatchedCores[0].Core.bDeleteMe && !UnmatchedCores[0].Core.bShuttingDown)
            UnmatchedCores[0].Core.SetVisualIdentity(self,Requests[0].Id);
        else ClientRetireVisual(Requests[0].Id,PredictionGeneration,MatchOwner,MatchController);
        Requests.Remove(0,1);
        UnmatchedCores.Remove(0,1);
    }
    while (UnmatchedCores.Length > 4) UnmatchedCores.Remove(0,1);
}

reliable client function ClientRetireVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController)
{
    local int i;
    if (Generation <= 0 || VisualOwner == None || VisualController == None) return;
    for (i=0;i<Visuals.Length;i++)
        if (Visuals[i] != None && !Visuals[i].bDeleteMe && Visuals[i].VisualId == Id
            && Visuals[i].PredictionGeneration == Generation && Visuals[i].PredictionOwner == VisualOwner
            && Visuals[i].PredictionController == VisualController)
        {
            Visuals[i].Destroy();
            RetiredVisualCount++;
            break;
        }
    PruneVisuals();
}

simulated function MatchVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController, NCShockBall Core)
{
    local int i;
    // Validate the actor metadata as well as the local visual. A weapon actor can
    // be reused by another owner while an earlier core is still replicating.
    if (Generation <= 0 || VisualOwner == None || VisualController == None
        || Core == None || Core.bDeleteMe || Core.bShuttingDown
        || Core.PredictionWeapon != self || Core.VisualId != Id
        || Core.PredictionGeneration != Generation || Core.PredictionOwner != VisualOwner
        || Core.PredictionController != VisualController || Core.Instigator != VisualOwner
        || VisualOwner.Controller != VisualController) return;
    PruneVisuals();
    for (i=0;i<Visuals.Length;i++)
        if (Visuals[i].VisualId == Id && Visuals[i].PredictionGeneration == Generation
            && Visuals[i].PredictionOwner == VisualOwner && Visuals[i].PredictionController == VisualController)
        {
            if (Visuals[i].MatchedCore == Core) return;
            Visuals[i].MatchTo(Core);
            if (Core != None && !Core.bDeleteMe && !Core.bShuttingDown) MatchedVisualCount++;
            return;
        }
}

simulated function PruneVisuals()
{
    local int i;
    for (i=Visuals.Length-1;i>=0;i--)
        if (Visuals[i] == None || Visuals[i].bDeleteMe) Visuals.Remove(i,1);
}

simulated function DetachWeapon()
{
    local int i;
    for (i=0;i<Visuals.Length;i++) if (Visuals[i] != None) Visuals[i].Destroy();
    Visuals.Length=0;
    UnmatchedCores.Length=0;
    Requests.Length=0;
    Super.DetachWeapon();
}

simulated event Destroyed()
{
    local int i;
    for (i=0;i<Visuals.Length;i++) if (Visuals[i] != None) Visuals[i].Destroy();
    Super.Destroyed();
}

defaultproperties
{
    WeaponProjectiles(1)=class'NCShockBall'
    bPredictionEnabled=true
    LastRequestAt=-1
}

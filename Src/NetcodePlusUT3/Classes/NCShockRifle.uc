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
var Pawn MatchOwner;
var Controller MatchController;
var float LastRequestAt;
var bool bPredictionEnabled;
// Local diagnostics: no replication or effect on firing decisions.
var int PredictedVisualCount, MatchedVisualCount;

replication
{
    if (bNetInitial && Role == ROLE_Authority) bPredictionEnabled;
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
    P=Super.ProjectileFire();
    if (CurrentFireMode != 1 || Instigator == None) return P;
    if (Role == ROLE_Authority)
    {
        CheckMatchOwner();
        if (NCShockBall(P) != None && !P.bDeleteMe && PlayerController(Instigator.Controller) != None && !Instigator.IsLocallyControlled())
        {
            Record.Core=NCShockBall(P);
            Record.Time=WorldInfo.TimeSeconds;
            UnmatchedCores.AddItem(Record);
            ServiceMatches();
        }
    }
    else if (bPredictionEnabled && Instigator.IsLocallyControlled() && !WorldInfo.bWithinDemoPlayback)
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
            Visual.Init(vector(GetAdjustedAim(Start)));
            Visuals.AddItem(Visual);
            PredictedVisualCount++;
            ServerVisual(NextVisualId);
        }
    }
    return P;
}

function CheckMatchOwner()
{
    if (MatchOwner != Instigator || (Instigator != None && MatchController != Instigator.Controller))
    {
        MatchOwner=Instigator;
        MatchController=None;
        if (Instigator != None) MatchController=Instigator.Controller;
        UnmatchedCores.Length=0;
        Requests.Length=0;
        LastVisualId=0;
        LastRequestAt=-1;
    }
}

// Metadata only: this function cannot fire, spawn, move, damage or spend ammo.
reliable server function ServerVisual(int Id)
{
    local VisualRequest Request;
    CheckMatchOwner();
    if (!bPredictionEnabled || Instigator == None || Instigator.Health <= 0 || Instigator.Weapon != self
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
    for (i=UnmatchedCores.Length-1;i>=0;i--)
        if (UnmatchedCores[i].Core == None || UnmatchedCores[i].Core.bDeleteMe
            || UnmatchedCores[i].Core.bShuttingDown || WorldInfo.TimeSeconds-UnmatchedCores[i].Time > 0.25)
            UnmatchedCores.Remove(i,1);
    for (i=Requests.Length-1;i>=0;i--)
        if (WorldInfo.TimeSeconds-Requests[i].Time > 0.25) Requests.Remove(i,1);
    while (UnmatchedCores.Length > 0 && Requests.Length > 0)
    {
        UnmatchedCores[0].Core.SetVisualIdentity(self,Requests[0].Id);
        Requests.Remove(0,1);
        UnmatchedCores.Remove(0,1);
    }
    while (UnmatchedCores.Length > 4) UnmatchedCores.Remove(0,1);
}

simulated function MatchVisual(int Id, NCShockBall Core)
{
    local int i;
    PruneVisuals();
    for (i=0;i<Visuals.Length;i++)
        if (Visuals[i].VisualId == Id)
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

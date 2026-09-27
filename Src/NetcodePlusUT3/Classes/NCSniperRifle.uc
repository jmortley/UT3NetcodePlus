// Stock zoom, firing state, cadence, ammo and native headshot damage are inherited.
class NCSniperRifle extends UTWeap_SniperRifle;

var NCRewind Rewind;
var bool bInstantTraceScope, bHistoricalDecision, bHistoricalHeadShot;
var Weapon.ImpactInfo HistoricalImpact;
var NCPawnHistory HistoricalHistory;
var float HistoricalTime;
// Local server diagnostics; no replication or firing authorization.
var int RewoundShotCount, RewoundBodyshotCount, RewoundHeadshotCount;

simulated function PostBeginPlay()
{
    // Profile settings modify the stock class defaults after child defaults exist.
    // Copy before stock initialization so negative priorities retain its fallback.
    Priority=class'UTWeap_SniperRifle'.default.Priority;
    Super.PostBeginPlay();
}

simulated function InstantFire()
{
    bInstantTraceScope=true;
    bHistoricalDecision=false;
    Super.InstantFire();
    bHistoricalDecision=false;
    bInstantTraceScope=false;
    HistoricalImpact.HitActor=None;
    HistoricalHistory=None;
}

simulated function ImpactInfo CalcWeaponFire(vector StartTrace, vector EndTrace, optional out array<ImpactInfo> ImpactList)
{
    local ImpactInfo Impact;
    local array<ImpactInfo> RewoundImpacts;
    local NCPawnHistory H;
    local UTPawn P;
    local UTPlayerController PC;
    local vector Position, HeadPosition;
    local float Delay, TargetTime, Radius, Height, HeadRadius, Scaling;
    local int i;
    bHistoricalDecision=false;
    HistoricalHistory=None;
    if (Role == ROLE_Authority && bInstantTraceScope && CurrentFireMode == 0
        && Instigator != None && PlayerController(Instigator.Controller) != None
        && UTConsolePlayerController(Instigator.Controller) == None && !WorldInfo.IsConsoleBuild())
    {
        PC=UTPlayerController(Instigator.Controller);
        if (PC != None && PC.AimingHelp(true)) return Super.CalcWeaponFire(StartTrace,EndTrace,ImpactList);
        if (Rewind == None) Rewind=class'NCRewind'.static.Find(self);
        if (Rewind != None)
        {
            Delay=Rewind.RewindFor(Instigator);
            if (Delay > 0.001)
            {
                TargetTime=WorldInfo.TimeSeconds-Delay;
                Rewind.RecordPawns();
                if (Rewind.TraceAt(self,StartTrace,EndTrace,TargetTime,Impact,RewoundImpacts,true))
                {
                    P=UTPawn(Impact.HitActor);
                    H=Rewind.FindHistory(P);
                    if (P != None && H != None && H.AtTime(TargetTime,Position,Radius,Height))
                    {
                        // Never combine a historical body with a current head.
                        // Unsupported/custom pawns and missing bone samples retain
                        // the entire stock trace, including native headshot logic.
                        if (NCPawn(P) == None || !H.HeadAtTime(TargetTime,HeadPosition,HeadRadius))
                            return Super.CalcWeaponFire(StartTrace,EndTrace,ImpactList);
                        if (VSize(Instigator.Velocity) < Instigator.GroundSpeed*Instigator.CrouchedPct)
                            Scaling=SlowHeadshotScale;
                        else Scaling=RunningHeadshotScale;
                        HistoricalImpact=Impact;
                        HistoricalHistory=H;
                        HistoricalTime=TargetTime;
                        // Stock IsLocationOnHead uses distance to the ray's line,
                        // after the body collision has selected this target.
                        bHistoricalHeadShot=PointDistToLine(HeadPosition,Impact.RayDir,Impact.HitLocation) < HeadRadius*Scaling;
                        bHistoricalDecision=true;
                    }
                    for (i=0;i<RewoundImpacts.Length;i++) ImpactList.AddItem(RewoundImpacts[i]);
                    RewoundShotCount++;
                    return Impact;
                }
            }
        }
    }
    return Super.CalcWeaponFire(StartTrace,EndTrace,ImpactList);
}

simulated function ProcessInstantHit(byte FiringMode, ImpactInfo Impact)
{
    local NCPawn P;
    local bool Scoped;
    local vector HeadPosition;
    local float HeadRadius;
    if (Role == ROLE_Authority && bInstantTraceScope && bHistoricalDecision
        && FiringMode == 0 && !bUsingAimingHelp && Impact.HitActor == HistoricalImpact.HitActor
        && Impact.HitLocation == HistoricalImpact.HitLocation && Impact.RayDir == HistoricalImpact.RayDir)
    {
        bHistoricalDecision=false;
        if (HistoricalHistory == None || HistoricalHistory.Tracked != Impact.HitActor
            || !HistoricalHistory.HeadAtTime(HistoricalTime,HeadPosition,HeadRadius)) return;
        P=NCPawn(Impact.HitActor);
        if (P != None) Scoped=P.BeginHistoricalHeadShot(self,Impact,bHistoricalHeadShot);
        // A pass-through damage callback can invalidate the victim after the
        // trace. Never replace a rejected historical decision with a live head.
        if (!Scoped) return;
        if (bHistoricalHeadShot) RewoundHeadshotCount++;
        else RewoundBodyshotCount++;
    }
    Super.ProcessInstantHit(FiringMode,Impact);
    if (Scoped) P.EndHistoricalHeadShot(self);
}

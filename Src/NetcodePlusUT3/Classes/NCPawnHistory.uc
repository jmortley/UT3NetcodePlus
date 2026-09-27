// NetcodePlusUT3, 2026-09-21. Bounded server history; never relocates a live pawn.
class NCPawnHistory extends Object;

struct Frame
{
    var float Time;
    var vector Position;
    var float Radius, Height;
};
var UTPawn Tracked;
var Frame Frames[128];
var int Count, NextIndex;
var byte TeleportGeneration;
var Controller LastController;
var Vehicle LastVehicle;
var bool bCrouched;

function Clear()
{
    Count=0;
    NextIndex=0;
}

// History models the normal upright cylinder only. Feign death and its recovery
// use native skeletal collision, which must remain on the current-world trace.
static function bool CanTrack(UTPawn P)
{
    return P != None && !P.bDeleteMe && P.Health > 0
        && !P.bTearOff && P.bCollideActors && P.bProjTarget
        && P.DrivenVehicle == None && !P.bFeigningDeath
        && !P.bPlayingFeignDeathRecovery && P.Physics != PHYS_RigidBody
        && P.CylinderComponent != None && P.CollisionComponent == P.CylinderComponent
        && P.CylinderComponent.CollideActors && P.CylinderComponent.BlockActors
        && P.CylinderComponent.BlockZeroExtent;
}

function bool IsLive()
{
    return CanTrack(Tracked);
}

function bool SameLifetime()
{
    return IsLive() && Tracked.BigTeleportCount == TeleportGeneration
        && Tracked.Controller == LastController && Tracked.DrivenVehicle == LastVehicle
        && Tracked.bIsCrouched == bCrouched;
}

function Record(float Now)
{
    local Frame F;
    local int Previous;
    local float DT, DistanceLimit;
    if (!IsLive()) { Clear(); return; }
    F.Time=Now;
    F.Position=Tracked.Location;
    Tracked.GetBoundingCylinder(F.Radius,F.Height);
    if (Count > 0)
    {
        Previous=(NextIndex+127)%128;
        DT=Now-Frames[Previous].Time;
        DistanceLimit=128.0+2.0*FMax(Tracked.GroundSpeed,VSize(Tracked.Velocity))*FMax(DT,0.0);
        if (!SameLifetime() || DT < 0 || DT > 0.1
            || VSize(F.Position-Frames[Previous].Position) > DistanceLimit)
            Clear();
        else if (DT == 0)
        {
            Frames[Previous]=F;
            return;
        }
    }
    TeleportGeneration=Tracked.BigTeleportCount;
    LastController=Tracked.Controller;
    LastVehicle=Tracked.DrivenVehicle;
    bCrouched=Tracked.bIsCrouched;
    Frames[NextIndex]=F;
    NextIndex=(NextIndex+1)%128;
    Count=Min(128,Count+1);
}

function bool AtTime(float Time, out vector Position, out float Radius, out float Height)
{
    local int i, Index, Previous, Oldest;
    local float Alpha, DT;
    if (Count == 0 || !SameLifetime()) return false;
    Oldest=(NextIndex+128-Count)%128;
    if (Time < Frames[Oldest].Time || Time > Frames[(NextIndex+127)%128].Time) return false;
    for (i=0;i<Count;i++)
    {
        Index=(Oldest+i)%128;
        if (Frames[Index].Time < Time) continue;
        Position=Frames[Index].Position;
        Radius=Frames[Index].Radius;
        Height=Frames[Index].Height;
        if (i > 0)
        {
            Previous=(Index+127)%128;
            DT=Frames[Index].Time-Frames[Previous].Time;
            if (DT <= 0 || DT > 0.1) return false;
            Alpha=FClamp((Time-Frames[Previous].Time)/DT,0.0,1.0);
            Position=Frames[Previous].Position+(Position-Frames[Previous].Position)*Alpha;
            Radius=FMin(Radius,Frames[Previous].Radius);
            Height=FMin(Height,Frames[Previous].Height);
        }
        return true;
    }
    return false;
}

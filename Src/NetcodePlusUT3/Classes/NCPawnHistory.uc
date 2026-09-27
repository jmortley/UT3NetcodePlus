// NetcodePlusUT3, 2026-09-21. Bounded server history; never relocates a live pawn.
class NCPawnHistory extends Object;

struct Frame
{
    var float Time;
    var vector Position;
    var float Radius, Height;
    var vector HeadPosition;
    var float HeadRadius;
    var bool bHeadValid;
    var SkeletalMesh HeadMesh;
    var name HeadBone;
    var rotator Facing;
    var float HeadHeight;
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
    F.Facing=Tracked.Rotation;
    F.HeadHeight=Tracked.HeadHeight;
    Tracked.GetBoundingCylinder(F.Radius,F.Height);
    // Head sampling is limited to pawns that support the scoped stock headshot
    // decision. The same-time body update reuses a matching mesh/position sample.
    if (NCPawn(Tracked) != None && Tracked.Mesh != None && Tracked.Mesh.SkeletalMesh != None
        && Tracked.HeadBone != '' && Tracked.Mesh.MatchRefBone(Tracked.HeadBone) != INDEX_NONE)
    {
        F.HeadMesh=Tracked.Mesh.SkeletalMesh;
        F.HeadBone=Tracked.HeadBone;
        Previous=(NextIndex+127)%128;
        if (Count > 0 && Frames[Previous].Time == Now && Frames[Previous].Position == F.Position
            && SameLifetime() && Frames[Previous].HeadMesh == F.HeadMesh && Frames[Previous].HeadBone == F.HeadBone
            && Frames[Previous].Facing == F.Facing && Frames[Previous].HeadHeight == F.HeadHeight)
        {
            F.HeadPosition=Frames[Previous].HeadPosition;
            F.bHeadValid=Frames[Previous].bHeadValid;
        }
        else
        {
            Tracked.Mesh.ForceSkelUpdate();
            F.HeadPosition=Tracked.Mesh.GetBoneLocation(Tracked.HeadBone)+vect(0,0,1)*Tracked.HeadHeight;
            F.bHeadValid=true;
        }
        F.HeadRadius=Tracked.HeadRadius*Tracked.HeadScale;
        if (F.HeadRadius <= 0) F.bHeadValid=false;
    }
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
    local Frame F;
    if (!FrameAtTime(Time,F)) return false;
    Position=F.Position;
    Radius=F.Radius;
    Height=F.Height;
    return true;
}

function bool HeadAtTime(float Time, out vector HeadPosition, out float HeadRadius)
{
    local Frame F;
    if (NCPawn(Tracked) == None || Tracked.Mesh == None || !FrameAtTime(Time,F) || !F.bHeadValid
        || Tracked.Mesh.SkeletalMesh != F.HeadMesh || Tracked.HeadBone != F.HeadBone) return false;
    HeadPosition=F.HeadPosition;
    HeadRadius=F.HeadRadius;
    return true;
}

function bool FrameAtTime(float Time, out Frame F)
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
        F=Frames[Index];
        if (i > 0)
        {
            Previous=(Index+127)%128;
            DT=Frames[Index].Time-Frames[Previous].Time;
            if (DT <= 0 || DT > 0.1) return false;
            Alpha=FClamp((Time-Frames[Previous].Time)/DT,0.0,1.0);
            F.Position=Frames[Previous].Position+(F.Position-Frames[Previous].Position)*Alpha;
            F.Radius=FMin(F.Radius,Frames[Previous].Radius);
            F.Height=FMin(F.Height,Frames[Previous].Height);
            F.HeadPosition=Frames[Previous].HeadPosition+(F.HeadPosition-Frames[Previous].HeadPosition)*Alpha;
            F.HeadRadius=FMin(F.HeadRadius,Frames[Previous].HeadRadius);
            F.bHeadValid=F.bHeadValid && Frames[Previous].bHeadValid
                && F.HeadMesh == Frames[Previous].HeadMesh && F.HeadBone == Frames[Previous].HeadBone;
        }
        return true;
    }
    return false;
}

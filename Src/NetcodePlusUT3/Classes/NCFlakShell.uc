// Stock Explode still creates five ordinary shards, with no second catch-up.
class NCFlakShell extends UTProj_FlakShell;

var byte CatchupState;
var float CatchupSeconds;
var repnotify NCFlakPhysics.FlakInitialState InitialFlakState;
var bool bInitialFlakStateApplied;
var float InitialFlakStateAppliedAt;

replication
{
    if (Role == ROLE_Authority && bNetInitial) InitialFlakState;
}

function RefreshInitialFlakState()
{
    if (Role == ROLE_Authority) class'NCFlakPhysics'.static.CaptureInitialState(self,InitialFlakState);
}

simulated function ApplyInitialFlakState()
{
    if (!bInitialFlakStateApplied && class'NCFlakPhysics'.static.ApplyInitialState(self,InitialFlakState))
    {
        bInitialFlakStateApplied=true;
        InitialFlakStateAppliedAt=WorldInfo.TimeSeconds;
    }
}

simulated event ReplicatedEvent(name VarName)
{
    if (VarName == 'InitialFlakState') ApplyInitialFlakState();
    else Super.ReplicatedEvent(VarName);
}

simulated event Tick(float DeltaTime)
{
    Super.Tick(DeltaTime);
    if (Role == ROLE_Authority) RefreshInitialFlakState();
    else ApplyInitialFlakState();
}

function Init(vector Direction)
{
    local NCFlakCannon W;
    Super.Init(Direction);
    RefreshInitialFlakState();
    if (Instigator != None) W=NCFlakCannon(Instigator.Weapon);
    if (W != None) W.RegisterFlak(self);
}

function float AdvanceAtSpawn(float Seconds)
{
    local float Advanced;
    Advanced=class'NCFlakPhysics'.static.Advance(self,Seconds,CatchupState);
    CatchupSeconds+=Advanced;
    RefreshInitialFlakState();
    return Advanced;
}

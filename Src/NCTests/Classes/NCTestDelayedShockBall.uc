// Test-only actor-replication delay. Native movement, collision, damage and
// normal visual-identity assignment continue during the quiet interval.
class NCTestDelayedShockBall extends NCShockBall;

var float ReplicationDelay;

simulated function PostBeginPlay()
{
    if (Role == ROLE_Authority) RemoteRole=ROLE_None;
    Super.PostBeginPlay();
    if (Role == ROLE_Authority && !bDeleteMe && !bShuttingDown)
    {
        SetTimer(ReplicationDelay,false,'ReleaseReplication');
        LogInternal("[NCMatchTrace] delayed-core queued time=" $ WorldInfo.TimeSeconds
            $ " core=" $ self $ " delay=" $ ReplicationDelay);
    }
}

function ReleaseReplication()
{
    if (Role != ROLE_Authority || bDeleteMe || bShuttingDown) return;
    RemoteRole=ROLE_SimulatedProxy;
    bNetDirty=true;
    bForceNetUpdate=true;
    SetNetUpdateTime(WorldInfo.TimeSeconds-1.0);
    LogInternal("[NCMatchTrace] delayed-core released time=" $ WorldInfo.TimeSeconds
        $ " core=" $ self $ " actor-age=" $ (WorldInfo.TimeSeconds-CreationTime)
        $ " id=" $ VisualId $ " generation=" $ PredictionGeneration);
}

simulated function Shutdown()
{
    // An early wall/contact/combo must never later resurrect replication.
    if (Role == ROLE_Authority) ClearTimer('ReleaseReplication');
    Super.Shutdown();
}

defaultproperties
{
    ReplicationDelay=0.9
}

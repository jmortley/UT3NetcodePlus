// Server-timed challenge/reply, adapted from UTComp3; GPL-2.0-or-later.
// The client returns an opaque serial, never a timestamp or rewind duration.
class NCPing extends Info;

var float Samples[8];
var int SampleCount, SampleIndex, Serial, PendingSerial;
var float SentAt, LastReply, MinimumRTT;

function PostBeginPlay()
{
    Super.PostBeginPlay();
    if (Role == ROLE_Authority) SetTimer(0.5,true,'Challenge');
}

function Challenge()
{
    if (Owner == None || Owner.bDeleteMe) { Destroy(); return; }
    Serial=(Serial+1)%1000000;
    PendingSerial=Serial;
    SentAt=WorldInfo.TimeSeconds;
    ClientChallenge(Serial);
}

unreliable client function ClientChallenge(int Value)
{
    // A client RPC may execute locally before its remote owner/channel exists.
    // Such a call must never become a zero-RTT server sample.
    if (WorldInfo.NetMode == NM_Client && Role < ROLE_Authority && !WorldInfo.bWithinDemoPlayback) ServerReply(Value);
}

unreliable server function ServerReply(int Value)
{
    local float RTT;
    local int i;
    if (PendingSerial < 0 || Value != PendingSerial) return;
    PendingSerial=-1;
    RTT=WorldInfo.TimeSeconds-SentAt;
    if (RTT < 0 || RTT > 1.0) return;
    Samples[SampleIndex]=RTT;
    SampleIndex=(SampleIndex+1)%8;
    SampleCount=Min(8,SampleCount+1);
    MinimumRTT=Samples[0];
    for (i=1;i<SampleCount;i++) MinimumRTT=FMin(MinimumRTT,Samples[i]);
    LastReply=WorldInfo.TimeSeconds;
}

function float GetRewind(float Limit)
{
    if (SampleCount < 3 || WorldInfo.TimeSeconds-LastReply > 5.0) return 0;
    return FClamp(MinimumRTT*0.5,0.0,Limit);
}

defaultproperties
{
    PendingSerial=-1
    RemoteRole=ROLE_SimulatedProxy
    bOnlyRelevantToOwner=true
    bSkipActorPropertyReplication=false
    NetUpdateFrequency=2
}

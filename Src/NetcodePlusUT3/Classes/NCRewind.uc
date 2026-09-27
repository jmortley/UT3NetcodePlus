// Server-only history and measured compensation. Live actors never move.
class NCRewind extends Info;

var float MaxRewindSeconds;
var float MaxCoreCatchupSeconds;
var float MaxRocketCatchupSeconds;
var array<NCPawnHistory> Histories;
var array<NCPing> Pings;

static function NCRewind Find(Actor Context)
{
    local NCRewind N;
    foreach Context.DynamicActors(class'NCRewind',N) return N;
    return None;
}

function RegisterPlayer(PlayerController PC)
{
    local int i;
    local NCPing P;
    if (PC == None || PC.bDeleteMe || PC.IsLocalPlayerController()) return;
    for (i=0;i<Pings.Length;i++) if (Pings[i] != None && Pings[i].Owner == PC) return;
    P=Spawn(class'NCPing',PC);
    if (P != None) Pings.AddItem(P);
}

function float RewindFor(Pawn Shooter)
{
    return MeasuredDelayFor(Shooter,MaxRewindSeconds);
}

function float CoreCatchupFor(Pawn Shooter)
{
    return MeasuredDelayFor(Shooter,FClamp(MaxCoreCatchupSeconds,0.0,0.10));
}

function float RocketCatchupFor(Pawn Shooter)
{
    return MeasuredDelayFor(Shooter,FClamp(MaxRocketCatchupSeconds,0.0,0.10));
}

function float MeasuredDelayFor(Pawn Shooter, float Limit)
{
    local int i;
    if (Shooter == None || Shooter.IsLocallyControlled() || PlayerController(Shooter.Controller) == None) return 0;
    for (i=0;i<Pings.Length;i++)
        if (Pings[i] != None && Pings[i].Owner == Shooter.Controller)
            return Pings[i].GetRewind(Limit);
    return 0;
}

function NCPawnHistory FindHistory(UTPawn P)
{
    local int i;
    for (i=0;i<Histories.Length;i++) if (Histories[i].Tracked == P) return Histories[i];
    return None;
}

// Custom teleporters that do not update BigTeleportCount can call this hook.
function ResetPawnHistory(Pawn P)
{
    local NCPawnHistory H;
    H=FindHistory(UTPawn(P));
    if (H != None) H.Clear();
}

function RecordPawns()
{
    local UTPawn P;
    local NCPawnHistory H;
    local int i;
    for (i=Histories.Length-1;i>=0;i--)
        if (!Histories[i].IsLive()) Histories.Remove(i,1);
    foreach WorldInfo.AllPawns(class'UTPawn',P)
    {
        if (!class'NCPawnHistory'.static.CanTrack(P)) continue;
        H=FindHistory(P);
        if (H == None && Histories.Length < 128)
        {
            H=new class'NCPawnHistory';
            H.Tracked=P;
            Histories.AddItem(H);
        }
        if (H != None) H.Record(WorldInfo.TimeSeconds);
    }
}

event Tick(float DeltaTime)
{
    local int i;
    if (Role != ROLE_Authority) return;
    RecordPawns();
    for (i=Pings.Length-1;i>=0;i--)
        if (Pings[i] == None || Pings[i].bDeleteMe) Pings.Remove(i,1);
}

function bool TraceShot(UTWeapon W, vector Start, vector End,
    out Weapon.ImpactInfo Impact, out array<Weapon.ImpactInfo> Impacts)
{
    local float Delay;
    Delay=RewindFor(W.Instigator);
    if (Delay <= 0.001) return false;
    RecordPawns(); // Observe lifecycle/teleport changes even before our next tick.
    return TraceAt(W,Start,End,WorldInfo.TimeSeconds-Delay,Impact,Impacts);
}

function bool TraceAt(UTWeapon W, vector Start, vector End, float TargetTime,
    out Weapon.ImpactInfo Impact, out array<Weapon.ImpactInfo> Impacts, optional bool bRequireHeadHistory)
{
    local Actor A, TraceOwner;
    local vector HL, HN, Position, HeadPosition;
    local TraceHitInfo HitInfo;
    local float Length, Best, Fraction, Radius, Height, HeadRadius;
    local int i, j;
    local NCPawnHistory H, BestHistory;
    local Weapon.ImpactInfo Empty, Candidate;
    local array<Weapon.ImpactInfo> PassHits;
    if (Role != ROLE_Authority || W == None) return false;
    Length=VSize(End-Start);
    if (Length < 0.001 || TargetTime > WorldInfo.TimeSeconds
        || TargetTime < WorldInfo.TimeSeconds-MaxRewindSeconds) return false;
    Impact=Empty;
    Impact.HitLocation=End;
    Impact.RayDir=Normal(End-Start);
    Best=1.0;
    TraceOwner=W.GetTraceOwner();
    A=TraceOwner.Trace(HL,HN,End,Start,false,vect(0,0,0),HitInfo,TRACEFLAG_Bullet);
    if (A != None)
    {
        Best=FClamp(VSize(HL-Start)/Length,0.0,1.0);
        Impact.HitActor=A;
        Impact.HitLocation=HL;
        Impact.HitNormal=HN;
        Impact.HitInfo=HitInfo;
    }
    foreach TraceOwner.TraceActors(class'Actor',A,HL,HN,End,Start,vect(0,0,0),HitInfo,TRACEFLAG_Bullet)
    {
        if (A == W || A == W.Instigator || A.bDeleteMe) continue;
        // Preserve stock portal recursion and native vehicle/non-UTPawn semantics.
        if (PortalTeleporter(A) != None || Vehicle(A) != None || (Pawn(A) != None && UTPawn(A) == None)) return false;
        H=FindHistory(UTPawn(A));
        if (H != None && H.AtTime(TargetTime,Position,Radius,Height))
        {
            // A sniper must not erase a live custom-pawn hit before discovering
            // that its historical head decision cannot be represented safely.
            if (bRequireHeadHistory && !H.HeadAtTime(TargetTime,HeadPosition,HeadRadius)) return false;
            continue;
        }
        if (!A.bBlockActors && !A.bProjTarget) continue;
        Candidate=Empty;
        Candidate.HitActor=A;
        Candidate.HitLocation=HL;
        Candidate.HitNormal=HN;
        Candidate.HitInfo=HitInfo;
        Candidate.RayDir=Impact.RayDir;
        if (!A.bBlockActors && W.PassThroughDamage(A))
        {
            // TraceActors is not assumed to be ordered. Deduplicate components.
            for (i=0;i<PassHits.Length;i++) if (PassHits[i].HitActor == A) break;
            if (i == PassHits.Length) PassHits.AddItem(Candidate);
            continue;
        }
        Fraction=VSize(HL-Start)/Length;
        if (Fraction < Best) { Best=Fraction; Impact=Candidate; }
    }
    for (i=0;i<Histories.Length;i++)
    {
        H=Histories[i];
        if (H.Tracked == W.Instigator || !H.AtTime(TargetTime,Position,Radius,Height)) continue;
        if (class'NCRewindMath'.static.SegmentCylinder(Start,End,Position,Radius,Height,Fraction,HN) && Fraction < Best)
        {
            Best=Fraction;
            BestHistory=H;
            Impact=Empty;
            Impact.HitActor=H.Tracked;
            Impact.HitLocation=Start+(End-Start)*Fraction;
            Impact.HitNormal=HN;
            Impact.RayDir=Normal(End-Start);
        }
    }
    // Registration order cannot let an unsupported pawn behind the selected
    // historical hit disable sniper compensation. Validate only the winner.
    if (bRequireHeadHistory && BestHistory != None
        && !BestHistory.HeadAtTime(TargetTime,HeadPosition,HeadRadius)) return false;
    // Only impacts before the blocking result receive damage, in ray order.
    for (i=0;i<PassHits.Length;i++)
    {
        if (VSize(PassHits[i].HitLocation-Start)/Length >= Best) continue;
        j=0;
        while (j<Impacts.Length && VSizeSq(Impacts[j].HitLocation-Start) <= VSizeSq(PassHits[i].HitLocation-Start)) j++;
        Impacts.Insert(j,1);
        Impacts[j]=PassHits[i];
    }
    Impacts.AddItem(Impact);
    return true;
}

defaultproperties
{
    MaxRewindSeconds=0.15
    MaxCoreCatchupSeconds=0.06
    MaxRocketCatchupSeconds=0.06
    RemoteRole=ROLE_None
    bAlwaysTick=true
    TickGroup=TG_PostAsyncWork
}

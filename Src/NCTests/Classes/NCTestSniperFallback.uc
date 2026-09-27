// A custom pawn cannot provide the scoped historical head decision. Both a
// current-world hit and a historical-only hit must keep stock sniper results.
class NCTestSniperFallback extends Info;

function Run(NCTestMutator T)
{
    local UTPawn Shooter, Target;
    local NCTestController PC;
    local NCSniperRifle W;
    local UTWeap_SniperRifle Stock;
    local NCTestRewind N;
    local NCPawnHistory H, NearHistory;
    local NCTestSniperPawn NearTarget;
    local vector Start, End, Position, HeadPosition;
    local float Now, Radius, Height, HeadRadius;
    local int Rewinds;
    local Weapon.ImpactInfo NativeImpact, Impact, FirstOrderImpact;
    local array<Weapon.ImpactInfo> Impacts;

    Shooter=T.MakePawn(vect(-500,8000,10000));
    Target=T.MakePawn(vect(600,8080,10000),true);
    PC=Spawn(class'NCTestController');
    N=Spawn(class'NCTestRewind');
    if (Shooter != None)
    {
        W=NCSniperRifle(Shooter.CreateInventory(class'NCSniperRifle',true));
        Stock=Spawn(class'UTWeap_SniperRifle',Shooter);
        if (Stock != None) Stock.Instigator=Shooter;
    }
    T.Check(Shooter != None && Target != None && PC != None && N != None && W != None && Stock != None,
        "custom-pawn sniper fallback setup");
    if (Shooter == None || Target == None || PC == None || N == None || W == None || Stock == None)
    {
        if (PC != None) PC.Destroy();
        if (N != None) N.Destroy();
        if (Stock != None) Stock.Destroy();
        if (Shooter != None) Shooter.Destroy();
        if (Target != None) Target.Destroy();
        Destroy();
        return;
    }
    PC.Possess(Shooter,false);
    Shooter.SetPhysics(PHYS_None);
    Shooter.Weapon=W;
    W.Rewind=N;
    W.bInstantTraceScope=true;
    Now=WorldInfo.TimeSeconds;
    Start=vect(100,8000,10000);
    End=vect(1200,8000,10000);
    H=new class'NCPawnHistory';
    H.Tracked=Target;
    N.Histories.AddItem(H);

    // The unsupported pawn is on the native ray now, but historically off it.
    H.Record(Now-0.08);
    H.Record(Now-0.04);
    Target.SetLocation(vect(600,8000,10000));
    H.Record(Now);
    NativeImpact=Stock.CalcWeaponFire(Start,End);
    T.Check(NCPawn(Target) == None && NativeImpact.HitActor == Target
        && H.AtTime(Now-0.06,Position,Radius,Height) && Abs(Position.Y-8080) < 0.1,
        "custom pawn current-hit historical-miss fixture");
    Impact=W.CalcWeaponFire(Start,End,Impacts);
    T.Check(Impact.HitActor == NativeImpact.HitActor && Impact.HitActor == Target
        && VSize(Impact.HitLocation-NativeImpact.HitLocation) < 0.1
        && !W.bHistoricalDecision && W.RewoundShotCount == 0,
        "custom pawn current hit keeps native sniper collision");

    // Inverse: a historical body hit must not replace the native miss when the
    // target has no compatible historical head decision.
    H.Clear();
    H.Record(Now-0.08);
    H.Record(Now-0.04);
    Target.SetLocation(vect(600,8080,10000));
    H.Record(Now);
    NativeImpact=Stock.CalcWeaponFire(Start,End);
    T.Check(NativeImpact.HitActor != Target
        && H.AtTime(Now-0.06,Position,Radius,Height) && Abs(Position.Y-8000) < 0.1,
        "custom pawn historical-hit current-miss fixture");
    Impacts.Length=0;
    Impact=W.CalcWeaponFire(Start,End,Impacts);
    T.Check(Impact.HitActor == NativeImpact.HitActor && Impact.HitActor != Target
        && VSize(Impact.HitLocation-NativeImpact.HitLocation) < 0.1
        && !W.bHistoricalDecision && W.RewoundShotCount == 0,
        "custom pawn historical-only hit keeps native sniper miss");

    // Both bodies are historically on the ray and currently off it. The
    // nearer supported target must win regardless of history registration order.
    NearTarget=Spawn(class'NCTestSniperPawn',,,vect(350,8000,10000));
    T.Check(NearTarget != None,"sniper history registration-order setup");
    if (NearTarget != None)
    {
        NearTarget.SetPhysics(PHYS_None);
        NearTarget.Health=1000;
        NearTarget.SetCollision(true,true);
        NearTarget.Mesh.SetSkeletalMesh(NearTarget.DefaultMesh);
        NearHistory=new class'NCPawnHistory';
        NearHistory.Tracked=NearTarget;
        NearHistory.Record(Now-0.08);
        NearHistory.Record(Now-0.04);
        NearTarget.SetLocation(vect(350,8080,10000));
        NearHistory.Record(Now);
        NativeImpact=Stock.CalcWeaponFire(Start,End);
        T.Check(NativeImpact.HitActor != Target && NativeImpact.HitActor != NearTarget
            && H.AtTime(Now-0.06,Position,Radius,Height) && Abs(Position.Y-8000) < 0.1
            && NearHistory.AtTime(Now-0.06,Position,Radius,Height) && Abs(Position.Y-8000) < 0.1
            && NearHistory.HeadAtTime(Now-0.06,HeadPosition,HeadRadius),
            "near supported and far custom histories share ray while native misses both");

        Rewinds=W.RewoundShotCount;
        N.Histories.Length=0;
        N.Histories.AddItem(H);
        N.Histories.AddItem(NearHistory);
        Impacts.Length=0;
        FirstOrderImpact=W.CalcWeaponFire(Start,End,Impacts);
        T.Check(FirstOrderImpact.HitActor == NearTarget && W.bHistoricalDecision
            && W.HistoricalHistory == NearHistory && W.RewoundShotCount == Rewinds+1,
            "far unsupported history registered first cannot suppress nearer sniper hit");

        N.Histories.Length=0;
        N.Histories.AddItem(NearHistory);
        N.Histories.AddItem(H);
        Impacts.Length=0;
        Impact=W.CalcWeaponFire(Start,End,Impacts);
        T.Check(Impact.HitActor == NearTarget && W.bHistoricalDecision
            && W.HistoricalHistory == NearHistory && W.RewoundShotCount == Rewinds+2
            && VSize(Impact.HitLocation-FirstOrderImpact.HitLocation) < 0.1,
            "reversing history registration preserves the same supported sniper hit");
        NearTarget.Destroy();
    }

    W.bInstantTraceScope=false;
    PC.UnPossess();
    PC.Destroy();
    Stock.Destroy();
    Shooter.Destroy();
    Target.Destroy();
    N.Destroy();
    Destroy();
}

defaultproperties { RemoteRole=ROLE_None }

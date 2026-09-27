// Real client replication acceptance. The long lifetime, stopped physics and
// fixed shrink timer below are test fixtures, not gameplay behavior.
class NCTestFlakSnapshotProbe extends Info;

var NCFlakShard Shard;
var NCFlakShardMain Main;
var vector ShardPosition, MainPosition;
var int FixtureIndex;
var bool bInitialized, bCreationStarted, bClientReadySent;
var bool bReady, bReported, bPassed, bClientSent, bClientLogged, bReferencesLogged;
var float StartedAt, ClientStartedAt;

replication
{
    if (Role == ROLE_Authority) ShardPosition, MainPosition, bInitialized, bReady;
}

function Initialize(int Index)
{
    FixtureIndex=Index;
    bInitialized=true;
    bNetDirty=true;
    bForceNetUpdate=true;
}

reliable server function ServerReady()
{
    if (!bInitialized || bCreationStarted || bReported) return;
    bCreationStarted=true;
    CreateFixtures();
}

function CreateFixtures()
{
    local NCTestBlocker Wall;
    local PlayerController PC;
    local vector Origin;
    local float ShardAdvance, MainAdvance;
    local bool Valid;
    StartedAt=WorldInfo.TimeSeconds;
    PC=PlayerController(Owner);
    if (PC == None || PC.Pawn == None)
    {
        bReported=true;
        bPassed=false;
        LogInternal("[NCNet] flak-snapshot missing owning pawn pass=False owner=" $ Owner);
        return;
    }
    // Keep the real projectile relevancy profile. The fixture must be within
    // its stock seven-thousand-unit cull distance of the connected observer.
    Origin=PC.Pawn.Location+vect(1000,0,1000)+vect(0,150,0)*FixtureIndex;
    Wall=Spawn(class'NCTestBlocker',,,Origin+vect(90,0,0));
    if (Wall != None) Wall.bWorldGeometry=true;
    Shard=Spawn(class'NCFlakShard',Owner,,Origin);
    if (Shard != None && Wall != None)
    {
        Shard.Instigator=None;
        // Keep the actor alive across packet lag while making a missing life
        // snapshot unambiguously different from the stock two-second default.
        Shard.LifeSpan=10;
        Shard.Init(vect(1,0,0));
        ShardAdvance=Shard.AdvanceAtSpawn(0.06);
    }
    if (Wall != None) Wall.Destroy();
    Origin+=vect(0,600,0);
    Wall=Spawn(class'NCTestBlocker',,,Origin+vect(90,0,0));
    if (Wall != None) Wall.bWorldGeometry=true;
    Main=Spawn(class'NCFlakShardMain',Owner,,Origin);
    if (Main != None && Wall != None)
    {
        Main.Instigator=None;
        Main.LifeSpan=10;
        // Exercise a native terminal bounce so bBounce must cross the wire as
        // false, rather than passing merely because its class default is true.
        Main.Bounces=0;
        Main.Init(vect(1,0,0));
        MainAdvance=Main.AdvanceAtSpawn(0.06);
        Main.ClearTimer('StartToShrink');
    }
    if (Wall != None) Wall.Destroy();
    Valid=Shard != None && Main != None;
    if (Valid)
    {
        Valid=ShardAdvance > 0 && MainAdvance > 0 && !Shard.bShuttingDown && !Main.bShuttingDown
            && Shard.Bounces == 1 && Main.Bounces == 0
            && Shard.bBlockedByInstigator && Main.bBlockedByInstigator
            && Shard.bBounce && !Main.bBounce;
        // Preserve the real snapshot fields after native catch-up, while
        // preventing further simulation from changing them before inspection.
        Shard.SetPhysics(PHYS_None); Main.SetPhysics(PHYS_None);
        Shard.SetCollision(false,false); Main.SetCollision(false,false);
        Shard.Velocity=vect(0,0,0); Main.Velocity=vect(0,0,0);
        // A repeatable terminal-shard timer exercises initial movement versus
        // repnotify ordering without depending on stock's random short delay.
        Main.SetTimer(1.5,false,'StartToShrink');
        Shard.RefreshInitialFlakState(); Main.RefreshInitialFlakState();
        ShardPosition=Shard.Location;
        MainPosition=Main.Location;
    }
    LogInternal("[NCNet] flak-snapshot-setup owner=" $ Owner $ " pass=" $ Valid
        $ " submitted=" $ ShardAdvance $ "/" $ MainAdvance
        $ " pawn=" $ PC.Pawn.Location $ " main-origin=" $ Origin);
    if (!Valid)
    {
        bReported=true;
        bPassed=false;
        return;
    }
    bReady=true;
    bNetDirty=true;
    bForceNetUpdate=true;
}

simulated function bool SnapshotMatches(UTProj_FlakShard P,
    const out NCFlakPhysics.FlakInitialState Snapshot, bool Applied, float AppliedAt,
    int ExpectedBounces, bool ExpectedBounce)
{
    local float NormalizedLife;
    if (P == None || P.Role == ROLE_Authority || !Applied || !Snapshot.bValid) return false;
    NormalizedLife=P.LifeSpan+FMax(0,WorldInfo.TimeSeconds-AppliedAt);
    return Snapshot.Bounces == ExpectedBounces && P.Bounces == ExpectedBounces
        && Snapshot.bBlockedByInstigator && P.bBlockedByInstigator
        && Snapshot.bBounce == ExpectedBounce && P.bBounce == ExpectedBounce
        && Snapshot.RemainingLifeSpan > 5
        && Abs(NormalizedLife-Snapshot.RemainingLifeSpan) < 0.05;
}

simulated event Tick(float DeltaTime)
{
    local PlayerController PC;
    local bool ShardPassed, MainPassed;
    if (Role == ROLE_Authority)
    {
        if (!bReported && bReady && WorldInfo.TimeSeconds-StartedAt > 8)
        {
            bReported=true;
            bPassed=false;
            LogInternal("[NCNet] flak-snapshot-timeout owner=" $ Owner $ " pass=False");
        }
        return;
    }
    if (bClientSent || !bInitialized) return;
    PC=PlayerController(Owner);
    if (PC == None || !PC.IsLocalPlayerController() || PC.Pawn == None) return;
    if (!bClientReadySent)
    {
        bClientReadySent=true;
        LogInternal("[NCNetClient] flak-snapshot ready-to-create owner=" $ Owner
            $ " time=" $ WorldInfo.TimeSeconds $ " pawn=" $ PC.Pawn.Location);
        ServerReady();
    }
    if (!bReady) return;
    if (ClientStartedAt == 0) ClientStartedAt=WorldInfo.TimeSeconds;
    DiscoverProjectiles();
    if (!bClientLogged)
    {
        bClientLogged=true;
        LogSnapshotState("first-ready");
    }
    if (!bReferencesLogged && Shard != None && Main != None)
    {
        bReferencesLogged=true;
        LogSnapshotState("local-actors-found");
    }
    if (Shard != None && Main != None && Shard.bInitialFlakStateApplied && Main.bInitialFlakStateApplied)
    {
        ShardPassed=SnapshotMatches(Shard,Shard.InitialFlakState,Shard.bInitialFlakStateApplied,
            Shard.InitialFlakStateAppliedAt,1,true);
        MainPassed=SnapshotMatches(Main,Main.InitialFlakState,Main.bInitialFlakStateApplied,
            Main.InitialFlakStateAppliedAt,0,false);
        MainPassed=MainPassed && Main.Physics == PHYS_None && Main.InitialFlakState.ShrinkDelay > 0
            && Main.IsTimerActive('StartToShrink')
            && Abs(Main.GetTimerRate('StartToShrink')-Main.InitialFlakState.ShrinkDelay) < 0.001;
        ShardPassed=CheckShardAppliesOnce() && ShardPassed;
        MainPassed=CheckMainAppliesOnce() && MainPassed;
        LogInternal("[NCNetClient] flak-snapshot owner=" $ Owner $ " shard-pass=" $ ShardPassed
            $ " main-pass=" $ MainPassed $ " bounces=" $ Shard.Bounces $ "/" $ Main.Bounces
            $ " blocks-owner=" $ Shard.bBlockedByInstigator $ "/" $ Main.bBlockedByInstigator
            $ " bounce=" $ Shard.bBounce $ "/" $ Main.bBounce
            $ " life=" $ Shard.LifeSpan $ "/" $ Main.LifeSpan
            $ " snapshot-life=" $ Shard.InitialFlakState.RemainingLifeSpan $ "/" $ Main.InitialFlakState.RemainingLifeSpan
            $ " shrink=" $ Main.GetTimerCount('StartToShrink') $ "/" $ Main.GetTimerRate('StartToShrink')
            $ " snapshot-shrink=" $ Main.InitialFlakState.ShrinkDelay);
        bClientSent=true;
        ServerResult(ShardPassed,MainPassed);
    }
    else if (WorldInfo.TimeSeconds-ClientStartedAt > 5)
    {
        LogSnapshotState("timeout");
        LogInternal("[NCNetClient] flak-snapshot unresolved actor/state pass=False owner=" $ Owner);
        bClientSent=true;
        ServerResult(false,false);
    }
}

simulated function DiscoverProjectiles()
{
    local NCFlakShard CandidateShard;
    local NCFlakShardMain CandidateMain;
    // Net-temporary projectile actor channels need not retain reference maps.
    // Discover the real replicated actors without changing their native profile.
    if (Shard == None)
        foreach DynamicActors(class'NCFlakShard',CandidateShard)
            if (CandidateShard.Class == class'NCFlakShard'
                && VSizeSq(CandidateShard.Location-ShardPosition) <= 25)
            {
                Shard=CandidateShard;
                break;
            }
    if (Main == None)
        foreach DynamicActors(class'NCFlakShardMain',CandidateMain)
            if (CandidateMain.Class == class'NCFlakShardMain'
                && VSizeSq(CandidateMain.Location-MainPosition) <= 25)
            {
                Main=CandidateMain;
                break;
            }
}

simulated function LogSnapshotState(string Label)
{
    local NCFlakShard CandidateShard;
    local NCFlakShardMain CandidateMain;
    local int ShardCount, MainCount;
    LogInternal("[NCNetClient] flak-snapshot-state " $ Label $ " owner=" $ Owner
        $ " time=" $ WorldInfo.TimeSeconds $ " elapsed=" $ (WorldInfo.TimeSeconds-ClientStartedAt)
        $ " shard=" $ Shard $ " main=" $ Main
        $ " expected-shard=" $ ShardPosition $ " expected-main=" $ MainPosition);
    if (Shard != None)
        LogInternal("[NCNetClient] flak-snapshot-shard applied=" $ Shard.bInitialFlakStateApplied
            $ " valid=" $ Shard.InitialFlakState.bValid $ " physics=" $ Shard.Physics
            $ " lifespan=" $ Shard.LifeSpan $ " snapshot-life=" $ Shard.InitialFlakState.RemainingLifeSpan
            $ " applied-at=" $ Shard.InitialFlakStateAppliedAt $ " role=" $ Shard.Role
            $ " location=" $ Shard.Location);
    if (Main != None)
        LogInternal("[NCNetClient] flak-snapshot-main applied=" $ Main.bInitialFlakStateApplied
            $ " valid=" $ Main.InitialFlakState.bValid $ " physics=" $ Main.Physics
            $ " lifespan=" $ Main.LifeSpan $ " snapshot-life=" $ Main.InitialFlakState.RemainingLifeSpan
            $ " applied-at=" $ Main.InitialFlakStateAppliedAt $ " role=" $ Main.Role
            $ " shrinking=" $ Main.bShrinking $ " timer=" $ Main.GetTimerCount('StartToShrink')
            $ "/" $ Main.GetTimerRate('StartToShrink') $ " snapshot-shrink=" $ Main.InitialFlakState.ShrinkDelay
            $ " location=" $ Main.Location);
    if (Shard == None || Main == None)
    {
        foreach DynamicActors(class'NCFlakShard',CandidateShard)
        {
            ShardCount++;
            LogInternal("[NCNetClient] flak-snapshot shard-candidate=" $ CandidateShard
                $ " class=" $ CandidateShard.Class $ " role=" $ CandidateShard.Role
                $ " location=" $ CandidateShard.Location $ " distance=" $ VSize(CandidateShard.Location-ShardPosition)
                $ " applied=" $ CandidateShard.bInitialFlakStateApplied $ " valid=" $ CandidateShard.InitialFlakState.bValid);
        }
        foreach DynamicActors(class'NCFlakShardMain',CandidateMain)
        {
            MainCount++;
            LogInternal("[NCNetClient] flak-snapshot main-candidate=" $ CandidateMain
                $ " class=" $ CandidateMain.Class $ " role=" $ CandidateMain.Role
                $ " location=" $ CandidateMain.Location $ " distance=" $ VSize(CandidateMain.Location-MainPosition)
                $ " applied=" $ CandidateMain.bInitialFlakStateApplied $ " valid=" $ CandidateMain.InitialFlakState.bValid);
        }
        LogInternal("[NCNetClient] flak-snapshot candidate-counts=" $ ShardCount $ "/" $ MainCount);
    }
}

simulated function bool CheckShardAppliesOnce()
{
    local NCFlakPhysics.FlakInitialState Saved;
    local float Life;
    local bool Passed;
    Saved=Shard.InitialFlakState;
    Life=Shard.LifeSpan;
    Shard.InitialFlakState.RemainingLifeSpan+=5;
    Shard.InitialFlakState.Bounces=99;
    Shard.InitialFlakState.ShrinkDelay=0.1;
    Shard.ApplyInitialFlakState();
    Passed=Shard.LifeSpan == Life && Shard.Bounces == 1 && !Shard.IsTimerActive('StartToShrink');
    Shard.InitialFlakState=Saved;
    return Passed;
}

simulated function bool CheckMainAppliesOnce()
{
    local NCFlakPhysics.FlakInitialState Saved;
    local float Life, TimerRate, TimerCount;
    local bool Passed;
    Saved=Main.InitialFlakState;
    Life=Main.LifeSpan;
    TimerRate=Main.GetTimerRate('StartToShrink');
    TimerCount=Main.GetTimerCount('StartToShrink');
    Main.InitialFlakState.RemainingLifeSpan+=5;
    Main.InitialFlakState.Bounces=99;
    Main.InitialFlakState.bBounce=true;
    Main.InitialFlakState.ShrinkDelay=0.1;
    Main.ApplyInitialFlakState();
    Passed=Main.LifeSpan == Life && Main.Bounces == 0 && !Main.bBounce && Main.IsTimerActive('StartToShrink')
        && Main.GetTimerRate('StartToShrink') == TimerRate && Main.GetTimerCount('StartToShrink') == TimerCount;
    Main.InitialFlakState=Saved;
    return Passed;
}

reliable server function ServerResult(bool ShardPassed, bool MainPassed)
{
    if (bReported) return;
    bReported=true;
    bPassed=ShardPassed && MainPassed;
    LogInternal("[NCNet] flak-snapshot-result owner=" $ Owner $ " shard-pass=" $ ShardPassed
        $ " main-pass=" $ MainPassed $ " pass=" $ bPassed);
}

event Destroyed()
{
    if (Role == ROLE_Authority)
    {
        if (Shard != None) Shard.Destroy();
        if (Main != None) Main.Destroy();
    }
    Super.Destroyed();
}

defaultproperties
{
    RemoteRole=ROLE_SimulatedProxy
    bOnlyRelevantToOwner=true
    bSkipActorPropertyReplication=false
    bAlwaysTick=true
    NetUpdateFrequency=10
}

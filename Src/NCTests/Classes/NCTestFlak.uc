// Native flak projectile behavior and actual stock firing-state comparisons.
class NCTestFlak extends Info;

var NCTestMutator Tests;
var NCTestFlakWeapon Held[2], Rapid[2], Tap[2];
var NCTestFlakStock StockHeld[2];
var NCFlakShard AgedShard;
var NCFlakShell AgedShell;
var bool bSpam;

function UTWeap_FlakCannon MakeWeapon(vector Position, bool bStock)
{
    local UTPawn P;
    local UTWeap_FlakCannon W;
    P=Tests.MakePawn(Position);
    if (P == None) return None;
    if (bStock) W=UTWeap_FlakCannon(P.CreateInventory(class'NCTestFlakStock',true));
    else W=UTWeap_FlakCannon(P.CreateInventory(class'NCTestFlakWeapon',true));
    if (W != None)
    {
        P.Weapon=W;
        W.AmmoCount=W.MaxAmmoCount;
        W.bAllowFiringWithoutController=true;
        W.GotoState('Active');
    }
    return W;
}

function CleanupWeapon(UTWeap_FlakCannon W)
{
    local UTProjectile P;
    local Pawn Shooter;
    if (W == None) return;
    Shooter=W.Instigator;
    foreach DynamicActors(class'UTProjectile',P)
        if (P.Instigator == Shooter) P.Destroy();
    W.Destroy();
    if (Shooter != None) Shooter.Destroy();
}

function AdvanceNative(UTProjectile P, float Seconds)
{
    local float Step;
    while (Seconds > 0.00001)
    {
        Step=FMin(Seconds,1.0/120.0);
        P.AutonomousPhysics(Step);
        Seconds-=Step;
    }
}

function TestVolley()
{
    local NCTestFlakWeapon W;
    local NCTestFlakStock S;
    local UTProj_FlakShard P;
    local int i, Row, Column, Zone, Centers, StockCenters, StockCount;
    local byte Zones[9];
    local bool Valid, Bounds;
    local vector V;
    local float Mag, Advanced;
    local byte CatchupStatus;
    W=NCTestFlakWeapon(MakeWeapon(vect(0,100000,10000),false));
    S=NCTestFlakStock(MakeWeapon(vect(0,101500,10000),true));
    Tests.Check(W != None && S != None,"flak primary stock-comparison setup");
    if (W == None || S == None) { CleanupWeapon(W); CleanupWeapon(S); return; }
    W.CurrentFireMode=0; S.CurrentFireMode=0;
    W.CustomFire(); S.CustomFire();
    LogInternal("[NCTests] flak volley fixture forced=" $ W.ForcedCatchup $ " delay=" $ W.FlakDelay()
        $ " caught=" $ W.CaughtUpShardCount $ " last=" $ W.LastFlakCatchup
        $ " early=" $ W.bAdvancedBeforeVolleyComplete);
    foreach DynamicActors(class'UTProj_FlakShard',P)
        if (P.Instigator == S.Instigator)
        {
            StockCount++;
            if (UTProj_FlakShardMain(P) != None) StockCenters++;
        }
    Tests.Check(W.Shots.Length == 9 && W.SpawnedShardCount == 9 && StockCount == 9 && StockCenters == 1,
        "flak primary preserves stock nine-shard count and center");
    Valid=true; Bounds=true;
    for (i=0;i<9;i++) Zones[i]=0;
    for (i=0;i<W.Shots.Length;i++)
    {
        P=UTProj_FlakShard(W.Shots[i]);
        if (P == None) { Valid=false; continue; }
        V=W.InitialVelocities[i];
        Advanced=0; CatchupStatus=0;
        if (NCFlakShardMain(P) != None)
        {
            Advanced=NCFlakShardMain(P).CatchupSeconds;
            CatchupStatus=NCFlakShardMain(P).CatchupState;
            Centers++;
            Valid=Valid && P.Bounces == 3 && NCFlakShardMain(P).CatchupSeconds > 0;
            Bounds=Bounds && Abs(V.Y) < 0.01 && Abs(V.Z) < 0.01;
        }
        else
        {
            if (NCFlakShard(P) != None)
            {
                Advanced=NCFlakShard(P).CatchupSeconds;
                CatchupStatus=NCFlakShard(P).CatchupState;
            }
            Valid=Valid && NCFlakShard(P) != None && P.Bounces == 2;
            Row=0; Column=0;
            if (V.Y > 0.01) Row=1;
            else if (V.Y < -0.01) Row=-1;
            if (V.Z > 0.01) Column=1;
            else if (V.Z < -0.01) Column=-1;
            Zone=(Row+1)*3+Column+1;
            Bounds=Bounds && Zone != 4 && Zones[Zone] == 0;
            Zones[Zone]=1;
            Mag=(Abs(Row)+Abs(Column) > 1) ? 0.7 : 1.0;
            if (Row != 0) Bounds=Bounds && Abs(V.Y/V.X) >= 0.3*Mag*W.SpreadDist-0.0001
                && Abs(V.Y/V.X) <= Mag*W.SpreadDist+0.0001;
            if (Column != 0) Bounds=Bounds && Abs(V.Z/V.X) >= 0.3*Mag*W.SpreadDist-0.0001
                && Abs(V.Z/V.X) <= Mag*W.SpreadDist+0.0001;
        }
        Valid=Valid && P.Damage == class'UTProj_FlakShard'.default.Damage
            && P.MomentumTransfer == class'UTProj_FlakShard'.default.MomentumTransfer
            && P.MyDamageType == class'UTProj_FlakShard'.default.MyDamageType;
        LogInternal("[NCTests] flak volley shard=" $ i $ " class=" $ P.Class $ " bounce=" $ P.Bounces
            $ " physics=" $ P.Physics $ " life=" $ P.LifeSpan $ " age=" $ (WorldInfo.TimeSeconds-P.CreationTime)
            $ " wide=" $ P.bWideCheck $ " dilation=" $ P.CustomTimeDilation $ " shutdown=" $ P.bShuttingDown
            $ " catch-state=" $ CatchupStatus $ " advanced=" $ Advanced
            $ " damage=" $ P.Damage $ " momentum=" $ P.MomentumTransfer $ " damage-type=" $ P.MyDamageType);
    }
    Tests.Check(Centers == 1 && Valid,"flak center and outer shards retain stock bounce/damage/momentum defaults");
    Tests.Check(Bounds,"flak primary retains all eight stock spread zones and random bounds");
    Tests.Check(!W.bAdvancedBeforeVolleyComplete && W.CaughtUpShardCount == 9
        && Abs(W.LastFlakCatchup-0.06) < 0.001,"flak finishes every stock spread draw before catch-up");
    Tests.Check(W.AmmoCount == S.AmmoCount && W.AmmoCount == W.MaxAmmoCount,
        "flak projectile helpers add no extra ammo consumption");
    CleanupWeapon(W); CleanupWeapon(S);
}

function TestPhysics()
{
    local NCFlakShard Shard;
    local NCFlakShardMain Main;
    local UTProj_FlakShardMain StockMain;
    local NCFlakShell Shell;
    local UTProj_FlakShell StockShell;
    local NCTestBlocker Wall;
    local NCTestFlakTarget Victim;
    local vector Origin, Before;
    local float Advanced, SavedLife, FreshDamage, FreshMomentum;
    Origin=vect(0,104000,10000);
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0));
    SavedLife=Shard.LifeSpan; Advanced=Shard.AdvanceAtSpawn(0.06);
    Tests.Check(Abs(Advanced-0.06) < 0.0001 && Abs(Shard.Location.X-Origin.X-210) < 0.5
        && Abs(SavedLife-Shard.LifeSpan-0.06) < 0.001,"flak shard catch-up advances native flight and ages lifetime");
    Before=Shard.Location;
    Tests.Check(Shard.AdvanceAtSpawn(0.06) == 0 && Shard.Location == Before,"flak shard advance is single-use");
    Shard.Destroy();
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0));
    Tests.Check(Abs(Shard.AdvanceAtSpawn(9)-0.10) < 0.0001 && Abs(Shard.Location.X-Origin.X-350) < 0.5,
        "flak shard catch-up clamps to 100ms");
    Shard.Destroy();
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0));
    SavedLife=Shard.LifeSpan;
    Tests.Check(Shard.AdvanceAtSpawn(0) == 0 && Shard.Location == Origin && Shard.LifeSpan == SavedLife,
        "zero-delay flak shard retains stock position and age");
    Shard.Destroy();
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0)); Shard.CustomTimeDilation=0.5;
    Tests.Check(Shard.AdvanceAtSpawn(0.06) == 0 && Shard.Location == Origin,"time-scaled flak shard keeps stock flight");
    Shard.Destroy();
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0)); Shard.bWideCheck=true;
    Tests.Check(Shard.AdvanceAtSpawn(0.06) == 0 && Shard.Location == Origin,
        "flak native aiming-help collision retains stock timing");
    Shard.Destroy();

    Victim=Spawn(class'NCTestFlakTarget',,,Origin+vect(1000,0,0));
    Victim.SetPhysics(PHYS_None); Victim.Health=1000; Victim.SetCollision(false,false);
    Main=Spawn(class'NCFlakShardMain',,,Origin); Main.Init(vect(1,0,0));
    StockMain=Spawn(class'UTProj_FlakShardMain',,,Origin+vect(0,400,0)); StockMain.Init(vect(1,0,0));
    FreshDamage=Main.GetDamage(Victim,Victim.Location);
    FreshMomentum=Main.GetMomentumTransfer();
    Main.AdvanceAtSpawn(0.06); StockMain.LifeSpan-=0.06;
    Tests.Check(Main.GetDamage(Victim,Victim.Location) < FreshDamage && Main.GetMomentumTransfer() < FreshMomentum
        && Abs(Main.GetDamage(Victim,Victim.Location)-StockMain.GetDamage(Victim,Victim.Location)) < 0.001
        && Abs(Main.GetMomentumTransfer()-StockMain.GetMomentumTransfer()) < 0.001,
        "flak center bonus damage and momentum use advanced stock age");
    Main.LifeSpan=Main.default.LifeSpan-0.21; StockMain.LifeSpan=StockMain.default.LifeSpan-0.21;
    Tests.Check(Main.GetDamage(Victim,Victim.Location) == StockMain.GetDamage(Victim,Victim.Location)
        && Main.GetDamage(Victim,Victim.Location) == Main.Damage
        && Main.GetMomentumTransfer() == Main.MomentumTransfer,"flak center bonus expires at stock age");
    Main.Destroy(); StockMain.Destroy(); Victim.Destroy();

    Wall=Spawn(class'NCTestBlocker',,,Origin+vect(90,0,0)); Wall.bWorldGeometry=true;
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0));
    Advanced=Shard.AdvanceAtSpawn(0.06);
    Tests.Check(Abs(Advanced-0.06) < 0.001 && Shard.Physics == PHYS_Falling && Shard.Bounces == 1
        && Shard.Velocity.X < 0 && Shard.bBlockedByInstigator && !Shard.bShuttingDown,
        "flak catch-up preserves native bounce and continues falling physics");
    Shard.Destroy();
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0)); Shard.Bounces=1;
    SavedLife=Shard.LifeSpan; Advanced=Shard.AdvanceAtSpawn(0.06);
    Tests.Check(Shard.Bounces == 0 && Abs(Shard.LifeSpan-(SavedLife+0.5-Advanced)) < 0.001,
        "flak catch-up retains stock final-bounce half-second lifetime extension");
    Shard.Destroy(); Wall.Destroy();
    Victim=Spawn(class'NCTestFlakTarget',,,Origin+vect(140,0,0));
    Victim.SetPhysics(PHYS_None); Victim.Health=1000; Victim.SetCollision(true,true);
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0)); Shard.AdvanceAtSpawn(0.06);
    Tests.Check(Shard.bShuttingDown && Victim.DamageEvents == 1 && Victim.LastDamage == 18
        && Abs(VSize(Victim.LastMomentum)-14000) < 1 && Victim.LastDamageType == class'UTDmgType_FlakShard',
        "flak shard catch-up uses native contact damage and momentum");
    Shard.Destroy();
    Victim.DamageEvents=0;
    Main=Spawn(class'NCFlakShardMain',,,Origin); Main.Init(vect(1,0,0)); Main.AdvanceAtSpawn(0.06);
    Tests.Check(Main.bShuttingDown && Victim.DamageEvents == 1 && Victim.MainAgeAtContact > 0
        && Victim.LastDamage == int(18+200*(0.2-Victim.MainAgeAtContact))
        && Victim.LastDamage < int(FreshDamage)
        && Abs(VSize(Victim.LastMomentum)-(14000+90000*(0.2-Victim.MainAgeAtContact))) < 1,
        "flak center collision observes elapsed bonus age inside native physics");
    Main.Destroy(); Victim.Destroy();

    Shell=Spawn(class'NCFlakShell',,,Origin); Shell.Init(vect(1,0,0));
    StockShell=Spawn(class'UTProj_FlakShell',,,Origin+vect(0,400,0)); StockShell.Init(vect(1,0,0));
    Tests.Check(Shell.Physics == PHYS_Falling && Shell.Velocity.Z == StockShell.Velocity.Z
        && Shell.TossZ == 305 && Shell.Damage == StockShell.Damage && Shell.DamageRadius == StockShell.DamageRadius
        && Shell.MomentumTransfer == StockShell.MomentumTransfer,"flak shell retains stock toss, gravity mode and damage defaults");
    SavedLife=Shell.LifeSpan; Advanced=Shell.AdvanceAtSpawn(0.06); AdvanceNative(StockShell,0.06);
    Tests.Check(Abs(Advanced-0.06) < 0.001 && VSize(Shell.Location-(StockShell.Location-vect(0,400,0))) < 0.1
        && VSize(Shell.Velocity-StockShell.Velocity) < 0.1 && Abs(SavedLife-Shell.LifeSpan-0.06) < 0.001,
        "flak shell catch-up matches native gravity trajectory and lifetime");
    Before=Shell.Location;
    Tests.Check(Shell.AdvanceAtSpawn(0.06) == 0 && Shell.Location == Before,"flak shell catch-up is single-use");
    Shell.Destroy(); StockShell.Destroy();
    Shell=Spawn(class'NCFlakShell',,,Origin); Shell.Init(vect(1,0,0)); SavedLife=Shell.LifeSpan;
    Tests.Check(Shell.AdvanceAtSpawn(0) == 0 && Shell.Location == Origin && Shell.LifeSpan == SavedLife,
        "zero-delay flak shell retains stock position and age");
    Shell.Destroy();
    Shell=Spawn(class'NCFlakShell',,,Origin); Shell.Init(vect(1,0,0)); Shell.CustomTimeDilation=0.5;
    Tests.Check(Shell.AdvanceAtSpawn(0.06) == 0 && Shell.Location == Origin,"time-scaled flak shell keeps stock flight");
    Shell.Destroy();
    Shell=Spawn(class'NCFlakShell',,,Origin); Shell.Init(vect(1,0,0)); Shell.bWideCheck=true;
    Tests.Check(Shell.AdvanceAtSpawn(0.06) == 0 && Shell.Location == Origin,
        "flak shell native aiming-help collision retains stock timing");
    Shell.Destroy();
    Shell=Spawn(class'NCFlakShell',,,Origin); Shell.Init(vect(1,0,0));
    Tests.Check(Abs(Shell.AdvanceAtSpawn(9)-0.10) < 0.001 && Abs(Shell.Location.X-Origin.X-120) < 0.5,
        "flak shell catch-up clamps to 100ms");
    Shell.Destroy();
    AgedShard=Spawn(class'NCFlakShard',,,Origin); AgedShard.Init(vect(1,0,0)); AgedShard.SetPhysics(PHYS_None);
    AgedShell=Spawn(class'NCFlakShell',,,Origin+vect(0,400,0)); AgedShell.Init(vect(1,0,0)); AgedShell.SetPhysics(PHYS_None);
}

function TestInheritedTouches()
{
    local NCFlakShard Shard, OtherShard;
    local NCTestFlakTarget OwnerPawn;
    local NCTestBlocker Wall;
    local vector Origin;
    Origin=vect(0,106000,10000);
    OwnerPawn=Spawn(class'NCTestFlakTarget',,,Origin+vect(80,0,0));
    OwnerPawn.SetPhysics(PHYS_None); OwnerPawn.Health=1000; OwnerPawn.SetCollision(true,true);
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Instigator=OwnerPawn; Shard.Init(vect(1,0,0));
    Shard.ProcessTouch(OwnerPawn,OwnerPawn.Location,vect(-1,0,0));
    Tests.Check(!Shard.bShuttingDown && OwnerPawn.DamageEvents == 0,"fresh flak shard ignores its own instigator");
    OtherShard=Spawn(class'NCFlakShard',,,Origin+vect(0,400,0)); OtherShard.Init(vect(1,0,0));
    Shard.ProcessTouch(OtherShard,OtherShard.Location,vect(-1,0,0));
    Tests.Check(!Shard.bShuttingDown && !OtherShard.bShuttingDown,"flak shards retain mutual contact immunity");
    OtherShard.Destroy();
    Wall=Spawn(class'NCTestBlocker',,,Origin+vect(160,0,0)); Wall.bWorldGeometry=true;
    Shard.AdvanceAtSpawn(0.10);
    Tests.Check(Shard.bShuttingDown && OwnerPawn.DamageEvents == 1 && OwnerPawn.LastMomentum.X < 0,
        "flak native bounce can hit its owner on reflected return");
    Shard.Destroy(); Wall.Destroy();
    OwnerPawn.DamageEvents=0;
    Shard=Spawn(class'NCFlakShard',,,Origin); Shard.Init(vect(1,0,0)); Shard.Velocity=vect(400,0,0);
    Shard.ProcessTouch(OwnerPawn,OwnerPawn.Location,vect(-1,0,0));
    Tests.Check(Shard.bShuttingDown && OwnerPawn.DamageEvents == 0,
        "flak stock low-speed contact retires shard without damage");
    Shard.Destroy(); OwnerPawn.Destroy();
}

function TestShellChildren()
{
    local NCTestFlakWeapon W;
    local NCFlakShell Shell;
    local UTProj_FlakShard Child;
    local NCTestBlocker Wall;
    local vector Start;
    local int Count;
    local bool StockChildren;
    W=NCTestFlakWeapon(MakeWeapon(vect(0,107000,10000),false));
    Tests.Check(W != None,"flak shell child-spawn setup");
    if (W == None) return;
    W.CurrentFireMode=1;
    Start=W.GetPhysicalFireStartLoc();
    Wall=Spawn(class'NCTestBlocker',,,Start+vect(50,0,0)); Wall.bWorldGeometry=true;
    Shell=NCFlakShell(W.ProjectileFire());
    StockChildren=true;
    foreach DynamicActors(class'UTProj_FlakShard',Child)
        if (Child.Instigator == W.Instigator)
        {
            Count++;
            StockChildren=StockChildren && Child.Class == class'UTProj_FlakShard'
                && !Child.bCheckShortRangeKill && Child.LifeSpan == Child.default.LifeSpan;
        }
    LogInternal("[NCTests] flak shell fixture forced=" $ W.ForcedCatchup $ " delay=" $ W.FlakDelay()
        $ " spawned=" $ W.SpawnedShellCount $ " caught=" $ W.CaughtUpShellCount
        $ " children=" $ Count $ " stock-children=" $ StockChildren $ " start=" $ Start);
    if (Shell != None)
        LogInternal("[NCTests] flak shell fixture physics=" $ Shell.Physics $ " shutdown=" $ Shell.bShuttingDown
            $ " wide=" $ Shell.bWideCheck $ " dilation=" $ Shell.CustomTimeDilation
            $ " catch-state=" $ Shell.CatchupState $ " advanced=" $ Shell.CatchupSeconds $ " location=" $ Shell.Location);
    Tests.Check(Shell != None && Shell.bShuttingDown && W.SpawnedShellCount == 1
        && W.CaughtUpShellCount == 1,"flak shell native wall impact occurs during catch-up");
    Tests.Check(Count == 5 && StockChildren && W.SpawnedShardCount == 0 && W.CaughtUpShardCount == 0,
        "flak shell creates five stock child shards with no second latency advance");
    Wall.Destroy(); CleanupWeapon(W);
}

function Run(NCTestMutator T)
{
    local int i, Mode;
    local vector Origin;
    Tests=T;
    TestVolley(); TestPhysics(); TestInheritedTouches(); TestShellChildren();
    for (Mode=0;Mode<2;Mode++)
    {
        Origin=vect(0,111000,10000)+vect(0,8000,0)*Mode;
        Held[Mode]=NCTestFlakWeapon(MakeWeapon(Origin,false));
        StockHeld[Mode]=NCTestFlakStock(MakeWeapon(Origin+vect(0,1500,0),true));
        Rapid[Mode]=NCTestFlakWeapon(MakeWeapon(Origin+vect(0,3000,0),false));
        Tap[Mode]=NCTestFlakWeapon(MakeWeapon(Origin+vect(0,4500,0),false));
        Tests.Check(Held[Mode] != None && StockHeld[Mode] != None && Rapid[Mode] != None && Tap[Mode] != None,
            "flak stock cadence setup mode " $ Mode);
        Held[Mode].ServerStartFire(Mode); StockHeld[Mode].ServerStartFire(Mode); Rapid[Mode].ServerStartFire(Mode);
        for (i=0;i<100;i++) { Tap[Mode].ServerStartFire(Mode); Tap[Mode].ServerStopFire(Mode); }
    }
    bSpam=true;
    SetTimer(0.15,false,'CheckAged');
    SetTimer(2.35,false,'StopCases');
    SetTimer(3.6,false,'Finish');
}

event Tick(float DeltaTime)
{
    local int i, Mode;
    if (!bSpam) return;
    for (Mode=0;Mode<2;Mode++)
        for (i=0;i<20;i++) { Rapid[Mode].ServerStopFire(Mode); Rapid[Mode].ServerStartFire(Mode); }
}

function CheckAged()
{
    local vector Before;
    Before=AgedShard.Location; AgedShard.SetPhysics(PHYS_Projectile);
    Tests.Check(AgedShard.AdvanceAtSpawn(0.06) == 0 && AgedShard.Location == Before,
        "aged flak shard cannot receive delayed catch-up");
    AgedShard.Destroy();
    Before=AgedShell.Location; AgedShell.SetPhysics(PHYS_Falling);
    Tests.Check(AgedShell.AdvanceAtSpawn(0.06) == 0 && AgedShell.Location == Before,
        "aged flak shell cannot receive delayed catch-up");
    AgedShell.Destroy();
}

function StopCases()
{
    local int Mode;
    bSpam=false;
    for (Mode=0;Mode<2;Mode++)
    {
        Held[Mode].ServerStopFire(Mode);
        StockHeld[Mode].ServerStopFire(Mode);
        Rapid[Mode].ServerStopFire(Mode);
    }
}

function Finish()
{
    local int Mode, i;
    local float Difference;
    for (Mode=0;Mode<2;Mode++)
    {
        Tests.Check(StockHeld[Mode].ShotTimes.Length == 3 && Held[Mode].ShotTimes.Length == 3
            && Rapid[Mode].ShotTimes.Length == 3,"flak held and rapid-input shot counts match stock mode " $ Mode);
        Difference=0;
        for (i=0;i<Min(Held[Mode].ShotTimes.Length,StockHeld[Mode].ShotTimes.Length);i++)
            Difference=FMax(Difference,Abs(Held[Mode].ShotTimes[i]-StockHeld[Mode].ShotTimes[i]));
        for (i=0;i<Min(Rapid[Mode].ShotTimes.Length,StockHeld[Mode].ShotTimes.Length);i++)
            Difference=FMax(Difference,Abs(Rapid[Mode].ShotTimes[i]-StockHeld[Mode].ShotTimes[i]));
        Tests.Check(Difference < 0.002 && Held[Mode].AmmoCount == Held[Mode].MaxAmmoCount-3
            && Held[Mode].AmmoCount == StockHeld[Mode].AmmoCount && Rapid[Mode].AmmoCount == StockHeld[Mode].AmmoCount,
            "flak cadence timestamps and ammo remain stock mode " $ Mode);
        Tests.Check(Tap[Mode].ShotTimes.Length == 1 && Tap[Mode].AmmoCount == Tap[Mode].MaxAmmoCount-1,
            "flak hundred tap pairs produce one legal shot mode " $ Mode);
        Tests.Check(Held[Mode].IsInState('Active') && StockHeld[Mode].IsInState('Active')
            && Rapid[Mode].IsInState('Active') && !Held[Mode].PendingFire(Mode) && !Rapid[Mode].PendingFire(Mode),
            "flak release returns to stock idle mode " $ Mode);
        if (Mode == 0)
            Tests.Check(Held[Mode].SpawnedShardCount == 27 && Rapid[Mode].SpawnedShardCount == 27
                && Tap[Mode].SpawnedShardCount == 9,"flak cadence emits nine shards per primary shell");
        else
            Tests.Check(Held[Mode].SpawnedShellCount == 3 && Rapid[Mode].SpawnedShellCount == 3
                && Tap[Mode].SpawnedShellCount == 1,"flak cadence emits one shell per secondary shot");
        CleanupWeapon(Held[Mode]); CleanupWeapon(StockHeld[Mode]); CleanupWeapon(Rapid[Mode]); CleanupWeapon(Tap[Mode]);
    }
    Destroy();
}

defaultproperties { RemoteRole=ROLE_None }

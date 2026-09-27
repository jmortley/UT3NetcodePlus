// Projectile physics and stock weapon-state acceptance checks; never shipped.
class NCTestRockets extends Info;

var NCTestMutator Tests;
var NCTestRocketLauncher Held, Rapid, Tap, Charged[3];
var NCTestRocketStock StockHeld, StockCharged[3];
var NCRocket AgedRocket;
var bool bSpam;

function UTWeap_RocketLauncher MakeWeapon(vector Position, bool bStock)
{
    local UTPawn P;
    local UTWeap_RocketLauncher W;
    P=Tests.MakePawn(Position);
    if (P == None) return None;
    if (bStock) W=UTWeap_RocketLauncher(P.CreateInventory(class'NCTestRocketStock',true));
    else W=UTWeap_RocketLauncher(P.CreateInventory(class'NCTestRocketLauncher',true));
    if (W != None)
    {
        P.Weapon=W;
        W.AmmoCount=W.MaxAmmoCount;
        W.bAllowFiringWithoutController=true;
        W.GotoState('Active');
        W.bTargetLockingActive=false;
    }
    return W;
}

function CleanupWeapon(UTWeap_RocketLauncher W)
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

function TestPhysics()
{
    local NCRocket R;
    local NCLoadedRocket Loaded;
    local NCGrenade G;
    local UTProj_SeekingRocket Seeking;
    local NCTestBlocker Wall;
    local NCTestPawn Victim;
    local vector Origin, Before;
    local float Advanced, Fuse, SavedLife;
    local byte Resolved;
    Origin=vect(0,60000,10000);
    R=Spawn(class'NCRocket',,,Origin); R.Init(vect(1,0,0));
    SavedLife=R.LifeSpan;
    Advanced=R.AdvanceAtSpawn(0.06);
    Tests.Check(Abs(Advanced-0.06) < 0.0001 && Abs(R.Location.X-Origin.X-81) < 0.5
        && Abs(SavedLife-R.LifeSpan-0.06) < 0.001,"rocket catch-up advances native flight and lifetime");
    Before=R.Location;
    Tests.Check(R.AdvanceAtSpawn(0.06) == 0 && R.Location == Before,"rocket catch-up is one-shot");
    R.Destroy();
    R=Spawn(class'NCRocket',,,Origin); R.Init(vect(1,0,0));
    Advanced=R.AdvanceAtSpawn(9);
    Tests.Check(Abs(Advanced-0.10) < 0.0001 && Abs(R.Location.X-Origin.X-135) < 0.5,
        "rocket catch-up clamps to 100ms");
    R.Destroy();
    R=Spawn(class'NCRocket',,,Origin); R.Init(vect(1,0,0));
    Tests.Check(R.AdvanceAtSpawn(0) == 0 && R.Location == Origin,"zero-delay rocket keeps stock spawn");
    R.Destroy();
    R=Spawn(class'NCRocket',,,Origin); R.Init(vect(1,0,0)); R.CustomTimeDilation=0.5;
    Tests.Check(R.AdvanceAtSpawn(0.06) == 0 && R.Location == Origin,"time-scaled rocket falls back to stock");
    R.Destroy();
    Loaded=Spawn(class'NCLoadedRocket',,,Origin); Loaded.Init(vect(1,0,0)); Loaded.FlockIndex=1;
    Tests.Check(Loaded.AdvanceAtSpawn(0.06) == 0 && Loaded.Location == Origin,"spiral projectile does not bypass its flock timer");
    Loaded.Destroy();
    Seeking=Spawn(class'UTProj_SeekingRocket',,,Origin); Seeking.Init(vect(1,0,0));
    Tests.Check(class'NCRocketPhysics'.static.Advance(Seeking,0.06,Resolved) == 0
        && Seeking.Location == Origin,"native seeking guidance keeps stock movement");
    Seeking.Destroy();
    Wall=Spawn(class'NCTestBlocker',,,Origin+vect(50,0,0));
    Wall.bWorldGeometry=true;
    R=Spawn(class'NCRocket',,,Origin); R.Init(vect(1,0,0));
    Advanced=R.AdvanceAtSpawn(0.06);
    Tests.Check(Advanced > 0 && R.bShuttingDown && R.Location.X < Origin.X+50,
        "rocket catch-up sweeps into nearby blocker and explodes");
    R.Destroy();
    G=Spawn(class'NCGrenade',,,Origin); G.Init(vect(1,0,0)); Fuse=G.GetTimerRate();
    Advanced=G.AdvanceAtSpawn(0.10);
    Tests.Check(Advanced > 0 && !G.bShuttingDown && G.Velocity.X < 0 && G.bBlockedByInstigator,
        "grenade catch-up preserves native bounce and instigator recontact rule");
    Tests.Check(Abs(G.GetTimerRate()-(Fuse-Advanced)) < 0.001,"grenade catch-up ages the existing random fuse");
    Before=G.Location; Fuse=G.GetTimerRate();
    Tests.Check(G.AdvanceAtSpawn(0.10) == 0 && G.Location == Before && G.GetTimerRate() == Fuse,
        "grenade catch-up cannot move or shorten fuse twice");
    G.Destroy(); Wall.Destroy();
    G=Spawn(class'NCGrenade',,,Origin); G.Init(vect(1,0,0)); Fuse=G.GetTimerRate();
    Tests.Check(G.AdvanceAtSpawn(0) == 0 && G.Location == Origin && G.GetTimerRate() == Fuse,
        "zero-delay grenade keeps stock flight and fuse");
    G.Destroy();
    G=Spawn(class'NCGrenade',,,Origin); G.Init(vect(1,0,0)); G.ClearTimer();
    Tests.Check(G.AdvanceAtSpawn(0.06) == 0 && G.Location == Origin,"grenade without stock fuse falls back safely");
    G.Destroy();
    Victim=NCTestPawn(Tests.MakePawn(Origin+vect(45,0,0),true));
    G=Spawn(class'NCGrenade',,,Origin); G.Init(vect(1,0,0));
    G.AdvanceAtSpawn(0.10);
    Tests.Check(G.bShuttingDown && Victim.DamageEvents > 0,"grenade catch-up preserves contact damage and explosion");
    G.Destroy(); Victim.Destroy();
    AgedRocket=Spawn(class'NCRocket',,,Origin); AgedRocket.Init(vect(1,0,0));
    AgedRocket.SetPhysics(PHYS_None);
}

function TestLoadedModes()
{
    local NCTestRocketLauncher W;
    local NCTestRocketStock S;
    local UTProjectile P;
    local UTProj_LoadedRocket Loaded;
    local UTProj_SeekingRocket Seeking;
    local byte Mode;
    local int Count, i, StockCount, Links;
    local bool ClassesOK, FlockOK;
    local vector Origin;
    for (Mode=0;Mode<3;Mode++)
        for (Count=1;Count<=3;Count++)
        {
            Origin=vect(0,62000,10000); Origin.Y+=float(Mode*3+Count)*1500;
            W=NCTestRocketLauncher(MakeWeapon(Origin,false));
            S=NCTestRocketStock(MakeWeapon(Origin+vect(0,600,0),true));
            Tests.Check(W != None && S != None,"loaded rocket setup mode " $ Mode $ " count " $ Count);
            if (W == None || S == None) return;
            W.ConfigureLoad(Mode,Count); S.ConfigureLoad(Mode,Count);
            W.FireLoad(); S.FireLoad();
            StockCount=0;
            foreach DynamicActors(class'UTProjectile',P)
                if (P.Instigator == S.Instigator) StockCount++;
            Tests.Check(W.Shots.Length == Count && StockCount == Count && W.SpawnedRocketCount == Count,
                "loaded rocket count matches stock mode " $ Mode $ " count " $ Count);
            ClassesOK=true; FlockOK=true;
            for (i=0;i<W.Shots.Length;i++)
            {
                P=W.Shots[i];
                if (Mode == 2) ClassesOK=ClassesOK && NCGrenade(P) != None;
                else if (Count > 1) ClassesOK=ClassesOK && NCLoadedRocket(P) != None;
                else ClassesOK=ClassesOK && NCRocket(P) != None;
                if (Mode == 1 && Count > 1)
                {
                    Loaded=UTProj_LoadedRocket(P); Links=0;
                    if (Loaded.Flock[0] != None) Links++;
                    if (Loaded.Flock[1] != None) Links++;
                    FlockOK=FlockOK && Loaded.FlockIndex != 0 && Links == Count-1;
                }
            }
            Tests.Check(ClassesOK && FlockOK && W.CaughtUpRocketCount == ((Mode == 1) ? 0 : Count),
                "loaded mode classes and safe catch-up selection " $ Mode $ " count " $ Count);
            Tests.Check(W.AmmoCount == S.AmmoCount && W.AmmoCount == W.MaxAmmoCount-Count
                && W.LoadedShotCount == S.LoadedShotCount,"loaded rocket spawn adds no ammo cost mode " $ Mode $ " count " $ Count);
            CleanupWeapon(W); CleanupWeapon(S);
        }
    W=NCTestRocketLauncher(MakeWeapon(vect(0,80000,10000),false));
    W.ConfigureLoad(0,3); W.bLockedOnTarget=true; W.LockedTarget=Tests.MakePawn(vect(3000,80000,10000),true);
    W.FireLoad(); StockCount=0; ClassesOK=true;
    foreach DynamicActors(class'UTProj_SeekingRocket',Seeking)
        if (Seeking.Instigator == W.Instigator)
        {
            StockCount++;
            ClassesOK=ClassesOK && Seeking.Seeking == W.LockedTarget;
        }
    Tests.Check(StockCount == 3 && ClassesOK && W.CaughtUpRocketCount == 0,
        "locked rocket load preserves stock seeking class and target");
    W.LockedTarget.Destroy(); CleanupWeapon(W);
}

function Run(NCTestMutator T)
{
    local int i;
    local vector Origin;
    Tests=T;
    TestPhysics();
    TestLoadedModes();
    Held=NCTestRocketLauncher(MakeWeapon(vect(0,82000,10000),false));
    StockHeld=NCTestRocketStock(MakeWeapon(vect(0,83500,10000),true));
    Rapid=NCTestRocketLauncher(MakeWeapon(vect(0,85000,10000),false));
    Tap=NCTestRocketLauncher(MakeWeapon(vect(0,86500,10000),false));
    Tests.Check(Held != None && StockHeld != None && Rapid != None && Tap != None,"rocket primary cadence setup");
    Held.ServerStartFire(0); StockHeld.ServerStartFire(0); Rapid.ServerStartFire(0);
    for (i=0;i<100;i++) { Tap.ServerStartFire(0); Tap.ServerStopFire(0); }
    bSpam=true;
    for (i=0;i<3;i++)
    {
        Origin=vect(0,88000,10000); Origin.Y+=float(i)*3000;
        Charged[i]=NCTestRocketLauncher(MakeWeapon(Origin,false));
        StockCharged[i]=NCTestRocketStock(MakeWeapon(Origin+vect(0,1500,0),true));
        Charged[i].ServerStartFire(1); StockCharged[i].ServerStartFire(1);
    }
    SetTimer(0.60,false,'ReleaseOne');
    SetTimer(1.60,false,'ReleaseTwo');
    SetTimer(2.55,false,'ReleaseThree');
    SetTimer(1.85,false,'StopPrimary');
    SetTimer(4.0,false,'CheckTimedCases');
}

event Tick(float DeltaTime)
{
    local int i;
    if (bSpam && Rapid != None)
        for (i=0;i<20;i++) { Rapid.ServerStopFire(0); Rapid.ServerStartFire(0); }
}

function ReleaseOne() { Charged[0].ServerStopFire(1); StockCharged[0].ServerStopFire(1); }
function ReleaseTwo() { Charged[1].ServerStopFire(1); StockCharged[1].ServerStopFire(1); }
function ReleaseThree() { Charged[2].ServerStopFire(1); StockCharged[2].ServerStopFire(1); }
function StopPrimary()
{
    bSpam=false;
    Held.ServerStopFire(0); StockHeld.ServerStopFire(0); Rapid.ServerStopFire(0);
}

function CheckTimedCases()
{
    local int i, StockCount;
    local float Difference;
    local UTProjectile P;
    local vector Before;
    Tests.Check(StockHeld.ShotTimes.Length > 1 && Held.ShotTimes.Length == StockHeld.ShotTimes.Length
        && Rapid.ShotTimes.Length == StockHeld.ShotTimes.Length,"rocket held and rapid-input counts match stock");
    Difference=0;
    for (i=0;i<Min(Held.ShotTimes.Length,StockHeld.ShotTimes.Length);i++)
        Difference=FMax(Difference,Abs(Held.ShotTimes[i]-StockHeld.ShotTimes[i]));
    for (i=0;i<Min(Rapid.ShotTimes.Length,StockHeld.ShotTimes.Length);i++)
        Difference=FMax(Difference,Abs(Rapid.ShotTimes[i]-StockHeld.ShotTimes[i]));
    Tests.Check(Difference < 0.002 && Held.AmmoCount == StockHeld.AmmoCount
        && Rapid.AmmoCount == StockHeld.AmmoCount,"rocket cadence timestamps and ammo remain stock");
    Tests.Check(Tap.ShotTimes.Length == 1 && Tap.AmmoCount == Tap.MaxAmmoCount-1,"rocket 100 tap pairs produce one legal shot");
    Tests.Check(!Held.PendingFire(0) && !Rapid.PendingFire(0) && Held.IsInState('Active'),"rocket primary release returns to stock idle state");
    for (i=0;i<3;i++)
    {
        StockCount=0;
        foreach DynamicActors(class'UTProjectile',P)
            if (P.Instigator == StockCharged[i].Instigator) StockCount++;
        Tests.Check(Charged[i].SpawnedRocketCount == i+1 && StockCount == i+1
            && Charged[i].AmmoCount == Charged[i].MaxAmmoCount-i-1
            && Charged[i].AmmoCount == StockCharged[i].AmmoCount,
            "stock charged release creates expected rockets and ammo count " $ (i+1));
        Tests.Check(Charged[i].IsInState('Active') && StockCharged[i].IsInState('Active')
            && !Charged[i].PendingFire(1) && Charged[i].LoadedShotCount == 0,
            "charged release resets stock load and idle state count " $ (i+1));
        CleanupWeapon(Charged[i]); CleanupWeapon(StockCharged[i]);
    }
    Before=AgedRocket.Location; AgedRocket.SetPhysics(PHYS_Projectile);
    Tests.Check(AgedRocket.AdvanceAtSpawn(0.06) == 0 && AgedRocket.Location == Before,"aged rocket cannot receive late catch-up");
    AgedRocket.Destroy();
    CleanupWeapon(Held); CleanupWeapon(StockHeld); CleanupWeapon(Rapid); CleanupWeapon(Tap);
    Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
}

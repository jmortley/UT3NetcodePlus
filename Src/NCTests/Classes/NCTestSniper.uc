// Native headshot/helmet integration and stock cadence comparisons.
class NCTestSniper extends Info;

var NCTestMutator Test;
var NCTestSniperWeapon Port, Rapid, Tap;
var NCTestSniperStock Stock;
var array<NCTestController> Controllers;
var bool bSpam;

function UTWeap_SniperRifle MakeWeapon(vector Position, bool bStock)
{
    local UTPawn P;
    local NCTestController C;
    local UTWeap_SniperRifle W;
    P=Test.MakePawn(Position);
    C=Spawn(class'NCTestController');
    if (P == None || C == None) return None;
    C.Pawn=P; P.Controller=C; Controllers.AddItem(C);
    if (bStock) W=UTWeap_SniperRifle(P.CreateInventory(class'NCTestSniperStock',true));
    else W=UTWeap_SniperRifle(P.CreateInventory(class'NCTestSniperWeapon',true));
    if (W != None)
    {
        P.Weapon=W; W.AmmoCount=W.MaxAmmoCount;
        W.bAllowFiringWithoutController=true;
        W.GotoState('Active');
    }
    return W;
}

function NCPawnHistory SeedHistory(NCTestRewind N, NCTestSniperPawn P, vector Origin, vector HeadOffset, bool bMoving)
{
    local NCTestSniperHistory H;
    local int i;
    local float Now;
    H=new class'NCTestSniperHistory'; H.Tracked=P;
    Now=WorldInfo.TimeSeconds;
    for (i=0;i<3;i++)
    {
        P.SetLocation(Origin);
        if (bMoving) P.SetLocation(Origin+vect(0,40,0)*float(i));
        H.Record(Now-0.04*float(2-i));
        // Deliberately controlled historical head poses, after separate real
        // bone-capture checks. The production body interpolation remains live.
        H.SetHead(i,P.Location+HeadOffset,9,true);
    }
    N.Histories.Length=0;
    N.Histories.AddItem(H);
    return H;
}

function TestHeadshots()
{
    local NCTestSniperWeapon W;
    local NCTestSniperPawn P;
    local NCTestRewind N;
    local NCPawnHistory H;
    local vector Origin, Head, NativeHead, Start, End, SavedPosition;
    local float Radius;
    local int Before, Rewinds;
    local Weapon.ImpactInfo Impact;
    local name Bone;
    local NCTestSniperTrigger Trigger;
    W=NCTestSniperWeapon(MakeWeapon(vect(-500,65000,10000),false));
    P=Spawn(class'NCTestSniperPawn',,,vect(600,65000,10000));
    N=Spawn(class'NCTestRewind');
    Test.Check(W != None && P != None && N != None,"sniper headshot setup");
    if (W == None || P == None || N == None) return;
    P.SetPhysics(PHYS_None); P.Health=1000; P.SetCollision(true,true);
    P.Mesh.SetSkeletalMesh(P.DefaultMesh);
    W.Rewind=N; W.CurrentFireMode=0;
    H=new class'NCPawnHistory'; H.Tracked=P; H.Record(WorldInfo.TimeSeconds);
    NativeHead=P.Mesh.GetBoneLocation(P.HeadBone)+vect(0,0,1)*P.HeadHeight;
    Test.Check(H.HeadAtTime(WorldInfo.TimeSeconds,Head,Radius) && VSize(Head-NativeHead)<0.01
        && Abs(Radius-P.HeadRadius*P.HeadScale)<0.001,"sniper history captures stock skeletal head center and scale");
    Bone=P.HeadBone; P.HeadBone='';
    Test.Check(!H.HeadAtTime(WorldInfo.TimeSeconds,Head,Radius),"missing or changed head bone invalidates head sample");
    P.HeadBone=Bone;

    Origin=P.Location;
    H=SeedHistory(N,P,Origin,vect(0,0,30),true);
    Test.Check(H.HeadAtTime(WorldInfo.TimeSeconds-0.06,Head,Radius)
        && VSize(Head-(Origin+vect(0,20,30)))<0.1,"sniper interpolates historical head with historical body");
    Start=Origin+vect(-500,20,30); End=Origin+vect(600,20,30);
    SavedPosition=P.Location;
    Impact=W.TraceAndProcess(Start,End);
    Test.Check(Impact.HitActor == P && P.DamageEvents == 1 && P.LastDamage == 140
        && P.LastDamageType == class'UTDmgType_SniperHeadShot' && W.RewoundHeadshotCount == 1,
        "rewound head uses native headshot damage and damage type");
    Test.Check(P.Location == SavedPosition && P.LastHitLocation == Impact.HitLocation
        && P.LastMomentum == Impact.RayDir && !P.bHeadDecisionPending && P.HeadDecisionWeapon == None,
        "headshot preserves native hit data without relocating pawn or leaking context");
    Before=P.DamageEvents; P.HelmetArmor=20; P.bShieldAbsorb=false;
    W.TraceAndProcess(Start,End);
    Test.Check(P.HelmetArmor == 0 && P.bShieldAbsorb && P.DamageEvents == Before,
        "native helmet absorbs rewound headshot without body damage");
    Start.Z-=12; End.Z-=12;
    W.Instigator.Velocity=vect(440,0,0);
    W.TraceAndProcess(Start,End);
    Test.Check(P.LastDamage == 70 && P.LastDamageType == class'UTDmgType_SniperPrimary',
        "running shooter keeps stock smaller headshot scale");
    W.Instigator.Velocity=vect(0,0,0);
    W.TraceAndProcess(Start,End);
    Test.Check(P.LastDamage == 140 && P.LastDamageType == class'UTDmgType_SniperHeadShot',
        "slow shooter keeps stock larger headshot scale");

    // Make the current head lie exactly on a body-hitting ray, while the older
    // head pose was below it. A current-pose head query would be a false headshot.
    P.SetLocation(Origin); P.Mesh.ForceSkelUpdate();
    NativeHead=P.Mesh.GetBoneLocation(P.HeadBone)+vect(0,0,1)*P.HeadHeight;
    P.HeadHeight+=P.Location.Z+30-NativeHead.Z;
    P.Mesh.ForceSkelUpdate();
    NativeHead=P.Mesh.GetBoneLocation(P.HeadBone)+vect(0,0,1)*P.HeadHeight;
    H=SeedHistory(N,P,Origin,NativeHead-Origin-vect(0,0,30),false);
    Start=NativeHead-vect(500,0,0); End=NativeHead+vect(600,0,0);
    Impact.HitActor=P; Impact.HitLocation=Start; Impact.RayDir=vect(1,0,0);
    Test.Check(P.IsLocationOnHead(Impact,W.SlowHeadshotScale),"current head would qualify before historical body decision");
    W.TraceAndProcess(Start,End);
    Test.Check(P.LastDamage == 70 && P.LastDamageType == class'UTDmgType_SniperPrimary'
        && W.RewoundBodyshotCount >= 2,"historical body hit cannot turn into current-pose headshot");

    H=SeedHistory(N,P,Origin,vect(0,0,30),true);
    NCTestSniperHistory(H).InvalidateHeads();
    Start=Origin+vect(-500,20,30); End=Origin+vect(600,20,30);
    Before=P.DamageEvents; Rewinds=W.RewoundShotCount;
    Impact=W.TraceAndProcess(Start,End);
    Test.Check(Impact.HitActor == None && P.DamageEvents == Before && W.RewoundShotCount == Rewinds,
        "missing historical head sample falls back to complete stock trace");
    H=SeedHistory(N,P,Origin,vect(0,0,30),true);
    Trigger=Spawn(class'NCTestSniperTrigger',,,Origin+vect(-200,20,30));
    Trigger.Target=P; Trigger.History=H;
    Before=P.DamageEvents;
    Impact=W.TraceAndProcess(Start,End);
    Test.Check(Trigger.DamageEvents == 1 && Impact.HitActor == P && P.DamageEvents == Before
        && !P.bHeadDecisionPending,"pass-through teleport cancels stale sniper damage before native head check");
    H=SeedHistory(N,P,Origin,vect(0,0,30),true);
    Trigger.History=H; Trigger.bClearHistory=true;
    Impact=W.TraceAndProcess(Start,End);
    Test.Check(Trigger.DamageEvents == 2 && Impact.HitActor == P && P.DamageEvents == Before
        && !P.bHeadDecisionPending,"pass-through history reset cannot fall back to a current-pose headshot");
    Trigger.Destroy();
    Test.Check(W.AmmoCount == W.MaxAmmoCount && W.ShotTimes.Length == 0,
        "head decision helpers do not authorize firing or spend ammo");
    P.Destroy(); W.Instigator.Destroy(); N.Destroy();
}

function Run(NCTestMutator T)
{
    local int i, AmmoBefore;
    Test=T;
    TestHeadshots();
    Stock=NCTestSniperStock(MakeWeapon(vect(0,70000,10000),true));
    Port=NCTestSniperWeapon(MakeWeapon(vect(0,72000,10000),false));
    Rapid=NCTestSniperWeapon(MakeWeapon(vect(0,74000,10000),false));
    Tap=NCTestSniperWeapon(MakeWeapon(vect(0,76000,10000),false));
    Test.Check(Stock != None && Port != None && Rapid != None && Tap != None,"sniper stock cadence setup");
    if (Stock == None || Port == None || Rapid == None || Tap == None) return;
    AmmoBefore=Port.AmmoCount;
    Port.ServerStartFire(1); Port.ServerStopFire(1);
    Test.Check(Port.AmmoCount == AmmoBefore && Port.ShotTimes.Length == 0
        && Port.bZoomedFireMode[1] == 1 && Port.FiringStatesArray[1] == 'Active',
        "sniper alternate remains stock zoom without projectile or ammo");
    Stock.ServerStartFire(0); Port.ServerStartFire(0); Rapid.ServerStartFire(0);
    for (i=0;i<100;i++) { Tap.ServerStartFire(0); Tap.ServerStopFire(0); }
    bSpam=true;
    SetTimer(2.85,false,'StopCases');
    SetTimer(4.2,false,'Finish');
}

event Tick(float DeltaTime)
{
    local int i;
    if (!bSpam) return;
    for (i=0;i<20;i++) { Rapid.ServerStopFire(0); Rapid.ServerStartFire(0); }
}

function StopCases()
{
    bSpam=false;
    Stock.ServerStopFire(0); Port.ServerStopFire(0); Rapid.ServerStopFire(0);
}

function Finish()
{
    local int i;
    local float Difference;
    Test.Check(Stock.ShotTimes.Length == 3 && Port.ShotTimes.Length == 3 && Rapid.ShotTimes.Length == 3,
        "sniper held and rapid-input shot counts match stock");
    for (i=0;i<Min(Stock.ShotTimes.Length,Port.ShotTimes.Length);i++)
        Difference=FMax(Difference,Abs(Stock.ShotTimes[i]-Port.ShotTimes[i]));
    for (i=0;i<Min(Stock.ShotTimes.Length,Rapid.ShotTimes.Length);i++)
        Difference=FMax(Difference,Abs(Stock.ShotTimes[i]-Rapid.ShotTimes[i]));
    Test.Check(Difference < 0.002,"sniper stock cadence timestamps preserved");
    Test.Check(Stock.AmmoCount == Stock.MaxAmmoCount-3 && Port.AmmoCount == Stock.AmmoCount
        && Rapid.AmmoCount == Stock.AmmoCount,"sniper ammo consumption matches stock");
    Test.Check(Tap.ShotTimes.Length == 1 && Tap.AmmoCount == Tap.MaxAmmoCount-1,"sniper 100 tap pairs cannot accelerate firing");
    Test.Check(!Port.PendingFire(0) && !Rapid.PendingFire(0) && Port.IsInState('Active'),"sniper stops and returns to idle");
    Stock.Instigator.Destroy(); Port.Instigator.Destroy(); Rapid.Instigator.Destroy(); Tap.Instigator.Destroy();
    for (i=0;i<Controllers.Length;i++) if (Controllers[i] != None) Controllers[i].Destroy();
    Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
}

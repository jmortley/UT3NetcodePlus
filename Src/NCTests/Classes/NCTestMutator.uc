// Synthetic engine acceptance checks. Separate package; never shipped as gameplay.
class NCTestMutator extends UTMutator;

var bool bFailed, bSpam;
var NCTestShock Port[2], Rapid[2], Tap[2];
var NCTestStockShock Stock[2];
var array<UTPawn> Pawns;
var int Checks;

function Check(bool Passed, string Label)
{
    Checks++;
    if (!Passed) bFailed=true;
    LogInternal("[NCTests] " $ Label $ " pass=" $ Passed);
}

function PostBeginPlay()
{
    Super.PostBeginPlay();
    SetTimer(1.0,false,'Run');
    SetTimer(4.5,false,'Finish');
}

function UTPawn MakePawn(vector Position, optional bool bTarget)
{
    local UTPawn P;
    P=Spawn(class'NCTestPawn',,,Position);
    if (P != None)
    {
        P.SetPhysics(PHYS_None);
        P.Health=1000;
        P.SetCollision(bTarget,bTarget);
        Pawns.AddItem(P);
    }
    return P;
}

function UTWeap_ShockRifle MakeWeapon(vector Position, bool bStock)
{
    local UTPawn P;
    local UTWeap_ShockRifle W;
    P=MakePawn(Position);
    if (P == None) return None;
    if (bStock) W=UTWeap_ShockRifle(P.CreateInventory(class'NCTestStockShock',true));
    else W=UTWeap_ShockRifle(P.CreateInventory(class'NCTestShock',true));
    if (W != None)
    {
        P.Weapon=W;
        W.AmmoCount=W.MaxAmmoCount;
        W.bAllowFiringWithoutController=true;
        W.GotoState('Active');
    }
    return W;
}

function int CountActor(array<Weapon.ImpactInfo> Impacts, Actor A)
{
    local int i, Count;
    for (i=0;i<Impacts.Length;i++) if (Impacts[i].HitActor == A) Count++;
    return Count;
}

function TestHistoryAndImpacts()
{
    local UTPawn P;
    local NCPawnHistory H;
    local NCTestRewind N;
    local NCTestShock W;
    local NCTestTrigger Before, Behind;
    local NCTestBlocker Wall;
    local vector Position, NormalHit, Start, End;
    local float Radius, Height, Fraction, Now;
    local Weapon.ImpactInfo Impact;
    local array<Weapon.ImpactInfo> Impacts;
    local bool Active;
    local int i;
    Check(class'NCRewindMath'.static.SegmentCylinder(vect(-100,0,0),vect(100,0,0),vect(0,0,0),20,40,Fraction,NormalHit)
        && Abs(Fraction-0.4) < 0.001,"cylinder entry");
    Check(!class'NCRewindMath'.static.SegmentCylinder(vect(-100,30,0),vect(100,30,0),vect(0,0,0),20,40,Fraction,NormalHit),"cylinder miss");
    P=MakePawn(vect(600,0,10000),true);
    W=NCTestShock(MakeWeapon(vect(-500,0,10000),false));
    N=Spawn(class'NCTestRewind');
    Check(P != None && W != None && N != None,"history setup");
    if (P == None || W == None || N == None) return;
    Now=WorldInfo.TimeSeconds;
    H=new class'NCPawnHistory';
    H.Tracked=P;
    H.Record(Now-0.08);
    P.SetLocation(vect(600,40,10000)); H.Record(Now-0.04);
    P.SetLocation(vect(600,80,10000)); H.Record(Now);
    N.Histories.AddItem(H);
    Check(H.AtTime(Now-0.06,Position,Radius,Height) && VSize(Position-vect(600,20,10000)) < 0.1,"moving target interpolation");
    Before=Spawn(class'NCTestTrigger',,,vect(300,20,10000));
    Behind=Spawn(class'NCTestTrigger',,,vect(900,20,10000));
    Start=vect(100,20,10000); End=vect(1200,20,10000);
    Active=N.TraceAt(W,Start,End,Now-0.06,Impact,Impacts);
    Check(Active && Impact.HitActor == P,"historical body hit when current body is off ray");
    Check(CountActor(Impacts,Before) == 1 && CountActor(Impacts,Behind) == 0,"pass-through trigger once before target, none behind");
    Wall=Spawn(class'NCTestBlocker',,,vect(450,20,10000));
    Impacts.Length=0;
    Active=N.TraceAt(W,Start,End,Now-0.06,Impact,Impacts);
    Check(Active && Impact.HitActor == Wall && CountActor(Impacts,P) == 0,"blocking geometry wins over historical target");
    Check(CountActor(Impacts,Before) == 1 && CountActor(Impacts,Behind) == 0,"trigger ordering around blocker");
    Wall.Destroy();
    // This is the same generation field incremented by stock PostTeleport/DoTranslocate.
    P.SetLocation(P.Location+vect(100,0,0)); P.BigTeleportCount++;
    Check(!H.AtTime(Now-0.06,Position,Radius,Height),"short teleport invalidates even before record tick");
    H.Record(Now+0.01);
    Check(H.Count == 1 && !H.AtTime(Now+0.005,Position,Radius,Height),"no interpolation across 100-unit teleport");
    H.Clear();
    for (i=0;i<200;i++) H.Record(Now+float(i)*0.001);
    Check(H.Count == 128 && !H.AtTime(Now+0.01,Position,Radius,Height)
        && H.AtTime(Now+0.15,Position,Radius,Height),"bounded ring wraps and rejects expired samples");
    P.Health=0;
    Check(!H.AtTime(Now+0.15,Position,Radius,Height),"death invalidates history immediately");
    Before.Destroy(); Behind.Destroy(); P.Destroy(); W.Instigator.Destroy(); N.Destroy();
}

function TestCores()
{
    local NCTestShock W;
    local NCTestController C;
    local NCShockBall Core, OtherCore;
    local NCPredictedCore Visual;
    local NCTestPawn Victim;
    local NCTestRewind N;
    local Weapon.ImpactInfo Impact;
    local array<Weapon.ImpactInfo> Impacts;
    local int AmmoBefore, DamageBefore;
    local vector Origin, SavedPosition;
    W=NCTestShock(MakeWeapon(vect(0,8000,10000),false));
    C=Spawn(class'NCTestController');
    Check(W != None && C != None,"core setup");
    if (W == None || C == None) return;
    C.Pawn=W.Instigator; W.Instigator.Controller=C;
    W.ServerVisual(1);
    Check(W.AmmoCount == W.MaxAmmoCount && W.LastProjectile == None,"visual metadata cannot fire or spend ammo");
    W.CurrentFireMode=1;
    W.FireAmmunition();
    Core=NCShockBall(W.LastProjectile);
    Check(Core != None && W.AmmoCount == W.MaxAmmoCount-1,"secondary creates authoritative core and spends one ammo");
    if (Core == None) return;
    Check(W.Requests.Length == 0 && W.UnmatchedCores.Length == 0,"pending visual metadata matches actual server spawn");
    Core.SetPhysics(PHYS_None);
    Origin=vect(300,8000,10000);
    Core.SetLocation(Origin);
    Victim=NCTestPawn(MakePawn(Origin+vect(100,0,0),true));
    N=Spawn(class'NCTestRewind'); W.Rewind=N;
    W.CurrentFireMode=0;
    Impact=W.CalcWeaponFire(Origin-vect(200,0,0),Origin+vect(250,0,0),Impacts);
    Check(Impact.HitActor == Core && W.bWasACombo,"rewound beam still hits a real core");
    AmmoBefore=W.AmmoCount;
    W.ProcessInstantHit(0,Impact);
    Check(Core.bComboed && Core.bShuttingDown && W.AmmoCount == AmmoBefore-Core.ComboAmmoCost,"stock combo explodes and charges combo ammo once");
    Check(Victim != None && Victim.DamageEvents > 0 && Victim.LastDamage > 0,"combo dispatches radial damage");
    W.CurrentFireMode=1; W.FireAmmunition(); Core=NCShockBall(W.LastProjectile);
    Core.SetPhysics(PHYS_None); Core.SetLocation(Origin);
    DamageBefore=Victim.DamageEvents;
    Core.ProcessTouch(Victim,Victim.Location,vect(-1,0,0));
    Check(Core.bShuttingDown && Victim.DamageEvents > DamageBefore,"secondary contact keeps stock damage and shutdown");
    W.FireAmmunition(); Core=NCShockBall(W.LastProjectile);
    Core.SetPhysics(PHYS_None); Core.SetLocation(Origin+vect(0,600,0));
    W.FireAmmunition(); OtherCore=NCShockBall(W.LastProjectile);
    Check(Core != None && OtherCore != None,"core collision setup at distinct spawn positions");
    if (Core != None && OtherCore != None)
    {
        OtherCore.SetPhysics(PHYS_None); OtherCore.SetLocation(Origin+vect(0,650,0));
        Core.ProcessTouch(OtherCore,Core.Location,vect(-1,0,0));
        Check(Core.bShuttingDown && OtherCore.bShuttingDown,"core versus core destroys both");
    }
    Visual=Spawn(class'NCPredictedCore',W,,Origin);
    DamageBefore=Victim.DamageEvents; AmmoBefore=W.AmmoCount;
    Visual.ProcessTouch(Victim,Victim.Location,vect(-1,0,0));
    Visual.TakeDamage(10,C,Visual.Location,vect(0,0,0),class'UTDmgType_ShockPrimary');
    Check(Victim.DamageEvents == DamageBefore && W.AmmoCount == AmmoBefore && !Visual.bComboed
        && !Visual.bProjTarget && !Visual.bCollideActors && Visual.RemoteRole == ROLE_None,"predicted visual cannot damage, combo, collide or replicate");
    W.FireAmmunition(); Core=NCShockBall(W.LastProjectile); Core.SetPhysics(PHYS_None);
    SavedPosition=Core.Location;
    Visual.MatchTo(Core); Visual.Tick(0.2);
    Check(Visual.bDeleteMe && !Core.bHidden && Core.Location == SavedPosition,"visual handoff leaves authoritative position intact and unhides core");
    W.ServerVisual(1);
    Check(W.Requests.Length == 0,"duplicate visual id is ignored");
    Core.Destroy(); Victim.Destroy(); W.Instigator.Destroy(); C.Destroy(); N.Destroy();
}

function Run()
{
    local int Mode, i, ShockPickups, StockPickups, ShockAmmo;
    local UTWeaponPickupFactory Factory;
    local UTAmmoPickupFactory Ammo;
    local vector Position;
    foreach AllActors(class'UTWeaponPickupFactory',Factory)
    {
        if (Factory.WeaponPickupClass == class'NCShockRifle') ShockPickups++;
        if (Factory.WeaponPickupClass == class'UTWeap_ShockRifle') StockPickups++;
    }
    foreach AllActors(class'UTAmmoPickupFactory',Ammo)
        if (Ammo.TargetWeapon == class'NCShockRifle') ShockAmmo++;
    Check(ShockPickups > 0 && StockPickups == 0,"DM-Deck Shock pickup replacement");
    Check(ShockAmmo > 0,"DM-Deck Shock ammo integration");
    TestHistoryAndImpacts();
    TestCores();
    for (Mode=0;Mode<2;Mode++)
    {
        Position=vect(0,20000,10000); Position.Y+=Mode*10000;
        Stock[Mode]=NCTestStockShock(MakeWeapon(Position,true));
        Port[Mode]=NCTestShock(MakeWeapon(Position+vect(0,2000,0),false));
        Rapid[Mode]=NCTestShock(MakeWeapon(Position+vect(0,4000,0),false));
        Tap[Mode]=NCTestShock(MakeWeapon(Position+vect(0,6000,0),false));
        Check(Stock[Mode] != None && Port[Mode] != None && Rapid[Mode] != None && Tap[Mode] != None,"cadence setup mode " $ Mode);
        if (Stock[Mode] == None || Port[Mode] == None || Rapid[Mode] == None || Tap[Mode] == None) return;
        Stock[Mode].ServerStartFire(Mode); Port[Mode].ServerStartFire(Mode); Rapid[Mode].ServerStartFire(Mode);
        for (i=0;i<100;i++) { Tap[Mode].ServerStartFire(Mode); Tap[Mode].ServerStopFire(Mode); }
    }
    bSpam=true;
    SetTimer(1.85,false,'StopCases');
}

event Tick(float DeltaTime)
{
    local int Mode, i;
    if (!bSpam) return;
    for (Mode=0;Mode<2;Mode++)
        for (i=0;i<20;i++) { Rapid[Mode].ServerStopFire(Mode); Rapid[Mode].ServerStartFire(Mode); }
}

function StopCases()
{
    local int Mode;
    bSpam=false;
    for (Mode=0;Mode<2;Mode++)
    {
        Stock[Mode].ServerStopFire(Mode); Port[Mode].ServerStopFire(Mode); Rapid[Mode].ServerStopFire(Mode);
    }
}

function Finish()
{
    local int Mode, i, Expected;
    local float Difference;
    for (Mode=0;Mode<2;Mode++)
    {
        if (Port[Mode] == None || Stock[Mode] == None || Rapid[Mode] == None || Tap[Mode] == None) { bFailed=true; continue; }
        Expected=3+Mode;
        Check(Stock[Mode].ShotTimes.Length == Expected && Port[Mode].ShotTimes.Length == Expected
            && Rapid[Mode].ShotTimes.Length == Expected,"held shot counts match stock mode " $ Mode);
        Difference=0;
        for (i=0;i<Min(Stock[Mode].ShotTimes.Length,Port[Mode].ShotTimes.Length);i++)
            Difference=FMax(Difference,Abs(Stock[Mode].ShotTimes[i]-Port[Mode].ShotTimes[i]));
        for (i=0;i<Min(Stock[Mode].ShotTimes.Length,Rapid[Mode].ShotTimes.Length);i++)
            Difference=FMax(Difference,Abs(Stock[Mode].ShotTimes[i]-Rapid[Mode].ShotTimes[i]));
        Check(Difference < 0.002,"stock and rapid-input timestamps match mode " $ Mode);
        Check(Port[Mode].AmmoCount == Port[Mode].MaxAmmoCount-Expected && Rapid[Mode].AmmoCount == Port[Mode].AmmoCount
            && Stock[Mode].AmmoCount == Port[Mode].AmmoCount,"stock ammo consumption mode " $ Mode);
        Check(Tap[Mode].ShotTimes.Length == 1 && Tap[Mode].AmmoCount == Tap[Mode].MaxAmmoCount-1,"100 tap pairs yield one shot mode " $ Mode);
        Check(!Port[Mode].PendingFire(Mode) && !Rapid[Mode].PendingFire(Mode) && Port[Mode].IsInState('Active'),"released and idle mode " $ Mode);
    }
    if (bFailed) LogInternal("[NCTests] FAILED checks=" $ Checks);
    else LogInternal("[NCTests] PASS checks=" $ Checks);
    LogInternal("[NCTests] FINISHED");
    ConsoleCommand("quit");
}

defaultproperties
{
    bExportMenuData=false
}

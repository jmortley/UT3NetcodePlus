// Cosmetic queue ordering under delayed delivery, reliable bursts and expiry.
class NCTestCoreQueue extends Info;

var NCTestMutator Tests;
var NCTestRewind Rewind;
var array<NCTestShock> Weapons;
var array<NCTestController> Controllers;
var array<NCShockBall> SpawnedCores;
var NCTestShock TimedWeapons[5];
var NCShockBall FirstCores[5], SecondCores[5];
var NCPredictedCore DeadVisual;
var float StartedAt;
var bool bAt20, bAt40, bAt62, bAt66, bAt72, bAt82, bAt85;

function NCTestShock MakeWeapon()
{
    local NCTestShock W;
    local NCTestController C;
    W=NCTestShock(Tests.MakeWeapon(vect(0,200000,10000)+vect(0,1000,0)*Weapons.Length,false));
    C=Spawn(class'NCTestController');
    Tests.Check(W != None && C != None,"core queue weapon fixture setup");
    if (W == None || C == None)
    {
        if (W != None) W.Instigator.Destroy();
        if (C != None) C.Destroy();
        return None;
    }
    C.Pawn=W.Instigator;
    W.Instigator.Controller=C;
    W.CheckMatchOwner();
    W.Rewind=Rewind;
    Weapons.AddItem(W);
    Controllers.AddItem(C);
    return W;
}

function NCPredictedCore MakeVisual(NCTestShock W, int Id)
{
    local NCPredictedCore Visual;
    Visual=Spawn(class'NCPredictedCore',W,,W.Instigator.Location+vect(0,400,200));
    if (Visual == None) return None;
    Visual.SetPhysics(PHYS_None);
    Visual.bCollideWorld=false;
    Visual.VisualId=Id;
    Visual.PredictionGeneration=W.PredictionGeneration;
    Visual.PredictionOwner=W.Instigator;
    Visual.PredictionController=W.Instigator.Controller;
    W.Visuals.AddItem(Visual);
    return Visual;
}

function NCShockBall FireOne(NCTestShock W, optional bool bUseFiringState, optional bool bEarlyImpact)
{
    local NCShockBall Core;
    local NCTestWorldWall Wall;
    local int BeforeShots;
    BeforeShots=W.ShotTimes.Length;
    if (bEarlyImpact)
        Wall=Spawn(class'NCTestWorldWall',,,W.GetPhysicalFireStartLoc()+vect(40,0,0));
    if (bUseFiringState)
    {
        W.ServerStartFire(1);
        W.ServerStopFire(1);
    }
    else
    {
        // Synchronous queue boundary probes call stock firing directly. Native
        // cadence is exercised by the four real-time lanes and existing tests.
        W.CurrentFireMode=1;
        W.FireAmmunition();
    }
    Core=NCShockBall(W.LastProjectile);
    Tests.Check(Core != None && W.ShotTimes.Length == BeforeShots+1,"core queue stock firing creates exactly one shot");
    if (Wall != None) Wall.Destroy();
    if (Core != None)
    {
        SpawnedCores.AddItem(Core);
        if (!Core.bDeleteMe && !Core.bShuttingDown)
        {
            // Preserve the real spawn/catch-up path, then isolate later contacts.
            Core.SetPhysics(PHYS_None);
            Core.SetCollision(false,false);
            Core.bCollideWorld=false;
            Core.SetLocation(vect(1500,225000,10000)+vect(0,200,0)*SpawnedCores.Length);
        }
    }
    return Core;
}

function CheckAmmo(NCTestShock W, int ExpectedShots, string Label)
{
    Tests.Check(W.ShotTimes.Length == ExpectedShots && W.AmmoCount == W.MaxAmmoCount-ExpectedShots,Label);
}

function Run(NCTestMutator T)
{
    local int i;
    Tests=T;
    Rewind=Spawn(class'NCTestRewind');
    Tests.Check(Rewind != None,"core queue catch-up fixture setup");
    if (Rewind == None) { Cleanup(); return; }
    Rewind.MaxCoreCatchupSeconds=0.06;
    for (i=0;i<5;i++)
    {
        TimedWeapons[i]=MakeWeapon();
        if (TimedWeapons[i] == None) { Cleanup(); return; }
    }
    StartedAt=WorldInfo.TimeSeconds;
    FirstCores[0]=FireOne(TimedWeapons[0],true);
    TimedWeapons[1].SubmitVisual(101);
    DeadVisual=MakeVisual(TimedWeapons[2],101);
    FirstCores[2]=FireOne(TimedWeapons[2],true,true);
    Tests.Check(DeadVisual != None && FirstCores[2] != None
        && FirstCores[2].bShuttingDown && TimedWeapons[2].UnmatchedCores.Length == 1,
        "core queue native early impact retains its unassigned shot slot");
    FirstCores[3]=FireOne(TimedWeapons[3],true);
    TimedWeapons[4].SubmitVisual(101);
    TestTimeouts();
    TestCapacityAndGaps();
}

function TestTimeouts()
{
    local NCTestShock W;
    local NCShockBall Core, LaterCore;
    local NCPredictedCore Visual;
    local Pawn P;
    local Controller C;
    local int OldGeneration, BeforeCatchup;
    local float Window;
    Window=class'NCShockRifle'.const.MatchWindow;

    W=MakeWeapon();
    if (W == None) return;
    Core=FireOne(W);
    if (Core == None || W.UnmatchedCores.Length != 1) return;
    W.UnmatchedCores[0].Time=WorldInfo.TimeSeconds-Window+0.001;
    W.ServiceMatches();
    Tests.Check(!W.bMatchingSuspended && W.UnmatchedCores.Length == 1,
        "core queue retains an unpaired core just inside its deadline");
    W.UnmatchedCores[0].Time=WorldInfo.TimeSeconds-Window-0.001;
    W.ServiceMatches();
    Tests.Check(W.bMatchingSuspended && W.UnmatchedCores.Length == 0 && W.Requests.Length == 0
        && Core.VisualId == 0 && !Core.bHidden,"core queue expired core suspends matching without hiding or relabeling it");
    BeforeCatchup=W.CaughtUpCoreCount;
    LaterCore=FireOne(W);
    W.SubmitVisual(101);
    W.SubmitVisual(102);
    Tests.Check(LaterCore != None && LaterCore.VisualId == 0 && !LaterCore.bHidden
        && W.UnmatchedCores.Length == 0 && W.Requests.Length == 0 && W.bMatchingSuspended,
        "core queue delayed metadata cannot claim a later shot after expiry");
    Tests.Check(W.CaughtUpCoreCount == BeforeCatchup+1 && LaterCore != None && LaterCore.CatchupSeconds > 0,
        "core queue suspension preserves server projectile catch-up");
    CheckAmmo(W,2,"core queue timeout and rejected metadata add no shots or ammo cost");

    // A normal weapon switch is not a new ownership session.
    OldGeneration=W.PredictionGeneration;
    W.DetachWeapon();
    Tests.Check(W.bMatchingSuspended && W.PredictionGeneration == OldGeneration,
        "core queue ordinary detach cannot clear the suspension latch");
    P=W.Instigator;
    C=P.Controller;
    P.InvManager.RemoveFromInventory(W);
    P.InvManager.AddInventory(W,true);
    P.Weapon=W;
    W.CheckMatchOwner();
    Tests.Check(!W.bMatchingSuspended && W.PredictionGeneration != OldGeneration
        && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0,
        "core queue real inventory reacquisition starts a clean matching session");
    W.ServerVisual(103,OldGeneration,P,C);
    Tests.Check(!W.bMatchingSuspended && W.LastVisualId == 0 && W.Requests.Length == 0,
        "core queue old session metadata cannot disturb recovery");
    W.SubmitVisual(501);
    LaterCore=FireOne(W);
    Tests.Check(LaterCore != None && LaterCore.VisualId == 501 && !W.bMatchingSuspended,
        "core queue recovered ownership accepts a fresh arbitrary first identity");
    CheckAmmo(W,3,"core queue recovery only spends ammo for its stock shot");

    W=MakeWeapon();
    if (W == None) return;
    Window=class'NCShockRifle'.const.RequestMatchWindow;
    Visual=MakeVisual(W,201);
    W.SubmitVisual(201);
    if (W.Requests.Length != 1) { Tests.Check(false,"core queue timeout request setup"); return; }
    W.Requests[0].Time=WorldInfo.TimeSeconds-Window+0.001;
    W.ServiceMatches();
    Tests.Check(!W.bMatchingSuspended && W.Requests.Length == 1,
        "core queue retains an unpaired request just inside its deadline");
    W.Requests[0].Time=WorldInfo.TimeSeconds-Window-0.001;
    W.ServiceMatches();
    Tests.Check(W.bMatchingSuspended && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0
        && Visual != None && Visual.bDeleteMe && W.RetiredVisualCount == 1,
        "core queue expired request retires its visual and suspends matching");
    LaterCore=FireOne(W);
    W.SubmitVisual(202);
    Tests.Check(LaterCore != None && LaterCore.VisualId == 0 && !LaterCore.bHidden
        && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0,
        "core queue expired request cannot shift a future authoritative core");
    CheckAmmo(W,1,"core queue request expiry and retirement cannot fire");
}

function TestCapacityAndGaps()
{
    local NCTestShock W;
    local NCShockBall Core;
    local NCPredictedCore Visual;
    local int i, OldGeneration;
    local float FirstRequestAt;

    W=MakeWeapon();
    if (W == None) return;
    for (i=0;i<4;i++)
    {
        MakeVisual(W,301+i);
        W.SubmitVisual(301+i);
    }
    Tests.Check(!W.bMatchingSuspended && W.Requests.Length == 4 && W.LastVisualId == 304,
        "core queue same-frame consecutive requests fill exactly four slots");
    if (W.Requests.Length == 4)
    {
        FirstRequestAt=W.Requests[0].Time;
        W.SubmitVisual(301);
        W.SubmitVisual(304);
        Tests.Check(!W.bMatchingSuspended && W.Requests.Length == 4 && W.LastVisualId == 304
            && W.Requests[0].Time == FirstRequestAt,"core queue duplicate metadata neither grows nor refreshes queued slots");
    }
    W.SubmitVisual(305);
    Tests.Check(W.bMatchingSuspended && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0
        && W.RetiredVisualCount == 4,"core queue request overflow suspends and retires all known queued visuals");
    CheckAmmo(W,0,"core queue metadata bursts and overflow cannot create shots");

    W=MakeWeapon();
    if (W == None) return;
    for (i=0;i<4;i++) FireOne(W);
    Tests.Check(!W.bMatchingSuspended && W.UnmatchedCores.Length == 4,
        "core queue holds four stock-authorized unmatched shot slots");
    Core=FireOne(W);
    W.SubmitVisual(401);
    Tests.Check(W.bMatchingSuspended && W.UnmatchedCores.Length == 0 && W.Requests.Length == 0
        && Core != None && Core.VisualId == 0 && !Core.bHidden,
        "core queue shot overflow suspends instead of dropping and shifting the oldest slot");
    CheckAmmo(W,5,"core queue shot overflow preserves exactly the five requested stock shots");

    W=MakeWeapon();
    if (W == None) return;
    Visual=MakeVisual(W,601);
    W.SubmitVisual(601);
    W.SubmitVisual(603);
    Tests.Check(W.bMatchingSuspended && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0
        && Visual != None && Visual.bDeleteMe && W.RetiredVisualCount == 1,
        "core queue forward identity gap suspends and retires the known pending visual");
    W.SubmitVisual(602);
    W.SubmitVisual(604);
    Tests.Check(W.bMatchingSuspended && W.Requests.Length == 0,
        "core queue a late missing identity cannot clear suspension");
    CheckAmmo(W,0,"core queue identity gap handling cannot authorize firing");

    W=MakeWeapon();
    if (W == None) return;
    Visual=MakeVisual(W,701);
    W.SubmitVisual(701);
    OldGeneration=W.PredictionGeneration;
    W.DetachWeapon();
    Tests.Check(W.bMatchingSuspended && W.PredictionGeneration == OldGeneration
        && W.Requests.Length == 0 && W.UnmatchedCores.Length == 0
        && Visual != None && Visual.bDeleteMe && W.Visuals.Length == 0,
        "core queue detach with a pending request retires it and suspends the same session");
    W.DetachWeapon();
    Tests.Check(W.bMatchingSuspended && W.PredictionGeneration == OldGeneration,
        "core queue a subsequent empty detach cannot resume suspended matching");
    CheckAmmo(W,0,"core queue pending-request detach cannot authorize firing");

    W=MakeWeapon();
    if (W == None) return;
    Core=FireOne(W);
    OldGeneration=W.PredictionGeneration;
    W.DetachWeapon();
    W.SubmitVisual(801);
    Tests.Check(W.bMatchingSuspended && W.PredictionGeneration == OldGeneration
        && W.UnmatchedCores.Length == 0 && W.Requests.Length == 0
        && Core != None && Core.VisualId == 0 && !Core.bHidden,
        "core queue detach with a pending core cannot resume or assign its late identity");
    CheckAmmo(W,1,"core queue pending-core detach preserves its one stock shot");
}

event Tick(float DeltaTime)
{
    local float Age;
    local int i;
    if (Tests == None || TimedWeapons[0] == None) return;
    Age=WorldInfo.TimeSeconds-StartedAt;
    if (!bAt20 && Age >= 0.20)
    {
        bAt20=true;
        FirstCores[1]=FireOne(TimedWeapons[1],true);
        Tests.Check(FirstCores[1] != None && FirstCores[1].VisualId == 101
            && !TimedWeapons[1].bMatchingSuspended,"core queue real 200ms late stock core consumes its original request");
    }
    if (!bAt40 && Age >= 0.40)
    {
        bAt40=true;
        LogInternal("[NCTests] core queue delayed delivery age=" $ Age);
        TimedWeapons[0].SubmitVisual(101);
        Tests.Check(FirstCores[0] != None && FirstCores[0].VisualId == 101
            && !TimedWeapons[0].bMatchingSuspended && Age > 0.25,
            "core queue real 400ms late request still identifies its original core");
        FirstCores[4]=FireOne(TimedWeapons[4],true);
        Tests.Check(FirstCores[4] != None && FirstCores[4].VisualId == 0
            && !FirstCores[4].bHidden && TimedWeapons[4].bMatchingSuspended
            && TimedWeapons[4].Requests.Length == 0 && TimedWeapons[4].UnmatchedCores.Length == 0,
            "core queue real 400ms expired request cannot claim a later stock core");
        TimedWeapons[2].SubmitVisual(101);
        Tests.Check(DeadVisual != None && DeadVisual.bDeleteMe && TimedWeapons[2].RetiredVisualCount == 1
            && TimedWeapons[2].UnmatchedCores.Length == 0 && !TimedWeapons[2].bMatchingSuspended,
            "core queue real delayed metadata retires its already impacted shot slot");
    }
    if (!bAt62 && Age >= 0.62)
    {
        bAt62=true;
        SecondCores[0]=FireOne(TimedWeapons[0],true);
        TimedWeapons[1].SubmitVisual(102);
        SecondCores[2]=FireOne(TimedWeapons[2],true);
        SecondCores[3]=FireOne(TimedWeapons[3],true);
    }
    if (!bAt66 && Age >= 0.66)
    {
        bAt66=true;
        TimedWeapons[3].SubmitVisual(101);
        TimedWeapons[3].SubmitVisual(102);
        Tests.Check(FirstCores[3] != None && SecondCores[3] != None
            && FirstCores[3].VisualId == 101 && SecondCores[3].VisualId == 102
            && !TimedWeapons[3].bMatchingSuspended && TimedWeapons[3].Requests.Length == 0
            && TimedWeapons[3].UnmatchedCores.Length == 0,
            "core queue consecutive reliable metadata delivered in one frame preserves both shot identities");
    }
    if (!bAt72 && Age >= 0.72)
    {
        bAt72=true;
        TimedWeapons[0].SubmitVisual(102);
        TimedWeapons[2].SubmitVisual(102);
        Tests.Check(FirstCores[0] != None && SecondCores[0] != None
            && FirstCores[0].VisualId == 101 && SecondCores[0].VisualId == 102
            && !TimedWeapons[0].bMatchingSuspended,"core queue delayed first request cannot steal the subsequent core slot");
        Tests.Check(SecondCores[2] != None && SecondCores[2].VisualId == 102
            && !TimedWeapons[2].bMatchingSuspended,"core queue delayed dead slot leaves the next live core correctly paired");
    }
    if (!bAt82 && Age >= 0.82)
    {
        bAt82=true;
        SecondCores[1]=FireOne(TimedWeapons[1],true);
        Tests.Check(FirstCores[1] != None && SecondCores[1] != None
            && FirstCores[1].VisualId == 101 && SecondCores[1].VisualId == 102
            && !TimedWeapons[1].bMatchingSuspended,"core queue delayed core leaves the subsequent request correctly paired");
    }
    if (!bAt85 && Age >= 0.85)
    {
        bAt85=true;
        TimedWeapons[3].SubmitVisual(101);
        TimedWeapons[3].SubmitVisual(102);
        Tests.Check(!TimedWeapons[3].bMatchingSuspended && TimedWeapons[3].LastVisualId == 102
            && TimedWeapons[3].Requests.Length == 0 && TimedWeapons[3].UnmatchedCores.Length == 0
            && FirstCores[3] != None && FirstCores[3].VisualId == 101
            && SecondCores[3] != None && SecondCores[3].VisualId == 102,
            "core queue later duplicate delivery is idempotent independently of an arrival-rate gate");
    }
    if (Age >= 1.15)
    {
        for (i=0;i<4;i++)
        {
            CheckAmmo(TimedWeapons[i],2,"core queue delayed protocol adds no shots or ammo cost case " $ i);
            Tests.Check(!TimedWeapons[i].PendingFire(1) && TimedWeapons[i].Requests.Length == 0
                && TimedWeapons[i].UnmatchedCores.Length == 0 && !TimedWeapons[i].bMatchingSuspended,
                "core queue timed lane ends released with empty matching queues case " $ i);
        }
        CheckAmmo(TimedWeapons[4],1,"core queue real request expiry adds no shots or ammo cost");
        Tests.Check(!TimedWeapons[4].PendingFire(1) && TimedWeapons[4].bMatchingSuspended,
            "core queue real request expiry remains suspended after fire release");
        Cleanup();
    }
}

function Cleanup()
{
    local int i;
    for (i=0;i<SpawnedCores.Length;i++) if (SpawnedCores[i] != None) SpawnedCores[i].Destroy();
    for (i=0;i<Weapons.Length;i++)
    {
        if (Weapons[i] == None) continue;
        if (Weapons[i].Instigator != None) Weapons[i].Instigator.Destroy();
        Weapons[i].Destroy();
    }
    for (i=0;i<Controllers.Length;i++) if (Controllers[i] != None) Controllers[i].Destroy();
    if (Rewind != None) Rewind.Destroy();
    Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
    bAlwaysTick=true
    TickGroup=TG_PostAsyncWork
}

// Real engine-time cosmetic handoffs, independent of network scheduling.
class NCTestCoreHandoff extends Info;

var NCTestMutator Tests;
var NCTestShock Weapon;
var NCTestController TestController;
var UTPawn TestPawn;
var NCPredictedCore Visuals[4];
var NCShockBall Cores[4], OtherCore;
var float StartedAt, DelayedAt, NearAt, NearOriginalDeadline, NearFinishedAt;
var int InitialAmmo;
var bool bDelayedAttempted, bDelayedAccepted, bNearAttempted, bNearAccepted;
var bool bNearPastDeadline, bWatchdogChecked, bDuplicateStable;

function bool Alive(NCPredictedCore Visual)
{
    return Visual != None && !Visual.bDeleteMe;
}

function NCPredictedCore MakeVisual(int Id, int Slot)
{
    local NCPredictedCore Visual;
    Visual=Spawn(class'NCPredictedCore',Weapon,,vect(0,180000,10000)+vect(0,300,0)*Slot);
    if (Visual == None) return None;
    Visual.VisualId=Id;
    Visual.PredictionGeneration=Weapon.PredictionGeneration;
    Visual.PredictionOwner=TestPawn;
    Visual.PredictionController=TestController;
    // Isolate contacts, leaving native lifespan and the production Tick intact.
    Visual.SetPhysics(PHYS_None);
    Visual.bCollideWorld=false;
    Visual.SetTickGroup(TG_PreAsyncWork);
    Weapon.Visuals.AddItem(Visual);
    return Visual;
}

function NCShockBall MakeCore(int Id, int Slot)
{
    local NCShockBall Core;
    Core=Tests.MakeCore(vect(240,180000,10000)+vect(0,300,0)*Slot);
    if (Core == None) return None;
    Core.SetPhysics(PHYS_None);
    Core.SetCollision(false,false);
    Core.bCollideWorld=false;
    Core.Instigator=TestPawn;
    Core.SetVisualIdentity(Weapon,Id);
    return Core;
}

function Match(int Id, NCShockBall Core)
{
    Weapon.MatchVisual(Id,Weapon.PredictionGeneration,TestPawn,TestController,Core);
}

function Run(NCTestMutator T)
{
    local int i;
    Tests=T;
    Weapon=NCTestShock(T.MakeWeapon(vect(0,179000,10000),false));
    TestController=Spawn(class'NCTestController');
    Tests.Check(Weapon != None && TestController != None,"handoff timed fixture setup");
    if (Weapon == None || TestController == None) { Cleanup(); return; }
    TestPawn=UTPawn(Weapon.Instigator);
    TestController.Pawn=TestPawn;
    TestPawn.Controller=TestController;
    Weapon.CheckMatchOwner();
    InitialAmmo=Weapon.AmmoCount;
    StartedAt=WorldInfo.TimeSeconds;
    bDuplicateStable=true;
    for (i=0;i<4;i++)
    {
        Visuals[i]=MakeVisual(i+1,i);
        Cores[i]=MakeCore(i+1,i);
        Tests.Check(Visuals[i] != None && Cores[i] != None,"handoff visual and core setup case " $ i);
        if (Visuals[i] == None || Cores[i] == None) { Cleanup(); return; }
    }
    OtherCore=MakeCore(4,4);
    Tests.Check(OtherCore != None && Abs(Visuals[2].LifeSpan-1.5)<0.001,
        "handoff untouched visual starts with bounded 1.5 second lifetime");
    if (OtherCore == None) { Cleanup(); return; }

    // Suppress only script blending. Native actor lifespan must still unhide the
    // real core within the short handoff lease even if cosmetic Tick cannot run.
    Match(4,Cores[3]);
    Tests.Check(Visuals[3].MatchedCore == Cores[3] && Cores[3].bHidden
        && Abs(Visuals[3].LifeSpan-0.20)<0.001 && Abs(Visuals[3].BlendRemaining-0.12)<0.001,
        "handoff begins a finite blend lease");
    Visuals[3].Disable('Tick');
}

function RepeatWatchdogMatches()
{
    local float BeforeLife, BeforeBlend;
    local int BeforeCount;
    local bool SameRejected, OtherRejected;
    if (!Alive(Visuals[3])) return;
    BeforeLife=Visuals[3].LifeSpan;
    BeforeBlend=Visuals[3].BlendRemaining;
    BeforeCount=Weapon.MatchedVisualCount;
    SameRejected=!Visuals[3].MatchTo(Cores[3]);
    OtherRejected=!Visuals[3].MatchTo(OtherCore);
    Match(4,Cores[3]);
    Match(4,OtherCore);
    bDuplicateStable=bDuplicateStable && SameRejected && OtherRejected
        && Visuals[3].MatchedCore == Cores[3] && !OtherCore.bHidden
        && Abs(Visuals[3].LifeSpan-BeforeLife)<0.00001
        && Abs(Visuals[3].BlendRemaining-BeforeBlend)<0.00001
        && Weapon.MatchedVisualCount == BeforeCount;
}

function DelayedHandoff()
{
    local int BeforeCount;
    bDelayedAttempted=true;
    BeforeCount=Weapon.MatchedVisualCount;
    Tests.Check(Alive(Visuals[0]) && WorldInfo.TimeSeconds-StartedAt >= 0.85,
        "handoff visual survives a real 850ms metadata delay");
    Match(1,Cores[0]);
    DelayedAt=WorldInfo.TimeSeconds;
    bDelayedAccepted=Alive(Visuals[0]) && Visuals[0].MatchedCore == Cores[0]
        && Cores[0].bHidden && Weapon.MatchedVisualCount == BeforeCount+1;
    Tests.Check(bDelayedAccepted,"handoff accepts the real 850ms delayed core once");
    LogInternal("[NCTests] handoff delayed age=" $ (DelayedAt-StartedAt)
        $ " alive=" $ Alive(Visuals[0]) $ " accepted=" $ bDelayedAccepted);
}

function NearDeadlineHandoff()
{
    local float OriginalLife;
    local int BeforeCount;
    bNearAttempted=true;
    NearAt=WorldInfo.TimeSeconds;
    if (Alive(Visuals[1])) OriginalLife=Visuals[1].LifeSpan;
    NearOriginalDeadline=NearAt+OriginalLife;
    BeforeCount=Weapon.MatchedVisualCount;
    Tests.Check(Alive(Visuals[1]) && NearAt-StartedAt >= 1.35
        && OriginalLife > 0 && OriginalLife <= 0.06,
        "handoff reaches the original expiry with less than half a blend remaining");
    Match(2,Cores[1]);
    bNearAccepted=Alive(Visuals[1]) && Visuals[1].MatchedCore == Cores[1]
        && Cores[1].bHidden && Weapon.MatchedVisualCount == BeforeCount+1;
    Tests.Check(bNearAccepted && Abs(Visuals[1].LifeSpan-0.20)<0.001
        && Abs(Visuals[1].BlendRemaining-0.12)<0.001,
        "handoff near expiry receives the full blend and watchdog budget");
    LogInternal("[NCTests] handoff near age=" $ (NearAt-StartedAt)
        $ " original-life=" $ OriginalLife $ " accepted=" $ bNearAccepted);
}

function CheckExpiredIdentity()
{
    local NCPredictedCore NewVisual;
    local int BeforeCount, OldGeneration;
    Tests.Check(!Alive(Visuals[2]),"handoff untouched unmatched visual expires within its bound");
    BeforeCount=Weapon.MatchedVisualCount;
    Match(3,Cores[2]);
    Weapon.PruneVisuals();
    Tests.Check(!Cores[2].bHidden && Weapon.MatchedVisualCount == BeforeCount
        && Weapon.Visuals.Length == 0,"handoff metadata after expiry cannot resurrect a visual or hide its core");

    OldGeneration=Weapon.PredictionGeneration;
    Weapon.ResetPredictionIdentity(TestPawn);
    NewVisual=MakeVisual(3,5);
    Tests.Check(NewVisual != None,"handoff reused ID fixture setup");
    if (NewVisual == None) return;
    Weapon.MatchVisual(3,OldGeneration,TestPawn,TestController,Cores[2]);
    Tests.Check(Alive(NewVisual) && NewVisual.MatchedCore == None && !Cores[2].bHidden
        && Weapon.MatchedVisualCount == BeforeCount,
        "handoff expired session metadata cannot claim a new session reused ID");
    NewVisual.Destroy();
    Weapon.PruneVisuals();
}

function CheckLatchedGuardAndCapacity()
{
    local NCPredictedCore GuardVisual, Oldest;
    local NCShockBall FirstCore, SecondCore;
    local float BeforeLife, BeforeBlend;
    local bool Accepted, Rejected;
    local int i, BeforeAmmo, BeforeShots;
    FirstCore=MakeCore(10,6);
    SecondCore=MakeCore(10,7);
    GuardVisual=MakeVisual(10,6);
    Tests.Check(FirstCore != None && SecondCore != None && GuardVisual != None,"handoff latched guard setup");
    if (FirstCore == None || SecondCore == None || GuardVisual == None)
    {
        if (FirstCore != None) FirstCore.Destroy();
        if (SecondCore != None) SecondCore.Destroy();
        if (GuardVisual != None) GuardVisual.Destroy();
        return;
    }
    Accepted=GuardVisual.MatchTo(FirstCore);
    BeforeLife=GuardVisual.LifeSpan;
    BeforeBlend=GuardVisual.BlendRemaining;
    // Model an engine-cleared actor reference after the one-use handoff began.
    GuardVisual.MatchedCore=None;
    Rejected=!GuardVisual.MatchTo(SecondCore);
    Tests.Check(Accepted && GuardVisual.bHandoffStarted && Rejected && !SecondCore.bHidden
        && GuardVisual.MatchedCore == None && GuardVisual.LifeSpan == BeforeLife
        && GuardVisual.BlendRemaining == BeforeBlend,
        "handoff latch rejects replacement after its matched actor reference clears");
    FirstCore.SetHidden(false); // The fixture deliberately removed the cleanup reference.
    GuardVisual.Destroy();
    Weapon.PruneVisuals();

    BeforeAmmo=Weapon.AmmoCount;
    BeforeShots=Weapon.ShotTimes.Length;
    for (i=0;i<4;i++)
    {
        GuardVisual=MakeVisual(10+i,8+i);
        if (i == 0) Oldest=GuardVisual;
    }
    Tests.Check(Weapon.Visuals.Length == 4 && Oldest != None,"handoff capacity fixture contains four visuals");
    if (Oldest != None) Oldest.MatchTo(FirstCore);
    Weapon.MakeVisualRoom();
    Tests.Check(Weapon.Visuals.Length == 3 && !Alive(Oldest) && !FirstCore.bHidden,
        "handoff capacity evicts the oldest visual and unhides its matched core");
    GuardVisual=MakeVisual(14,12);
    Tests.Check(GuardVisual != None && Weapon.Visuals.Length == 4
        && Weapon.Visuals[0].VisualId == 11 && Weapon.Visuals[3].VisualId == 14
        && Weapon.AmmoCount == BeforeAmmo && Weapon.ShotTimes.Length == BeforeShots,
        "handoff capacity admits a fresh identity without firing or spending ammo");
    FirstCore.Destroy();
    SecondCore.Destroy();
}

function FinishCases()
{
    Tests.Check(bDelayedAccepted && WorldInfo.TimeSeconds-DelayedAt >= 0.20
        && !Alive(Visuals[0]) && !Cores[0].bHidden,"handoff delayed blend finishes and restores the real core");
    Tests.Check(bNearPastDeadline,"handoff stays alive beyond its original expiry while blending");
    Tests.Check(bNearAccepted && NearFinishedAt-NearAt >= 0.115 && NearFinishedAt-NearAt <= 0.20
        && !Alive(Visuals[1]) && !Cores[1].bHidden,"handoff near expiry completes the full timed blend then unhides the core");
    LogInternal("[NCTests] handoff near blend-elapsed=" $ (NearFinishedAt-NearAt)
        $ " survived-original-deadline=" $ bNearPastDeadline);
    CheckExpiredIdentity();
    CheckLatchedGuardAndCapacity();
    Tests.Check(Weapon.AmmoCount == InitialAmmo && Weapon.ShotTimes.Length == 0,
        "handoff lifecycle and capacity cannot authorize shots or consume ammo");
    Cleanup();
}

event Tick(float DeltaTime)
{
    local float Age;
    if (Tests == None || Weapon == None) return;
    Age=WorldInfo.TimeSeconds-StartedAt;
    if (!bWatchdogChecked)
    {
        RepeatWatchdogMatches();
        if (Age >= 0.30)
        {
            bWatchdogChecked=true;
            Tests.Check(bDuplicateStable,"handoff repeated same and different core metadata cannot renew its lease or hide another core");
            Tests.Check(!Alive(Visuals[3]) && !Cores[3].bHidden && !OtherCore.bHidden,
                "handoff native watchdog cleans up even with cosmetic Tick disabled");
        }
    }
    if (!bDelayedAttempted && Age >= 0.85) DelayedHandoff();
    if (!bNearAttempted && Age >= 1.35 && (!Alive(Visuals[1]) || Visuals[1].LifeSpan <= 0.06)) NearDeadlineHandoff();
    if (bNearAccepted)
    {
        if (Alive(Visuals[1]) && WorldInfo.TimeSeconds > NearOriginalDeadline+0.005
            && Visuals[1].BlendRemaining > 0) bNearPastDeadline=true;
        if (!Alive(Visuals[1]) && NearFinishedAt == 0) NearFinishedAt=WorldInfo.TimeSeconds;
    }
    if (Age >= 1.8) FinishCases();
}

function Cleanup()
{
    local int i;
    for (i=0;i<4;i++)
    {
        if (Visuals[i] != None) Visuals[i].Destroy();
        if (Cores[i] != None) Cores[i].Destroy();
    }
    if (OtherCore != None) OtherCore.Destroy();
    if (Weapon != None) Weapon.Destroy();
    if (TestPawn != None) TestPawn.Destroy();
    if (TestController != None) TestController.Destroy();
    Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
    bAlwaysTick=true
    TickGroup=TG_PostAsyncWork
}

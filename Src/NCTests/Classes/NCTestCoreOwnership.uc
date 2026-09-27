// Cosmetic identity acceptance checks using real inventory removal/acquisition.
class NCTestCoreOwnership extends Info;

function NCPredictedCore MakeVisual(NCTestShock W, int Id)
{
    local NCPredictedCore Visual;
    Visual=Spawn(class'NCPredictedCore',W,,vect(0,19800,10000));
    Visual.VisualId=Id;
    Visual.PredictionGeneration=W.PredictionGeneration;
    Visual.PredictionOwner=W.Instigator;
    Visual.PredictionController=W.Instigator.Controller;
    W.Visuals.AddItem(Visual);
    return Visual;
}

function NCShockBall MakeIdentifiedCore(NCTestMutator T, NCTestShock W, int Id)
{
    local NCShockBall Core;
    Core=T.MakeCore(vect(0,19700,10000));
    Core.Instigator=W.Instigator;
    Core.SetPhysics(PHYS_None);
    Core.SetVisualIdentity(W,Id);
    return Core;
}

function Run(NCTestMutator T)
{
    local NCTestShock W;
    local UTPawn FirstPawn, SecondPawn;
    local NCTestController FirstController, SecondController;
    local NCShockBall OldCore, CurrentCore;
    local NCPredictedCore Visual;
    local int AmmoBefore, OldGeneration, SameOwnerGeneration, ControllerGeneration;

    W=NCTestShock(T.MakeWeapon(vect(0,19000,10000),false));
    SecondPawn=T.MakePawn(vect(0,19500,10000));
    FirstController=Spawn(class'NCTestController');
    SecondController=Spawn(class'NCTestController');
    T.Check(W != None && SecondPawn != None && FirstController != None && SecondController != None,"ownership setup");
    if (W == None || SecondPawn == None || FirstController == None || SecondController == None) return;
    FirstPawn=UTPawn(W.Instigator);
    FirstController.Pawn=FirstPawn; FirstPawn.Controller=FirstController;
    SecondController.Pawn=SecondPawn; SecondPawn.Controller=SecondController;
    W.CheckMatchOwner();
    OldCore=MakeIdentifiedCore(T,W,7);
    OldGeneration=W.PredictionGeneration;
    AmmoBefore=W.AmmoCount;

    // Stock pickup transfer preserves this weapon actor while changing ownership.
    FirstPawn.InvManager.RemoveFromInventory(W);
    SecondPawn.InvManager.AddInventory(W,true);
    SecondPawn.Weapon=W;
    W.CheckMatchOwner();
    T.Check(W.Instigator == SecondPawn && W.Owner == SecondPawn,"inventory transfer reuses the weapon actor");
    T.Check(W.PredictionGeneration != OldGeneration && W.PredictionGeneration > 0,"inventory transfer starts a new prediction session");
    Visual=MakeVisual(W,7);
    W.MatchVisual(7,OldGeneration,FirstPawn,FirstController,OldCore);
    T.Check(Visual.MatchedCore == None && !OldCore.bHidden,"late old core metadata cannot match a new owner's visual");
    OldCore.Shutdown();
    T.Check(!Visual.bDeleteMe && W.RetiredVisualCount == 0,"old owner core cannot retire a new owner's reused visual ID");
    W.ClientRetireVisual(7,OldGeneration,FirstPawn,FirstController);
    T.Check(!Visual.bDeleteMe && W.RetiredVisualCount == 0,"in-flight old retirement cannot clear a new prediction session");
    W.ServerVisual(8,OldGeneration,FirstPawn,FirstController);
    T.Check(W.Requests.Length == 0 && W.LastVisualId == 0,"stale owner metadata cannot reserve a new owner's core");
    W.SubmitVisual(8);
    T.Check(W.Requests.Length == 1 && W.LastVisualId == 8,"new owner metadata remains accepted");
    CurrentCore=MakeIdentifiedCore(T,W,7);
    W.MatchVisual(7,W.PredictionGeneration,SecondPawn,SecondController,CurrentCore);
    T.Check(Visual.MatchedCore == CurrentCore && CurrentCore.bHidden,"current ownership identity still matches and hides the real core");
    CurrentCore.Shutdown();
    T.Check(Visual.bDeleteMe && W.RetiredVisualCount == 1,"current ownership identity retires its own visual");
    OldCore.Destroy(); CurrentCore.Destroy();

    // Returning to the same pawn/controller must not revive an old session.
    OldCore=MakeIdentifiedCore(T,W,9);
    SameOwnerGeneration=W.PredictionGeneration;
    SecondPawn.InvManager.RemoveFromInventory(W);
    SecondPawn.InvManager.AddInventory(W,true);
    SecondPawn.Weapon=W;
    W.CheckMatchOwner();
    T.Check(W.PredictionGeneration != SameOwnerGeneration && W.Requests.Length == 0,"same-owner removal and reacquisition invalidate old matching queues");
    Visual=MakeVisual(W,9);
    OldCore.Shutdown();
    W.ClientRetireVisual(9,SameOwnerGeneration,SecondPawn,SecondController);
    T.Check(!Visual.bDeleteMe && W.RetiredVisualCount == 1,"same-owner reacquisition rejects old core and delayed retirement");
    Visual.Destroy(); OldCore.Destroy(); W.PruneVisuals();

    // Possession can change controllers without inventory removal or a new pawn.
    OldCore=MakeIdentifiedCore(T,W,10);
    ControllerGeneration=W.PredictionGeneration;
    SecondController.Pawn=None;
    FirstController.Pawn=SecondPawn; SecondPawn.Controller=FirstController;
    FirstPawn.Controller=None;
    W.CheckMatchOwner();
    T.Check(W.PredictionGeneration != ControllerGeneration,"controller-only change invalidates prediction session");
    Visual=MakeVisual(W,10);
    OldCore.Shutdown();
    W.ClientRetireVisual(10,ControllerGeneration,SecondPawn,SecondController);
    W.ClientRetireVisual(10,W.PredictionGeneration,FirstPawn,FirstController);
    T.Check(!Visual.bDeleteMe && W.RetiredVisualCount == 1,"controller and pawn scope protect current visuals");
    W.ServerVisual(10,W.PredictionGeneration,SecondPawn,SecondController);
    W.ServerVisual(10,0,SecondPawn,FirstController);
    T.Check(W.Requests.Length == 0 && W.LastVisualId == 0,"wrong controller and unknown session cannot reserve a core");
    CurrentCore=MakeIdentifiedCore(T,W,10);
    W.MatchVisual(10,W.PredictionGeneration,SecondPawn,FirstController,CurrentCore);
    ControllerGeneration=W.PredictionGeneration;
    W.DetachWeapon();
    T.Check(Visual.bDeleteMe && !CurrentCore.bHidden && W.Visuals.Length == 0
        && W.PredictionGeneration == ControllerGeneration,"ordinary detach cleans visuals and unhides core without changing owner session");
    T.Check(W.AmmoCount == AmmoBefore && W.ShotTimes.Length == 0,"ownership cleanup cannot fire or consume ammo");
    OldCore.Destroy(); CurrentCore.Destroy();
    W.Destroy(); FirstPawn.Destroy(); SecondPawn.Destroy();
    FirstController.Destroy(); SecondController.Destroy();
    Destroy();
}

defaultproperties
{
    RemoteRole=ROLE_None
}

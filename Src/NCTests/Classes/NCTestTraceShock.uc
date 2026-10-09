// Test-only observations of the unchanged cosmetic protocol and its deadlines.
class NCTestTraceShock extends NCShockRifle;

reliable server function ServerVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController)
{
    local int PreviousId, PreviousGeneration;
    PreviousId=LastVisualId;
    PreviousGeneration=PredictionGeneration;
    LogInternal("[NCMatchTrace] request time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
        $ " id=" $ Id $ " generation=" $ Generation $ " server-generation=" $ PredictionGeneration
        $ " pawn=" $ VisualOwner $ " server-pawn=" $ MatchOwner
        $ " controller=" $ VisualController $ " server-controller=" $ MatchController
        $ " previous-id=" $ PreviousId $ " request-gap=" $ (WorldInfo.TimeSeconds-LastRequestAt));
    Super.ServerVisual(Id,Generation,VisualOwner,VisualController);
    LogInternal("[NCMatchTrace] request-result time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
        $ " id=" $ Id $ " previous-id=" $ PreviousId $ " last-id=" $ LastVisualId
        $ " previous-generation=" $ PreviousGeneration $ " server-generation=" $ PredictionGeneration
        $ " requests=" $ Requests.Length $ " cores=" $ UnmatchedCores.Length);
}

function ServiceMatches()
{
    local int i;
    local array<NCShockBall> BeforeCores;
    for (i=0;i<Requests.Length;i++)
        LogInternal("[NCMatchTrace] queued-request time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
            $ " id=" $ Requests[i].Id $ " age=" $ (WorldInfo.TimeSeconds-Requests[i].Time)
            $ " over-window=" $ (WorldInfo.TimeSeconds-Requests[i].Time > RequestMatchWindow));
    for (i=0;i<UnmatchedCores.Length;i++)
    {
        BeforeCores.AddItem(UnmatchedCores[i].Core);
        LogInternal("[NCMatchTrace] queued-core time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
            $ " core=" $ UnmatchedCores[i].Core $ " age=" $ (WorldInfo.TimeSeconds-UnmatchedCores[i].Time)
            $ " over-window=" $ (WorldInfo.TimeSeconds-UnmatchedCores[i].Time > MatchWindow));
    }
    Super.ServiceMatches();
    for (i=0;i<BeforeCores.Length;i++)
        if (BeforeCores[i] != None)
            LogInternal("[NCMatchTrace] core-result time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
                $ " core=" $ BeforeCores[i] $ " id=" $ BeforeCores[i].VisualId
                $ " generation=" $ BeforeCores[i].PredictionGeneration
                $ " pawn=" $ BeforeCores[i].PredictionOwner $ " controller=" $ BeforeCores[i].PredictionController
                $ " deleted=" $ BeforeCores[i].bDeleteMe $ " shutdown=" $ BeforeCores[i].bShuttingDown);
}

simulated function MatchVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController, NCShockBall Core)
{
    local int i, PreviousMatches;
    local bool bSameId, bExactVisual;
    local float VisualAge, VisualLife;
    PreviousMatches=MatchedVisualCount;
    VisualAge=-1;
    VisualLife=-1;
    for (i=0;i<Visuals.Length;i++)
        if (Visuals[i] != None && !Visuals[i].bDeleteMe && Visuals[i].VisualId == Id)
        {
            bSameId=true;
            VisualAge=WorldInfo.TimeSeconds-Visuals[i].CreationTime;
            VisualLife=Visuals[i].LifeSpan;
            bExactVisual=Visuals[i].PredictionGeneration == Generation
                && Visuals[i].PredictionOwner == VisualOwner && Visuals[i].PredictionController == VisualController;
            break;
        }
    LogInternal("[NCMatchTrace] client-match time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
        $ " core=" $ Core $ " id=" $ Id $ " generation=" $ Generation
        $ " weapon-generation=" $ PredictionGeneration $ " pawn=" $ VisualOwner $ " controller=" $ VisualController
        $ " same-id=" $ bSameId $ " exact-visual=" $ bExactVisual
        $ " visual-age=" $ VisualAge $ " visual-life=" $ VisualLife $ " visuals=" $ Visuals.Length);
    if (Core != None)
        LogInternal("[NCMatchTrace] client-core time=" $ WorldInfo.TimeSeconds $ " core=" $ Core
            $ " id=" $ Core.VisualId $ " generation=" $ Core.PredictionGeneration
            $ " pawn=" $ Core.PredictionOwner $ " instigator=" $ Core.Instigator
            $ " controller=" $ Core.PredictionController $ " core-weapon=" $ Core.PredictionWeapon
            $ " local-actor-age=" $ (WorldInfo.TimeSeconds-Core.CreationTime)
            $ " deleted=" $ Core.bDeleteMe $ " shutdown=" $ Core.bShuttingDown);
    Super.MatchVisual(Id,Generation,VisualOwner,VisualController,Core);
    LogInternal("[NCMatchTrace] client-match-result time=" $ WorldInfo.TimeSeconds $ " weapon=" $ self
        $ " core=" $ Core $ " id=" $ Id $ " matched=" $ (MatchedVisualCount > PreviousMatches)
        $ " total-matched=" $ MatchedVisualCount);
}

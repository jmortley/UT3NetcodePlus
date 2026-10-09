// Preserve trace diagnostics while forcing an authoritative actor to arrive
// after the old 0.75-second unmatched visual deadline.
class NCTestDelayedShock extends NCTestTraceShock;

var int LateVisualMatchCount;

simulated function MatchVisual(int Id, int Generation, Pawn VisualOwner, Controller VisualController, NCShockBall Core)
{
    local int i, PreviousMatches;
    local float VisualAge;
    local NCPredictedCore Candidate;
    PreviousMatches=MatchedVisualCount;
    for (i=0;i<Visuals.Length;i++)
        if (Visuals[i] != None && !Visuals[i].bDeleteMe && Visuals[i].VisualId == Id
            && Visuals[i].PredictionGeneration == Generation && Visuals[i].PredictionOwner == VisualOwner
            && Visuals[i].PredictionController == VisualController)
        {
            Candidate=Visuals[i];
            VisualAge=WorldInfo.TimeSeconds-Candidate.CreationTime;
            break;
        }
    Super.MatchVisual(Id,Generation,VisualOwner,VisualController,Core);
    if (MatchedVisualCount > PreviousMatches && Candidate != None && !Candidate.bDeleteMe
        && Core != None && !Core.bDeleteMe && !Core.bShuttingDown
        && Candidate.MatchedCore == Core && VisualAge > 0.75)
    {
        LateVisualMatchCount++;
        LogInternal("[NCMatchTrace] delayed-match success core=" $ Core $ " id=" $ Id
            $ " generation=" $ Generation $ " visual-age=" $ VisualAge
            $ " late-matches=" $ LateVisualMatchCount);
    }
}

defaultproperties
{
    WeaponProjectiles(1)=class'NCTestDelayedShockBall'
}

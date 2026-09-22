class NCTestNetGame extends UTDeathmatch;
var int TestLag, TestLoss;
event InitGame(string Options, out string ErrorMessage)
{
    TestLag=GetIntOption(Options,"TestLag",0);
    TestLoss=GetIntOption(Options,"TestLoss",0);
    Super.InitGame(Options,ErrorMessage);
}
function PostBeginPlay()
{
    DefaultInventory.Length=1;
    Super.PostBeginPlay();
}
defaultproperties
{
    bDelayedStart=false
    bWarmupRound=false
    bQuickStart=true
    DefaultInventory(0)=class'NetcodePlusUT3.NCShockRifle'
    DefaultInventory(1)=None
    DefaultInventory(2)=None
    bUseSeamlessTravel=false
}

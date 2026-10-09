class NCTestNetGame extends UTDeathmatch;
var int TestLag, TestLoss;
var bool bDelayedShock;
event InitGame(string Options, out string ErrorMessage)
{
    TestLag=GetIntOption(Options,"TestLag",0);
    TestLoss=GetIntOption(Options,"TestLoss",0);
    bDelayedShock=GetIntOption(Options,"TestDelayedShock",0) != 0;
    Super.InitGame(Options,ErrorMessage);
}
function PostBeginPlay()
{
    DefaultInventory.Length=1;
    if (bDelayedShock) DefaultInventory[0]=class'NCTestDelayedShock';
    Super.PostBeginPlay();
}
defaultproperties
{
    bDelayedStart=false
    bWarmupRound=false
    bQuickStart=true
    DefaultInventory(0)=class'NCTestTraceShock'
    DefaultInventory(1)=None
    DefaultInventory(2)=None
    bUseSeamlessTravel=false
    PlayerControllerClass=class'NCTestInputIsolatedController'
}

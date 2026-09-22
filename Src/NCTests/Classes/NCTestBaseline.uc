// Stock UTDeathmatch connection baseline: no NetcodePlus mutator or weapons.
class NCTestBaseline extends UTMutator;
function PostBeginPlay()
{
    Super.PostBeginPlay();
    LogInternal("[NCNet] server-ready");
    SetTimer(1.0,false,'StartStockMatch');
    SetTimer(15.0,false,'Finish');
}
function StartStockMatch() { WorldInfo.Game.StartMatch(); }
function Finish()
{
    local PlayerController PC;
    local int Count;
    foreach WorldInfo.AllControllers(class'PlayerController',PC)
        if (!PC.IsLocalPlayerController()) Count++;
    if (Count == 2) LogInternal("[NCNet] PASS stock-baseline clients=" $ Count);
    else LogInternal("[NCNet] FAILED stock-baseline clients=" $ Count);
    ConsoleCommand("quit");
}
defaultproperties
{
    bExportMenuData=false
}

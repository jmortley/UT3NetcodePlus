class NCTestWeaponNetGame extends NCTestNetGame;
var string TestWeapon;

event InitGame(string Options, out string ErrorMessage)
{
    TestWeapon=ParseOption(Options,"TestWeapon");
    Super.InitGame(Options,ErrorMessage);
}

function PostBeginPlay()
{
    if (TestWeapon ~= "Sniper") DefaultInventory[0]=class'NCSniperRifle';
    else if (TestWeapon ~= "StockSniper") DefaultInventory[0]=class'UTWeap_SniperRifle';
    else if (TestWeapon ~= "StockFlak") DefaultInventory[0]=class'UTWeap_FlakCannon';
    else if (TestWeapon ~= "Flak") DefaultInventory[0]=class'NCFlakCannon';
    else DefaultInventory[0]=class'NCRocketLauncher';
    Super.PostBeginPlay();
}

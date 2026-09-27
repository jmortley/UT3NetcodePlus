class NCTestRocketStock extends UTWeap_RocketLauncher;

var array<float> ShotTimes;

function ConfigureLoad(byte Mode, int Count)
{
    CurrentFireMode=1;
    LoadedFireMode=ERocketFireMode(Mode);
    LoadedShotCount=Count;
    AmmoCount=MaxAmmoCount-Count;
}

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

class NCTestRocketLauncher extends NCRocketLauncher;

var array<float> ShotTimes;
var array<UTProjectile> Shots;
var float ForcedCatchup;

function float RocketDelay() { return ForcedCatchup; }

function ConfigureLoad(byte Mode, int Count)
{
    CurrentFireMode=1;
    LoadedFireMode=ERocketFireMode(Mode);
    LoadedShotCount=Count;
    AmmoCount=MaxAmmoCount-Count;
}

function RegisterRocket(UTProjectile P)
{
    Super.RegisterRocket(P);
    if (P != None) Shots.AddItem(P);
}

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

defaultproperties
{
    ForcedCatchup=0.06
}

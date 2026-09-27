class NCTestSniperStock extends UTWeap_SniperRifle;
var array<float> ShotTimes;

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

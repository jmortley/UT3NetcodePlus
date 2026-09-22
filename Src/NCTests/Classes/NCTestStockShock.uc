class NCTestStockShock extends UTWeap_ShockRifle;
var array<float> ShotTimes;
simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

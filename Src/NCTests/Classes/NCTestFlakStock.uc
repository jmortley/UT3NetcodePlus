class NCTestFlakStock extends UTWeap_FlakCannon;
var array<float> ShotTimes;

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

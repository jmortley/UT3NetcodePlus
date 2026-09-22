class NCTestShock extends NCShockRifle;
var array<float> ShotTimes;
var Projectile LastProjectile;
simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}
simulated function Projectile ProjectileFire()
{
    LastProjectile=Super.ProjectileFire();
    return LastProjectile;
}

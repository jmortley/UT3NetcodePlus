class NCTestShock extends NCShockRifle;
var array<float> ShotTimes;
var Projectile LastProjectile;
function SubmitVisual(int Id)
{
    CheckMatchOwner();
    ServerVisual(Id,PredictionGeneration,MatchOwner,MatchController);
}
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

class NCTestPawn extends UTPawn;
var int DamageEvents, LastDamage;
// Record stock weapon/projectile damage dispatch without match spawn protection.
event TakeDamage(int Amount, Controller From, vector HitLocation, vector Momentum,
    class<DamageType> Type, optional TraceHitInfo HitInfo, optional Actor Causer)
{
    DamageEvents++;
    LastDamage=Amount;
}

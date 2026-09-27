// Uses the production NCPawn head decision and stock UTPawn.TakeHeadShot.
// Only the final damage sink is recorded, avoiding spawn protection/match rules.
class NCTestSniperPawn extends NCPawn;
var int DamageEvents, LastDamage;
var class<DamageType> LastDamageType;
var vector LastHitLocation, LastMomentum;

event TakeDamage(int Amount, Controller From, vector HitLocation, vector Momentum,
    class<DamageType> Type, optional TraceHitInfo HitInfo, optional Actor Causer)
{
    DamageEvents++;
    LastDamage=Amount;
    LastDamageType=Type;
    LastHitLocation=HitLocation;
    LastMomentum=Momentum;
}

// Observe stock native contact/damage dispatch without match spawn protection.
class NCTestFlakTarget extends UTPawn;
var int DamageEvents, LastDamage;
var vector LastMomentum;
var class<DamageType> LastDamageType;
var float MainAgeAtContact;

event TakeDamage(int Amount, Controller From, vector HitLocation, vector Momentum,
    class<DamageType> Type, optional TraceHitInfo HitInfo, optional Actor Causer)
{
    local UTProj_FlakShardMain Main;
    DamageEvents++;
    LastDamage=Amount;
    LastMomentum=Momentum;
    LastDamageType=Type;
    Main=UTProj_FlakShardMain(Causer);
    if (Main != None) MainAgeAtContact=Main.default.LifeSpan-Main.LifeSpan;
}

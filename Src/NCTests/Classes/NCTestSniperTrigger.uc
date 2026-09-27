// A pass-through impact invalidates a later target before its damage callback.
class NCTestSniperTrigger extends NCTestTrigger;
var UTPawn Target;
var NCPawnHistory History;
var bool bClearHistory;
var int DamageEvents;

event TakeDamage(int Amount, Controller From, vector HitLocation, vector Momentum,
    class<DamageType> Type, optional TraceHitInfo HitInfo, optional Actor Causer)
{
    DamageEvents++;
    if (bClearHistory) History.Clear();
    else Target.BigTeleportCount++;
}

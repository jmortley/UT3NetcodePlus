// Preserve UTPawn.TakeHeadShot; only its geometric decision can be historical.
class NCPawn extends UTPawn;

var NCSniperRifle HeadDecisionWeapon;
var Weapon.ImpactInfo HeadDecisionImpact;
var bool bHeadDecisionPending, bHistoricalHeadShot;

function bool BeginHistoricalHeadShot(NCSniperRifle W, const out Weapon.ImpactInfo Impact, bool bHeadHit)
{
    if (Role != ROLE_Authority || W == None || W.bDeleteMe || Impact.HitActor != self
        || bHeadDecisionPending || !class'NCPawnHistory'.static.CanTrack(self)) return false;
    HeadDecisionWeapon=W;
    HeadDecisionImpact=Impact;
    bHistoricalHeadShot=bHeadHit;
    bHeadDecisionPending=true;
    return true;
}

function EndHistoricalHeadShot(NCSniperRifle W)
{
    if (HeadDecisionWeapon == W)
    {
        bHeadDecisionPending=false;
        HeadDecisionWeapon=None;
        HeadDecisionImpact.HitActor=None;
    }
}

function bool IsLocationOnHead(const out ImpactInfo Impact, float AdditionalScale)
{
    if (Role == ROLE_Authority && bHeadDecisionPending && HeadDecisionWeapon != None
        && Impact.HitActor == self && Impact.HitLocation == HeadDecisionImpact.HitLocation
        && Impact.RayDir == HeadDecisionImpact.RayDir)
    {
        // Consume before native helmet/damage callbacks can cause another query.
        bHeadDecisionPending=false;
        return bHistoricalHeadShot;
    }
    return Super.IsLocationOnHead(Impact,AdditionalScale);
}

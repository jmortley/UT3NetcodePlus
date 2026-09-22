// Authoritative collision, damage, core/core interaction and combos are stock.
class NCShockBall extends UTProj_ShockBall;

var NCShockRifle PredictionWeapon;
var int VisualId;
var bool bMatchResolved;

replication
{
    if (Role == ROLE_Authority) PredictionWeapon, VisualId;
}

function SetVisualIdentity(NCShockRifle W, int Id)
{
    if (Role != ROLE_Authority || VisualId != 0) return;
    PredictionWeapon=W;
    VisualId=Id;
    bNetDirty=true;
    bForceNetUpdate=true;
}

simulated event Tick(float DeltaTime)
{
    // The actor, weapon reference and identity may arrive in different updates.
    // Wait for all three instead of passing an unmapped actor in a weapon RPC.
    if (Role < ROLE_Authority && !bMatchResolved && VisualId > 0
        && PredictionWeapon != None && Instigator != None && Instigator.IsLocallyControlled())
    {
        PredictionWeapon.MatchVisual(VisualId,self);
        bMatchResolved=true;
    }
}

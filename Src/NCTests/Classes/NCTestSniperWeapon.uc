class NCTestSniperWeapon extends NCSniperRifle;
var array<float> ShotTimes;

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

function ImpactInfo TraceAndProcess(vector Start, vector End)
{
    local ImpactInfo Impact;
    local array<ImpactInfo> Impacts;
    local int i;
    bInstantTraceScope=true;
    bHistoricalDecision=false;
    Impact=CalcWeaponFire(Start,End,Impacts);
    for (i=0;i<Impacts.Length;i++) ProcessInstantHit(0,Impacts[i]);
    bHistoricalDecision=false;
    bInstantTraceScope=false;
    HistoricalImpact.HitActor=None;
    HistoricalHistory=None;
    return Impact;
}

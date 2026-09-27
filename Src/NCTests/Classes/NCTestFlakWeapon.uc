class NCTestFlakWeapon extends NCFlakCannon;

var array<float> ShotTimes;
var array<UTProjectile> Shots;
var array<vector> InitialVelocities;
var float ForcedCatchup;
var int VolleyStartIndex;
var bool bAdvancedBeforeVolleyComplete;

function float FlakDelay() { return ForcedCatchup; }

simulated function CustomFire()
{
    VolleyStartIndex=Shots.Length;
    Super.CustomFire();
}

function RegisterFlak(UTProjectile P)
{
    local int i;
    // Stock primary draws random spread/rotation between Init callbacks. An
    // earlier projectile must not run impact physics during that sequence.
    if (CurrentFireMode == 0)
        for (i=VolleyStartIndex;i<Shots.Length;i++)
        {
            if (NCFlakShard(Shots[i]) != None && NCFlakShard(Shots[i]).CatchupState != 0)
                bAdvancedBeforeVolleyComplete=true;
            if (NCFlakShardMain(Shots[i]) != None && NCFlakShardMain(Shots[i]).CatchupState != 0)
                bAdvancedBeforeVolleyComplete=true;
        }
    Super.RegisterFlak(P);
    if (P != None)
    {
        Shots.AddItem(P);
        InitialVelocities.AddItem(P.Velocity);
    }
}

simulated function FireAmmunition()
{
    ShotTimes.AddItem(WorldInfo.TimeSeconds);
    Super.FireAmmunition();
}

defaultproperties
{
    ForcedCatchup=0.06
}

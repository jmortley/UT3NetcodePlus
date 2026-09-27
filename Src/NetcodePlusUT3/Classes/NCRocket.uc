class NCRocket extends UTProj_Rocket;

var byte CatchupState;
var float CatchupSeconds;

function Init(vector Direction)
{
    local NCRocketLauncher W;
    Super.Init(Direction);
    if (Instigator != None) W=NCRocketLauncher(Instigator.Weapon);
    if (W != None) W.RegisterRocket(self);
}

function float AdvanceAtSpawn(float Seconds)
{
    local float Advanced;
    Advanced=class'NCRocketPhysics'.static.Advance(self,Seconds,CatchupState);
    CatchupSeconds+=Advanced;
    return Advanced;
}

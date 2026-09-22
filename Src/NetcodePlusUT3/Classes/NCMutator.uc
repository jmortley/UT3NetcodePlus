// Shock-only integration. Other weapon classes and match rules are unchanged.
class NCMutator extends UTMutator config(NetcodePlusUT3);

var config float MaxRewindSeconds;
var config bool bPredictCores;
var NCRewind Rewind;

function PostBeginPlay()
{
    local UTGame G;
    local int i;
    Super.PostBeginPlay();
    MaxRewindSeconds=FClamp(MaxRewindSeconds,0.0,0.25);
    Rewind=Spawn(class'NCRewind');
    if (Rewind == None) { LogInternal("[NetcodePlusUT3] Initialization failed: history service"); return; }
    Rewind.MaxRewindSeconds=MaxRewindSeconds;
    G=UTGame(WorldInfo.Game);
    if (G != None)
        for (i=0;i<G.DefaultInventory.Length;i++)
            if (G.DefaultInventory[i] == class'UTWeap_ShockRifle') G.DefaultInventory[i]=class'NCShockRifle';
    SetTimer(1.0,true,'RegisterPlayers');
    LogInternal("[NetcodePlusUT3] Shock alpha: beam rewind, predicted core visuals, stock firing and combos");
}

function RegisterPlayers()
{
    local PlayerController PC;
    if (Rewind == None) return;
    foreach WorldInfo.AllControllers(class'PlayerController',PC) Rewind.RegisterPlayer(PC);
}

function ModifyPlayer(Pawn Other)
{
    if (Rewind != None)
    {
        Rewind.ResetPawnHistory(Other);
        Rewind.RegisterPlayer(PlayerController(Other.Controller));
    }
    Super.ModifyPlayer(Other);
}

function bool CheckReplacement(Actor Other)
{
    local UTWeaponPickupFactory Factory;
    local UTWeaponLocker Locker;
    local UTAmmoPickupFactory Ammo;
    local NCShockRifle W;
    local int i;
    Factory=UTWeaponPickupFactory(Other);
    if (Factory != None && Factory.WeaponPickupClass == class'UTWeap_ShockRifle')
    {
        Factory.WeaponPickupClass=class'NCShockRifle';
        Factory.InitializePickup();
    }
    Locker=UTWeaponLocker(Other);
    if (Locker != None)
        for (i=0;i<Locker.Weapons.Length;i++)
            if (Locker.Weapons[i].WeaponClass == class'UTWeap_ShockRifle') Locker.ReplaceWeapon(i,class'NCShockRifle');
    Ammo=UTAmmoPickupFactory(Other);
    if (Ammo != None && Ammo.TargetWeapon == class'UTWeap_ShockRifle') Ammo.TargetWeapon=class'NCShockRifle';
    W=NCShockRifle(Other);
    if (W != None) W.bPredictionEnabled=bPredictCores;
    return true;
}

defaultproperties
{
    MaxRewindSeconds=0.15
    bPredictCores=true
    GroupNames(0)="NetcodePlusUT3"
}

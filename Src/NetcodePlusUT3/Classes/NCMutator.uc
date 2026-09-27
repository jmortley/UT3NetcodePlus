// Stock weapon adapters; unrelated weapon classes and match rules stay intact.
class NCMutator extends UTMutator config(NetcodePlusUT3);

var config float MaxRewindSeconds;
var config float MaxCoreCatchupSeconds;
var config float MaxRocketCatchupSeconds;
var config bool bPredictCores;
var NCRewind Rewind;

function PostBeginPlay()
{
    local UTGame G;
    local class<UTWeapon> Replacement;
    local int i;
    Super.PostBeginPlay();
    MaxRewindSeconds=FClamp(MaxRewindSeconds,0.0,0.25);
    MaxCoreCatchupSeconds=FClamp(MaxCoreCatchupSeconds,0.0,0.10);
    MaxRocketCatchupSeconds=FClamp(MaxRocketCatchupSeconds,0.0,0.10);
    Rewind=Spawn(class'NCRewind');
    if (Rewind == None) { LogInternal("[NetcodePlusUT3] Initialization failed: history service"); return; }
    Rewind.MaxRewindSeconds=MaxRewindSeconds;
    Rewind.MaxCoreCatchupSeconds=MaxCoreCatchupSeconds;
    Rewind.MaxRocketCatchupSeconds=MaxRocketCatchupSeconds;
    G=UTGame(WorldInfo.Game);
    if (G != None)
    {
        // Only replace the stock pawn: custom game modes retain their own class.
        // NCPawn changes only the scoped head test used by a rewound sniper shot.
        if (G.DefaultPawnClass == class'UTPawn') G.DefaultPawnClass=class'NCPawn';
        for (i=0;i<G.DefaultInventory.Length;i++)
        {
            Replacement=ReplacementFor(class<UTWeapon>(G.DefaultInventory[i]));
            if (Replacement != None) G.DefaultInventory[i]=Replacement;
        }
    }
    SetTimer(1.0,true,'RegisterPlayers');
    LogInternal("[NetcodePlusUT3] Weapon alpha: Shock/sniper rewind, core prediction, bounded projectile catch-up");
}

function class<UTWeapon> ReplacementFor(class<UTWeapon> WeaponClass)
{
    if (WeaponClass == class'UTWeap_ShockRifle') return class'NCShockRifle';
    if (WeaponClass == class'UTWeap_SniperRifle') return class'NCSniperRifle';
    if (WeaponClass == class'UTWeap_RocketLauncher') return class'NCRocketLauncher';
    return WeaponClass;
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
    local class<UTWeapon> Replacement;
    local int i;
    Factory=UTWeaponPickupFactory(Other);
    if (Factory != None)
    {
        Replacement=ReplacementFor(Factory.WeaponPickupClass);
        if (Replacement != Factory.WeaponPickupClass)
        {
            Factory.WeaponPickupClass=Replacement;
            Factory.InitializePickup();
        }
    }
    Locker=UTWeaponLocker(Other);
    if (Locker != None)
        for (i=0;i<Locker.Weapons.Length;i++)
        {
            Replacement=ReplacementFor(Locker.Weapons[i].WeaponClass);
            if (Replacement != Locker.Weapons[i].WeaponClass) Locker.ReplaceWeapon(i,Replacement);
        }
    Ammo=UTAmmoPickupFactory(Other);
    if (Ammo != None) Ammo.TargetWeapon=ReplacementFor(Ammo.TargetWeapon);
    W=NCShockRifle(Other);
    if (W != None) W.bPredictionEnabled=bPredictCores;
    return true;
}

defaultproperties
{
    MaxRewindSeconds=0.15
    MaxCoreCatchupSeconds=0.06
    MaxRocketCatchupSeconds=0.06
    bPredictCores=true
    GroupNames(0)="NetcodePlusUT3"
}

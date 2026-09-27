// Verify profile-loaded parent defaults reach new adapter instances without
// changing either class defaults or later per-instance priority overrides.
class NCTestWeaponIntegration extends Info;

function CheckPriority(NCTestMutator T, class<UTWeapon> StockClass,
    class<UTWeapon> AdapterClass, string Label, float ProfilePriority)
{
    local UTWeapon Stock, Adapter;
    local float SavedStockPriority, SavedAdapterPriority, Expected;

    SavedStockPriority=StockClass.default.Priority;
    SavedAdapterPriority=AdapterClass.default.Priority;
    StockClass.default.Priority=ProfilePriority;
    Stock=Spawn(StockClass);
    Adapter=Spawn(AdapterClass);
    // Restore immediately after spawning, including a failed-spawn path. Each
    // instance must already hold its profile value when PostBeginPlay returns.
    StockClass.default.Priority=SavedStockPriority;
    T.Check(Stock != None && Adapter != None,Label $ " priority setup");
    if (Stock != None && Adapter != None)
    {
        Expected=ProfilePriority;
        if (Expected < 0) Expected=Stock.InventoryWeight;
        T.Check(Abs(Stock.GetWeaponRating()-Expected) < 0.001
            && Abs(Adapter.GetWeaponRating()-Expected) < 0.001
            && Abs(Adapter.Priority-Stock.Priority) < 0.001
            && AdapterClass.default.Priority == SavedAdapterPriority,
            Label $ " profile priority matches stock initialization");

        // A mutator may customize an existing instance. Rating must not reread
        // the restored stock class default and overwrite that customization.
        Stock.Priority=71.5;
        Adapter.Priority=71.5;
        T.Check(Abs(Stock.GetWeaponRating()-71.5) < 0.001
            && Abs(Adapter.GetWeaponRating()-Stock.GetWeaponRating()) < 0.001,
            Label $ " later instance priority remains intact");
    }
    if (Stock != None) Stock.Destroy();
    if (Adapter != None) Adapter.Destroy();
}

function Run(NCTestMutator T)
{
    CheckPriority(T,class'UTWeap_ShockRifle',class'NCShockRifle',"Shock positive",97.25);
    CheckPriority(T,class'UTWeap_ShockRifle',class'NCShockRifle',"Shock default fallback",-1);
    CheckPriority(T,class'UTWeap_SniperRifle',class'NCSniperRifle',"sniper positive",97.25);
    CheckPriority(T,class'UTWeap_SniperRifle',class'NCSniperRifle',"sniper default fallback",-1);
    CheckPriority(T,class'UTWeap_RocketLauncher',class'NCRocketLauncher',"rocket positive",97.25);
    CheckPriority(T,class'UTWeap_RocketLauncher',class'NCRocketLauncher',"rocket default fallback",-1);
    Destroy();
}

defaultproperties { RemoteRole=ROLE_None }

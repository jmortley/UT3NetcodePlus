class NCTestBlocker extends Actor;
defaultproperties
{
    Begin Object Class=CylinderComponent Name=TestCylinder
        CollisionRadius=25
        CollisionHeight=100
        BlockZeroExtent=true
        BlockNonZeroExtent=true
        CollideActors=true
        BlockActors=true
    End Object
    CollisionComponent=TestCylinder
    Components.Add(TestCylinder)
    bCollideActors=true
    bBlockActors=true
    bProjTarget=true
}

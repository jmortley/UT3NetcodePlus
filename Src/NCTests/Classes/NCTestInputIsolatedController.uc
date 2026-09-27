// Automated clients must not mix desktop clicks with the scripted weapon calls.
// The driver still calls Weapon.StartFire/StopFire directly, preserving their
// stock local prediction, reliable RPCs, firing states and release behavior.
class NCTestInputIsolatedController extends UTPlayerController;

exec function StartFire(optional byte FireModeNum) {}
exec function StopFire(optional byte FireModeNum) {}
exec function StartAltFire(optional byte FireModeNum) {}
exec function StopAltFire(optional byte FireModeNum) {}

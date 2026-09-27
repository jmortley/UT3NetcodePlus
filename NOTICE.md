# Provenance

NetcodePlusUT3 is a new UnrealScript implementation for the user's installed UT3 build 3809, prepared September 21, 2026. It selectively implements features discussed while reviewing the user's current UT4 NetcodePlus plugin. It is not the complete UT4 plugin port and does not use UT2004 NetcodePlus 06.7k as its port target.

The cylinder intersection and server-timed ping pattern adapt the supplied UTComp3 development prototype. That prototype's notice provides its new source under GNU GPL version 2 or later, and identifies original UTComp authors Aaron Everitt and Joël Moffatt. This derivative source package is likewise provided under GPL version 2 or later; see LICENSE. The upstream authors are not represented as authors or endorsers of this implementation.

The history ring, trace integration, scoped sniper headshot adapter, core visual prediction/matching, bounded core/rocket/grenade/Flak native-physics catch-up, mutator and tests were implemented here with the installed UT3 UnrealScript API as reference. The default catch-up windows follow the current UT4 NetcodePlus plugin's 120 ms RTT prediction cap (60 ms half RTT). Stock engine/game classes are inherited, not bundled. UT3 and its referenced content remain Epic's property; a licensed UT3 installation is required. No Epic game packages, executable, recovered stock source, UT4 assets, or original UTComp3 binary are distributed in this package.

All changes from the supplied prototype are separate from its original archive. The UT4 plugin's tracked source has not been edited for this work.

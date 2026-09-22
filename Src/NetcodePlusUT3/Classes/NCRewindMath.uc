// Adapted from UTComp3 UTCRewindMath, GPL-2.0-or-later, 2026-09-21.
class NCRewindMath extends Object;

static function bool SegmentCylinder(vector Start, vector End, vector Center,
    float Radius, float Height, out float Fraction, out vector HitNormal)
{
    local vector D, O, P;
    local float A, B, C, Disc, NearXY, FarXY, NearZ, FarZ, T, Enter, Leave;
    if (Radius <= 0 || Height <= 0 || VSizeSq(End-Start) < 0.000001) return false;
    D=End-Start;
    O=Start-Center;
    A=D.X*D.X+D.Y*D.Y;
    B=2.0*(O.X*D.X+O.Y*D.Y);
    C=O.X*O.X+O.Y*O.Y-Radius*Radius;
    NearXY=-1000000.0;
    FarXY=1000000.0;
    if (A < 0.000001) { if (C > 0) return false; }
    else
    {
        Disc=B*B-4.0*A*C;
        if (Disc < 0) return false;
        NearXY=(-B-Sqrt(Disc))/(2.0*A);
        FarXY=(-B+Sqrt(Disc))/(2.0*A);
    }
    NearZ=-1000000.0;
    FarZ=1000000.0;
    if (Abs(D.Z) < 0.000001) { if (Abs(O.Z) > Height) return false; }
    else
    {
        NearZ=(-Height-O.Z)/D.Z;
        FarZ=(Height-O.Z)/D.Z;
        if (NearZ > FarZ) { T=NearZ; NearZ=FarZ; FarZ=T; }
    }
    Enter=FMax(0.0,FMax(NearXY,NearZ));
    Leave=FMin(1.0,FMin(FarXY,FarZ));
    if (Enter > Leave) return false;
    Fraction=Enter;
    P=O+D*Enter;
    if (NearZ > NearXY && Enter > 0)
    {
        HitNormal=vect(0,0,1);
        if (P.Z < 0) HitNormal.Z=-1;
    }
    else
    {
        P.Z=0;
        HitNormal=Normal(P);
        if (VSizeSq(HitNormal) < 0.01) HitNormal=-Normal(D);
    }
    return true;
}

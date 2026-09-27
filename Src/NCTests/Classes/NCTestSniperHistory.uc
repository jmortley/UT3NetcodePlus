// Controlled head poses on real recorded body frames, without crossing the
// UnrealScript context limit for a packed bool inside the large fixed array.
class NCTestSniperHistory extends NCPawnHistory;

function SetHead(int Index, vector Position, float Radius, bool bValid)
{
    local Frame F;
    F=Frames[Index];
    F.HeadPosition=Position;
    F.HeadRadius=Radius;
    F.bHeadValid=bValid;
    Frames[Index]=F;
}

function InvalidateHeads()
{
    local int i;
    local Frame F;
    for (i=0;i<Count;i++)
    {
        F=Frames[i];
        F.bHeadValid=false;
        Frames[i]=F;
    }
}

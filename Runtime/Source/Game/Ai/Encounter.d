
module Game.Ai.Encounter;

import Game.Ai.Ai;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct Encounter
{

DatumIndex selfIndex;
Ai*        ai;

int squadBegin;
int squadEnd;

int platoonBegin;
int platoonEnd;

bool active;

void placeActors()
{
    foreach(int i, ref tagSquad ; Cache.inst.scenario.encounters[selfIndex.i].squads)
    {
        Squad* squad = &ai.squads[squadBegin + i];

        // TODO(IMPLEMENT, DIFFICULTY) change depending on difficulty

        int count = tagSquad.normalDiffCount;

        switch(tagSquad.uniqueLeaderType) with(TagEnums)
        {
        case UniqueLeader.normal: break;
        case UniqueLeader.none: break;
        case UniqueLeader.random: break;
        case UniqueLeader.sgtJohnson: break;
        case UniqueLeader.sgtLehto: break;
        default:
        }

        foreach(j ; 0 .. count)
        {

        }

    }
}

}

// Squad ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct Squad
{

BitArray!(TagConstants.Actor.maxStartingPositions) spawnPositions;
BitArray!(TagConstants.Actor.maxStartingPositions) unusedPositions;

int respawnTotal;
int delayTicks;

}

// Platoon //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct Platoon
{

bool startInDefendingState;

}
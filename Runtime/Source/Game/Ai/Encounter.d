
module Game.Ai.Encounter;

import Game.Ai.Ai;
import Game.World;

import Game.Cache;
import Game.Core;
import Game.Tags;

struct AiEncounter
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
        AiSquad* squad = &ai.squads[squadBegin + i];

        int count = tagSquad.normalDiffCount; // TODO(IMPLEMENT, DIFFICULTY) change depending on difficulty
        int regionPermutation = 0;

        switch(tagSquad.uniqueLeaderType) with(TagEnums)
        {
        // TODO region permutation
        case UniqueLeader.normal:     break;
        case UniqueLeader.none:       break;
        case UniqueLeader.random:     break;
        case UniqueLeader.sgtJohnson: break;
        case UniqueLeader.sgtLehto:   break;
        default:
        }

        foreach(j ; 0 .. count)
        {
            createActorForSquad(i, regionPermutation);
            regionPermutation = 0;
        }

    }
}

private int findStartingPositionIndex(int squadIndex)
{
    const Tag.SquadsBlock* tagSquad = &Cache.inst.scenario.encounters[selfIndex.i].squads[squadIndex];
    AiSquad* squad = &ai.squads[squadBegin + squadIndex];

    return 0; // TODO
}

private DatumIndex createActorForSquad(int squadIndex, int regionPermutation)
{
    const Tag.SquadsBlock* tagSquad = &Cache.inst.scenario.encounters[selfIndex.i].squads[squadIndex];

    int positionIndex = findStartingPositionIndex(squadIndex);

    if(positionIndex == indexNone)
    {
        return DatumIndex();
    }

    const Tag.ActorStartingLocationsBlock* tagPosition = &tagSquad.startingLocations[positionIndex];
    short actorPaletteIndex = tagPosition.actorType != indexNone ? tagPosition.actorType : tagSquad.actorType;

    if(!Cache.inst.scenario.actorPalette.inBounds(actorPaletteIndex))
    {
        return DatumIndex();
    }

    const tagActorVariant = Cache.get!TagActorVariant(Cache.inst.scenario.actorPalette[actorPaletteIndex].reference);

    if(tagActorVariant.majorVariant)
    {
        assert(0); // TODO
    }



    assert(0);
}

private DatumIndex createActorObject(
    const Tag.ActorStartingLocationsBlock* tagPosition,
    DatumIndex actorVariantIndex,
    bool       majorUpgrade,
    int        squadIndex,
    int        regionPermutation)
{
    const tagActorVariant = Cache.get!TagActorVariant(actorVariantIndex);

    if(majorUpgrade)
    {
        assert(0); // TODO
    }

    GObject.Creation creation;

    creation.tagIndex = tagActorVariant.unit.index;
    creation.position = tagPosition.position;
    creation.regionPermutation = regionPermutation;
    creation.forward = Vec3.fromAngleZ(tagPosition.facing);

    GObject* object = ai.world.createObject(creation);


    assert(0); // TODO
}

}

// Squad ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct AiSquad
{

BitArray!(TagConstants.Actor.maxStartingPositions) spawnPositions;
BitArray!(TagConstants.Actor.maxStartingPositions) unusedPositions;

int respawnTotal;
int delayTicks;

}

// Platoon //////////////////////////////////////////////////////////////////////////////////////////////////////////////////

struct AiPlatoon
{

bool startInDefendingState;

}


module Game.Ai.Ai;

import Game.Ai.Encounter;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World : World;

struct Ai
{

World* world;

DatumArray!Encounter encounters;
Squad[1024]          squads;
Platoon[256]         platoons;

void initialize()
{
    encounters.allocate(128, multichar!"ec");
}

}
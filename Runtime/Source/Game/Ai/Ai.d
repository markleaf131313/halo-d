
module Game.Ai.Ai;

import Game.Ai.Actor;
import Game.Ai.Encounter;
import Game.Ai.Prop;

import Game.Cache;
import Game.Core;
import Game.Tags;
import Game.World : World;

struct Ai
{

World* world;

DatumArray!AiActor     actors;
DatumArray!AiEncounter encounters;
AiSquad[1024]          squads;
AiPlatoon[256]         platoons;

DatumArray!AiProp      props;

void initialize()
{
    actors.allocate(256, multichar!"ac");
    encounters.allocate(128, multichar!"ec");
    props.allocate(1024, multichar!"pr");
}

}

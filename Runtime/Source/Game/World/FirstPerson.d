
module Game.World.FirstPerson;

import Game.World.Objects;

import Game.Core;
import Game.Tags;

// TODO(REFACTOR, ?) this might be better in some sort of interface module?
struct FirstPerson
{
@nogc nothrow:

    enum Action
    {
        fire1,
        fire2,
        misfire1,
        misfire2,
        melee,
        lightOff,
        lightOn,
        unused7,
        unused8,
        reloadEmpty,
        reloadFull,
        putAway,
        ready,
        invalidateWeapon,
        overcharged,
        overheating,
        overheatExit,
        throwGrenade,
    }

    enum State
    {
        none = indexNone,
        idle = 0,
        overheating,
        overheatingAgain,
        overheated,
        overcharged,
        posing,
        fire1,
        fire2,
        misfire1,
        misfire2,
        melee,
        lightOff,
        lightOn,
        reloadEmpty,
        reloadFull,
        enter,
        exitEmpty,
        exitFull,
        putAway,
        ready,
        throwGrenade,
        throwOverheated,
        overheatEnter,
        overheatExit,
    }

    bool visible;

    // TODO(REFACTOR, ?) use SheepGObjectPtr here to ensure objects are alive?
    Biped*  biped;
    Weapon* weapon;

    State state = State.none;

    int overlayAnimationIndex = indexNone;

    GObject.AnimationController baseAnimation; // TODO(REFACTOR, ?) move AnimationController out of GObject ?
    GObject.AnimationController movingAnimation;
    GObject.AnimationController jitterAnimation;

    float jitterFrame;

    int interpolateIndex;
    int interpolateCount;

    Transform  [TagConstants.Animation.maxNodes] transforms;
    Orientation[TagConstants.Animation.maxNodes] orientations;
    Orientation[TagConstants.Animation.maxNodes] interpolateOrientations;

    bool weaponMapValid;
    bool handsMapValid;

    int[TagConstants.Animation.maxNodes] weaponIndexMap;
    int[TagConstants.Animation.maxNodes] handsIndexMap;


    static ref FirstPerson inst(int i)
    {
        __gshared FirstPerson[TagConstants.Player.maxLocalPlayers] instances;
        return instances[i];
    }

    void updateLogic()
    {
        assert(0); // TODO
    }

    void doAction(Action action)
    {
        assert(0); // TODO

    }

    void ready()
    {
        assert(0); // TODO
    }

    void changeState(State desired)
    {
        assert(0); // TODO
    }

    void interpolateCurrent(int frames)
    {
        assert(0); // TODO
    }
}
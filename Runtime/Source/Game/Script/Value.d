
module Game.Script.Value;

enum HsType : short
{
    unparsed,
    specialForm,
    functionName,
    passthrough,

    hsVoid,
    hsBool,
    hsFloat,
    hsShort,
    hsInt,
    string,
    script,

    triggerVolume,
    cutsceneFlag,
    cutsceneCameraPoint,
    cutsceneTitle,
    cutsceneRecording,
    deviceGroup,
    ai,
    aiCommandList,
    startingProfile,
    conversation,

    navpoint,
    hudMessage,

    objectList,

    sound,
    effect,
    damage,
    loopingSound,
    animationGraph,
    actorVariant,
    damageEffect,
    objectDefinition,

    gameDifficulty,
    team,
    aiDefaultState,
    actorType,
    hudCorner,

    object,
    unit,
    vehicle,
    weapon,
    device,
    scenery,

    objectName,
    unitName,
    vehicleName,
    weaponName,
    deviceName,
    sceneryName,



}

struct HsValue
{

static assert(this.sizeof == 4);

union
{
    uint  bits;
    void* ptr;
}

@property @nogc nothrow
T as(T)() const
{
    static assert(T.sizeof <= this.sizeof);
    return *cast(T*)&this;
}

}
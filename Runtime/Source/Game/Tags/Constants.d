
module Game.Tags.Constants;

private import Game.Core.Math : toRadians;

struct Animation
{
    @disable this();
    enum maxNodes = 64;
}
struct Biped
{
    @disable this();
    enum maxPhysicsIterations = 16;
}
struct Bsp
{
    @disable this();
    enum maxSurfaceEdges = 8;
    enum maxBsp3dDepth = 64;
}
struct Camera
{
    @disable this();
    enum float maxPitchAngle = toRadians(85.5f);
}
struct Effect
{
    @disable this();
    enum maxLocations         = 32;
    enum maxParticlesPerEvent = 32;
}
struct Model
{
    @disable this();
    enum maxFindablePermutations = 32;
    enum maxLocationsPerMarker = 16;
    enum maxPermutations = 100;
    enum maxPartLocalNodes = 24;
    enum maxRegions = 8;
}
struct Object
{
    @disable this();
    enum maxClusterPresence = 64;
    enum maxInputFunctions  = 4;
    enum maxOutputFunctions = 4;
}
struct Particle
{
    enum float restingThreshold = 1.0f / 16.0f;
}
struct Player
{
    @disable this();
    enum float minEnterSeatDistanceSqr   = 1.0f;
    enum float driverAdvantageMultiplier = 1.5f;
    enum maxLocalPlayers                 = 16;
}
struct PointPhysics
{
    enum float densityConversion = 118613.34f; // from g/ml to world unit density
    enum float densityOfAir      = densityConversion * 0.0011f;
    enum float densityOfWater    = densityConversion * 1.0f;
}
struct StructureBsp
{
    @disable this();
    enum maxClusters = 512;
}
struct Unit
{
    @disable this();
    enum maxPoweredSeats = 2;
    enum maxHeldWeapons = 4;
    enum maxCountedHeldWeapons = 2;

    static assert(maxCountedHeldWeapons <= maxHeldWeapons);
}
struct Vehicle
{
    @disable this();

    enum maxSuspension = 8;
    enum maxCollisionObjects = 2048;
}
struct Weapon
{
    @disable this();
    enum maxMagazines = 2;
    enum maxTriggers  = 2;
    enum needlerReloadFrameIndex = 44;

    static assert(maxTriggers >= 2, "Weapon requires at least 2 triggers.");

}
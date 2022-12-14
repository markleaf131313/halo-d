
module Game.Tags.Funcs.Sound;

mixin template TagSound()
{
@nogc nothrow:

import Game.Core : indexNone, randomValueFromZero, randomPercent;

float getMinimumDistance() const
{
    static immutable float[51] defaultValues =
    [
        1.4f,       // projectile_impact
        8.0f,       // projectile_detonation
        float.nan,
        float.nan,
        4.0f,       // weapon_fire
        1.0f,       // weapon_ready
        1.0f,       // weapon_reload
        1.0f,       // weapon_empty
        1.0f,       // weapon_charge
        1.0f,       // weapon_overheat
        1.0f,       // weapon_idle
        float.nan,
        float.nan,
        0.5f,       // object_impacts
        0.5f,       // particle_impacts
        0.5f,       // slow_particle_impacts
        float.nan,
        float.nan,
        0.9f,      // unit_footsteps
        3.0f,      // unit_dialog
        float.nan,
        float.nan,
        1.4f,       // vehicle_collision
        1.4f,       // vehicle_engine
        float.nan,
        float.nan,
        0.9f,       // device_door
        0.9f,       // device_force_field
        0.9f,       // device_machinery
        0.9f,       // device_nature
        0.5f,       // device_computers
        float.nan,
        0.9f,       // music
        0.9f,       // ambient_nature
        0.9f,       // ambient_machinery
        0.5f,       // ambient_computers
        float.nan,
        float.nan,
        float.nan,
        0.5f,       // first_person_damage
        float.nan,
        float.nan,
        float.nan,
        float.nan,
        3.0f,       // scripted_dialog_player
        2.0f,       // scripted_effect
        3.0f,       // scripted_dialog_other
        3.0f,       // scripted_dialog_force_unspatialized
        float.nan,
        float.nan,
        3.0f,       // game_event
    ];

    if(minimumDistance == 0.0f)
    {
        return defaultValues[soundClass];
    }

    return minimumDistance;
}

float getMaximumDistance() const
{
    static immutable float[51] defaultValues =
    [
        8.0f,       // projectile_impact
        120.0f,     // projectile_detonation
        float.nan,
        float.nan,
        70.0f,      // weapon_fire
        9.0f,       // weapon_ready
        9.0f,       // weapon_reload
        9.0f,       // weapon_empty
        9.0f,       // weapon_charge
        9.0f,       // weapon_overheat
        9.0f,       // weapon_idle
        float.nan,
        float.nan,
        3.0f,       // object_impacts
        3.0f,       // particle_impacts
        3.0f,       // slow_particle_impacts
        float.nan,
        float.nan,
        10.0f,      // unit_footsteps
        20.0f,      // unit_dialog
        float.nan,
        float.nan,
        8.0f,       // vehicle_collision
        8.0f,       // vehicle_engine
        float.nan,
        float.nan,
        5.0f,       // device_door
        5.0f,       // device_force_field
        5.0f,       // device_machinery
        5.0f,       // device_nature
        3.0f,       // device_computers
        float.nan,
        5.0f,       // music
        5.0f,       // ambient_nature
        5.0f,       // ambient_machinery
        3.0f,       // ambient_computers
        float.nan,
        float.nan,
        float.nan,
        3.0f,       // first_person_damage
        float.nan,
        float.nan,
        float.nan,
        float.nan,
        20.0f,      // scripted_dialog_player
        5.0f,       // scripted_effect
        20.0f,      // scripted_dialog_other
        20.0f,      // scripted_dialog_force_unspatialized
        float.nan,
        float.nan,
        20.0f,      // game_event
    ];

    if(maximumDistance == 0.0f)
    {
        return defaultValues[soundClass];
    }

    return maximumDistance;
}

int selectPitchRange(float pitch, int suggestedIndex = indexNone) const
{
    if(suggestedIndex != indexNone && suggestedIndex < pitchRanges.size)
    {
        const pitchRange = &pitchRanges[suggestedIndex];

        if(pitchRange.bendBounds.inBounds!"[]"(pitch) && pitchRange.permutations.size > 0)
        {
            return suggestedIndex;
        }
    }

    int result = indexNone;
    float closest = float.max;

    foreach(int i, ref pitchRange ; pitchRanges)
    {
        if(pitchRange.permutations.size <= 0)
        {
            continue;
        }

        if(pitchRange.bendBounds.inBounds!"[]"(pitch))
        {
            return i;
        }

        float scaled = (pitch >= pitchRange.bendBounds.upper)
            ? pitchRange.bendBounds.lower / pitch
            : pitch / pitchRange.bendBounds.upper;

        if(scaled < closest)
        {
            closest = scaled;
            result  = i;
        }
    }

    return result;
}

int selectPermutation(int pitchRangeIndex, int prevPermutationIndex = indexNone)
{
    auto pitchRange = &pitchRanges[pitchRangeIndex];

    if(pitchRange.nextPermutationIndex != indexNone)
    {
        return pitchRange.nextPermutationIndex;
    }

    if(flags.splitLongSoundIntoPermutations && prevPermutationIndex != indexNone)
    {
        return pitchRange.permutations[prevPermutationIndex].nextPermutationIndex;
    }

    int index = randomValueFromZero(pitchRange.actualPermutationCount);

    foreach(int i ; 0 .. pitchRange.actualPermutationCount)
    {
        int   permutationIndex = (index + i) % pitchRange.actualPermutationCount;
        const permutation      = &pitchRange.permutations[permutationIndex];
        int   allSet           = 1 << pitchRange.actualPermutationCount - 1;

        if((allSet & ~pitchRange.playedPermutationBits) == 0)
        {
            if(pitchRange.actualPermutationCount > 1)
            {
                pitchRange.playedPermutationBits = 1 << pitchRange.prevPermutationIndex;
            }
            else
            {
                pitchRange.playedPermutationBits = 0;
            }
        }

        if(pitchRange.playedPermutationBits & (1 << permutationIndex))
        {
            continue;
        }

        pitchRange.playedPermutationBits |= 1 << permutationIndex;

        if(permutation.skipFraction > randomPercent())
        {
            continue;
        }

        index = permutationIndex;
        break;
    }

    pitchRange.prevPermutationIndex = cast(short)index;

    return index;
}

bool isValid() const
{
    if(pitchRanges.size <= 0 || pitchRanges[0].permutations.size <= 0)
    {
        return false;
    }

    // TODO global value that enables/disables sound classes

    return true;
}

}

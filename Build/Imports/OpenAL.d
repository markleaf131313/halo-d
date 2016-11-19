
module OpenAL;

enum : int
{
    AL_INVALID              = -1,
    AL_NONE                 = 0,

    AL_SOURCE_RELATIVE      = 0x202,

    AL_CONE_INNER_ANGLE     = 0x1001,
    AL_CONE_OUTER_ANGLE     = 0x1002,

    AL_PITCH                = 0x1003,
    AL_POSITION             = 0x1004,
    AL_DIRECTION            = 0x1005,
    AL_VELOCITY             = 0x1006,
    AL_LOOPING              = 0x1007,
    AL_BUFFER               = 0x1009,
    AL_GAIN                 = 0x100A,
    AL_MIN_GAIN             = 0x100D,
    AL_MAX_GAIN             = 0x100E,
    AL_ORIENTATION          = 0x100F,

    AL_CHANNEL_MASK         = 0x3000,

    AL_SOURCE_STATE         = 0x1010,
    AL_INITIAL              = 0x1011,
    AL_PLAYING              = 0x1012,
    AL_PAUSED               = 0x1013,
    AL_STOPPED              = 0x1014,

    AL_BUFFERS_QUEUED       = 0x1015,
    AL_BUFFERS_PROCESSED    = 0x1016,

    AL_REFERENCE_DISTANCE   = 0x1020,
    AL_ROLLOFF_FACTOR       = 0x1021,
    AL_CONE_OUTER_GAIN      = 0x1022,
    AL_MAX_DISTANCE         = 0x1023,

    AL_SEC_OFFSET           = 0x1024,
    AL_SAMPLE_OFFSET        = 0x1025,
    AL_BYTE_OFFSET          = 0x1026,

    AL_SOURCE_TYPE          = 0x1027,
    AL_STATIC               = 0x1028,
    AL_STREAMING            = 0x1029,
    AL_UNDETERMINED         = 0x1030,

    AL_FORMAT_MONO8         = 0x1100,
    AL_FORMAT_MONO16        = 0x1101,
    AL_FORMAT_STEREO8       = 0x1102,
    AL_FORMAT_STEREO16      = 0x1103,

    AL_FREQUENCY            = 0x2001,
    AL_BITS                 = 0x2002,
    AL_CHANNELS             = 0x2003,
    AL_SIZE                 = 0x2004,

    AL_UNUSED               = 0x2010,
    AL_PENDING              = 0x2011,
    AL_PROCESSED            = 0x2012,

    AL_NO_ERROR             = 0x0000,
    AL_INVALID_NAME         = 0xA001,
    AL_INVALID_ENUM         = 0xA002,
    AL_INVALID_VALUE        = 0xA003,
    AL_INVALID_OPERATION    = 0xA004,
    AL_OUT_OF_MEMORY        = 0xA005,

    AL_VENDOR               = 0xB001,
    AL_VERSION              = 0xB002,
    AL_RENDERER             = 0xB003,
    AL_EXTENSIONS           = 0xB004,

    AL_DOPPLER_FACTOR       = 0xC000,
    AL_DOPPLER_VELOCITY     = 0xC001,
    AL_SPEED_OF_SOUND       = 0xC003,

    AL_DISTANCE_MODEL               = 0xD000,
    AL_INVERSE_DISTANCE             = 0xD001,
    AL_INVERSE_DISTANCE_CLAMPED     = 0xD002,
    AL_LINEAR_DISTANCE              = 0xD003,
    AL_LINEAR_DISTANCE_CLAMPED      = 0xD004,
    AL_EXPONENT_DISTANCE            = 0xD005,
    AL_EXPONENT_DISTANCE_CLAMPED    = 0xD006,
}

struct ALCdevice  { @disable this(); }
struct ALCcontext { @disable this(); }

enum : int
{
    ALC_FREQUENCY                        = 0x1007,
    ALC_REFRESH                          = 0x1008,
    ALC_SYNC                             = 0x1009,

    ALC_MONO_SOURCES                     = 0x1010,
    ALC_STEREO_SOURCES                   = 0x1011,

    ALC_NO_ERROR                         = 0x0000,
    ALC_INVALID_DEVICE                   = 0xA001,
    ALC_INVALID_CONTEXT                  = 0xA002,
    ALC_INVALID_ENUM                     = 0xA003,
    ALC_INVALID_VALUE                    = 0xA004,
    ALC_OUT_OF_MEMORY                    = 0xA005,

    ALC_DEFAULT_DEVICE_SPECIFIER         = 0x1004,
    ALC_DEVICE_SPECIFIER                 = 0x1005,
    ALC_EXTENSIONS                       = 0x1006,

    ALC_MAJOR_VERSION                    = 0x1000,
    ALC_MINOR_VERSION                    = 0x1001,

    ALC_ATTRIBUTES_SIZE                  = 0x1002,
    ALC_ALL_ATTRIBUTES                   = 0x1003,

    ALC_CAPTURE_DEVICE_SPECIFIER         = 0x310,
    ALC_CAPTURE_DEFAULT_DEVICE_SPECIFIER = 0x311,
    ALC_CAPTURE_SAMPLES                  = 0x312,
}

enum : int
{
    AL_FORMAT_IMA_ADPCM_MONO16_EXT          = 0x10000,
    AL_FORMAT_IMA_ADPCM_STEREO16_EXT        = 0x10001,

    AL_FORMAT_WAVE_EXT                      = 0x10002,

    AL_FORMAT_VORBIS_EXT                    = 0x10003,

    AL_FORMAT_QUAD8_LOKI                    = 0x10004,
    AL_FORMAT_QUAD16_LOKI                   = 0x10005,

    AL_FORMAT_MONO_FLOAT32                  = 0x10010,
    AL_FORMAT_STEREO_FLOAT32                = 0x10011,

    ALC_CHAN_MAIN_LOKI                      = 0x500001,
    ALC_CHAN_PCM_LOKI                       = 0x500002,
    ALC_CHAN_CD_LOKI                        = 0x500003,

    ALC_DEFAULT_ALL_DEVICES_SPECIFIER       = 0x1012,
    ALC_ALL_DEVICES_SPECIFIER               = 0x1013,

    AL_FORMAT_QUAD8                         = 0x1204,
    AL_FORMAT_QUAD16                        = 0x1205,
    AL_FORMAT_QUAD32                        = 0x1206,
    AL_FORMAT_REAR8                         = 0x1207,
    AL_FORMAT_REAR16                        = 0x1208,
    AL_FORMAT_REAR32                        = 0x1209,
    AL_FORMAT_51CHN8                        = 0x120A,
    AL_FORMAT_51CHN16                       = 0x120B,
    AL_FORMAT_51CHN32                       = 0x120C,
    AL_FORMAT_61CHN8                        = 0x120D,
    AL_FORMAT_61CHN16                       = 0x120E,
    AL_FORMAT_61CHN32                       = 0x120F,
    AL_FORMAT_71CHN8                        = 0x1210,
    AL_FORMAT_71CHN16                       = 0x1211,
    AL_FORMAT_71CHN32                       = 0x1212,

    AL_FORMAT_MONO_IMA4                     = 0x1300,
    AL_FORMAT_STEREO_IMA4                   = 0x1301,
}

extern(C) @nogc nothrow
{
    void alEnable(int);
    void alDisable(int);
    bool alIsEnabled(int);

    const(char)* alGetString(int);
    void alGetBooleanv(int, bool*);
    void alGetIntegerv(int, int*);
    void alGetFloatv(int, float*);
    void alGetDoublev(int, double*);
    bool alGetBoolean(int);
    int alGetInteger(int);
    float alGetFloat(int);
    double alGetDouble(int);
    int alGetError();

    bool alIsExtensionPresent(const(char)*);
    void* alGetProcAddress(const(char)*);
    int alGetEnumValue(const(char)*);

    void alListenerf(int, float);
    void alListener3f(int, float, float, float);
    void alListenerfv(int, const(float)*);
    void alListeneri(int, int);
    void alListener3i(int, int, int, int);
    void alListeneriv(int, const(int)*);

    void alGetListenerf(int, float*);
    void alGetListener3f(int, float*, float*, float*);
    void alGetListenerfv(int, float*);
    void alGetListeneri(int, int*);
    void alGetListener3i(int, int*, int*, int*);
    void alGetListeneriv(int, int*);

    void alGenSources(int, uint*);
    void alDeleteSources(int, const(uint)*);
    bool alIsSource(uint);

    void alSourcef(uint, int, float);
    void alSource3f(uint, int, float, float, float);
    void alSourcefv(uint, int, const(float)*);
    void alSourcei(uint, int, int);
    void alSource3i(uint, int, int, int, int);
    void alSourceiv(uint, int, const(int)*);

    void alGetSourcef(uint, int, float*);
    void alGetSource3f(uint, int, float*, float*, float*);
    void alGetSourcefv(uint, int, float*);
    void alGetSourcei(uint, int, int*);
    void alGetSource3i(uint, int, int*, int*, int*);
    void alGetSourceiv(uint, int, int*);

    void alSourcePlayv(int, const(uint)*);
    void alSourceStopv(int, const(uint)*);
    void alSourceRewindv(int, const(uint)*);
    void alSourcePausev(int, const(uint)*);
    void alSourcePlay(uint);
    void alSourcePause(uint);
    void alSourceRewind(uint);
    void alSourceStop(uint);

    void alSourceQueueBuffers(uint, int, uint*);
    void alSourceUnqueueBuffers(uint, int, uint*);

    void alGenBuffers(int, uint*);
    void alDeleteBuffers(int, const(uint)*);
    bool alIsBuffer(uint);
    void alBufferData(uint, int, const(void)*, int, int);

    void alBufferf(uint, int, float);
    void alBuffer3f(uint, int, float, float, float);
    void alBufferfv(uint, int, const(float)*);
    void alBufferi(uint, int, int);
    void alBuffer3i(uint, int, int, int, int);
    void alBufferiv(uint, int, const(int)*);

    void alGetBufferf(uint, int, float*);
    void alGetBuffer3f(uint, int, float*, float*, float*);
    void alGetBufferfv(uint, int, float*);
    void alGetBufferi(uint, int, int*);
    void alGetBuffer3i(uint, int, int*, int*, int*);
    void alGetBufferiv(uint, int, int*);

    void alDopplerFactor(float);
    void alDopplerVelocity(float);
    void alSpeedOfSound(float);
    void alDistanceModel(int);

    ALCcontext* alcCreateContext(ALCdevice*, const(int)*);
    bool alcMakeContextCurrent(ALCcontext*);
    void alcProcessContext(ALCcontext*);
    void alcSuspendContext(ALCcontext*);
    void alcDestroyContext(ALCcontext*);
    ALCcontext* alcGetCurrentContext();
    ALCdevice* alcGetContextsDevice(ALCcontext*);
    ALCdevice* alcOpenDevice(const(char)*);
    bool alcCloseDevice(ALCdevice*);
    int alcGetError(ALCdevice*);
    bool alcIsExtensionPresent(ALCdevice*, const(char)*);
    void* alcGetProcAddress(ALCdevice*, const(char)*);
    int alcGetEnumValue(ALCdevice*, const(char)*);
    const(char)* alcGetString(ALCdevice*, int);
    void alcGetIntegerv(ALCdevice*, int, int, int*);
    ALCdevice* alcCaptureOpenDevice(const(char)*, uint, int, int);
    bool alcCaptureCloseDevice(ALCdevice*);
    void alcCaptureStart(ALCdevice*);
    void alcCaptureStop(ALCdevice*);
    void alcCaptureSamples(ALCdevice*, void*, int);
}
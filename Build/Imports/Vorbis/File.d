
module Vorbis.File;

import core.stdc.config : c_long;

import Vorbis.Ogg;
import Vorbis.Vorbis;

struct ov_callbacks
{
    extern(C) nothrow
    {
        size_t function(void*, size_t, size_t, void*) read_func;
        int    function(void*, ogg_int64_t, int)      seek_func;
        int    function(void*)                        close_func;
        c_long function(void*)                        tell_func;
    }
}

enum
{
    NOTOPEN   = 0,
    PARTOPEN  = 1,
    OPENED    = 2,
    STREAMSET = 3,
    INITSET   = 4,
}

struct OggVorbis_File
{
    @disable this();
    @disable this(this);

    void* datasource;
    int seekable;
    ogg_int64_t offset;
    ogg_int64_t end;
    ogg_sync_state oy = void;
    int links;
    ogg_int64_t* offsets;
    ogg_int64_t* dataoffsets;
    c_long* serialnos;
    ogg_int64_t* pcmlengths;
    vorbis_info* vi;
    vorbis_comment* vc;
    ogg_int64_t pcm_offset;
    int ready_state;
    c_long current_serialno;
    int current_link;
    double bittrack;
    double samptrack;
    ogg_stream_state os    = void;
    vorbis_dsp_state vd    = void;
    vorbis_block vb        = void;
    ov_callbacks callbacks = void;
}

extern(C) @nogc nothrow
{
    int ov_clear(OggVorbis_File*);
    int ov_fopen(const(char)*, OggVorbis_File*);
    int ov_open_callbacks(void* datasource, OggVorbis_File*, const(char)*, c_long, ov_callbacks);
    int ov_test_callbacks(void*, OggVorbis_File*, const(char)*, c_long, ov_callbacks);
    int ov_test_open(OggVorbis_File*);
    c_long ov_bitrate(OggVorbis_File*, int);
    c_long ov_bitrate_instant(OggVorbis_File*);
    c_long ov_streams(OggVorbis_File*);
    c_long ov_seekable(OggVorbis_File*);
    c_long ov_serialnumber(OggVorbis_File*, int);
    ogg_int64_t ov_raw_total(OggVorbis_File*, int);
    ogg_int64_t ov_pcm_total(OggVorbis_File*, int);
    double ov_time_total(OggVorbis_File*, int);
    int ov_raw_seek(OggVorbis_File*, ogg_int64_t);
    int ov_pcm_seek(OggVorbis_File*, ogg_int64_t);
    int ov_pcm_seek_page(OggVorbis_File*, ogg_int64_t);
    int ov_time_seek(OggVorbis_File*, double);
    int ov_time_seek_page(OggVorbis_File*, double);
    int ov_raw_seek_lap(OggVorbis_File*, ogg_int64_t);
    int ov_pcm_seek_lap(OggVorbis_File*, ogg_int64_t);
    int ov_pcm_seek_page_lap(OggVorbis_File*, ogg_int64_t);
    int ov_time_seek_lap(OggVorbis_File*, double);
    int ov_time_seek_page_lap(OggVorbis_File*, double);
    ogg_int64_t ov_raw_tell(OggVorbis_File*);
    ogg_int64_t ov_pcm_tell(OggVorbis_File*);
    double ov_time_tell(OggVorbis_File*);
    vorbis_info* ov_info(OggVorbis_File*, int);
    vorbis_comment* ov_comment(OggVorbis_File*, int);
    c_long ov_read_float(OggVorbis_File*, float***, int, int*);
    c_long ov_read_filter(OggVorbis_File*, char*, int, int, int, int, int*);
    c_long ov_read(OggVorbis_File*, byte*, int, int, int, int, int*);
    int ov_crosslap(OggVorbis_File*, OggVorbis_File*);
    int ov_halfrate(OggVorbis_File*, int);
    int ov_halfrate_p(OggVorbis_File*);
}

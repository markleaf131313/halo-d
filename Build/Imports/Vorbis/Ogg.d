
module Vorbis.Ogg;

import core.stdc.config : c_long;

alias ogg_int64_t  = long;
alias ogg_uint64_t = ulong;
alias ogg_int32_t  = int;
alias ogg_uint32_t = uint;
alias ogg_int16_t  = short;
alias ogg_uint16_t = ushort;

struct ogg_iovec_t
{
    void* iov_base;
    size_t iov_len;
}

struct oggpack_buffer
{
    c_long endbyte;
    int endbit;
    ubyte* buffer;
    ubyte* ptr;
    c_long storage;
}

struct ogg_page
{
    ubyte* header;
    c_long header_len;
    ubyte* body_;
    c_long body_len;
}

struct ogg_stream_state
{
    ubyte* body_data;
    c_long body_storage;
    c_long body_fill;
    c_long body_returned;
    int* lacing_vals;
    ogg_int64_t* granule_vals;
    c_long lacing_storage;
    c_long lacing_fill;
    c_long lacing_packet;
    c_long lacing_returned;
    ubyte[282] header;
    int header_fill;
    int e_o_s;
    int b_o_s;
    c_long serialno;
    c_long pageno;
    ogg_int64_t packetno;
    ogg_int64_t granulepos;
}

struct ogg_packet
{
    ubyte* packet;
    c_long bytes;
    c_long b_o_s;
    c_long e_o_s;
    ogg_int64_t granulepos;
    ogg_int64_t packetno;
}

struct ogg_sync_state
{
    ubyte* data;
    int storage;
    int fill;
    int returned;

    int unsynced;
    int headerbytes;
    int bodybytes;
}

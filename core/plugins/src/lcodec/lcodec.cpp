
#include "lcodec.h"

namespace lcodec {

    thread_local ketama thread_ketama;
    thread_local serializer thread_seri;
    static slice* encode_slice(lua_State* L) {
        return thread_seri.encode_slice(L);
    }
    static int decode_slice(lua_State* L, slice* buf) {
        return thread_seri.decode_slice(L, buf);
    }
    static int serialize(lua_State* L) {
        return thread_seri.serialize(L);
    }
    static int unserialize(lua_State* L) {
        return thread_seri.unserialize(L);
    }
    static int encode(lua_State* L) {
        return thread_seri.encode(L);
    }
    static int decode(lua_State* L, const char* buf, size_t len) {
        return thread_seri.decode(L, buf, len);
    }
    static bool ketama_insert(std::string name, uint32_t node_id) {
        return thread_ketama.insert(name, node_id, 255);
    }
    static void ketama_remove(uint32_t node_id) {
        thread_ketama.remove(node_id);
    }
    static uint32_t ketama_next(uint32_t node_id) {
        return thread_ketama.next(node_id);
    }
    static std::map<uint32_t, uint32_t> ketama_map() {
        return thread_ketama.virtual_map;
    }

    luakit::lua_table open_lcodec(lua_State* L) {
        luakit::kit_state kit_state(L);
        auto llcodec = kit_state.new_table();
        llcodec.set_function("encode", encode);
        llcodec.set_function("decode", decode);
        llcodec.set_function("serialize", serialize);
        llcodec.set_function("unserialize", unserialize);
        llcodec.set_function("encode_slice", encode_slice);
        llcodec.set_function("decode_slice", decode_slice);
        llcodec.set_function("guid_new", guid_new);
        llcodec.set_function("guid_string", guid_string);
        llcodec.set_function("guid_tostring", guid_tostring);
        llcodec.set_function("guid_number", guid_number);
        llcodec.set_function("guid_encode", guid_encode);
        llcodec.set_function("guid_decode", guid_decode);
        llcodec.set_function("guid_source", guid_source);
        llcodec.set_function("guid_group", guid_group);
        llcodec.set_function("guid_index", guid_index);
        llcodec.set_function("guid_time", guid_time);
        llcodec.set_function("hash_code", hash_code);
        llcodec.set_function("jumphash", jumphash_l);
        llcodec.set_function("fnv_1_32", fnv_1_32_l);
        llcodec.set_function("fnv_1a_32", fnv_1a_32_l);
        llcodec.set_function("murmur3_32", murmur3_32_l);
        llcodec.set_function("ketama_insert", ketama_insert);
        llcodec.set_function("ketama_remove", ketama_remove);
        llcodec.set_function("ketama_next", ketama_next);
        llcodec.set_function("ketama_map", ketama_map);
        kit_state.new_class<slice>(
            "size", &slice::size,
            "read", &slice::read,
            "peek", &slice::check,
            "string", &slice::string,
            "contents", &slice::contents
            );
        return llcodec;
    }
}

extern "C" {
    LUALIB_API int luaopen_lcodec(lua_State* L) {
        auto lcodec = lcodec::open_lcodec(L);
        return lcodec.push_stack();
    }
}

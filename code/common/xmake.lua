add_requires("hopscotch-map", "snappy", "catch2 2.13.9", "libuv", "openssl", "spdlog")
-- gamenetworkingsockets handled separately as local build
add_requireconfs("*.protobuf*", { build = true })
add_requireconfs("mimalloc", {configs = {rltgenrandom = true}})
add_requireconfs("gamenetworkingsockets", {configs = {languages = "c++17"}})

if is_plat("windows") then
    add_requires("minhook", "mem", "xbyak")
end

target("Common")
    set_kind("static")
    add_files("**.cpp")
    remove_files("Tests/**")
    set_group("Libraries")
    add_headerfiles("**.h", "**.hpp", "**.inl")

    -- Depend on local GameNetworkingSockets
    add_deps("GameNetworkingSockets")

    set_pcxxheader("CommonPCH.h")
    add_includedirs(".", {public = true})
    add_includedirs(
        "../../build", 
        "../../vendor"
    )

    add_packages("hopscotch-map", "snappy", "libuv")

    -- Add local GameNetworkingSockets
    add_includedirs("../../vendor/GameNetworkingSockets/include", {public = true})
    add_includedirs("../../vendor/GameNetworkingSockets/src/public", {public = true})
    add_defines("STEAMNETWORKINGSOCKETS_STATIC_LINK")
    if is_plat("windows") then
        add_packages("minhook", "mem", "xbyak")
    else
        remove_files("Reverse/**")
    end

    add_cxflags("-fPIC")
    add_defines("STEAMNETWORKINGSOCKETS_STATIC_LINK")

    add_packages(
        "spdlog",
        "glm",
        "hopscotch-map",
        "mimalloc",
        "snappy",
        "openssl",
        "libuv",
        "protobuf-cpp")

    -- Link GameNetworkingSockets when ready
    on_load(function(target)
        local gns_lib = path.join("../../vendor/GameNetworkingSockets/build/.xmake/windows/x64/release/GameNetworkingSockets.lib")
        if os.exists(gns_lib) then
            target:add("links", gns_lib)
        end
        if is_plat("windows") then
            target:add("syslinks", "ws2_32", "winmm", "crypt32", "bcrypt")
        end
    end)

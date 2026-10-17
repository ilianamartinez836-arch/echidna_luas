-- @author: Natsumi
-- @created: 11.06 19:48
-- Echidna Script
-- INJECT OTHER HACKS FIRST, THEN INJECT ECHIDNA

--Fix For storm:
echidna_hooks.disable("ClientMode_CreateMove")
--storm: disables aim, AA, pred and more things like bhop
-- no crashes and/or stuck in ground bs
-- you can re-hook createmove if you want but you need to use minhook.
-- or you can just use: echidna_features.disable("Feature_EnginePrediction")
-- to fix the stuck to the ground problem

--Fix for Nostalgia solutions
echidna_hooks.disable("BasePlayer_CalcPlayerView")
echidna_hooks.disable("ClientMode_CreateMove")
echidna_hooks.disable("CL_Move")
--Nostalgia: Disables aim, speed and visual recoil stuff to give priority to nostalgia's one
-- not recommended to be combined.

--Fix for VR:
-- nothing really to change, you can use the ones above if you crash with VR

--Fix for heaven hook
-- you might aswell disable ALL, to do so, here is the command commented:
-- for _, name in ipairs(echidna_hooks.list()) do echidna_hooks.disable(name) end
-- you can use echidna_hooks.disable("Hook bullshit0")
-- to restore an specific hook, here is how to list all if they are removed, disabled or enabled:
-- for _, name in ipairs(echidna_hooks.list()) do print(name, echidna_hooks.state(name)) end
-- if your game crashes even after, just set mat_queue_mode 0 THIS will fix it, aka just disable multicore rendering

--Fix for hacks that almost no one uses now:
-- Big packets (no changes, compatible)
-- Celestial (you are fucked.)
-- Pol: echidna_hooks.disable("PerformTrace") NOT RECOMMENDED, disable all if you find problems and test.
-- UwUhax (no changes, compatible)
-- Voidk/L4d2bot by space (no changes, but may be problematic)
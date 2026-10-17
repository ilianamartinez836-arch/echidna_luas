local KEY_N = 78
local IN_ATTACK = 1

-- ===== DEBUG =====
local DEBUG = false
local function dbg(...)
    if DEBUG then print("[ceiling]", ...) end
end

-- Alternator state for rising-edge injection
local _attack_state = false

function on_create_move(cmd, local_player)
    -- Safety gates
    if not EngineClient or not EngineClient.IsConnected or not EngineClient.IsInGame then return end
    if not EngineClient.IsConnected() or not EngineClient.IsInGame() then return end
    if not cmd then return end

    -- Key state (hold-to-activate, no edge detection)
    local is_pressed = false
    if imgui and imgui.IsKeyDown then
        is_pressed = imgui.IsKeyDown(KEY_N)
    elseif Input and Input.KeyState then
        local state = Input.KeyState(KEY_N)
        is_pressed = (state == true or state == 1 or (type(state) == "number" and state ~= 0))
    end

    if not is_pressed then return end

    -- ===== 1. Snapshot and apply ceiling pitch =====
    local ang_ok, ang = pcall(function() return cmd:get_viewangles() end)
    if ang_ok and ang then
        local yaw = nil
        if type(ang) == "table" then
            yaw = ang.y or ang[2] or ang.yaw
        end

        local new_ang = { x = 11.55, y = yaw or 0, z = 0 }
        local set_ok = pcall(function() cmd:set_viewangles(new_ang) end)
        if not set_ok then
            pcall(function() cmd:set_viewangles(11.55, yaw or 0, 0) end)
        end
    end

    -- ===== 2. EngineClient visual camera =====
    local vang = EngineClient.GetViewAngles()
    if vang then
        if vang.x ~= nil then vang.x = 11.55 end
        if vang.pitch ~= nil then vang.pitch = 11.55 end
        if vang[1] ~= nil then vang[1] = 11.55 end

        if vang.z ~= nil then vang.z = 0 end
        if vang.roll ~= nil then vang.roll = 0 end
        if vang[3] ~= nil then vang[3] = 0 end

        EngineClient.SetViewAngles(vang)
    end

    -- ===== 3. Autoclicker: alternate the button bit every tick =====
    -- This produces a rising edge on every other tick, which is what the
    -- pounce system accepts. Holding the bit steady would only fire once.
    if _attack_state then
        pcall(function() cmd:add_button(IN_ATTACK) end)
    else
        pcall(function() cmd:remove_button(IN_ATTACK) end)
    end
    _attack_state = not _attack_state
end
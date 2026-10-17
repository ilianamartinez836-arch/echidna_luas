local VK_NUMPAD0    = 0x60
local WRITE_AMOUNT  = 20000

local active    = false
local key_held  = false

function on_key_down(key)
    if key == VK_NUMPAD0 and not key_held then
        key_held = true
        active = not active
        print("[seq] " .. (active and "ON" or "OFF"))
    end
end

function on_key_up(key)
    if key == VK_NUMPAD0 then
        key_held = false
    end
end

function on_create_move()
    if not active then return end

    local nc = EngineClient.GetNetChannelInfo()
    if not nc or nc:IsNull() then return end

    local current = nc:m_nOutSequenceNr()
    if not current then return end

    nc:SetOutSequenceNr(current + WRITE_AMOUNT)
end
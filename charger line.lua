local NAME = "chargerline"
local CFG_FILE = "echidna_chargerline.cfg"
local CFG = {
    enabled = true, len = 900, width = 20, edges = true, warn = true,
    thick = 2, col01 = false, font = 0, fov_override = 0,
}
local sqrt, abs, max, floor = math.sqrt, math.abs, math.max, math.floor
local rad = math.rad

local PL        = "CTerrorPlayer"
local GROUP_SV  = GROUP_PLAYER_SURVIVOR or 1

local function log(s) pcall(client.print, "[" .. NAME .. "] " .. tostring(s)) end
local function V(x, y, z) return { x = x, y = y, z = z } end
local function clamp(v, lo, hi) if v < lo then return lo elseif v > hi then return hi end return v end
local maxc_cache = 32
local function handle_index(h)
    if type(h) ~= "number" or h < 0 then return nil end
    local i = h % 2048
    if i < 1 or i >= 2047 then return nil end
    return i
end
local function player_handle(h)
    local i = handle_index(h)
    if i and i <= maxc_cache then return i end
    return nil
end

local function all_infected()
    local out, have = {}, {}
    local function add(list, need_team)
        if type(list) ~= "table" then return end
        for _, p in ipairs(list) do
            local ok, idx = pcall(function() return p:entindex() end)
            if ok and idx and not have[idx] then
                local keep = true
                if need_team then
                    local okt, tm = pcall(function() return p:get_team() end)
                    keep = okt and tm == 3
                end
                if keep then have[idx] = true; out[#out + 1] = p end
            end
        end
    end
    pcall(function() add(EntityCache.GetGroup(GROUP_SPECIAL_INFECTED or 4), false) end)
    pcall(function() add(EntityCache.GetGroup(GROUP_PLAYER_INFECTED or 2), true) end)
    pcall(function() add(EntityCache.GetGroup(GROUP_PLAYER_ALL or 0), true) end)
    return out
end

local function save_cfg()
    pcall(function()
        local f = io.open(CFG_FILE, "w")
        for k, v in pairs(CFG) do f:write(k, "=", tostring(v), "\n") end
        f:close()
    end)
end
pcall(function()
    local f = io.open(CFG_FILE, "r")
    if not f then return end
    for line in f:lines() do
        local k, v = line:match("^([%w_]+)=(.+)$")
        if k and CFG[k] ~= nil then
            if v == "true" then CFG[k] = true elseif v == "false" then CFG[k] = false
            else CFG[k] = tonumber(v) or CFG[k] end
        end
    end
    f:close()
end)

local function btn(label) local ok, r = pcall(imgui.Button, label); return ok and r == true end
local function text(s) pcall(imgui.Text, s) end
local clock = (os and os.clock) or function() return GlobalVars.curtime() end
local W = { value_first = nil, broken = false, last_flip = {} }
local function detect_convention()
    if W.value_first ~= nil or W.broken then return end
    for _, fn in ipairs({ imgui.SliderInt, imgui.SliderFloat }) do
        local ok, r1, r2 = pcall(fn, "##det_" .. NAME, 0, 0, 1)
        if ok and type(r1) == "number" then W.value_first = true; return end
        if ok and type(r2) == "number" then W.value_first = false; return end
    end
    W.broken = true
end
local function toggle(key, label)
    local cur = CFG[key] and true or false
    if W.broken or W.value_first == nil then
        if btn((cur and "[ON]  " or "[off] ") .. label .. "##" .. key) then return not cur end
        return cur
    end
    local ok, r1, r2 = pcall(imgui.Checkbox, label .. "##" .. key, cur)
    if not ok then W.broken = true; return cur end
    local new
    if r2 == nil then
        if W.value_first then new = r1 else new = (r1 == true) and not cur or cur end
    elseif W.value_first then new = r1 else new = r2 end
    if type(new) ~= "boolean" then W.broken = true; return cur end
    if new ~= cur then
        local f = clock()
        if W.last_flip[key] and f - W.last_flip[key] < 0.05 then W.broken = true; return cur end
        W.last_flip[key] = f
    end
    return new
end
local function slider(label, cur)
    if W.broken or W.value_first == nil then return cur end
    for _, fn in ipairs({ imgui.SliderInt, imgui.SliderFloat }) do
        local ok, r1, r2 = pcall(fn, label, cur, 0, 100)
        if ok and type(r1) == "number" then return r1 end
        if ok and type(r2) == "number" then return r2 end
    end
    return cur
end
local function set(key, val) if CFG[key] ~= val then CFG[key] = val; save_cfg() end end
local function header(s) pcall(imgui.Spacing); text(s); pcall(imgui.Separator) end
local function box(key, label) set(key, toggle(key, label)) end
local function ranged(key, label, lo, hi, unit)
    local pct = floor((CFG[key] - lo) / (hi - lo) * 100 + 0.5)
    local np = slider(string.format("%s  %d%s##%s", label, CFG[key], unit or "", key), pct)
    if type(np) == "number" and abs(np - pct) >= 1 then set(key, floor(lo + clamp(np, 0, 100) / 100 * (hi - lo) + 0.5)) end
end

local function register_menu(title, draw_ui, win_id, prev_paint)
    local tab_ok = false
    pcall(function()
        local args = { title }
        local unpack_ = unpack or table.unpack
        for _ = 1, 6 do
            local ok, err = pcall(menu.add_main_tab, unpack_(args))
            if ok then tab_ok = true; return end
            local n, want = tostring(err):match("bad argument #(%d+) to '[^']*' %((%a+) expected")
            n = tonumber(n)
            if not n or n ~= #args + 1 then return end
            if want == "string" then args[n] = title
            elseif want == "function" then args[n] = draw_ui
            elseif want == "number" then args[n] = 0
            elseif want == "boolean" then args[n] = true
            else return end
        end
    end)
    if not tab_ok then
        local prev = on_paint
        function on_paint()
            if prev then pcall(prev) end
            local open = false
            pcall(function() open = menu.is_open() end)
            if not open then return end
            if pcall(imgui.Begin, title .. "##" .. win_id) then pcall(draw_ui) end
            pcall(imgui.End)
        end
    end
    return tab_ok
end

local ZC_CHARGER = 6

local view = { have = false, t = -99, ox = 0, oy = 0, oz = 0, ax = 0, ay = 0, az = 0, fov = 90 }
local prev_ov = on_override_view
function on_override_view(ox, oy, oz, ax, ay, az, fov)
    if prev_ov then pcall(prev_ov, ox, oy, oz, ax, ay, az, fov) end
    if type(ox) == "number" and type(ax) == "number" then
        view.have, view.t = true, clock()
        view.ox, view.oy, view.oz, view.ax, view.ay, view.az = ox, oy, oz, ax, ay, az
        if type(fov) == "number" and fov > 1 and fov < 179 then view.fov = fov end
    end
end

local frame = nil
local function build_frame(lp)
    local sw, sh
    pcall(function() sw, sh = Draw.GetScreenSize() end)
    if type(sw) ~= "number" or sw <= 0 then pcall(function() sw, sh = EngineClient.GetScreenSize() end) end
    if type(sw) ~= "number" or sw <= 0 then return nil end
    local f = { sw = sw, sh = sh }
    local src = "on_override_view"
    if view.have and clock() - view.t < 1.0 then
        f.ox, f.oy, f.oz, f.ax, f.ay = view.ox, view.oy, view.oz, view.ax, view.ay
        f.fov = view.fov
    else
        local e, a
        pcall(function() e, a = lp:EyePosition(), lp:get_eye_angles() end)
        if not e or not a then return nil end
        f.ox, f.oy, f.oz, f.ax, f.ay, f.fov = e.x, e.y, e.z, a.x, a.y, 90
        src = "player eye (fallback - on_override_view not firing)"
    end
    if CFG.fov_override > 0 then f.fov = CFG.fov_override end
    local aspect = f.sw / f.sh
    local hfov = 2 * math.atan(math.tan(rad(f.fov) / 2) * (aspect / (4 / 3)))
    f.scale = (f.sw / 2) / math.tan(hfov / 2)
    local p, y = rad(f.ax), rad(f.ay)
    local cp, sp, cy, sy = math.cos(p), math.sin(p), math.cos(y), math.sin(y)
    f.fx, f.fy, f.fz = cp * cy, cp * sy, -sp
    f.rx, f.ry, f.rz = sy, -cy, 0
    f.ux, f.uy, f.uz = sp * cy, sp * sy, cp
    view.src = src
    return f
end

local function project(f, x, y, z)
    local dx, dy, dz = x - f.ox, y - f.oy, z - f.oz
    local fwd = dx * f.fx + dy * f.fy + dz * f.fz
    if fwd < 1 then return nil end
    return f.sw / 2 + (dx * f.rx + dy * f.ry + dz * f.rz) / fwd * f.scale,
           f.sh / 2 - (dx * f.ux + dy * f.uy + dz * f.uz) / fwd * f.scale
end

local draw_err = nil
local function c(v) if CFG.col01 then return v end return floor(v * 255 + 0.5) end
local function line(x1, y1, x2, y2, r, g, b, a)
    local ok, err = pcall(function()
        if CFG.thick > 1 and Draw.LineThick then
            Draw.LineThick(x1, y1, x2, y2, c(r), c(g), c(b), c(a), CFG.thick)
        else
            Draw.Line(x1, y1, x2, y2, c(r), c(g), c(b), c(a))
        end
    end)
    if not ok then draw_err = tostring(err) end
end
local function world_line(f, x1, y1, z, x2, y2, r, g, b, a)
    local len = sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
    local n = max(1, math.ceil(len / 40))
    local px, py = project(f, x1, y1, z)
    for i = 1, n do
        local t = i / n
        local qx, qy = project(f, x1 + (x2 - x1) * t, y1 + (y2 - y1) * t, z)
        if px and qx then line(px, py, qx, qy, r, g, b, a) end
        px, py = qx, qy
    end
end
local function put_text(f, y, r, g, b, s)
    local ok, err = pcall(function()
        local w = #s * 7
        pcall(function() local tw = Draw.GetTextWidth(CFG.font, s); if type(tw) == "number" and tw > 0 then w = tw end end)
        Draw.String(CFG.font, floor((f.sw - w) / 2), floor(y), c(r), c(g), c(b), c(1), 0, s)
    end)
    if not ok then draw_err = tostring(err) end
end

local vprev, vel_broken, vel_checks = {}, false, 0
local function velocity(ent, idx, now, o)
    local v
    pcall(function() v = ent:get_velocity() end)
    if not (type(v) == "table" or type(v) == "userdata") or type(v.x) ~= "number" then v = nil end
    local pv, d = vprev[idx], nil
    if pv and now > pv.t and now - pv.t < 0.2 then
        d = V((o.x - pv.x) / (now - pv.t), (o.y - pv.y) / (now - pv.t), 0)
    end
    vprev[idx] = { x = o.x, y = o.y, t = now }
    if v and d and sqrt(v.x * v.x + v.y * v.y) < 1 and sqrt(d.x * d.x + d.y * d.y) > 120 then
        vel_checks = vel_checks + 1
        if vel_checks >= 8 then vel_broken = true end
    end
    if v and not vel_broken then return v end
    return d or v
end

local info = { found = 0, in_lane = false }

local function prop_player(ent, name)
    local h
    pcall(function() h = ent:get_prop_int(PL, name) end)
    return player_handle(h)
end

local function survivors(lp)
    local out, have = {}, {}
    local function add(p)
        local idx
        pcall(function() idx = p:entindex() end)
        if not idx or have[idx] then return end
        have[idx] = true
        local ok, o, alive, down = pcall(function() return p:get_origin(), p:is_alive(), p:is_incapacitated() end)
        if not ok or not o or not alive then return end
        out[#out + 1] = { idx = idx, o = o, down = down == true,
                          pummel_by = prop_player(p, "m_pummelAttacker"), carry_by = prop_player(p, "m_carryAttacker") }
    end
    pcall(function() for _, p in ipairs(EntityCache.GetGroup(GROUP_SV)) do add(p) end end)
    add(lp)
    return out
end

local function on_paint_cl()
    info.found, info.in_lane = 0, false
    if not CFG.enabled then return end
    local in_game = false
    pcall(function() in_game = EngineClient.IsInGame() end)
    if not in_game then return end
    local lp
    pcall(function() lp = EntityCache.GetLocal() end)
    if not lp then return end
    local alive = false
    pcall(function() alive = lp:is_alive() end)
    if not alive then return end
    local f = build_frame(lp)
    if not f then return end
    local me
    pcall(function() me = lp:get_origin() end)
    if not me then return end
    local now = clock()

    local danger_any, danger_who = false, nil
    local survs = survivors(lp)
    for _, e in ipairs(all_infected()) do
        local d
        pcall(function()
            if not (e:is_alive() and not e:is_ghost() and not e:is_dormant() and e:get_zombie_class() == ZC_CHARGER) then return end
            local o = e:get_origin()
            if not o then return end
            local v = velocity(e, e:entindex(), now, o)
            local dx, dy, charging = nil, nil, false
            if v and v.x then
                local sp = sqrt(v.x * v.x + v.y * v.y)
                if sp >= 250 then dx, dy, charging = v.x / sp, v.y / sp, true end
            end
            if not dx then
                local ang = e:get_eye_angles()
                if ang and type(ang.y) == "number" then
                    local yaw = rad(ang.y)
                    dx, dy = math.cos(yaw), math.sin(yaw)
                end
            end
            if not dx then return end
            local ci = e:entindex()
            d = { o = o, dx = dx, dy = dy, charging = charging, idx = ci,
                  pummel = prop_player(e, "m_pummelVictim"), carry = prop_player(e, "m_carryVictim") }
        end)
        if d then
            for _, s in ipairs(survs) do
                if s.pummel_by == d.idx then d.pummel = d.pummel or s.idx end
                if s.carry_by == d.idx then d.carry = d.carry or s.idx end
            end
        end
        if d and d.pummel then
            info.found = info.found + 1
            d = nil
        end
        if d then
            info.found = info.found + 1
            local o = d.o
            local rx, ry = me.x - o.x, me.y - o.y
            local along = rx * d.dx + ry * d.dy
            local lat = abs(rx * d.dy - ry * d.dx)
            local danger = along > -20 and along < CFG.len and lat < (CFG.width + 18)
            if danger then danger_any = true; danger_who = d.charging and "CHARGING" or "aiming" end
            local r, g, b = 0.2, 1.0, 0.3
            if danger then r, g, b = 1.0, 0.15, 0.15 end
            local a = d.charging and 1.0 or 0.6
            local z = o.z + 8
            local len, stop = CFG.len, false
            for _, s in ipairs(survs) do
                if s.idx ~= d.carry and not s.down then
                    local sx, sy = s.o.x - o.x, s.o.y - o.y
                    local al = sx * d.dx + sy * d.dy
                    local la = abs(sx * d.dy - sy * d.dx)
                    if al > 20 and al < len and la < (CFG.width + 18) then len, stop = al, true end
                end
            end
            local ex, ey = o.x + d.dx * len, o.y + d.dy * len
            local nx, ny = -d.dy * CFG.width, d.dx * CFG.width
            world_line(f, o.x, o.y, z, ex, ey, r, g, b, a)
            if CFG.edges then
                world_line(f, o.x + nx, o.y + ny, z, ex + nx, ey + ny, r, g, b, a * 0.6)
                world_line(f, o.x - nx, o.y - ny, z, ex - nx, ey - ny, r, g, b, a * 0.6)
            end
            if stop then world_line(f, ex + nx, ey + ny, z, ex - nx, ey - ny, r, g, b, a) end
        end
    end
    info.in_lane = danger_any
    if danger_any and CFG.warn then
        put_text(f, f.sh * 0.30, 1.0, 0.2, 0.2, "CHARGER " .. (danger_who or "") .. " - MOVE SIDEWAYS")
    end
end

local INSTANCE = {}
_G.echidna_chargerline_instance = INSTANCE
local prev_paint = on_paint
function on_paint()
    if prev_paint then pcall(prev_paint) end
    if _G.echidna_chargerline_instance ~= INSTANCE then return end
    pcall(on_paint_cl)
end

local function draw_ui()
    detect_convention()
    header("Charger Line")
    box("enabled", "Show charger line")
    ranged("len", "Line length", 200, 2500, " u")
    ranged("width", "Lane half-width", 8, 60, " u")
    ranged("thick", "Line thickness", 1, 6, " px")
    box("edges", "Draw lane edges")
    box("warn", "Warning text when you are in the lane")
    header("If it looks wrong")
    box("col01", "Colors are 0-1 (default is 0-255: lines look white/odd -> try this)")
    ranged("font", "Font id (no warning text -> try other values)", 0, 20, "")
    ranged("fov_override", "FOV correction (0 = use the game's)", 0, 120, "")
    header("Status")
    text(string.format("chargers seen: %d   you in lane: %s", info.found, tostring(info.in_lane)))
    text("view source: " .. tostring(view.src or "-"))
    text("velocity: " .. (vel_broken and "origin delta (game value reads 0)" or "game value"))
    if draw_err then text("draw error: " .. draw_err) end
end

register_menu("Charger Line", draw_ui, "echidna_chargerline")
log("loaded - settings in the Charger Line menu tab")

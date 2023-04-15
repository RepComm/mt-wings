--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
-- Lua Library inline imports
local function __TS__New(target, ...)
    local instance = setmetatable({}, target.prototype)
    instance:____constructor(...)
    return instance
end

local function __TS__Class(self)
    local c = {prototype = {}}
    c.prototype.__index = c.prototype
    c.prototype.constructor = c
    return c
end

local __TS__Symbol, Symbol
do
    local symbolMetatable = {__tostring = function(self)
        return ("Symbol(" .. (self.description or "")) .. ")"
    end}
    function __TS__Symbol(description)
        return setmetatable({description = description}, symbolMetatable)
    end
    Symbol = {
        iterator = __TS__Symbol("Symbol.iterator"),
        hasInstance = __TS__Symbol("Symbol.hasInstance"),
        species = __TS__Symbol("Symbol.species"),
        toStringTag = __TS__Symbol("Symbol.toStringTag")
    }
end

local __TS__Iterator
do
    local function iteratorGeneratorStep(self)
        local co = self.____coroutine
        local status, value = coroutine.resume(co)
        if not status then
            error(value, 0)
        end
        if coroutine.status(co) == "dead" then
            return
        end
        return true, value
    end
    local function iteratorIteratorStep(self)
        local result = self:next()
        if result.done then
            return
        end
        return true, result.value
    end
    local function iteratorStringStep(self, index)
        index = index + 1
        if index > #self then
            return
        end
        return index, string.sub(self, index, index)
    end
    function __TS__Iterator(iterable)
        if type(iterable) == "string" then
            return iteratorStringStep, iterable, 0
        elseif iterable.____coroutine ~= nil then
            return iteratorGeneratorStep, iterable
        elseif iterable[Symbol.iterator] then
            local iterator = iterable[Symbol.iterator](iterable)
            return iteratorIteratorStep, iterator
        else
            return ipairs(iterable)
        end
    end
end

local Set
do
    Set = __TS__Class()
    Set.name = "Set"
    function Set.prototype.____constructor(self, values)
        self[Symbol.toStringTag] = "Set"
        self.size = 0
        self.nextKey = {}
        self.previousKey = {}
        if values == nil then
            return
        end
        local iterable = values
        if iterable[Symbol.iterator] then
            local iterator = iterable[Symbol.iterator](iterable)
            while true do
                local result = iterator:next()
                if result.done then
                    break
                end
                self:add(result.value)
            end
        else
            local array = values
            for ____, value in ipairs(array) do
                self:add(value)
            end
        end
    end
    function Set.prototype.add(self, value)
        local isNewValue = not self:has(value)
        if isNewValue then
            self.size = self.size + 1
        end
        if self.firstKey == nil then
            self.firstKey = value
            self.lastKey = value
        elseif isNewValue then
            self.nextKey[self.lastKey] = value
            self.previousKey[value] = self.lastKey
            self.lastKey = value
        end
        return self
    end
    function Set.prototype.clear(self)
        self.nextKey = {}
        self.previousKey = {}
        self.firstKey = nil
        self.lastKey = nil
        self.size = 0
    end
    function Set.prototype.delete(self, value)
        local contains = self:has(value)
        if contains then
            self.size = self.size - 1
            local next = self.nextKey[value]
            local previous = self.previousKey[value]
            if next ~= nil and previous ~= nil then
                self.nextKey[previous] = next
                self.previousKey[next] = previous
            elseif next ~= nil then
                self.firstKey = next
                self.previousKey[next] = nil
            elseif previous ~= nil then
                self.lastKey = previous
                self.nextKey[previous] = nil
            else
                self.firstKey = nil
                self.lastKey = nil
            end
            self.nextKey[value] = nil
            self.previousKey[value] = nil
        end
        return contains
    end
    function Set.prototype.forEach(self, callback)
        for ____, key in __TS__Iterator(self:keys()) do
            callback(nil, key, key, self)
        end
    end
    function Set.prototype.has(self, value)
        return self.nextKey[value] ~= nil or self.lastKey == value
    end
    Set.prototype[Symbol.iterator] = function(self)
        return self:values()
    end
    function Set.prototype.entries(self)
        local nextKey = self.nextKey
        local key = self.firstKey
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                local result = {done = not key, value = {key, key}}
                key = nextKey[key]
                return result
            end
        }
    end
    function Set.prototype.keys(self)
        local nextKey = self.nextKey
        local key = self.firstKey
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                local result = {done = not key, value = key}
                key = nextKey[key]
                return result
            end
        }
    end
    function Set.prototype.values(self)
        local nextKey = self.nextKey
        local key = self.firstKey
        return {
            [Symbol.iterator] = function(self)
                return self
            end,
            next = function(self)
                local result = {done = not key, value = key}
                key = nextKey[key]
                return result
            end
        }
    end
    Set[Symbol.species] = Set
end
-- End of Lua Library inline imports
local ____exports = {}
local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath .. "/vec.lua")
dofile(modpath .. "/evt.lua")
local function lerp(self, from, to, by)
    return from * (1 - by) + to * by
end
local function lerpClamped(self, from, to, by)
    local result = from * (1 - by) + to * by
    if result < from then
        result = from
    end
    if result > to then
        result = to
    end
    return result
end
local wingsEntityName = modname .. ":wings_entity"
local function entityOnGround(self, en, ySearchDown)
    if ySearchDown == nil then
        ySearchDown = 1.5
    end
    local from = en:get_pos()
    local to = {x = from.x, y = from.y - ySearchDown, z = from.z}
    local hits = minetest.raycast(from, to)
    local hit
    for hit in hits do
        if hit.type == "node" then
            return true
        end
    end
    return false
end
local RAD2DEG = 57.29578
local v3zero = {x = 0, y = 0, z = 0}
local wingPos = {x = 0, y = -2.7809, z = 5.10305}
local wings
wings = {
    events = __TS__New(EventDispatcher),
    all = __TS__New(Set),
    getPlayerWingEntity = function(playername)
        for ____, wing in __TS__Iterator(wings.all) do
            if wing._playername == playername then
                return wing
            end
        end
        return nil
    end,
    isWingUsed = function(wing)
        return wing._playername ~= nil
    end,
    clearWing = function(wing)
        wing.object:remove()
        wings.all:delete(wing)
    end,
    clearUnused = function()
        for ____, wing in __TS__Iterator(wings.all) do
            if not wings.isWingUsed(wing) then
                wing.object:remove()
                wings.all:delete(wing)
            end
        end
    end,
    clearAll = function()
        for id in pairs(minetest.luaentities) do
            local luaen = minetest.luaentities[id]
            if luaen.name == wingsEntityName then
                luaen.object:remove()
                wings.all:delete(luaen)
            end
        end
    end,
    getOrCreate = function(player)
        local playername = player:get_player_name()
        local result = wings.getPlayerWingEntity(playername)
        if result == nil then
            local pos = player:get_pos()
            local en = minetest.add_entity(pos, wingsEntityName)
            result = en:get_luaentity()
            result._playername = playername
            wings.all:add(result)
            result:_updateAttachment(player)
        end
        return result
    end,
    clearPlayerWingEntity = function(playername)
        local wing = wings.getPlayerWingEntity(playername)
        if wing == nil then
            return
        end
        wings.clearWing(wing)
    end
}
wings.events:listen(
    "glidechange",
    function(____, evt)
        minetest.chat_send_player(
            evt.player:get_player_name(),
            ("You " .. (evt.isGliding and "started" or "stopped")) .. " gliding"
        )
    end
)
local function wings_onstep(self, dtime)
    local player
    if self._playername == nil then
        self:_setGliding(false)
        return
    end
    player = minetest.get_player_by_name(self._playername)
    if player == nil then
        self:_setGliding(false)
        return
    end
    local ____temp_0 = player:get_player_control()
    local jump = ____temp_0.jump
    local sneak = ____temp_0.sneak
    local t = minetest.get_gametime()
    if self._isGliding then
        if sneak then
            self:_setGliding(false)
        end
    else
        if jump and t - self._timeLastJump > 1 then
            minetest.after(
                0.2,
                function()
                    self._timeLastJump = t
                    if not entityOnGround(nil, player, 2) then
                        self:_setGliding(true)
                    end
                end
            )
        end
    end
    if self._isGliding then
        self._yaw = player:get_look_horizontal()
        self._pitch = player:get_look_vertical()
        self._vel = self.object:get_velocity()
        self._speed = vec:copy(self._vel):magnitude()
        self:_glide(dtime)
        if self._speed < self._groundCalcSpeedMax and entityOnGround(nil, self.object, 0.6) then
            self:_setGliding(false)
        end
    end
end
local wingsEnDef = {
    visual = "mesh",
    mesh = "wings.x",
    textures = {"wings_entity.png"},
    backface_culling = false,
    collisionbox = {
        -0.2,
        -0.45,
        -0.2,
        0.2,
        0.1,
        0.2
    },
    physical = true,
    _playername = nil,
    _yaw = 0,
    _pitch = 0,
    _glideTime = 0,
    _outVelocity = {x = 0, y = 0, z = 0},
    _vel = {x = 0, y = 0, z = 0},
    _wingFoldedDeg = 75,
    _wingSpanDeg = 0,
    _wingStressDeg = 15,
    _wingRelaxDeg = 0,
    _speed = 0,
    _groundCalcSpeedMax = 12,
    _isGliding = false,
    _wasGliding = false,
    _timeLastJump = 0,
    on_activate = function(self, sd, dtime)
        minetest.after(
            0.1,
            function()
                if self._playername == nil then
                    self.object:remove()
                end
            end
        )
    end,
    _glide = function(self, dtime)
        self.object:set_bone_position("root", v3zero, {y = 0, x = 90 + self._pitch * RAD2DEG, z = -(self._yaw * RAD2DEG)})
        local wingsSpeedBend = lerp(nil, self._wingSpanDeg, self._wingFoldedDeg, self._speed / 60)
        local wingsStressBend = lerpClamped(nil, self._wingRelaxDeg, self._wingStressDeg, self._speed / 8)
        self.object:set_bone_position("left", wingPos, {x = 0, y = wingsSpeedBend, z = wingsStressBend})
        self.object:set_bone_position("right", wingPos, {x = 0, y = -wingsSpeedBend, z = -wingsStressBend})
        local yawcos = math.cos(-self._yaw - math.pi)
        local yawsin = math.sin(-self._yaw - math.pi)
        local pitchcos = math.cos(self._pitch)
        local pitchsin = math.sin(self._pitch)
        local lookX = yawsin * -pitchcos
        local lookY = -pitchsin
        local lookZ = yawcos * -pitchcos
        local hvel = math.sqrt(self._vel.x * self._vel.x + self._vel.z * self._vel.z)
        local hlook = pitchcos
        local sqrpitchcos = pitchcos * pitchcos
        local ____self__outVelocity_1, ____y_2 = self._outVelocity, "y"
        ____self__outVelocity_1[____y_2] = ____self__outVelocity_1[____y_2] + (-0.08 + sqrpitchcos * 0.06)
        if self._outVelocity.y < 0 and hlook > 0 then
            local yacc = self._vel.y * -0.1 * sqrpitchcos
            local ____self__vel_3, ____y_4 = self._vel, "y"
            ____self__vel_3[____y_4] = ____self__vel_3[____y_4] + yacc
            local ____self__vel_5, ____x_6 = self._vel, "x"
            ____self__vel_5[____x_6] = ____self__vel_5[____x_6] + lookX * yacc / hlook
            local ____self__vel_7, ____z_8 = self._vel, "z"
            ____self__vel_7[____z_8] = ____self__vel_7[____z_8] + lookZ * yacc / hlook
        end
        if self._pitch < 0 then
            local yacc = hvel * -pitchsin * 0.04
            local ____self__vel_9, ____y_10 = self._vel, "y"
            ____self__vel_9[____y_10] = ____self__vel_9[____y_10] + yacc * 3.5
            local ____self__vel_11, ____x_12 = self._vel, "x"
            ____self__vel_11[____x_12] = ____self__vel_11[____x_12] - lookX * yacc / hlook
            local ____self__vel_13, ____z_14 = self._vel, "z"
            ____self__vel_13[____z_14] = ____self__vel_13[____z_14] - lookZ * yacc / hlook
        end
        if hlook > 0 then
            local ____self__vel_15, ____x_16 = self._vel, "x"
            ____self__vel_15[____x_16] = ____self__vel_15[____x_16] + (lookX / hlook * hvel - self._vel.x) * 0.1
            local ____self__vel_17, ____z_18 = self._vel, "z"
            ____self__vel_17[____z_18] = ____self__vel_17[____z_18] + (lookZ / hlook * hvel - self._vel.z) * 0.1
        end
        local ____self__vel_19, ____x_20 = self._vel, "x"
        ____self__vel_19[____x_20] = ____self__vel_19[____x_20] * 0.99
        local ____self__vel_21, ____y_22 = self._vel, "y"
        ____self__vel_21[____y_22] = ____self__vel_21[____y_22] * 0.98
        local ____self__vel_23, ____z_24 = self._vel, "z"
        ____self__vel_23[____z_24] = ____self__vel_23[____z_24] * 0.99
        self._outVelocity.x = self._vel.x
        self._outVelocity.y = self._vel.y
        self._outVelocity.z = self._vel.z
        self._glideTime = self._glideTime + dtime
        local ____self__outVelocity_25, ____y_26 = self._outVelocity, "y"
        ____self__outVelocity_25[____y_26] = ____self__outVelocity_25[____y_26] - 0.98
        self.object:set_velocity(self._outVelocity)
    end,
    _updateAttachment = function(self, player)
        if self._isGliding then
            self.object:set_pos(player:get_pos())
            self.object:set_detach()
            minetest.after(
                0.2,
                function()
                    local pv = player:get_velocity()
                    self.object:set_velocity(pv)
                    vec:copy(pv):store(self._vel)
                    player:set_attach(self.object, "mount", v3zero, v3zero)
                end
            )
        else
            player:set_detach()
            minetest.after(
                0.2,
                function()
                    self.object:set_attach(player, "Body", v3zero, v3zero)
                    self.object:set_bone_position("root", v3zero, {x = -10, y = 0, z = 0})
                    self.object:set_bone_position("left", wingPos, {x = 0, y = self._wingFoldedDeg, z = self._wingRelaxDeg})
                    self.object:set_bone_position("right", wingPos, {x = 0, y = -self._wingFoldedDeg, z = -self._wingRelaxDeg})
                end
            )
        end
    end,
    _setGliding = function(self, isGliding)
        local player
        if not self._playername then
            return
        end
        player = minetest.get_player_by_name(self._playername)
        if not player then
            return
        end
        self._wasGliding = self._isGliding
        self._isGliding = isGliding
        if self._isGliding ~= self._wasGliding then
            self:_updateAttachment(player)
            wings.events:fire("glidechange", {isGliding = isGliding, player = player, wings = self})
        end
    end,
    on_step = wings_onstep
}
minetest.register_entity(wingsEntityName, wingsEnDef)
local wingsItemName = modname .. ":wings_feather"
local wingsInvTex = modname .. "_inv_wings_feather.png"
armor:register_armor(wingsItemName, {
    armor_groups = {fleshy = 1},
    groups = {armor_torso = 1},
    damage_groups = {flammable = 1, fluffy = 1},
    description = "You're free as a bird",
    inventory_image = wingsInvTex
})
minetest.register_on_leaveplayer(function(p, timedout)
    local pname = p:get_player_name()
    local wing = wings.getPlayerWingEntity(pname)
    if wing == nil then
        return
    end
    wings.clearWing(wing)
end)
wings.events:listen(
    "equipchange",
    function(____, evt)
        minetest.chat_send_player(
            evt.player:get_player_name(),
            ("You " .. (evt.equipped and "equipped" or "unequipped")) .. " wings"
        )
    end
)
armor:register_on_equip(function(p, index, stack)
    if stack:get_name() == wingsItemName then
        local wing = wings.getOrCreate(p)
        wings.events:fire("equipchange", {equipped = true, player = p, wing = wing})
    end
end)
armor:register_on_unequip(function(player, index, stack)
    local pname = player:get_player_name()
    if stack:get_name() == wingsItemName then
        wings.clearPlayerWingEntity(pname)
        wings.events:fire("equipchange", {equipped = false, player = player})
    end
end)
minetest.register_craft({type = "shaped", output = wingsItemName, recipe = {{"", "", ""}, {"", "default:stone", ""}, {"", "", ""}}})
return ____exports

--[[ Generated with https://github.com/TypeScriptToLua/TypeScriptToLua ]]
local ____exports = {}
local vec = {
    v = {x = 0, y = 0, z = 0},
    copy = function(self, other)
        self.v.x = other.x
        self.v.y = other.y
        self.v.z = other.z
        return self
    end,
    store = function(self, other)
        other.x = self.v.x
        other.y = self.v.y
        other.z = self.v.z
        return self
    end,
    magnitude = function(self)
        return math.sqrt(self.v.x * self.v.x + self.v.y * self.v.y + self.v.z * self.v.z)
    end,
    floor = function(self)
        self.v.x = math.floor(self.v.x)
        self.v.y = math.floor(self.v.y)
        self.v.z = math.floor(self.v.z)
        return self
    end
}
_G.vec = vec
return ____exports

local LevelingConstants = {}

local BASE_XP_PER_LEVEL = 100
local XP_GROWTH_PER_LEVEL = 25

function LevelingConstants.getXPRequiredForLevel(level: number): number
	local normalizedLevel = math.max(1, math.floor(level))
	return BASE_XP_PER_LEVEL + (normalizedLevel - 1) * XP_GROWTH_PER_LEVEL
end

return LevelingConstants

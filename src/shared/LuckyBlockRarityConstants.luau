local LuckyBlockRarityConstants = {}

LuckyBlockRarityConstants.DEFAULT = "Common"

LuckyBlockRarityConstants.SPAWN_TYPE_TO_RARITY = {
	Regular = "Common",
}

LuckyBlockRarityConstants.RARITY_COLORS = {
	Common = Color3.fromRGB(255, 255, 255),
}

LuckyBlockRarityConstants.RARITY_STROKE_COLORS = {
	Common = Color3.fromRGB(0, 0, 0),
}

LuckyBlockRarityConstants.RARITY_GRADIENTS = {
	Common = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 0)),
	}),
}

function LuckyBlockRarityConstants.normalizeRarity(rarity: string?): string
	if typeof(rarity) ~= "string" or rarity == "" then
		return LuckyBlockRarityConstants.DEFAULT
	end

	local mappedRarity = LuckyBlockRarityConstants.SPAWN_TYPE_TO_RARITY[rarity]
	if mappedRarity then
		return mappedRarity
	end

	if LuckyBlockRarityConstants.RARITY_COLORS[rarity] then
		return rarity
	end

	return LuckyBlockRarityConstants.DEFAULT
end

function LuckyBlockRarityConstants.getRarityFromSpawnType(spawnType: string?): string
	if typeof(spawnType) == "string" and spawnType ~= "" then
		local mappedRarity = LuckyBlockRarityConstants.SPAWN_TYPE_TO_RARITY[spawnType]
		if mappedRarity then
			return mappedRarity
		end
	end

	return LuckyBlockRarityConstants.DEFAULT
end

function LuckyBlockRarityConstants.getColor(rarity: string?): Color3
	local normalized = LuckyBlockRarityConstants.normalizeRarity(rarity)
	return LuckyBlockRarityConstants.RARITY_COLORS[normalized] or LuckyBlockRarityConstants.RARITY_COLORS[LuckyBlockRarityConstants.DEFAULT]
end

function LuckyBlockRarityConstants.getGradient(rarity: string?): ColorSequence
	local normalized = LuckyBlockRarityConstants.normalizeRarity(rarity)
	return LuckyBlockRarityConstants.RARITY_GRADIENTS[normalized]
		or LuckyBlockRarityConstants.RARITY_GRADIENTS[LuckyBlockRarityConstants.DEFAULT]
end

function LuckyBlockRarityConstants.getStrokeColor(rarity: string?): Color3
	local normalized = LuckyBlockRarityConstants.normalizeRarity(rarity)
	return LuckyBlockRarityConstants.RARITY_STROKE_COLORS[normalized]
		or LuckyBlockRarityConstants.RARITY_STROKE_COLORS[LuckyBlockRarityConstants.DEFAULT]
end

return LuckyBlockRarityConstants

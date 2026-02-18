local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)
local LevelingConstants = require(Shared.LevelingConstants)

local PROFILE_TEMPLATE = {
	Cash = 0,
	Blocks = 0,
	Level = 1,
	XP = 0,
}

local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		BlockCount = Knit.CreateProperty(-1),
		Level = Knit.CreateProperty(1),
		XP = Knit.CreateProperty(0),
	},
})

function DataService:KnitInit()
	self.Profiles = {}
	self._runtimeBlockCounts = {}
	self._runtimeLevels = {}
	self._runtimeXP = {}
end

function DataService:KnitStart()
	Players.PlayerAdded:Connect(function(player)
		self:_playerAdded(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_playerRemoving(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_playerAdded(player)
		end)
	end
end

function DataService:_playerAdded(player)
	local profile = PlayerStore:StartSessionAsync(`{player.UserId}`, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile ~= nil then
		profile:AddUserId(player.UserId)
		profile:Reconcile()

		profile.OnSessionEnd:Connect(function()
			self.Profiles[player] = nil
			self._runtimeBlockCounts[player] = nil
			self._runtimeLevels[player] = nil
			self._runtimeXP[player] = nil
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			self.Profiles[player] = profile
			local blockCount = self:GetBlockCount(player)
			local level = self:GetLevel(player)
			local xp = self:GetXP(player)
			self._runtimeBlockCounts[player] = blockCount
			self._runtimeLevels[player] = level
			self._runtimeXP[player] = xp
			self.Client.BlockCount:SetFor(player, blockCount)
			self.Client.Level:SetFor(player, level)
			self.Client.XP:SetFor(player, xp)
		else
			profile:EndSession()
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end
end

function DataService:_playerRemoving(player)
	self._runtimeBlockCounts[player] = nil
	self._runtimeLevels[player] = nil
	self._runtimeXP[player] = nil
	local profile = self.Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService:GetProfile(player)
	return self.Profiles[player]
end

function DataService:GetBlockCount(player: Player): number
	local profile = self.Profiles[player]
	if profile ~= nil then
		local count = profile.Data.Blocks
		if typeof(count) == "number" then
			return math.max(0, math.floor(count))
		end
	end

	local runtimeCount = self._runtimeBlockCounts[player]
	if typeof(runtimeCount) == "number" then
		return math.max(0, math.floor(runtimeCount))
	end

	return 0
end

function DataService:AddBlocks(player: Player, amount: number): number
	local profile = self.Profiles[player]
	local delta = math.floor(amount)
	if delta == 0 then
		return self:GetBlockCount(player)
	end

	local current = self:GetBlockCount(player)
	local nextCount = math.max(0, current + delta)
	self._runtimeBlockCounts[player] = nextCount
	if profile ~= nil then
		profile.Data.Blocks = nextCount
	end
	self.Client.BlockCount:SetFor(player, nextCount)
	return nextCount
end

function DataService:GetLevel(player: Player): number
	local profile = self.Profiles[player]
	if profile ~= nil then
		local level = profile.Data.Level
		if typeof(level) == "number" then
			return math.max(1, math.floor(level))
		end
	end

	local runtimeLevel = self._runtimeLevels[player]
	if typeof(runtimeLevel) == "number" then
		return math.max(1, math.floor(runtimeLevel))
	end

	return 1
end

function DataService:AddLevel(player: Player, amount: number): number
	local profile = self.Profiles[player]
	local delta = math.floor(amount)
	if delta == 0 then
		return self:GetLevel(player)
	end

	local current = self:GetLevel(player)
	local nextLevel = math.max(1, current + delta)
	self._runtimeLevels[player] = nextLevel
	if profile ~= nil then
		profile.Data.Level = nextLevel
	end
	self.Client.Level:SetFor(player, nextLevel)
	return nextLevel
end

function DataService:GetXP(player: Player): number
	local profile = self.Profiles[player]
	if profile ~= nil then
		local xp = profile.Data.XP
		if typeof(xp) == "number" then
			return math.max(0, math.floor(xp))
		end
	end

	local runtimeXP = self._runtimeXP[player]
	if typeof(runtimeXP) == "number" then
		return math.max(0, math.floor(runtimeXP))
	end

	return 0
end

function DataService:AddXP(player: Player, amount: number): number
	local profile = self.Profiles[player]
	local delta = math.floor(amount)
	if delta == 0 then
		return self:GetXP(player)
	end

	local nextXP = self:GetXP(player) + delta
	local nextLevel = self:GetLevel(player)

	while nextXP < 0 and nextLevel > 1 do
		nextLevel -= 1
		nextXP += LevelingConstants.getXPRequiredForLevel(nextLevel)
	end

	if nextXP < 0 then
		nextXP = 0
	end

	local xpRequired = LevelingConstants.getXPRequiredForLevel(nextLevel)
	while nextXP >= xpRequired do
		nextXP -= xpRequired
		nextLevel += 1
		xpRequired = LevelingConstants.getXPRequiredForLevel(nextLevel)
	end

	self._runtimeLevels[player] = nextLevel
	self._runtimeXP[player] = nextXP
	if profile ~= nil then
		profile.Data.Level = nextLevel
		profile.Data.XP = nextXP
	end
	self.Client.Level:SetFor(player, nextLevel)
	self.Client.XP:SetFor(player, nextXP)
	return nextXP
end

return DataService

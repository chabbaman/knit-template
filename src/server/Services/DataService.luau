local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local PROFILE_TEMPLATE = {
	Cash = 0,
	Blocks = 0,
}

local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {
		BlockCount = Knit.CreateProperty(0),
	},
})

function DataService:KnitInit()
	self.Profiles = {}
	self._runtimeBlockCounts = {}
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
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			self.Profiles[player] = profile
			local blockCount = self:GetBlockCount(player)
			self._runtimeBlockCounts[player] = blockCount
			self.Client.BlockCount:SetFor(player, blockCount)
		else
			profile:EndSession()
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end
end

function DataService:_playerRemoving(player)
	self._runtimeBlockCounts[player] = nil
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

return DataService

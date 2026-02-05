local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local ProfileStore = require(ServerScriptService.ServerPackages.ProfileStore)

local PROFILE_TEMPLATE = {
	Cash = 0,
}

local PlayerStore = ProfileStore.New("PlayerStore", PROFILE_TEMPLATE)

local DataService = Knit.CreateService({
	Name = "DataService",
	Client = {},
})

function DataService:KnitInit()
	self.Profiles = {}
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
			player:Kick("Profile session end - Please rejoin")
		end)

		if player.Parent == Players then
			self.Profiles[player] = profile
		else
			profile:EndSession()
		end
	else
		player:Kick("Profile load fail - Please rejoin")
	end
end

function DataService:_playerRemoving(player)
	local profile = self.Profiles[player]
	if profile ~= nil then
		profile:EndSession()
	end
end

function DataService:GetProfile(player)
	return self.Profiles[player]
end

return DataService

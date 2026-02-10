local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local PlotService = Knit.CreateService({
	Name = "PlotService",
	Client = {},
})

function PlotService:KnitInit()
	self._playerToPlot = {}
	self._plotToPlayer = {}
	self._availablePlots = {}
	self._characterConns = {}
end

function PlotService:KnitStart()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			table.insert(self._availablePlots, plot)
		end
	end

	Players.PlayerAdded:Connect(function(player)
		self:_assignPlot(player)
	end)

	for _, player in Players:GetPlayers() do
		self:_assignPlot(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:_freePlot(player)
	end)
end

function PlotService:_teleportToPlot(player: Player, character: Model)
	local plot = self._playerToPlot[player]
	if not plot then
		return
	end

	local spawnPart = plot:FindFirstChild("SpawnPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	task.spawn(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 10)
		if not hrp then
			return
		end
		character:PivotTo(spawnPart.CFrame + Vector3.new(0, 5, 0))
	end)
end

function PlotService:_assignPlot(player: Player)
	if self._playerToPlot[player] then
		return
	end

	if #self._availablePlots == 0 then
		return
	end

	local plot = table.remove(self._availablePlots, 1)
	self._playerToPlot[player] = plot
	self._plotToPlayer[plot] = player

	self._characterConns[player] = player.CharacterAdded:Connect(function(character)
		self:_teleportToPlot(player, character)
	end)

	if player.Character then
		self:_teleportToPlot(player, player.Character)
	end
end

function PlotService:_freePlot(player: Player)
	local plot = self._playerToPlot[player]
	if not plot then
		return
	end

	if self._characterConns[player] then
		self._characterConns[player]:Disconnect()
		self._characterConns[player] = nil
	end

	self._playerToPlot[player] = nil
	self._plotToPlayer[plot] = nil
	table.insert(self._availablePlots, plot)

	for _, child in plot:GetChildren() do
		if child:IsA("Model") then
			child:Destroy()
		end
	end
end

function PlotService:GetPlayerPlot(player: Player): Instance?
	return self._playerToPlot[player]
end

function PlotService:GetPlotOwner(plot: Instance): Player?
	return self._plotToPlayer[plot]
end

function PlotService:GetAssignedPlots(): { [Instance]: Player }
	return self._plotToPlayer
end

return PlotService

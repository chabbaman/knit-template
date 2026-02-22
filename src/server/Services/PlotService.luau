local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local vide = require(Packages.Vide)
local create = vide.create
local root = vide.root

local PlotService = Knit.CreateService({
	Name = "PlotService",
	Client = {},
})

function PlotService:KnitInit()
	self._playerToPlot = {}
	self._plotToPlayer = {}
	self._availablePlots = {}
	self._characterConns = {}
	self._billboardRoots = {}
	self.PlotAssigned = Instance.new("BindableEvent")
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

function PlotService:_createPlotBillboard(player: Player, plot: Instance)
	local adornee = plot:FindFirstChild("SpawnPart") or plot:FindFirstChildWhichIsA("BasePart")
	if not adornee then
		return
	end

	local headshotUrl = Players:GetUserThumbnailAsync(
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size100x100
	)

	local destroy = root(function()
		create("BillboardGui")({
			Name = "PlotBillboard",
			Adornee = adornee,
			Size = UDim2.fromOffset(200, 120),
			StudsOffset = Vector3.new(0, 28, 0),
			AlwaysOnTop = true,
			ResetOnSpawn = false,
			Parent = adornee,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 4),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),

			create("ImageLabel")({
				Name = "Headshot",
				BackgroundTransparency = 1,
				Image = headshotUrl,
				LayoutOrder = 1,
				Size = UDim2.fromOffset(64, 64),

				create("UICorner")({
					CornerRadius = UDim.new(1, 0),
				}),
			}),

			create("TextLabel")({
				Name = "OwnerName",
				BackgroundTransparency = 1,
				LayoutOrder = 2,
				Size = UDim2.fromOffset(200, 40),
				FontFace = Font.new(
					"rbxasset://fonts/families/FredokaOne.json",
					Enum.FontWeight.Heavy,
					Enum.FontStyle.Normal
				),
				Text = player.DisplayName .. "'s Farm",
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextScaled = true,

				create("UIStroke")({
					Color = Color3.fromRGB(0, 0, 0),
					LineJoinMode = Enum.LineJoinMode.Round,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.08,
					Transparency = 0.2,
				}),
			}),
		})
	end)

	self._billboardRoots[player] = destroy
end

function PlotService:_removePlotBillboard(player: Player)
	local destroy = self._billboardRoots[player]
	if destroy then
		destroy()
		self._billboardRoots[player] = nil
	end
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

	self:_createPlotBillboard(player, plot)

	self._characterConns[player] = player.CharacterAdded:Connect(function(character)
		self:_teleportToPlot(player, character)
	end)

	if player.Character then
		self:_teleportToPlot(player, player.Character)
	end

	self.PlotAssigned:Fire(player, plot)
end

function PlotService:_freePlot(player: Player)
	local plot = self._playerToPlot[player]
	if not plot then
		return
	end

	self:_removePlotBillboard(player)

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

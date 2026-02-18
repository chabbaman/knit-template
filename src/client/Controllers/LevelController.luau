local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local vide = require(Packages.Vide)
local LevelingConstants = require(Shared.LevelingConstants)
local create = vide.create
local root = vide.root
local source = vide.source
local spring = vide.spring

local BAR_PULSE_SCALE = 1.04
local BAR_PULSE_RETURN_DELAY = 0.07

local LevelController = Knit.CreateController({
	Name = "LevelController",
})

function LevelController:KnitInit()
	self._dataService = nil
	self._levelProperty = nil
	self._xpProperty = nil
	self._uiRoot = nil
	self._levelTarget = nil
	self._xpTarget = nil
	self._barPulseTarget = nil
	self._level = 1
	self._xp = 0
end

function LevelController:_setLevel(level: number)
	if typeof(level) ~= "number" then
		return
	end

	local previousLevel = self._level
	local nextLevel = math.max(1, math.floor(level))
	self._level = nextLevel
	if self._levelTarget then
		self._levelTarget(nextLevel)
	end

	if self._barPulseTarget and nextLevel > previousLevel then
		local pulseTarget = self._barPulseTarget
		pulseTarget(BAR_PULSE_SCALE)
		task.delay(BAR_PULSE_RETURN_DELAY, function()
			if self._barPulseTarget == pulseTarget then
				pulseTarget(1)
			end
		end)
	end
end

function LevelController:_setXP(xp: number)
	if typeof(xp) ~= "number" then
		return
	end

	local nextXP = math.max(0, math.floor(xp))
	local previousXP = self._xp
	self._xp = nextXP
	if self._xpTarget then
		self._xpTarget(nextXP)
	end

	if self._barPulseTarget and nextXP > previousXP then
		local pulseTarget = self._barPulseTarget
		pulseTarget(BAR_PULSE_SCALE)
		task.delay(BAR_PULSE_RETURN_DELAY, function()
			if self._barPulseTarget == pulseTarget then
				pulseTarget(1)
			end
		end)
	end
end

function LevelController:KnitStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local levelTarget = source(1)
	local xpTarget = source(0)
	local barPulseTarget = source(1)

	self._levelTarget = levelTarget
	self._xpTarget = xpTarget
	self._barPulseTarget = barPulseTarget
	self._dataService = Knit.GetService("DataService")
	self._levelProperty = self._dataService.Level
	self._xpProperty = self._dataService.XP

	self._levelProperty:Observe(function(level)
		self:_setLevel(level)
	end)

	self._xpProperty:Observe(function(xp)
		self:_setXP(xp)
	end)

	self._uiRoot = root(function()
		local animatedPulse = spring(barPulseTarget, 0.16, 1)
		local animatedXP = spring(xpTarget, 0.22, 1)

		create("ScreenGui")({
			Name = "LevelGui",
			DisplayOrder = 25,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,

			create("Frame")({
				Name = "Container",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.025),
				Size = UDim2.fromScale(0.46, 0.085),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Vertical,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.05, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Top,
				}),

				create("TextLabel")({
					Name = "LevelText",
					BackgroundTransparency = 1,
					LayoutOrder = 1,
					Size = UDim2.fromScale(0.7, 0.38),
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					Text = function()
						return `Level {math.max(1, math.floor(levelTarget()))}`
					end,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.06,
						Transparency = 0.15,
					}),
				}),

				create("Frame")({
					Name = "ProgressBar",
					BackgroundColor3 = Color3.fromRGB(23, 29, 38),
					BackgroundTransparency = 0.15,
					LayoutOrder = 2,
					Size = function()
						local scale = animatedPulse()
						return UDim2.fromScale(0.95 * scale, 0.45 * scale)
					end,

					create("UICorner")({
						Name = "UICorner",
						CornerRadius = UDim.new(0.5, 0),
					}),

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(255, 255, 255),
						LineJoinMode = Enum.LineJoinMode.Round,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.03,
						Transparency = 0.2,
					}),

					create("Frame")({
						Name = "TrailFillMask",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.01, 0.08),
						Size = function()
							local level = math.max(1, math.floor(levelTarget()))
							local requiredXP = LevelingConstants.getXPRequiredForLevel(level)
							local fraction = math.clamp((animatedXP() / math.max(requiredXP, 1)) * 0.96, 0, 1)
							return UDim2.fromScale(fraction * 0.98, 0.84)
						end,
						ZIndex = 1,

						create("UICorner")({
							Name = "UICorner",
							CornerRadius = UDim.new(0.5, 0),
						}),

						create("ImageLabel")({
							Name = "TrailFill",
							BackgroundTransparency = 0,
							Image = "rbxassetid://6927295847",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = 0.66,
							ResampleMode = Enum.ResamplerMode.Pixelated,
							ScaleType = Enum.ScaleType.Tile,
							Size = function()
								local level = math.max(1, math.floor(levelTarget()))
								local requiredXP = LevelingConstants.getXPRequiredForLevel(level)
								local fraction = math.clamp((animatedXP() / math.max(requiredXP, 1)) * 0.96, 0.001, 1)
								return UDim2.fromScale(1 / fraction, 1)
							end,
							TileSize = UDim2.fromScale(0.04, 0.8),

							create("UICorner")({
								Name = "UICorner",
								CornerRadius = UDim.new(0.5, 0),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 90, 45)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 55, 25)),
								}),
								Rotation = -90,
							}),
						}),
					}),

					create("Frame")({
						Name = "FillMask",
						BackgroundTransparency = 1,
						ClipsDescendants = true,
						Position = UDim2.fromScale(0.01, 0.08),
						Size = function()
							local level = math.max(1, math.floor(levelTarget()))
							local requiredXP = LevelingConstants.getXPRequiredForLevel(level)
							local fraction = math.clamp(animatedXP() / math.max(requiredXP, 1), 0, 1)
							return UDim2.fromScale(fraction * 0.98, 0.84)
						end,
						ZIndex = 2,

						create("UICorner")({
							Name = "UICorner",
							CornerRadius = UDim.new(0.5, 0),
						}),

						create("ImageLabel")({
							Name = "Fill",
							BackgroundTransparency = 0,
							Image = "rbxassetid://6927295847",
							ImageColor3 = Color3.fromRGB(255, 255, 255),
							ImageTransparency = 0.66,
							ResampleMode = Enum.ResamplerMode.Pixelated,
							ScaleType = Enum.ScaleType.Tile,
							Size = function()
								local level = math.max(1, math.floor(levelTarget()))
								local requiredXP = LevelingConstants.getXPRequiredForLevel(level)
								local fraction = math.clamp(animatedXP() / math.max(requiredXP, 1), 0.001, 1)
								return UDim2.fromScale(1 / fraction, 1)
							end,
							TileSize = UDim2.fromScale(0.04, 0.8),

							create("UICorner")({
								Name = "UICorner",
								CornerRadius = UDim.new(0.5, 0),
							}),

							create("UIGradient")({
								Name = "UIGradient",
								Color = ColorSequence.new({
									ColorSequenceKeypoint.new(0, Color3.fromRGB(57, 150, 78)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(33, 104, 51)),
								}),
								Rotation = -90,
							}),
						}),
					}),

					create("TextLabel")({
						Name = "ProgressText",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/FredokaOne.json",
							Enum.FontWeight.Heavy,
							Enum.FontStyle.Normal
						),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(0.95, 0.85),
						Text = function()
							local level = math.max(1, math.floor(levelTarget()))
							local requiredXP = LevelingConstants.getXPRequiredForLevel(level)
							local shownXP = math.max(0, math.floor(xpTarget()))
							return `{shownXP}/{requiredXP} XP`
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 3,

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.fromRGB(0, 0, 0),
							LineJoinMode = Enum.LineJoinMode.Round,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.05,
							Transparency = 0.15,
						}),
					}),
				}),
			}),
		})
	end)
end

return LevelController

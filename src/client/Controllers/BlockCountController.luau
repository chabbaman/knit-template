local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)
local vide = require(Packages.Vide)
local create = vide.create
local root = vide.root
local source = vide.source
local spring = vide.spring

local STUD_ICON_ASSET_ID = "rbxassetid://86094156392599"
local PANEL_SIZE = UDim2.fromOffset(140, 72)
local PANEL_OFFSET = Vector2.new(18, -18)
local IMPULSE_SCALE = 1.09
local IMPULSE_RETURN_DELAY = 0.06
local COUNT_LABEL_BASE_SIZE = UDim2.fromScale(1, 0.95)

local BlockCountController = Knit.CreateController({
	Name = "BlockCountController",
})

function BlockCountController:SetBlockCount(count: number)
	if typeof(count) ~= "number" then
		return
	end

	local nextCount = math.max(0, math.floor(count))
	local previousCount = self._count
	self._count = nextCount

	if not self._countTarget then
		return
	end

	self._countTarget(nextCount)

	if previousCount ~= nil and nextCount > previousCount and self._countPulseTarget then
		local pulseTarget = self._countPulseTarget
		pulseTarget(IMPULSE_SCALE)
		task.delay(IMPULSE_RETURN_DELAY, function()
			if self._countPulseTarget == pulseTarget then
				pulseTarget(1)
			end
		end)
	end
end

function BlockCountController:_syncFromAuthoritative(count: number)
	if typeof(count) ~= "number" or count < 0 then
		return
	end

	local nextAuthoritative = math.max(0, math.floor(count))
	local displayedCount = self._displayedCount
	self._authoritativeCount = nextAuthoritative

	if displayedCount == nil then
		self._pendingCount = 0
		self._displayedCount = nextAuthoritative
		self:SetBlockCount(nextAuthoritative)
		return
	end

	if nextAuthoritative <= displayedCount then
		self._pendingCount = 0
		self._displayedCount = nextAuthoritative
		self:SetBlockCount(nextAuthoritative)
		return
	end

	self._pendingCount = nextAuthoritative - displayedCount
end

function BlockCountController:_consumePendingFromCollection()
	local pendingCount = self._pendingCount or 0
	if pendingCount <= 0 then
		return
	end

	local displayedCount = self._displayedCount or 0
	local nextDisplayed = displayedCount + 1
	self._pendingCount = pendingCount - 1
	self._displayedCount = nextDisplayed
	self:SetBlockCount(nextDisplayed)
end

function BlockCountController:KnitInit()
	self._countTarget = nil
	self._countPulseTarget = nil
	self._uiRoot = nil
	self._count = nil
	self._dataService = nil
	self._blockCountProperty = nil
	self._authoritativeCount = nil
	self._displayedCount = nil
	self._pendingCount = 0
end

function BlockCountController:KnitStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local countTarget = source(0)
	local countPulseTarget = source(1)
	self._countTarget = countTarget
	self._countPulseTarget = countPulseTarget
	self._dataService = Knit.GetService("DataService")
	self._blockCountProperty = self._dataService.BlockCount

	self._blockCountProperty:Observe(function(nextCount)
		self:_syncFromAuthoritative(nextCount)
	end)

	local luckyBlockController = Knit.GetController("LuckyBlockController")
	luckyBlockController:ConnectDebrisCollected(function()
		self:_consumePendingFromCollection()
	end)

	self._uiRoot = root(function()
		local animatedCountPulse = spring(countPulseTarget, 0.12, 1)

		create("ScreenGui")({
			Name = "BlockCountGui",
			DisplayOrder = 20,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,

			create("Frame")({
				Name = "Panel",
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				Position = UDim2.new(0, PANEL_OFFSET.X, 1, PANEL_OFFSET.Y),
				Size = PANEL_SIZE,

				create("UIPadding")({
					Name = "UIPadding",
					PaddingBottom = UDim.new(0, 8),
					PaddingLeft = UDim.new(0, 2),
					PaddingRight = UDim.new(0, 2),
					PaddingTop = UDim.new(0, 8),
				}),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, 10),
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				create("ImageLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Image = STUD_ICON_ASSET_ID,
					LayoutOrder = 1,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromOffset(52, 52),
				}),

				create("Frame")({
					Name = "TextGroup",
					BackgroundTransparency = 1,
					LayoutOrder = 2,
					Size = UDim2.fromOffset(76, 52),

					create("TextLabel")({
						Name = "Count",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/FredokaOne.json",
							Enum.FontWeight.Heavy,
							Enum.FontStyle.Normal
						),
						LayoutOrder = 1,
						Position = function()
							local scale = animatedCountPulse()
							return UDim2.fromScale(0.5 * scale, 0.5)
						end,
						Size = function()
							local scale = animatedCountPulse()
							return UDim2.fromScale(COUNT_LABEL_BASE_SIZE.X.Scale * scale, COUNT_LABEL_BASE_SIZE.Y.Scale * scale)
						end,
						Text = function()
							return tostring(math.floor(countTarget() + 0.5))
						end,
						TextColor3 = Color3.fromRGB(255, 255, 255),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIStroke")({
							Name = "UIStroke",
							Color = Color3.fromRGB(0, 0, 0),
							LineJoinMode = Enum.LineJoinMode.Round,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.08,
							Transparency = 0.2,
						}),
					}),
				}),
			}),
		})
	end)
end

return BlockCountController

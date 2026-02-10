local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local vide = require(Packages.Vide)
local LuckyBlockRarityConstants = require(Shared.LuckyBlockRarityConstants)
local create = vide.create
local source = vide.source
local spring = vide.spring
local root = vide.root

local DISPLAY_DURATION = 3
local FADE_CLEANUP_DELAY = 1.2
local NOTIFICATION_HEIGHT = 42
local NOTIFICATION_MAX_WIDTH = 280

local NotificationController = Knit.CreateController({
	Name = "NotificationController",
})

function NotificationController:Show(text: string, rarity: string?)
	local container = self._container
	if not container then
		return
	end

	local gradient = LuckyBlockRarityConstants.getGradient(rarity)
	local strokeColor = LuckyBlockRarityConstants.getStrokeColor(rarity)

	local scaleTarget = source(0)

	local destroy = root(function()
		local animatedScale = spring(scaleTarget, 0.4, 1)

		create("Frame")({
			Name = "Notification",
			BackgroundTransparency = 1,
			ClipsDescendants = false,
			Size = function()
				local s = math.clamp(animatedScale(), 0, 1)
				return UDim2.new(1, 0, 0, NOTIFICATION_HEIGHT * s)
			end,
			Parent = container,

			create("TextLabel")({
				Name = "Text",
				AnchorPoint = Vector2.new(0.5, 0),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0),
				Size = UDim2.fromScale(1, 1),
				FontFace = Font.new(
					"rbxasset://fonts/families/FredokaOne.json",
					Enum.FontWeight.Heavy,
					Enum.FontStyle.Normal
				),
				Text = text,
				TextColor3 = Color3.new(1, 1, 1),
				TextScaled = true,
				TextTransparency = function()
					return 1 - math.clamp(animatedScale(), 0, 1)
				end,

				create("UIGradient")({
					Color = gradient,
					Rotation = -90,
				}),

				create("UIStroke")({
					Color = strokeColor,
					LineJoinMode = Enum.LineJoinMode.Round,
					StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
					Thickness = 0.06,
					Transparency = function()
						return 0.15 + (1 - math.clamp(animatedScale(), 0, 1)) * 0.85
					end,
				}),
			}),
		})
	end)

	scaleTarget(1)

	task.delay(DISPLAY_DURATION, function()
		scaleTarget(0)
		task.delay(FADE_CLEANUP_DELAY, function()
			destroy()
		end)
	end)
end

function NotificationController:KnitInit()
	self._container = nil
	self._uiRoot = nil
end

function NotificationController:KnitStart()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local containerFrame
	self._uiRoot = root(function()
		local gui = create("ScreenGui")({
			Name = "NotificationGui",
			DisplayOrder = 30,
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = playerGui,
		})

		containerFrame = create("Frame")({
			Name = "Container",
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0.85, 0),
			Size = UDim2.new(0, NOTIFICATION_MAX_WIDTH, 0.4, 0),
			Parent = gui,

			create("UIListLayout")({
				FillDirection = Enum.FillDirection.Vertical,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				VerticalAlignment = Enum.VerticalAlignment.Bottom,
				Padding = UDim.new(0, 8),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
		})
	end)

	self._container = containerFrame

	local luckyBlockController = Knit.GetController("LuckyBlockController")
	luckyBlockController:ConnectBlockBroken(function(blockName, rarity)
		self:Show(blockName .. " Destroyed!", rarity)
	end)
end

return NotificationController

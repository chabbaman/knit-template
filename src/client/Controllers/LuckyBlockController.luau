local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local spr = require(Shared.Spr)
local SoundUtil = require(Shared.SoundUtil)
local LuckyBlockRarityConstants = require(Shared.LuckyBlockRarityConstants)
local vide = require(Packages.Vide)
local create = vide.create
local source = vide.source
local spring = vide.spring
local root = vide.root

local BILLBOARD_RANGE_SQ = 30 * 30
local BILLBOARD_SIZE = UDim2.fromScale(10.125, 6.75)
local COLLECT_BILLBOARD_SIZE = UDim2.fromScale(3, 1.5)
local DETECTION_RANGE_SQ = 8 * 8
local MAX_HEALTH_FALLBACK = 100
local DEBRIS_STAGGER_TIME = 0.1
local DEBRIS_TEMPLATE = ReplicatedStorage.Assets.LuckyBlockDebris
local DEBRIS_LAUNCH_TIME = 0.15
local DEBRIS_PULL_ACCEL = 250
local DEBRIS_COLLECT_DIST_SQ = 3 * 3
local COLLECT_TEXT_FADE_DELAY = 2
local COLLECT_TEXT_FADE_CLEAR_DELAY = 0.3
local FOV_IMPULSE_AMOUNT = 2
local FOV_IMPULSE_HOLD = 0.05
local LOCK_ON_TURN_RESPONSE = 14
local INDICATOR_SIZE = 5
local INDICATOR_HEIGHT_OFFSET = 0.05
local INDICATOR_IMAGE = "rbxassetid://4885490162"
local BREAK_PIECE_COUNT = 16
local BREAK_PIECE_LIFETIME = 2
local BREAK_PIECE_MIN_SIZE = 0.4
local BREAK_PIECE_MAX_SIZE = 1.2
local HIT_PIECE_COUNT = 3
local HIT_PIECE_LIFETIME = 1.2
local HIT_PIECE_MIN_SIZE = 0.35
local HIT_PIECE_MAX_SIZE = 0.7
local BRAINROT_REVEAL_HEIGHT_OFFSET = 0.05
local BRAINROT_REVEAL_START_SCALE = 0.08
local BRAINROT_REVEAL_PEAK_SCALE = 1.02
local BRAINROT_REVEAL_LOW_SCALE = 0.92
local BRAINROT_REVEAL_TOTAL_CYCLES_MIN = 13
local BRAINROT_REVEAL_TOTAL_CYCLES_MAX = 19
local BRAINROT_REVEAL_START_DELAY = 0.06
local BRAINROT_REVEAL_END_DELAY = 0.32
local BRAINROT_REVEAL_FINAL_HOLD = 1.5
local BRAINROT_REVEAL_TRANSITION_OVERLAP = 0.09

local random = Random.new()

local LuckyBlockController = Knit.CreateController({
	Name = "LuckyBlockController",
})

function LuckyBlockController:ConnectDebrisCollected(callback: () -> ())
	return self._debrisCollectedEvent.Event:Connect(callback)
end

function LuckyBlockController:ConnectBlockBroken(callback: () -> ())
	return self._blockBrokenEvent.Event:Connect(callback)
end

function LuckyBlockController:_createBillboard(block: Model, adornee: BasePart)
	local _, size = block:GetBoundingBox()
	local blockPos = block:GetPivot().Position
	local attachmentPos = blockPos + Vector3.new(0, size.Y / 2, 0)

	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.new(attachmentPos)
	attachment.Parent = workspace.Terrain

	local scaleTarget = source(0)
	self._scaleTargets[block] = scaleTarget
	local healthFractionTarget = source(1)
	self._healthFractionTargets[block] = healthFractionTarget
	local progressPulseTarget = source(1)
	self._progressPulseTargets[block] = progressPulseTarget
	local timeLeftTarget = source(0)
	self._timeLeftTargets[block] = timeLeftTarget
	local rarityTarget = source(LuckyBlockRarityConstants.DEFAULT)
	self._rarityTargets[block] = rarityTarget
	local rarityColorTarget = source(LuckyBlockRarityConstants.getColor(LuckyBlockRarityConstants.DEFAULT))
	self._rarityColorTargets[block] = rarityColorTarget
	local rarityStrokeColorTarget = source(LuckyBlockRarityConstants.getStrokeColor(LuckyBlockRarityConstants.DEFAULT))
	self._rarityStrokeColorTargets[block] = rarityStrokeColorTarget
	local rarityGradientTarget = source(LuckyBlockRarityConstants.getGradient(LuckyBlockRarityConstants.DEFAULT))
	self._rarityGradientTargets[block] = rarityGradientTarget
	local indicatorVisibleTarget = source(0)
	self._indicatorVisibleTargets[block] = indicatorVisibleTarget
	local trailHealthFractionTarget = source(1)
	self._trailHealthFractionTargets[block] = trailHealthFractionTarget

	local destroy = root(function()
		local animatedScale = spring(scaleTarget, 0.3, 0.6)
		local animatedHealthFraction = spring(healthFractionTarget, 0.14, 1.05)
		local animatedTrailHealthFraction = spring(trailHealthFractionTarget, 0.3, 1.5)
		local animatedProgressPulse = spring(progressPulseTarget, 0.12, 1)

		create("BillboardGui")({
			Name = "BillboardGui",
			Active = true,
			Brightness = 1.5,
			MaxDistance = 100,
			ResetOnSpawn = false,
			Size = function()
				local s = animatedScale()
				return UDim2.fromScale(BILLBOARD_SIZE.X.Scale * s, BILLBOARD_SIZE.Y.Scale * s)
			end,
			StudsOffsetWorldSpace = Vector3.new(0, 6, 0),
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = attachment,

			create("Frame")({
				Name = "Inner",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),

				create("UIListLayout")({
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				}),

				--[[ create "TextLabel" {
					Name = "Mutation",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					LayoutOrder = -4,
					Size = UDim2.fromScale(1, 0.2),
					Text = "Gold",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 94, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 217, 0)),
						}),
						Rotation = -90,
					},

					create "UIStroke" {
						Name = "UIStroke",
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					},
				}, ]]

				create("TextLabel")({
					Name = "Name",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					LayoutOrder = -3,
					Size = UDim2.fromScale(1, 0.2),
					Text = block.Name,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create("UIGradient")({
						Name = "UIGradient",
						Color = function()
							return rarityGradientTarget()
						end,
						Rotation = -90,
					}),

					create("UIStroke")({
						Name = "UIStroke",
						Color = function()
							return rarityStrokeColorTarget()
						end,
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					}),
				}),

				create("TextLabel")({
					Name = "Rarity",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					LayoutOrder = -2,
					Size = UDim2.fromScale(1, 0.2),
					Text = function()
						return rarityTarget()
					end,
					TextColor3 = function()
						return rarityColorTarget()
					end,
					TextScaled = true,

					create("UIStroke")({
						Name = "UIStroke",
						Color = function()
							return rarityStrokeColorTarget()
						end,
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					}),
				}),

				--[[ create("TextLabel")({
					Name = "Earnings",
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					LayoutOrder = -1,
					Size = UDim2.fromScale(1, 0.2),
					Text = "$30/s",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 255, 0)),
						}),
						Rotation = -90,
					}),

					create("UIStroke")({
						Name = "UIStroke",
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					}),
				}), ]]

				create("Frame")({
					Name = "TimeLeft",
					BackgroundTransparency = 1,
					LayoutOrder = -5,
					Size = UDim2.fromScale(0.5, 0.2),

					create("ImageLabel")({
						Name = "ImageLabel",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://89665851185071",
						LayoutOrder = -1,
						Position = UDim2.fromScale(0, 0.5),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.3, 1),
					}),

					create("TextLabel")({
						Name = "TimeLeft",
						AnchorPoint = Vector2.new(0.5, 0.5),
						BackgroundTransparency = 1,
						FontFace = Font.new(
							"rbxasset://fonts/families/GothamSSm.json",
							Enum.FontWeight.Heavy,
							Enum.FontStyle.Normal
						),
						LayoutOrder = 2,
						Size = UDim2.fromScale(0.5, 1),
						Text = function()
							return `{math.ceil(math.max(0, timeLeftTarget()))}s`
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create("UIGradient")({
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 85, 255)),
							}),
							Rotation = -90,
						}),

						create("UIStroke")({
							Name = "UIStroke",
							LineJoinMode = Enum.LineJoinMode.Miter,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.05,
						}),
					}),

					create("UIListLayout")({
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.05, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					}),
				}),

				create("Frame")({
					Name = "ProgressBar",
					BackgroundColor3 = Color3.fromRGB(23, 29, 38),
					BackgroundTransparency = 0.15,
					LayoutOrder = 1,
					Size = function()
						local scale = animatedProgressPulse()
						return UDim2.fromScale(0.85 * scale, 0.13 * scale)
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
							return UDim2.fromScale(math.clamp(animatedTrailHealthFraction(), 0, 1) * 0.98, 0.84)
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
								local fraction = math.clamp(animatedTrailHealthFraction(), 0.001, 1)
								return UDim2.fromScale(1 / fraction, 1)
							end,
							TileSize = UDim2.fromScale(0.08, 0.8),

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
							return UDim2.fromScale(math.clamp(animatedHealthFraction(), 0, 1) * 0.98, 0.84)
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
								local fraction = math.clamp(animatedHealthFraction(), 0.001, 1)
								return UDim2.fromScale(1 / fraction, 1)
							end,
							TileSize = UDim2.fromScale(0.08, 0.8),

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
							return `{math.floor(math.clamp(animatedHealthFraction(), 0, 1) * 100 + 0.5)}%`
						end,
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						ZIndex = 2,

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

	local indicatorPart = Instance.new("Part")
	indicatorPart.Name = "LuckyBlockIndicator"
	indicatorPart.Anchored = true
	indicatorPart.CanCollide = false
	indicatorPart.CanQuery = false
	indicatorPart.CanTouch = false
	indicatorPart.Size = Vector3.new(INDICATOR_SIZE, 0.05, INDICATOR_SIZE)
	indicatorPart.Transparency = 1
	indicatorPart.CFrame = CFrame.new(blockPos - Vector3.new(0, size.Y / 2 - INDICATOR_HEIGHT_OFFSET, 0))
		* CFrame.Angles(0, 0, 0)
	indicatorPart.Parent = workspace

	local indicatorDestroy = root(function()
		local animatedVisible = spring(indicatorVisibleTarget, 0.3, 0.7)

		create("SurfaceGui")({
			Name = "IndicatorGui",
			Face = Enum.NormalId.Top,
			Brightness = 1.5,
			LightInfluence = 0,
			MaxDistance = 50,
			PixelsPerStud = 100,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			Parent = indicatorPart,

			create("ImageLabel")({
				Name = "Circle",
				BackgroundTransparency = 1,
				Image = INDICATOR_IMAGE,
				ImageColor3 = Color3.new(1, 1, 1),
				ImageTransparency = function()
					return 1 - math.clamp(animatedVisible(), 0, 1)
				end,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = function()
					local s = math.clamp(animatedVisible(), 0, 1)
					return UDim2.fromScale(s, s)
				end,
				ScaleType = Enum.ScaleType.Fit,
			}),
		})
	end)

	self._uiRoots[block] = {
		destroy = destroy,
		attachment = attachment,
		indicatorPart = indicatorPart,
		indicatorDestroy = indicatorDestroy,
	}
	self:_updateHealthForBlock(block)
	self:_updateTimeLeftForBlock(block)
	self:_updateRarityForBlock(block)
	self:_pulseProgressBar(block)
end

function LuckyBlockController:_setupCollectBillboard(hrp: BasePart)
	self:_cleanupCollectBillboard()

	local attachment = Instance.new("Attachment")
	attachment.Name = "LuckyBlockCollectAttachment"
	attachment.Position = Vector3.new(0, 0, 0)
	attachment.Parent = hrp

	local visibleTarget = source(0)
	local pulseTarget = source(1)
	local countTarget = source(0)
	local faceTarget = source(0)
	self._collectVisibleTarget = visibleTarget
	self._collectPulseTarget = pulseTarget
	self._collectCountTarget = countTarget
	self._collectFaceTarget = faceTarget
	self._collectCount = 0
	self._collectTextVersion = 0

	local destroy = root(function()
		local animatedVisible = spring(visibleTarget, 0.22, 0.95)
		local animatedPulse = spring(pulseTarget, 0.14, 1)
		local animatedFace = spring(faceTarget, 0.22, 0.9)

		create("BillboardGui")({
			Name = "CollectBillboardGui",
			Active = false,
			AlwaysOnTop = true,
			Brightness = 1.5,
			MaxDistance = 100,
			ResetOnSpawn = false,
			Size = function()
				local pulse = animatedPulse()
				return UDim2.fromScale(COLLECT_BILLBOARD_SIZE.X.Scale * pulse, COLLECT_BILLBOARD_SIZE.Y.Scale * pulse)
			end,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			Parent = attachment,

			create("Frame")({
				Name = "CollectRow",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = function()
					return animatedFace()
				end,
				Size = UDim2.fromScale(1, 1),

				create("UIListLayout")({
					Name = "UIListLayout",
					FillDirection = Enum.FillDirection.Horizontal,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0.03, 0),
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),

				create("ImageLabel")({
					Name = "Icon",
					BackgroundTransparency = 1,
					Image = "rbxassetid://86094156392599",
					ImageTransparency = function()
						return 1 - math.clamp(animatedVisible(), 0, 1)
					end,
					LayoutOrder = 1,
					ScaleType = Enum.ScaleType.Fit,
					Size = UDim2.fromScale(0.66, 1),
				}),

				create("TextLabel")({
					Name = "CollectText",
					BackgroundTransparency = 1,
					FontFace = Font.new(
						"rbxasset://fonts/families/FredokaOne.json",
						Enum.FontWeight.Heavy,
						Enum.FontStyle.Normal
					),
					LayoutOrder = 2,
					Size = UDim2.fromScale(0.74, 1),
					Text = function()
						local count = countTarget()
						if count <= 0 then
							return ""
						end
						return `+{count}`
					end,
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					TextTransparency = function()
						return 1 - math.clamp(animatedVisible(), 0, 1)
					end,

					create("UIGradient")({
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 248, 177)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 232, 125)),
						}),
						Rotation = -90,
					}),

					create("UIStroke")({
						Name = "UIStroke",
						Color = Color3.fromRGB(0, 0, 0),
						LineJoinMode = Enum.LineJoinMode.Round,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.06,
						Transparency = function()
							return 0.15 + (1 - math.clamp(animatedVisible(), 0, 1)) * 0.85
						end,
					}),
				}),
			}),
		})
	end)

	self._collectUiRoot = { destroy = destroy, attachment = attachment }
end

function LuckyBlockController:_cleanupCollectBillboard()
	if self._collectUiRoot then
		self._collectUiRoot.destroy()
		self._collectUiRoot.attachment:Destroy()
		self._collectUiRoot = nil
	end

	self._collectVisibleTarget = nil
	self._collectPulseTarget = nil
	self._collectCountTarget = nil
	self._collectFaceTarget = nil
	self._collectCount = 0
	self._collectTextVersion = (self._collectTextVersion or 0) + 1
end

function LuckyBlockController:_onDebrisCollected()
	if self._debrisCollectedEvent then
		self._debrisCollectedEvent:Fire()
	end

	local visibleTarget = self._collectVisibleTarget
	local pulseTarget = self._collectPulseTarget
	local countTarget = self._collectCountTarget
	if not visibleTarget or not pulseTarget or not countTarget then
		return
	end

	self._collectCount += 1
	countTarget(self._collectCount)
	visibleTarget(1)
	pulseTarget(1.14)

	task.delay(0.06, function()
		if self._collectPulseTarget == pulseTarget then
			pulseTarget(1)
		end
	end)

	local version = (self._collectTextVersion or 0) + 1
	self._collectTextVersion = version
	task.delay(COLLECT_TEXT_FADE_DELAY, function()
		if self._collectTextVersion ~= version then
			return
		end

		visibleTarget(0)
		task.delay(COLLECT_TEXT_FADE_CLEAR_DELAY, function()
			if self._collectTextVersion ~= version then
				return
			end
			self._collectCount = 0
			countTarget(0)
		end)
	end)
end

function LuckyBlockController:_pulseProgressBar(block: Model)
	local pulseTarget = self._progressPulseTargets[block]
	if not pulseTarget then
		return
	end

	pulseTarget(1.04)
	task.delay(0.03, function()
		if self._progressPulseTargets[block] ~= pulseTarget then
			return
		end
		pulseTarget(1)
	end)
end

function LuckyBlockController:_updateHealthForBlock(block: Model)
	local target = self._healthFractionTargets[block]
	if not target then
		return
	end

	local maxHealth = block:GetAttribute("MaxHealth")
	local health = block:GetAttribute("Health")
	if typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		maxHealth = MAX_HEALTH_FALLBACK
	end
	if typeof(health) ~= "number" then
		health = maxHealth
	end

	local fraction = math.clamp(health / maxHealth, 0, 1)
	target(fraction)

	local trailTarget = self._trailHealthFractionTargets[block]
	if trailTarget then
		local version = (self._trailVersions[block] or 0) + 1
		self._trailVersions[block] = version
		task.delay(0.15, function()
			if self._trailVersions[block] ~= version then
				return
			end
			trailTarget(fraction)
		end)
	end
end

function LuckyBlockController:_updateTimeLeftForBlock(block: Model)
	local target = self._timeLeftTargets[block]
	if not target then
		return
	end

	local despawnAt = block:GetAttribute("DespawnAt")
	if typeof(despawnAt) ~= "number" then
		target(0)
		return
	end

	target(math.max(0, despawnAt - workspace:GetServerTimeNow()))
end

function LuckyBlockController:_updateRarityForBlock(block: Model)
	local rarityTarget = self._rarityTargets[block]
	local rarityColorTarget = self._rarityColorTargets[block]
	local rarityStrokeColorTarget = self._rarityStrokeColorTargets[block]
	local rarityGradientTarget = self._rarityGradientTargets[block]
	if not rarityTarget or not rarityColorTarget or not rarityStrokeColorTarget or not rarityGradientTarget then
		return
	end

	local rarity = LuckyBlockRarityConstants.normalizeRarity(block:GetAttribute("Rarity") :: string?)
	rarityTarget(rarity)
	rarityColorTarget(LuckyBlockRarityConstants.getColor(rarity))
	rarityStrokeColorTarget(LuckyBlockRarityConstants.getStrokeColor(rarity))
	rarityGradientTarget(LuckyBlockRarityConstants.getGradient(rarity))
end

function LuckyBlockController:_setupBlock(block: Model)
	local adornee = block.PrimaryPart or block:FindFirstChildWhichIsA("BasePart", true)
	if adornee then
		self:_createBillboard(block, adornee)
	else
		-- Parts haven't loaded yet; wait for the first BasePart to appear
		local conn
		conn = block.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("BasePart") then
				conn:Disconnect()
				self:_createBillboard(block, descendant)
			end
		end)
		self._pendingConn = self._pendingConn or {}
		self._pendingConn[block] = conn
	end

	self._healthConns[block] = {
		block:GetAttributeChangedSignal("Health"):Connect(function()
			self:_updateHealthForBlock(block)
			self:_pulseProgressBar(block)
		end),
		block:GetAttributeChangedSignal("MaxHealth"):Connect(function()
			self:_updateHealthForBlock(block)
		end),
		block:GetAttributeChangedSignal("DespawnAt"):Connect(function()
			self:_updateTimeLeftForBlock(block)
		end),
		block:GetAttributeChangedSignal("Rarity"):Connect(function()
			self:_updateRarityForBlock(block)
		end),
	}
end

function LuckyBlockController:_cleanupBlock(block: Model)
	local entry = self._uiRoots[block]
	if entry then
		entry.destroy()
		entry.attachment:Destroy()
		if entry.indicatorDestroy then
			entry.indicatorDestroy()
		end
		if entry.indicatorPart then
			entry.indicatorPart:Destroy()
		end
		self._uiRoots[block] = nil
	end
	self._scaleTargets[block] = nil
	self._healthFractionTargets[block] = nil
	self._progressPulseTargets[block] = nil
	self._timeLeftTargets[block] = nil
	self._rarityTargets[block] = nil
	self._rarityColorTargets[block] = nil
	self._rarityStrokeColorTargets[block] = nil
	self._rarityGradientTargets[block] = nil
	self._indicatorVisibleTargets[block] = nil
	self._trailHealthFractionTargets[block] = nil
	self._trailVersions[block] = nil
	if self._pendingConn and self._pendingConn[block] then
		self._pendingConn[block]:Disconnect()
		self._pendingConn[block] = nil
	end
	if self._healthConns[block] then
		for _, conn in self._healthConns[block] do
			conn:Disconnect()
		end
		self._healthConns[block] = nil
	end
	if self._highlightedBlock == block then
		if self._highlight then
			self._highlight:Destroy()
			self._highlight = nil
		end
		self._highlightedBlock = nil
	end
end

function LuckyBlockController:_getClosestBlock(characterPosition: Vector3): (Model?, number)
	local blocks = self._blocks
	local closestBlock: Model? = nil
	local closestSq = math.huge

	for i = 1, #blocks do
		local block = blocks[i]
		local delta = block:GetPivot().Position - characterPosition
		local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z

		if distSq < closestSq then
			closestSq = distSq
			closestBlock = block
		end
	end

	return closestBlock, closestSq
end

function LuckyBlockController:_cacheBlocks()
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plotsFolder then
		for _, block in self._blocks do
			self:_cleanupBlock(block)
		end
		self._blocks = {}
		return
	end

	local blocks = {}
	local current = {}

	for _, plot in plotsFolder:GetChildren() do
		for _, child in plot:GetChildren() do
			if child:IsA("Model") then
				blocks[#blocks + 1] = child
				current[child] = true

				if not self._uiRoots[child] and not (self._pendingConn and self._pendingConn[child]) then
					self:_setupBlock(child)
				end
			end
		end
	end

	for _, block in self._blocks do
		if not current[block] then
			self:_cleanupBlock(block)
		end
	end

	self._blocks = blocks
end

function LuckyBlockController:_getOriginals(block: Model)
	local data = self._originals[block]
	if not data then
		local pivot = block:GetPivot()
		local scale = block:GetScale()
		-- Half-height from pivot to bottom of the bounding box
		local _, size = block:GetBoundingBox()
		local halfHeight = size.Y / 2
		data = { pivot = pivot, scale = scale, halfHeight = halfHeight }
		self._originals[block] = data
	end
	return data
end

-- Compute a pivot offset so the bottom of the block stays on the floor
-- when the scale changes. ScaleTo scales from the pivot, so growing by
-- a factor means the bottom drops by halfHeight * (factor - 1).
function LuckyBlockController:_pivotForScale(originals, scaleFactor: number, nudge: Vector3?): CFrame
	local liftCompensation = originals.halfHeight * (scaleFactor - 1)
	local offset = Vector3.new(0, liftCompensation, 0)
	if nudge then
		offset += nudge
	end
	return originals.pivot + offset
end

function LuckyBlockController:_spawnDebris(block: Model, blockPosition: Vector3, count: number)
	local blockColors = {}
	for _, descendant in block:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(blockColors, descendant.Color)
		end
	end

	for i = 1, count do
		task.delay((i - 1) * DEBRIS_STAGGER_TIME, function()
			local debris = DEBRIS_TEMPLATE:Clone()
			debris.Anchored = true
			debris.CanCollide = false
			if #blockColors > 0 then
				debris.Color = blockColors[random:NextInteger(1, #blockColors)]
			end
			debris.CFrame = CFrame.new(blockPosition)
			debris.Parent = workspace

			-- Random launch velocity: outward + upward
			local angle = random:NextNumber(0, math.pi * 2)
			local horizontalSpeed = random:NextNumber(10, 25)
			local verticalSpeed = random:NextNumber(35, 55)
			local velocity =
				Vector3.new(math.cos(angle) * horizontalSpeed, verticalSpeed, math.sin(angle) * horizontalSpeed)

			local originalSize = debris.Size
			local elapsed = 0
			local pulling = false
			local connection
			connection = RunService.Heartbeat:Connect(function(dt)
				if not debris.Parent then
					connection:Disconnect()
					return
				end

				elapsed += dt
				local pos = debris.Position

				if not pulling then
					-- Launch phase: move outward with simple gravity
					velocity += Vector3.new(0, -196.2 * dt, 0)
					pos += velocity * dt
					debris.CFrame = CFrame.new(pos)
						* CFrame.Angles(
							random:NextNumber(-0.5, 0.5) * dt,
							random:NextNumber(-0.5, 0.5) * dt,
							random:NextNumber(-0.5, 0.5) * dt
						)
						* (debris.CFrame - debris.Position)

					if elapsed >= DEBRIS_LAUNCH_TIME then
						pulling = true
					end
				else
					-- Pull phase: accelerate toward the player's HRP
					local hrp = self._hrp
					if not hrp then
						debris:Destroy()
						connection:Disconnect()
						return
					end

					local target = hrp.Position
					local delta = target - pos
					local dist = delta.Magnitude

					if dist < 0.01 then
						debris:Destroy()
						connection:Disconnect()
						return
					end

					local dir = delta / dist

					-- Accelerate toward player, building up speed
					velocity = velocity + dir * DEBRIS_PULL_ACCEL * dt
					-- Kill sideways velocity aggressively so it doesn't overshoot
					local towardComponent = velocity:Dot(dir) * dir
					local sideways = velocity - towardComponent
					velocity = towardComponent + sideways * math.max(0, 1 - 15 * dt)

					pos += velocity * dt
					debris.CFrame = CFrame.new(pos)

					-- Shrink as it gets close
					local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
					if distSq < DEBRIS_COLLECT_DIST_SQ then
						local alpha = math.sqrt(distSq / DEBRIS_COLLECT_DIST_SQ)
						debris.Size = originalSize * alpha

						if distSq < 0.25 then
							self:_impulseFov()
							SoundUtil.playFromSoundsFolder("BlockSound")
							self:_onDebrisCollected()
							debris:Destroy()
							connection:Disconnect()
						end
					end
				end
			end)
		end)
	end
end

function LuckyBlockController:_impulseFov()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	if self._baseFov == nil then
		self._baseFov = camera.FieldOfView
	end

	local version = (self._fovImpulseVersion or 0) + 1
	self._fovImpulseVersion = version

	spr.target(camera, 0.5, 9, {
		FieldOfView = self._baseFov + FOV_IMPULSE_AMOUNT,
	})

	task.delay(FOV_IMPULSE_HOLD, function()
		if self._fovImpulseVersion ~= version then
			return
		end

		spr.target(camera, 0.75, 5, {
			FieldOfView = self._baseFov,
		})
	end)
end

function LuckyBlockController:_animateBlock(block: Model, playerPosition: Vector3, debrisCount: number)
	local orig = self:_getOriginals(block)

	-- Cancel any in-flight springs and reset to rest pose instantly
	spr.stop(block)
	block:ScaleTo(orig.scale)
	block:PivotTo(orig.pivot)

	-- Spawn debris from the block's position
	self:_spawnDebris(block, orig.pivot.Position, debrisCount)

	-- Camera shake on hit
	self._cameraShake:Shake(0.3, 0.15, 25)

	-- Subtle nudge away from player
	local awayDir = (orig.pivot.Position - playerPosition) * Vector3.new(1, 0, 1)
	if awayDir.Magnitude < 0.01 then
		awayDir = Vector3.new(1, 0, 0)
	else
		awayDir = awayDir.Unit
	end
	local nudge = awayDir * random:NextNumber(0.3, 0.6)

	-- Bump the animation version so stale task.delays become no-ops
	local version = (self._animVersion[block] or 0) + 1
	self._animVersion[block] = version

	-- Randomize per hit
	local squishFlat = random:NextNumber(0.5, 0.65)
	local stretchTall = random:NextNumber(1.2, 1.4)
	local landingSquish = random:NextNumber(0.7, 0.8)

	-- Random rotation offset that persists after this hit (X axis only)
	local rotX = math.rad(random:NextNumber(-15, 15))
	local restPivot = orig.pivot * CFrame.Angles(rotX, 0, 0)

	-- Update stored originals so next hit builds on this rotation
	orig.pivot = restPivot

	-- Phase 1: Squish down (impact compression) + nudge away
	spr.target(block, 1, 25, {
		Scale = orig.scale * squishFlat,
		Pivot = self:_pivotForScale(orig, squishFlat, nudge),
	})

	-- Phase 2: Stretch tall (rebound)
	task.delay(0.08, function()
		if self._animVersion[block] ~= version then
			return
		end
		spr.target(block, 1, 18, {
			Scale = orig.scale * stretchTall,
			Pivot = self:_pivotForScale(orig, stretchTall),
		})
	end)

	-- Phase 3: Subtle float upward (very slight lift)
	local floatHeight = random:NextNumber(0.3, 0.5)
	task.delay(0.18, function()
		if self._animVersion[block] ~= version then
			return
		end
		spr.target(block, 1, 14, {
			Scale = orig.scale,
			Pivot = restPivot + Vector3.new(0, floatHeight, 0),
		})
	end)

	-- Phase 4: Compress again (secondary bounce, back on ground)
	task.delay(0.3, function()
		if self._animVersion[block] ~= version then
			return
		end
		spr.target(block, 1, 20, {
			Scale = orig.scale * landingSquish,
			Pivot = self:_pivotForScale(orig, landingSquish),
		})
	end)

	-- Phase 5: Bouncy settle to new resting rotation (underdamped = wobbly)
	task.delay(0.4, function()
		if self._animVersion[block] ~= version then
			return
		end
		spr.target(block, 0.3, 5, {
			Scale = orig.scale,
			Pivot = restPivot,
		})
	end)
end

function LuckyBlockController:_spawnBreakEffect(block: Model, blockPosition: Vector3)
	local parts = {}
	for _, descendant in block:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	if #parts == 0 then
		return
	end

	for _ = 1, BREAK_PIECE_COUNT do
		local original = parts[random:NextInteger(1, #parts)]
		local piece = original:Clone()

		piece:ClearAllChildren()
		local s = random:NextNumber(BREAK_PIECE_MIN_SIZE, BREAK_PIECE_MAX_SIZE)
		piece.Size = Vector3.new(s, s, s)
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Transparency = 0

		local offset = Vector3.new(random:NextNumber(-1, 1), random:NextNumber(0, 0.5), random:NextNumber(-1, 1))
		piece.CFrame = CFrame.new(blockPosition + offset)
			* CFrame.Angles(
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2)
			)
		piece.Parent = workspace

		local angle = random:NextNumber(0, math.pi * 2)
		local hSpeed = random:NextNumber(12, 30)
		local vSpeed = random:NextNumber(35, 60)
		piece.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * hSpeed, vSpeed, math.sin(angle) * hSpeed)
		piece.AssemblyAngularVelocity =
			Vector3.new(random:NextNumber(-10, 10), random:NextNumber(-10, 10), random:NextNumber(-10, 10))

		task.delay(BREAK_PIECE_LIFETIME, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

function LuckyBlockController:_spawnHitEffect(block: Model, blockPosition: Vector3)
	local parts = {}
	for _, descendant in block:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	if #parts == 0 then
		return
	end

	for _ = 1, HIT_PIECE_COUNT do
		local original = parts[random:NextInteger(1, #parts)]
		local piece = original:Clone()

		piece:ClearAllChildren()
		local s = random:NextNumber(HIT_PIECE_MIN_SIZE, HIT_PIECE_MAX_SIZE)
		piece.Size = Vector3.new(s, s, s)
		piece.Anchored = false
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Transparency = 0

		local offset =
			Vector3.new(random:NextNumber(-0.5, 0.5), random:NextNumber(0, 0.3), random:NextNumber(-0.5, 0.5))
		piece.CFrame = CFrame.new(blockPosition + offset)
			* CFrame.Angles(
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2),
				random:NextNumber(0, math.pi * 2)
			)
		piece.Parent = workspace

		local angle = random:NextNumber(0, math.pi * 2)
		local hSpeed = random:NextNumber(8, 18)
		local vSpeed = random:NextNumber(25, 40)
		piece.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * hSpeed, vSpeed, math.sin(angle) * hSpeed)
		piece.AssemblyAngularVelocity =
			Vector3.new(random:NextNumber(-6, 6), random:NextNumber(-6, 6), random:NextNumber(-6, 6))

		task.delay(HIT_PIECE_LIFETIME, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

function LuckyBlockController:_resetBlockVisualToRest(block: Model)
	local orig = self._originals[block]
	if not orig then
		return
	end

	-- Cancel any in-flight local hit squash/stretch before server break animation starts.
	spr.stop(block)
	block:ScaleTo(orig.scale)
	block:PivotTo(orig.pivot)

	self._animVersion[block] = (self._animVersion[block] or 0) + 1
end

function LuckyBlockController:_setBrainrotDisplayPhysicalState(model: Model)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end
end

function LuckyBlockController:_shrinkAndDestroyBrainrot(model: Model)
	if not model or model.Parent == nil then
		return
	end

	local currentScale = model:GetScale()
	spr.stop(model)
	spr.target(model, 1, 9, {
		Scale = math.max(0.01, currentScale * 0.35),
	})

	task.delay(BRAINROT_REVEAL_TRANSITION_OVERLAP, function()
		if model.Parent then
			model:Destroy()
		end
	end)
end

function LuckyBlockController:_getNormalBrainrotTemplates(): { Model }
	if self._normalBrainrotTemplates then
		return self._normalBrainrotTemplates
	end

	local templates = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local normal = brainrots and brainrots:FindFirstChild("Normal")
	if normal then
		for _, child in normal:GetChildren() do
			if child:IsA("Model") then
				table.insert(templates, child)
			end
		end
	end

	self._normalBrainrotTemplates = templates
	return templates
end

function LuckyBlockController:_getModelBottomY(model: Model): number
	local minY = math.huge
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local halfX = descendant.Size.X * 0.5
			local halfY = descendant.Size.Y * 0.5
			local halfZ = descendant.Size.Z * 0.5
			local cf = descendant.CFrame
			local extentY = math.abs(cf.XVector.Y) * halfX
				+ math.abs(cf.YVector.Y) * halfY
				+ math.abs(cf.ZVector.Y) * halfZ
			local bottomY = cf.Position.Y - extentY
			if bottomY < minY then
				minY = bottomY
			end
		end
	end

	if minY == math.huge then
		return model:GetPivot().Position.Y
	end

	return minY
end

function LuckyBlockController:_getRevealFloorY(block: Model, blockPosition: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { block }
	params.IgnoreWater = true

	local castOrigin = blockPosition + Vector3.new(0, 12, 0)
	local castDirection = Vector3.new(0, -80, 0)
	local result = workspace:Raycast(castOrigin, castDirection, params)
	if result then
		return result.Position.Y + BRAINROT_REVEAL_HEIGHT_OFFSET
	end

	local _, blockSize = block:GetBoundingBox()
	return blockPosition.Y - blockSize.Y * 0.5 + BRAINROT_REVEAL_HEIGHT_OFFSET
end

function LuckyBlockController:_getRevealYawRotation(blockPosition: Vector3): CFrame
	local hrp = self._hrp
	if not hrp then
		return CFrame.new()
	end

	local toPlayer = hrp.Position - blockPosition
	local planar = Vector3.new(toPlayer.X, 0, toPlayer.Z)
	if planar.Magnitude < 0.001 then
		return CFrame.new()
	end

	return CFrame.lookAt(Vector3.zero, planar.Unit)
end

function LuckyBlockController:_playBrainrotRevealCycle(blockPosition: Vector3, floorY: number)
	local templates = self:_getNormalBrainrotTemplates()
	if #templates == 0 then
		return
	end

	local version = (self._brainrotRevealVersion or 0) + 1
	self._brainrotRevealVersion = version

	if self._brainrotRevealModel and self._brainrotRevealModel.Parent then
		self._brainrotRevealModel:Destroy()
	end
	self._brainrotRevealModel = nil

	local finalTemplate = templates[random:NextInteger(1, #templates)]
	local totalCycles = random:NextInteger(BRAINROT_REVEAL_TOTAL_CYCLES_MIN, BRAINROT_REVEAL_TOTAL_CYCLES_MAX)
	local activeModel = nil

	for i = 1, totalCycles do
		if self._brainrotRevealVersion ~= version then
			if activeModel and activeModel.Parent then
				activeModel:Destroy()
			end
			return
		end

		local isFinal = i == totalCycles
		local template = if isFinal then finalTemplate else templates[random:NextInteger(1, #templates)]
		local model = template:Clone()
		self:_setBrainrotDisplayPhysicalState(model)
		if not isFinal then
			local highlight = Instance.new("Highlight")
			highlight.FillColor = Color3.new(0, 0, 0)
			highlight.FillTransparency = 1
			highlight.OutlineColor = Color3.new(1, 1, 1)
			highlight.OutlineTransparency = 1
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Adornee = model
			highlight.Parent = model
			spr.target(highlight, 0.72, 8, {
				FillTransparency = 0,
				OutlineTransparency = 0,
			})
		end

		local baseScale = model:GetScale()
		local yawRotation = self:_getRevealYawRotation(blockPosition)
		model:PivotTo(CFrame.new(blockPosition) * yawRotation)
		model:ScaleTo(baseScale)

		local groundLift = floorY - self:_getModelBottomY(model)
		local groundedBasePivot = model:GetPivot() + Vector3.new(0, groundLift, 0)
		model:PivotTo(groundedBasePivot)

		local pivotToFloor = groundedBasePivot.Position.Y - floorY
		local function pivotForScale(targetScale: number): CFrame
			local scaleFactor = targetScale / math.max(baseScale, 0.001)
			local y = floorY + pivotToFloor * scaleFactor
			local pos = groundedBasePivot.Position
			return CFrame.new(pos.X, y, pos.Z) * yawRotation
		end

		model:ScaleTo(baseScale * BRAINROT_REVEAL_START_SCALE)
		model:PivotTo(pivotForScale(baseScale * BRAINROT_REVEAL_START_SCALE))
		model.Parent = workspace

		task.delay(0.1, function()
			SoundUtil.playDirectFromSoundsFolder("Tick")
		end)

		local previousModel = activeModel

		spr.stop(model)
		local firstTargetScale = if isFinal then baseScale else baseScale * BRAINROT_REVEAL_PEAK_SCALE
		spr.target(model, 0.72, 8, {
			Scale = firstTargetScale,
			Pivot = pivotForScale(firstTargetScale),
		})
		task.wait(0.045)
		if self._brainrotRevealVersion ~= version then
			model:Destroy()
			return
		end
		if not isFinal then
			spr.target(model, 0.85, 7, {
				Scale = baseScale * BRAINROT_REVEAL_LOW_SCALE,
				Pivot = pivotForScale(baseScale * BRAINROT_REVEAL_LOW_SCALE),
			})
		end
		if previousModel and previousModel.Parent then
			self:_shrinkAndDestroyBrainrot(previousModel)
		end

		activeModel = model
		self._brainrotRevealModel = model

		local alpha = (i - 1) / math.max(totalCycles - 1, 1)
		local delayDuration = BRAINROT_REVEAL_START_DELAY
			+ (BRAINROT_REVEAL_END_DELAY - BRAINROT_REVEAL_START_DELAY) * (alpha * alpha)
		task.wait(delayDuration)
	end

	if self._brainrotRevealVersion ~= version then
		if activeModel and activeModel.Parent then
			activeModel:Destroy()
		end
		return
	end

	task.delay(BRAINROT_REVEAL_FINAL_HOLD, function()
		if self._brainrotRevealVersion ~= version then
			return
		end
		local model = self._brainrotRevealModel
		if model and model.Parent then
			model:Destroy()
		end
		self._brainrotRevealModel = nil
	end)
end

function LuckyBlockController:_onInput()
	local hrp = self._hrp
	if not hrp then
		return
	end

	local blocks = self._blocks
	if #blocks == 0 then
		return
	end

	local closestBlock, closestSq = self:_getClosestBlock(hrp.Position)

	if closestBlock and closestSq <= DETECTION_RANGE_SQ then
		if self._luckyBlockService then
			local character = Players.LocalPlayer.Character
			if character then
				local tool = character:FindFirstChildOfClass("Tool")
				if
					not tool
					or typeof(tool:GetAttribute("Strength")) ~= "number"
					or tool:GetAttribute("Strength") <= 0
				then
					self._notificationController:Show(
						"Equip a Pickaxe!",
						nil,
						ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 30, 30)),
						}),
						Color3.fromRGB(100, 0, 0)
					)
					return
				end
			end

			local blockPosition = closestBlock:GetPivot().Position
			local revealFloorY = self:_getRevealFloorY(closestBlock, blockPosition)
			self._luckyBlockService:TryHitBlock(closestBlock):andThen(function(ok, broke, blocksAwarded)
				if ok then
					SoundUtil.playFromSoundsFolder("BlockImpact")
					if broke then
						SoundUtil.playFromSoundsFolder("BlockReward")
						self:_spawnBreakEffect(closestBlock, blockPosition)
						self:_spawnDebris(closestBlock, blockPosition, blocksAwarded or 1)
						task.spawn(function()
							self:_playBrainrotRevealCycle(blockPosition, revealFloorY)
						end)
						self:_resetBlockVisualToRest(closestBlock)
						self._blockBrokenEvent:Fire(
							closestBlock.Name,
							LuckyBlockRarityConstants.normalizeRarity(closestBlock:GetAttribute("Rarity"))
						)
					else
						self:_spawnHitEffect(closestBlock, blockPosition)
						self:_animateBlock(closestBlock, hrp.Position, blocksAwarded or 1)
					end
				end
			end)
		end
	end
end

function LuckyBlockController:_watchPlot(plot: Instance)
	if self._watchedContainers[plot] then
		return
	end

	local conn1 = plot.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			self:_cacheBlocks()
		end
	end)

	local conn2 = plot.ChildRemoved:Connect(function(child)
		if child:IsA("Model") then
			self:_cacheBlocks()
		end
	end)

	self._watchedContainers[plot] = { conn1, conn2 }
end

function LuckyBlockController:KnitInit()
	self._blocks = {}
	self._hrp = nil
	self._originals = {}
	self._animVersion = {}
	self._uiRoots = {}
	self._scaleTargets = {}
	self._healthFractionTargets = {}
	self._progressPulseTargets = {}
	self._timeLeftTargets = {}
	self._rarityTargets = {}
	self._rarityColorTargets = {}
	self._rarityStrokeColorTargets = {}
	self._rarityGradientTargets = {}
	self._indicatorVisibleTargets = {}
	self._trailHealthFractionTargets = {}
	self._trailVersions = {}
	self._healthConns = {}
	self._watchedContainers = {}
	self._cameraShake = nil
	self._baseFov = nil
	self._fovImpulseVersion = 0
	self._luckyBlockService = nil
	self._collectUiRoot = nil
	self._collectVisibleTarget = nil
	self._collectPulseTarget = nil
	self._collectCountTarget = nil
	self._collectFaceTarget = nil
	self._collectCount = 0
	self._collectTextVersion = 0
	self._highlightedBlock = nil
	self._highlight = nil
	self._normalBrainrotTemplates = nil
	self._brainrotRevealVersion = 0
	self._brainrotRevealModel = nil
	self._debrisCollectedEvent = Instance.new("BindableEvent")
	self._blockBrokenEvent = Instance.new("BindableEvent")
end

function LuckyBlockController:KnitStart()
	self._cameraShake = Knit.GetController("CameraShakeController")
	self._notificationController = Knit.GetController("NotificationController")
	self._luckyBlockService = Knit.GetService("LuckyBlockService")
	local camera = workspace.CurrentCamera
	if camera then
		self._baseFov = camera.FieldOfView
	end

	local player = Players.LocalPlayer

	-- Cache HumanoidRootPart reference on character spawn
	local function onCharacterAdded(character: Model)
		self._hrp = character:WaitForChild("HumanoidRootPart")
		self:_setupCollectBillboard(self._hrp)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	player.CharacterRemoving:Connect(function()
		self:_cleanupCollectBillboard()
		self._hrp = nil
	end)

	self:_cacheBlocks()

	local plotsFolder = workspace:FindFirstChild("Plots")
	if plotsFolder then
		for _, plot in plotsFolder:GetChildren() do
			self:_watchPlot(plot)
		end
	end

	-- Update billboard visibility based on proximity + face nearest block when in range
	RunService.Heartbeat:Connect(function(dt)
		for _, block in self._blocks do
			self:_updateTimeLeftForBlock(block)
		end

		local hrp = self._hrp
		if not hrp then
			return
		end

		local playerPos = hrp.Position
		local faceTarget = self._collectFaceTarget
		if faceTarget then
			local camera = workspace.CurrentCamera
			if camera then
				local toCamera = camera.CFrame.Position - playerPos
				local planar = Vector3.new(toCamera.X, 0, toCamera.Z)
				if planar.Magnitude > 0.001 then
					local right = Vector3.new(hrp.CFrame.RightVector.X, 0, hrp.CFrame.RightVector.Z)
					if right.Magnitude > 0.001 then
						local side = right.Unit:Dot(planar.Unit)
						faceTarget(math.clamp(side * 10, -10, 10))
					end
				end
			end
		end

		for _, block in self._blocks do
			local scaleTarget = self._scaleTargets[block]
			local indicatorTarget = self._indicatorVisibleTargets[block]
			if scaleTarget then
				if block:GetAttribute("IsBreaking") == true then
					scaleTarget(0)
					if indicatorTarget then
						indicatorTarget(0)
					end
				else
					local delta = block:GetPivot().Position - playerPos
					local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
					scaleTarget(if distSq <= BILLBOARD_RANGE_SQ then 1 else 0)
					if indicatorTarget then
						indicatorTarget(if distSq <= DETECTION_RANGE_SQ then 1 else 0)
					end
				end
			end
		end

		-- Face the closest block when within break range
		local closestBlock, closestSq = self:_getClosestBlock(playerPos)
		if closestBlock and closestSq <= DETECTION_RANGE_SQ then
			local blockPos = closestBlock:GetPivot().Position
			local targetDir = Vector3.new(blockPos.X - playerPos.X, 0, blockPos.Z - playerPos.Z)
			local humanoid = hrp.Parent and hrp.Parent:FindFirstChildWhichIsA("Humanoid")
			if humanoid and targetDir.Magnitude > 0.01 then
				local currentDir = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
				if currentDir.Magnitude < 0.001 then
					currentDir = targetDir
				end

				local blendAlpha = 1 - math.exp(-LOCK_ON_TURN_RESPONSE * dt)
				local blendedDir = currentDir.Unit:Lerp(targetDir.Unit, math.clamp(blendAlpha, 0, 1))
				if blendedDir.Magnitude > 0.001 then
					hrp.CFrame = CFrame.lookAt(playerPos, playerPos + blendedDir.Unit)
				end
			end
		end

		-- Highlight the closest breakable block
		local targetBlock = if closestBlock and closestSq <= DETECTION_RANGE_SQ then closestBlock else nil
		if targetBlock ~= self._highlightedBlock then
			if self._highlight then
				self._highlight:Destroy()
				self._highlight = nil
			end
			self._highlightedBlock = targetBlock
			if targetBlock then
				local highlight = Instance.new("Highlight")
				highlight.FillColor = Color3.new(1, 1, 1)
				highlight.FillTransparency = 0.75
				highlight.OutlineColor = Color3.new(1, 1, 1)
				highlight.OutlineTransparency = 0
				highlight.Adornee = targetBlock
				highlight.Parent = targetBlock
				self._highlight = highlight
			end
		end
	end)

	-- Click (MouseButton1) or tap (Touch)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			self:_onInput()
		end
	end)
end

return LuckyBlockController

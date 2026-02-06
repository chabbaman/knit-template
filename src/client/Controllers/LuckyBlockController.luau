local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local spr = require(Shared.Spr)
local vide = require(Packages.Vide)
local create = vide.create
local source = vide.source
local spring = vide.spring
local root = vide.root

local BILLBOARD_RANGE_SQ = 30 * 30
local BILLBOARD_SIZE = UDim2.fromScale(10.125, 6.75)
local DETECTION_RANGE_SQ = 8 * 8
local DEBRIS_MIN = 1
local DEBRIS_MAX = 3
local DEBRIS_TEMPLATE = ReplicatedStorage.Assets.LuckyBlockDebris
local DEBRIS_LAUNCH_TIME = 0.15
local DEBRIS_PULL_ACCEL = 250
local DEBRIS_COLLECT_DIST_SQ = 3 * 3


local random = Random.new()

local LuckyBlockController = Knit.CreateController({
	Name = "LuckyBlockController",
})

function LuckyBlockController:_createBillboard(block: Model, adornee: BasePart)
	local _, size = block:GetBoundingBox()
	local blockPos = block:GetPivot().Position
	local attachmentPos = blockPos + Vector3.new(0, size.Y / 2, 0)

	local attachment = Instance.new("Attachment")
	attachment.CFrame = CFrame.new(attachmentPos)
	attachment.Parent = workspace.Terrain

	local scaleTarget = source(0)
	self._scaleTargets[block] = scaleTarget

	local destroy = root(function()
		local animatedScale = spring(scaleTarget, 0.3, 0.6)

		create "BillboardGui" {
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

			create "Frame" {
				Name = "Inner",
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),

				create "UIListLayout" {
					Name = "UIListLayout",
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					SortOrder = Enum.SortOrder.LayoutOrder,
					VerticalAlignment = Enum.VerticalAlignment.Center,
				},

				create "TextLabel" {
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
				},

				create "TextLabel" {
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
					Text = "OdinDinDinDun",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,
					ZIndex = 2,

					create "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(165, 196, 199)),
							ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
						}),
						Rotation = -90,
					},

					create "UIStroke" {
						Name = "UIStroke",
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					},
				},

				create "TextLabel" {
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
					Text = "Celestial",
					TextColor3 = Color3.new(1, 1, 1),
					TextScaled = true,

					create "UIStroke" {
						Name = "UIStroke",
						Color = Color3.new(1, 1, 1),
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					},
				},

				create "TextLabel" {
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

					create "UIGradient" {
						Name = "UIGradient",
						Color = ColorSequence.new({
							ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 255, 0)),
							ColorSequenceKeypoint.new(1, Color3.fromRGB(132, 255, 0)),
						}),
						Rotation = -90,
					},

					create "UIStroke" {
						Name = "UIStroke",
						LineJoinMode = Enum.LineJoinMode.Miter,
						StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
						Thickness = 0.05,
					},
				},

				create "Frame" {
					Name = "TimeLeft",
					BackgroundTransparency = 1,
					LayoutOrder = -5,
					Size = UDim2.fromScale(0.5, 0.2),

					create "ImageLabel" {
						Name = "ImageLabel",
						AnchorPoint = Vector2.new(0, 0.5),
						BackgroundTransparency = 1,
						Image = "rbxassetid://89665851185071",
						LayoutOrder = -1,
						Position = UDim2.fromScale(0, 0.5),
						ScaleType = Enum.ScaleType.Fit,
						Size = UDim2.fromScale(0.3, 1),
					},

					create "TextLabel" {
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
						Text = "60s",
						TextColor3 = Color3.new(1, 1, 1),
						TextScaled = true,
						TextXAlignment = Enum.TextXAlignment.Left,

						create "UIGradient" {
							Name = "UIGradient",
							Color = ColorSequence.new({
								ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 170, 255)),
								ColorSequenceKeypoint.new(1, Color3.fromRGB(85, 85, 255)),
							}),
							Rotation = -90,
						},

						create "UIStroke" {
							Name = "UIStroke",
							LineJoinMode = Enum.LineJoinMode.Miter,
							StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
							Thickness = 0.05,
						},
					},

					create "UIListLayout" {
						Name = "UIListLayout",
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						Padding = UDim.new(0.05, 0),
						SortOrder = Enum.SortOrder.LayoutOrder,
					},
				},
			},
		}
	end)

	self._uiRoots[block] = { destroy = destroy, attachment = attachment }
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
end

function LuckyBlockController:_cleanupBlock(block: Model)
	local entry = self._uiRoots[block]
	if entry then
		entry.destroy()
		entry.attachment:Destroy()
		self._uiRoots[block] = nil
	end
	self._scaleTargets[block] = nil
	if self._pendingConn and self._pendingConn[block] then
		self._pendingConn[block]:Disconnect()
		self._pendingConn[block] = nil
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
	local container = workspace:FindFirstChild("Lucky Blocks")
	if not container then
		-- Clean up any existing UIs
		for _, block in self._blocks do
			self:_cleanupBlock(block)
		end
		self._blocks = {}
		return
	end

	local blocks = {}
	local children = container:GetChildren()

	-- Track which blocks are still present
	local current = {}
	for i = 1, #children do
		local child = children[i]
		if child:IsA("Model") then
			blocks[#blocks + 1] = child
			current[child] = true

			-- Set up UI for new blocks
			if not self._uiRoots[child] and not (self._pendingConn and self._pendingConn[child]) then
				self:_setupBlock(child)
			end
		end
	end

	-- Clean up removed blocks
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

function LuckyBlockController:_spawnDebris(block: Model, blockPosition: Vector3)
	local count = random:NextInteger(DEBRIS_MIN, DEBRIS_MAX)
	for _ = 1, count do
		local debris = DEBRIS_TEMPLATE:Clone()
		debris.Anchored = true
		debris.CanCollide = false
		debris.CFrame = CFrame.new(blockPosition)
		debris.Parent = workspace

		-- Random launch velocity: outward + upward
		local angle = random:NextNumber(0, math.pi * 2)
		local horizontalSpeed = random:NextNumber(10, 25)
		local verticalSpeed = random:NextNumber(35, 55)
		local velocity = Vector3.new(
			math.cos(angle) * horizontalSpeed,
			verticalSpeed,
			math.sin(angle) * horizontalSpeed
		)

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
				debris.CFrame = CFrame.new(pos) * CFrame.Angles(
					random:NextNumber(-0.5, 0.5) * dt,
					random:NextNumber(-0.5, 0.5) * dt,
					random:NextNumber(-0.5, 0.5) * dt
				) * (debris.CFrame - debris.Position)

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
						debris:Destroy()
						connection:Disconnect()
					end
				end
			end
		end)
	end
end

function LuckyBlockController:_animateBlock(block: Model, playerPosition: Vector3)
	local orig = self:_getOriginals(block)

	-- Cancel any in-flight springs and reset to rest pose instantly
	spr.stop(block)
	block:ScaleTo(orig.scale)
	block:PivotTo(orig.pivot)

	-- Spawn debris from the block's position
	self:_spawnDebris(block, orig.pivot.Position)

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
		if self._animVersion[block] ~= version then return end
		spr.target(block, 1, 18, {
			Scale = orig.scale * stretchTall,
			Pivot = self:_pivotForScale(orig, stretchTall),
		})
	end)

	-- Phase 3: Subtle float upward (very slight lift)
	local floatHeight = random:NextNumber(0.3, 0.5)
	task.delay(0.18, function()
		if self._animVersion[block] ~= version then return end
		spr.target(block, 1, 14, {
			Scale = orig.scale,
			Pivot = restPivot + Vector3.new(0, floatHeight, 0),
		})
	end)

	-- Phase 4: Compress again (secondary bounce, back on ground)
	task.delay(0.3, function()
		if self._animVersion[block] ~= version then return end
		spr.target(block, 1, 20, {
			Scale = orig.scale * landingSquish,
			Pivot = self:_pivotForScale(orig, landingSquish),
		})
	end)

	-- Phase 5: Bouncy settle to new resting rotation (underdamped = wobbly)
	task.delay(0.4, function()
		if self._animVersion[block] ~= version then return end
		spr.target(block, 0.3, 5, {
			Scale = orig.scale,
			Pivot = restPivot,
		})
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
		print("You are near a Lucky Block!")
		self:_animateBlock(closestBlock, hrp.Position)
	end
end

function LuckyBlockController:KnitInit()
	self._blocks = {}
	self._hrp = nil
	self._originals = {}
	self._animVersion = {}
	self._uiRoots = {}
	self._scaleTargets = {}
	self._cameraShake = nil
end

function LuckyBlockController:KnitStart()
	self._cameraShake = Knit.GetController("CameraShakeController")

	local player = Players.LocalPlayer

	-- Cache HumanoidRootPart reference on character spawn
	local function onCharacterAdded(character: Model)
		self._hrp = character:WaitForChild("HumanoidRootPart")
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		task.spawn(onCharacterAdded, player.Character)
	end

	player.CharacterRemoving:Connect(function()
		self._hrp = nil
	end)

	-- Cache blocks and listen for changes
	self:_cacheBlocks()

	local container = workspace:FindFirstChild("Lucky Blocks")
	if container then
		container.ChildAdded:Connect(function()
			self:_cacheBlocks()
		end)

		container.ChildRemoved:Connect(function()
			self:_cacheBlocks()
		end)
	end

	-- Update billboard visibility based on proximity + face nearest block when in range
	RunService.Heartbeat:Connect(function()
		local hrp = self._hrp
		if not hrp then
			return
		end

		local playerPos = hrp.Position
		for _, block in self._blocks do
			local scaleTarget = self._scaleTargets[block]
			if scaleTarget then
				local delta = block:GetPivot().Position - playerPos
				local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
				scaleTarget(if distSq <= BILLBOARD_RANGE_SQ then 1 else 0)
			end
		end

		-- Face the closest block when within break range
		local closestBlock, closestSq = self:_getClosestBlock(playerPos)
		if closestBlock and closestSq <= DETECTION_RANGE_SQ then
			local blockPos = closestBlock:GetPivot().Position
			local lookAt = Vector3.new(blockPos.X, playerPos.Y, blockPos.Z)
			local humanoid = hrp.Parent and hrp.Parent:FindFirstChildWhichIsA("Humanoid")
			if humanoid and (lookAt - playerPos).Magnitude > 0.01 then
				hrp.CFrame = CFrame.lookAt(playerPos, lookAt)
			end
		end
	end)

	-- Click (MouseButton1) or tap (Touch)
	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end

		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self:_onInput()
		end
	end)
end

return LuckyBlockController

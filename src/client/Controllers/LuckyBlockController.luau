local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local spr = require(Shared.Spr)

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
		self._blocks = {}
		return
	end

	local blocks = {}
	local children = container:GetChildren()

	for i = 1, #children do
		if children[i]:IsA("Model") then
			blocks[#blocks + 1] = children[i]
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

	-- Phase 3: Compress again (secondary bounce)
	task.delay(0.2, function()
		if self._animVersion[block] ~= version then return end
		spr.target(block, 1, 20, {
			Scale = orig.scale * landingSquish,
			Pivot = self:_pivotForScale(orig, landingSquish),
		})
	end)

	-- Phase 4: Bouncy settle to original size (underdamped = wobbly)
	task.delay(0.3, function()
		if self._animVersion[block] ~= version then return end
		spr.target(block, 0.3, 5, {
			Scale = orig.scale,
			Pivot = orig.pivot,
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

end

function LuckyBlockController:KnitStart()
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

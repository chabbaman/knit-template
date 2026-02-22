local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local spr = require(Shared.Spr)
local LuckyBlockRarityConstants = require(Shared.LuckyBlockRarityConstants)

local BREAK_RANGE_SQ = 8 * 8
local HIT_COOLDOWN = 0.12
local BREAK_ANIMATION_DURATION = 0.6
local BREAK_ANIMATION_SCALE_MULTIPLIER = 1.75
local DEFAULT_HIT_PARTICLE_EMIT_COUNT = 16
local DETACHED_PARTICLE_CLEANUP_PADDING = 0.4
local BLOCKS_PER_HIT_MIN = 1
local BLOCKS_PER_HIT_MAX = 3
local XP_PER_HIT = 10
local LUCKY_BLOCK_TOOL_TAG = "Lucky Block"
local DEFAULT_SPAWN_TYPE = "Regular"
local THROW_COOLDOWN = 0.35
local THROW_ANIMATION_DURATION = 0.6
local THROW_DISTANCE = 4
local THROW_DISTANCE_MULTIPLIER = 2.5
local THROW_RAYCAST_HEIGHT = 10
local THROW_RAYCAST_DEPTH = 100
local THROW_BOUNDARY_MARGIN = 0.5
local SPAWN_CLEARANCE = 0.05
local BRAINROT_REVEAL_HEIGHT_OFFSET = 0.05
local PLACED_BRAINROT_PREFIX = "PlacedBrainrot_"
local PLACED_BRAINROT_Y_OFFSET = 5

local random = Random.new()

local LuckyBlockService = Knit.CreateService({
	Name = "LuckyBlockService",
	Client = {
		BrainrotReveal = Knit.CreateSignal(),
		BrainrotPlaced = Knit.CreateSignal(),
	},
})

function LuckyBlockService:KnitInit()
	self._lastHitAt = {}
	self._lastThrowAt = {}
	self._dataService = nil
	self._plotService = nil
	self._normalBrainrotTemplateNames = nil
	self._carriedBrainrots = {}
	self._placementPromptConns = {}
end

function LuckyBlockService:KnitStart()
	self._dataService = Knit.GetService("DataService")
	self._plotService = Knit.GetService("PlotService")

	Players.PlayerRemoving:Connect(function(player)
		self._lastHitAt[player] = nil
		self._lastThrowAt[player] = nil
		self._carriedBrainrots[player] = nil
	end)

	self:_connectPlacementPrompts()

	if self._dataService.ProfileLoaded then
		self._dataService.ProfileLoaded.Event:Connect(function(player)
			self:_tryRestorePlacementsForPlayer(player)
		end)
	end

	if self._plotService.PlotAssigned then
		self._plotService.PlotAssigned.Event:Connect(function(player)
			self:_tryRestorePlacementsForPlayer(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		self:_tryRestorePlacementsForPlayer(player)
	end
end

function LuckyBlockService:_setBlockPhysicalState(block: Model, anchored: boolean, canCollide: boolean)
	for _, descendant in block:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = canCollide
			descendant.CanQuery = canCollide
			descendant.CanTouch = canCollide
		end
	end
end

function LuckyBlockService:_setHandleTrailEnabled(block: Model, enabled: boolean)
	local handle = block:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end

	local trail = handle:FindFirstChild("Trail")
	if trail and trail:IsA("Trail") then
		trail.Enabled = enabled
	end
end

function LuckyBlockService:_getNormalBrainrotTemplateNames(): { string }
	if self._normalBrainrotTemplateNames then
		return self._normalBrainrotTemplateNames
	end

	local names = {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local normal = brainrots and brainrots:FindFirstChild("Normal")
	if normal then
		for _, child in normal:GetChildren() do
			if child:IsA("Model") then
				table.insert(names, child.Name)
			end
		end
	end

	self._normalBrainrotTemplateNames = names
	return names
end

function LuckyBlockService:_rollBrainrotTemplateName(): string?
	local names = self:_getNormalBrainrotTemplateNames()
	if #names == 0 then
		return nil
	end

	return names[random:NextInteger(1, #names)]
end

function LuckyBlockService:_getNormalBrainrotFolder(): Folder?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local brainrots = assets and assets:FindFirstChild("Brainrots")
	local normal = brainrots and brainrots:FindFirstChild("Normal")
	if normal and normal:IsA("Folder") then
		return normal
	end

	return nil
end

function LuckyBlockService:_getBrainrotTemplateByName(brainrotName: string): Model?
	local normal = self:_getNormalBrainrotFolder()
	if not normal then
		return nil
	end

	local template = normal:FindFirstChild(brainrotName)
	if template and template:IsA("Model") then
		return template
	end

	return nil
end

function LuckyBlockService:_getPlacementSpotByName(plot: Instance, spotName: string): Instance?
	local placementSpots = plot:FindFirstChild("PlacementSpots")
	if not placementSpots then
		return nil
	end

	return placementSpots:FindFirstChild(spotName)
end

function LuckyBlockService:_getSpotPivot(spot: Instance): CFrame?
	if spot:IsA("Model") then
		return spot:GetPivot()
	end

	if spot:IsA("BasePart") then
		return spot.CFrame
	end

	return nil
end

function LuckyBlockService:_getPlacedBrainrotInstanceName(spotName: string): string
	return `{PLACED_BRAINROT_PREFIX}{spotName}`
end

function LuckyBlockService:_destroyPlacedBrainrotAtSpot(plot: Instance, spotName: string)
	local existing = plot:FindFirstChild(self:_getPlacedBrainrotInstanceName(spotName))
	if existing and existing:IsA("Model") then
		existing:Destroy()
	end
end

function LuckyBlockService:_setPlacePromptEnabled(spot: Instance, enabled: boolean)
	local promptsFolder = spot:FindFirstChild("ProximityPrompts")
	local placeBrainrot = promptsFolder and promptsFolder:FindFirstChild("PlaceBrainrot")
	if not placeBrainrot then
		return
	end

	local prompt = placeBrainrot:FindFirstChild("ProximityPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Enabled = enabled
	end
end

function LuckyBlockService:_spawnPlacedBrainrotAtSpot(plot: Instance, spotName: string, brainrotName: string): boolean
	local spot = self:_getPlacementSpotByName(plot, spotName)
	if not spot then
		return false
	end

	local spotPivot = self:_getSpotPivot(spot)
	if not spotPivot then
		return false
	end

	local template = self:_getBrainrotTemplateByName(brainrotName)
	if not template then
		return false
	end

	self:_destroyPlacedBrainrotAtSpot(plot, spotName)

	local placed = template:Clone()
	placed.Name = self:_getPlacedBrainrotInstanceName(spotName)
	placed:SetAttribute("BrainrotName", brainrotName)
	placed:SetAttribute("PlacementSpot", spotName)
	placed:SetAttribute("IsPlacedBrainrot", true)

	for _, descendant in placed:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
		end
	end

	placed:PivotTo(spotPivot + Vector3.new(0, PLACED_BRAINROT_Y_OFFSET, 0))
	placed.Parent = plot

	self:_setPlacePromptEnabled(spot, false)
	return true
end

function LuckyBlockService:_restorePlacementsForPlayerPlot(player: Player, plot: Instance)
	if not self._dataService then
		return
	end

	local placementSpots = plot:FindFirstChild("PlacementSpots")
	if placementSpots then
		for _, spot in placementSpots:GetChildren() do
			self:_setPlacePromptEnabled(spot, true)
		end
	end

	local placements = self._dataService:GetBrainrotPlacements(player)
	for spotName, brainrotName in placements do
		if typeof(spotName) == "string" and typeof(brainrotName) == "string" and brainrotName ~= "" then
			self:_spawnPlacedBrainrotAtSpot(plot, spotName, brainrotName)
		end
	end
end

function LuckyBlockService:_tryRestorePlacementsForPlayer(player: Player)
	if player.Parent ~= Players then
		return
	end

	if not self._dataService:GetProfile(player) then
		return
	end

	local plot = self._plotService:GetPlayerPlot(player)
	if plot then
		self:_restorePlacementsForPlayerPlot(player, plot)
	end
end

function LuckyBlockService:_connectPlacementPrompts()
	local plotsFolder = Workspace:FindFirstChild("Plots")
	if not plotsFolder then
		return
	end

	for _, plot in plotsFolder:GetChildren() do
		local plotRef = plot
		local placementSpots = plot:FindFirstChild("PlacementSpots")
		if placementSpots then
			for _, spot in placementSpots:GetChildren() do
				local promptsFolder = spot:FindFirstChild("ProximityPrompts")
				local placeBrainrot = promptsFolder and promptsFolder:FindFirstChild("PlaceBrainrot")
				local prompt = placeBrainrot and placeBrainrot:FindFirstChild("ProximityPrompt")
				if prompt and prompt:IsA("ProximityPrompt") and not self._placementPromptConns[prompt] then
					local spotRef = spot
					local promptRef = prompt
					self._placementPromptConns[promptRef] = promptRef.Triggered:Connect(function(player)
						self:_onPlacePromptTriggered(player, plotRef, spotRef, promptRef)
					end)
				end
			end
		end
	end
end

function LuckyBlockService:_getRevealFloorY(block: Model, blockPosition: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { block }
	params.IgnoreWater = true

	local castOrigin = blockPosition + Vector3.new(0, 12, 0)
	local castDirection = Vector3.new(0, -80, 0)
	local result = Workspace:Raycast(castOrigin, castDirection, params)
	if result then
		return result.Position.Y + BRAINROT_REVEAL_HEIGHT_OFFSET
	end

	local _, blockSize = block:GetBoundingBox()
	return blockPosition.Y - blockSize.Y * 0.5 + BRAINROT_REVEAL_HEIGHT_OFFSET
end

function LuckyBlockService:_initializeBlock(block: Model, spawnType: string?)
	block:SetAttribute("IsBreaking", false)

	for _, descendant in block:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		end
	end

	local rarity = block:GetAttribute("Rarity")
	if typeof(rarity) ~= "string" or rarity == "" then
		rarity = LuckyBlockRarityConstants.getRarityFromSpawnType(spawnType)
	else
		rarity = LuckyBlockRarityConstants.normalizeRarity(rarity)
	end
	block:SetAttribute("Rarity", rarity)

	local maxHealth = LuckyBlockRarityConstants.getHealth(rarity)
	block:SetAttribute("MaxHealth", maxHealth)
	block:SetAttribute("Health", maxHealth)
	block:SetAttribute("SpawnType", spawnType or DEFAULT_SPAWN_TYPE)
end

function LuckyBlockService:_resolveSpawnTypeFromTool(tool: Tool): string
	local spawnType = tool:GetAttribute("SpawnType")
	if typeof(spawnType) == "string" and spawnType ~= "" then
		return spawnType
	end

	return DEFAULT_SPAWN_TYPE
end

function LuckyBlockService:_cloneToolAsBlockModel(tool: Tool): Model?
	local clonedTool = tool:Clone()
	local block = Instance.new("Model")
	block.Name = clonedTool.Name

	for attributeName, attributeValue in clonedTool:GetAttributes() do
		block:SetAttribute(attributeName, attributeValue)
	end

	for _, child in clonedTool:GetChildren() do
		if child:IsA("Script") or child:IsA("LocalScript") then
			child:Destroy()
		else
			child.Parent = block
		end
	end

	clonedTool:Destroy()

	local handle = block:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		block.PrimaryPart = handle
	else
		local primaryPart = block:FindFirstChildWhichIsA("BasePart", true)
		if primaryPart then
			block.PrimaryPart = primaryPart
		end
	end

	if not block.PrimaryPart then
		block:Destroy()
		return nil
	end

	return block
end

function LuckyBlockService:_isThrowOnCooldown(player: Player): boolean
	local now = os.clock()
	local lastThrowAt = self._lastThrowAt[player]
	if lastThrowAt and now - lastThrowAt < THROW_COOLDOWN then
		return true
	end

	self._lastThrowAt[player] = now
	return false
end

function LuckyBlockService:_clampToSpawnPartXZ(spawnPart: BasePart, position: Vector3): Vector3
	local localPos = spawnPart.CFrame:PointToObjectSpace(position)
	local halfX = math.max(0, spawnPart.Size.X * 0.5 - THROW_BOUNDARY_MARGIN)
	local halfZ = math.max(0, spawnPart.Size.Z * 0.5 - THROW_BOUNDARY_MARGIN)
	local clampedLocal = Vector3.new(
		math.clamp(localPos.X, -halfX, halfX),
		localPos.Y,
		math.clamp(localPos.Z, -halfZ, halfZ)
	)

	return spawnPart.CFrame:PointToWorldSpace(clampedLocal)
end

function LuckyBlockService.Client:SetCarriedBrainrot(player: Player, brainrotName: string): boolean
	return self.Server:_setCarriedBrainrot(player, brainrotName)
end

function LuckyBlockService:_setCarriedBrainrot(player: Player, brainrotName: string): boolean
	if typeof(brainrotName) ~= "string" or brainrotName == "" then
		return false
	end

	if not self:_getBrainrotTemplateByName(brainrotName) then
		return false
	end

	self._carriedBrainrots[player] = brainrotName
	player:SetAttribute("CarriedBrainrot", brainrotName)
	return true
end

function LuckyBlockService:_onPlacePromptTriggered(player: Player, plot: Instance, spot: Instance, prompt: ProximityPrompt)
	if not player or player.Parent ~= Players then
		return
	end

	if self._plotService:GetPlayerPlot(player) ~= plot then
		return
	end

	if not prompt.Enabled then
		return
	end

	local carriedBrainrotName = self._carriedBrainrots[player]
	if typeof(carriedBrainrotName) ~= "string" or carriedBrainrotName == "" then
		return
	end

	local spotName = spot.Name
	if not self:_spawnPlacedBrainrotAtSpot(plot, spotName, carriedBrainrotName) then
		return
	end

	if self._dataService then
		self._dataService:SetBrainrotPlacement(player, spotName, carriedBrainrotName)
	end

	self._carriedBrainrots[player] = nil
	player:SetAttribute("CarriedBrainrot", nil)
	self.Client.BrainrotPlaced:FireAll(player, spotName, carriedBrainrotName)
end

function LuckyBlockService.Client:ThrowLuckyBlock(player: Player, tool: Instance): (boolean, Model?, Vector3?, Vector3?)
	return self.Server:_throwLuckyBlock(player, tool)
end

function LuckyBlockService:_throwLuckyBlock(player: Player, tool: Instance): (boolean, Model?, Vector3?, Vector3?)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false, nil, nil, nil
	end

	if not CollectionService:HasTag(tool, LUCKY_BLOCK_TOOL_TAG) then
		return false, nil, nil, nil
	end

	local character = player.Character
	if not character or tool.Parent ~= character then
		return false, nil, nil, nil
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false, nil, nil, nil
	end

	local plot = self._plotService:GetPlayerPlot(player)
	if not plot then
		return false, nil, nil, nil
	end

	local spawnPart = plot:FindFirstChild("SpawnPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return false, nil, nil, nil
	end

	if self:_isThrowOnCooldown(player) then
		return false, nil, nil, nil
	end

	local spawnType = self:_resolveSpawnTypeFromTool(tool)
	local block = self:_cloneToolAsBlockModel(tool)
	if not block then
		return false, nil, nil, nil
	end

	local throwDirection = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if throwDirection.Magnitude < 0.001 then
		throwDirection = Vector3.new(0, 0, -1)
	else
		throwDirection = throwDirection.Unit
	end

	local startPosition = hrp.Position + Vector3.new(0, 2, 0) + throwDirection * 2
	local baseTarget = startPosition + throwDirection * THROW_DISTANCE
	local extendedTarget = startPosition + (baseTarget - startPosition) * THROW_DISTANCE_MULTIPLIER
	extendedTarget = self:_clampToSpawnPartXZ(spawnPart, extendedTarget)

	local _, baseSize = block:GetBoundingBox()
	local finalHalfHeight = baseSize.Y * 0.5

	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { block, character }
	raycastParams.IgnoreWater = true

	local rayResult = Workspace:Raycast(
		extendedTarget + Vector3.new(0, THROW_RAYCAST_HEIGHT, 0),
		Vector3.new(0, -THROW_RAYCAST_DEPTH, 0),
		raycastParams
	)

	local fallbackFloorY = spawnPart.Position.Y + spawnPart.Size.Y * 0.5 + SPAWN_CLEARANCE
	local floorY = if rayResult then rayResult.Position.Y + finalHalfHeight else fallbackFloorY + finalHalfHeight
	local floorPosition = Vector3.new(extendedTarget.X, floorY, extendedTarget.Z)

	self:_setBlockPhysicalState(block, true, false)
	self:_setHandleTrailEnabled(block, true)
	block:SetAttribute("IsBreaking", true)
	block:SetAttribute("SpawnType", spawnType)
	block:ScaleTo(1)
	block:PivotTo(CFrame.new(startPosition))
	block.Parent = workspace

	tool:Destroy()

	task.delay(THROW_ANIMATION_DURATION, function()
		if block.Parent == nil then
			return
		end

		self:_setHandleTrailEnabled(block, false)
		block:PivotTo(CFrame.new(floorPosition))
		block.Parent = plot
		self:_setBlockPhysicalState(block, true, true)
		self:_initializeBlock(block, spawnType)
	end)

	return true, block, startPosition, floorPosition
end

function LuckyBlockService:_pivotForScaleGrounded(
	basePivot: CFrame,
	halfHeight: number,
	targetScale: number,
	baseScale: number
): CFrame
	local scaleFactor = targetScale / math.max(baseScale, 0.001)
	local liftCompensation = halfHeight * (scaleFactor - 1)
	return basePivot + Vector3.new(0, liftCompensation, 0)
end

function LuckyBlockService:_playBreakAnimationAndDestroy(block: Model)
	if block:GetAttribute("IsBreaking") == true then
		return
	end

	block:SetAttribute("IsBreaking", true)

	for _, descendant in block:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			spr.stop(descendant)
			spr.target(descendant, 1, 5.5, {
				Transparency = 1,
			})
		elseif descendant:IsA("ParticleEmitter") then
			descendant.Enabled = false
		elseif descendant:IsA("Decal") or descendant:IsA("Texture") then
			spr.stop(descendant)
			spr.target(descendant, 1, 5.5, {
				Transparency = 1,
			})
		end
	end

	local basePivot = block:GetPivot()
	local baseScale = block:GetScale()
	local _, size = block:GetBoundingBox()
	local halfHeight = size.Y * 0.5
	local targetScale = baseScale * BREAK_ANIMATION_SCALE_MULTIPLIER
	local targetPivot = self:_pivotForScaleGrounded(basePivot, halfHeight, targetScale, baseScale)
	spr.stop(block)
	block:ScaleTo(baseScale)
	block:PivotTo(basePivot)
	spr.target(block, 0.78, 5.5, {
		Scale = targetScale,
		Pivot = targetPivot,
	})

	task.delay(BREAK_ANIMATION_DURATION + 0.05, function()
		for _, descendant in block:GetDescendants() do
			if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
				descendant.Transparency = 1
			end
		end

		if block.Parent ~= nil then
			block:Destroy()
		end
	end)
end

function LuckyBlockService:_emitHitParticles(block: Model)
	local emitCount = block:GetAttribute("HitParticleEmitCount")
	if typeof(emitCount) ~= "number" or emitCount <= 0 then
		emitCount = DEFAULT_HIT_PARTICLE_EMIT_COUNT
	end

	for _, descendant in block:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			local worldCFrame = block:GetPivot()
			local emitterParent = descendant.Parent
			if emitterParent and emitterParent:IsA("Attachment") then
				worldCFrame = emitterParent.WorldCFrame
			elseif emitterParent and emitterParent:IsA("BasePart") then
				worldCFrame = emitterParent.CFrame
			end

			local terrain = Workspace.Terrain
			local tempAttachment = Instance.new("Attachment")
			tempAttachment.Name = "LuckyBlockParticleAttachment"
			tempAttachment.CFrame = worldCFrame
			tempAttachment.Parent = terrain

			local detachedEmitter = descendant:Clone()
			detachedEmitter.Parent = tempAttachment
			detachedEmitter.Enabled = true
			detachedEmitter:Emit(math.floor(emitCount))
			task.delay(0.05, function()
				if detachedEmitter.Parent ~= nil then
					detachedEmitter.Enabled = false
				end
			end)

			local lifetime = detachedEmitter.Lifetime
			local cleanupDelay = math.max(lifetime.Min, lifetime.Max) + DETACHED_PARTICLE_CLEANUP_PADDING
			task.delay(cleanupDelay, function()
				if tempAttachment.Parent ~= nil then
					tempAttachment:Destroy()
				end
			end)
		end
	end
end

function LuckyBlockService:_isValidBlock(block: Instance): boolean
	if not block or not block:IsA("Model") then
		return false
	end

	local plot = block.Parent
	local plotsFolder = workspace:FindFirstChild("Plots")
	if not plot or not plotsFolder or plot.Parent ~= plotsFolder then
		return false
	end

	if block:GetAttribute("IsBreaking") == true then
		return false
	end

	return true
end

function LuckyBlockService:_getEquippedToolStrength(player: Player): number?
	local character = player.Character
	if not character then
		return nil
	end

	local tool = character:FindFirstChildOfClass("Tool")
	if not tool then
		return nil
	end

	local strength = tool:GetAttribute("Strength")
	if typeof(strength) ~= "number" or strength <= 0 then
		return nil
	end

	return strength
end

function LuckyBlockService:_canHitBlock(player: Player, block: Model): boolean
	local character = player.Character
	if not character then
		return false
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return false
	end

	local primaryPart = block.PrimaryPart or block:FindFirstChildWhichIsA("BasePart", true)
	if not primaryPart then
		return false
	end

	local delta = primaryPart.Position - hrp.Position
	local distSq = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
	if distSq > BREAK_RANGE_SQ then
		return false
	end

	local plot = self._plotService:GetPlayerPlot(player)
	if not plot then
		return false
	end

	if block.Parent ~= plot then
		return false
	end

	local now = os.clock()
	local playerHits = self._lastHitAt[player]
	if not playerHits then
		playerHits = {}
		self._lastHitAt[player] = playerHits
	end

	local lastHit = playerHits[block]
	if lastHit and now - lastHit < HIT_COOLDOWN then
		return false
	end

	playerHits[block] = now
	return true
end

function LuckyBlockService.Client:TryHitBlock(player: Player, block: Instance): (boolean, boolean, number)
	return self.Server:_tryHitBlock(player, block)
end

function LuckyBlockService:_tryHitBlock(player: Player, block: Instance): (boolean, boolean, number)
	if not self:_isValidBlock(block) then
		return false, false, 0
	end

	local typedBlock = block :: Model
	if not self:_canHitBlock(player, typedBlock) then
		return false, false, 0
	end

	local maxHealth = typedBlock:GetAttribute("MaxHealth")
	if typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		maxHealth = LuckyBlockRarityConstants.getHealth(typedBlock:GetAttribute("Rarity"))
		typedBlock:SetAttribute("MaxHealth", maxHealth)
	end

	local health = typedBlock:GetAttribute("Health")
	if typeof(health) ~= "number" then
		health = maxHealth
	end

	health = math.clamp(health, 0, maxHealth)
	if health <= 0 then
		return false, false, 0
	end

	local damage = self:_getEquippedToolStrength(player)
	if not damage then
		return false, false, 0
	end
	local newHealth = math.max(0, health - damage)
	typedBlock:SetAttribute("Health", newHealth)
	self:_emitHitParticles(typedBlock)
	local blocksAwarded = random:NextInteger(BLOCKS_PER_HIT_MIN, BLOCKS_PER_HIT_MAX)
	if self._dataService then
		self._dataService:AddBlocks(player, blocksAwarded)
		self._dataService:AddXP(player, XP_PER_HIT)
	end
	local broke = newHealth <= 0
	if broke then
		local blockPosition = typedBlock:GetPivot().Position
		local revealFloorY = self:_getRevealFloorY(typedBlock, blockPosition)
		local brainrotTemplateName = self:_rollBrainrotTemplateName()
		if brainrotTemplateName then
			local revealSeed = random:NextInteger(1, 2147483646)
			player:SetAttribute("LastRolledBrainrot", brainrotTemplateName)
			self.Client.BrainrotReveal:FireAll(player, blockPosition, revealFloorY, brainrotTemplateName, revealSeed)
		end

		self:_playBreakAnimationAndDestroy(typedBlock)
	end

	return true, broke, blocksAwarded
end

return LuckyBlockService

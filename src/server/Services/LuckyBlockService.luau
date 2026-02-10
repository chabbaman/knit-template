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
local DAMAGE_PER_HIT = 10
local DEFAULT_SPAWN_INTERVAL = 8
local DEFAULT_SPAWN_TYPE = "Regular"
local INITIAL_SPAWN_COUNT = 10
local MIN_ACTIVE_BLOCKS = 10
local DEFAULT_SPAWN_PADDING = 6
local MAX_SPAWN_POSITION_ATTEMPTS = 24
local SPAWN_CLEARANCE = 0.05
local DEFAULT_DESPAWN_AFTER = 60
local DEFAULT_DESPAWN_JITTER = 12
local SPAWN_START_SCALE = 0.65
local SPAWN_OVERSHOOT_SCALE = 1.08
local SPAWN_OVERSHOOT_DELAY = 0.08
local BREAK_ANIMATION_DURATION = 0.6
local BREAK_ANIMATION_SCALE_MULTIPLIER = 1.75
local DEFAULT_HIT_PARTICLE_EMIT_COUNT = 16
local DETACHED_PARTICLE_CLEANUP_PADDING = 0.4
local BLOCKS_PER_HIT_MIN = 1
local BLOCKS_PER_HIT_MAX = 3

local random = Random.new()

local LuckyBlockService = Knit.CreateService({
	Name = "LuckyBlockService",
	Client = {},
})

function LuckyBlockService:KnitInit()
	self._lastHitAt = {}
	self._spawnThread = nil
	self._dataService = nil
	self._plotService = nil
end

function LuckyBlockService:KnitStart()
	self._dataService = Knit.GetService("DataService")
	self._plotService = Knit.GetService("PlotService")

	Players.PlayerRemoving:Connect(function(player)
		self._lastHitAt[player] = nil
	end)

	Players.PlayerAdded:Connect(function(player)
		self:_spawnInitialBlocksForPlayer(player)
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_spawnInitialBlocksForPlayer(player)
		end)
	end

	self._spawnThread = task.spawn(function()
		self:_runSpawner()
	end)
end

function LuckyBlockService:_spawnInitialBlocksForPlayer(player: Player)
	local plot = self._plotService:GetPlayerPlot(player)
	if not plot then
		return
	end

	for _ = 1, INITIAL_SPAWN_COUNT do
		self:_spawnOne(plot)
	end
end

function LuckyBlockService:_getSpawnPartAttribute(
	spawnPart: BasePart,
	name: string,
	default: number,
	minValue: number?
): number
	local attr = spawnPart:GetAttribute(name)
	if typeof(attr) == "number" then
		if minValue and attr < minValue then
			return default
		end
		if attr > 0 or (minValue and minValue <= 0) then
			return attr
		end
	end
	return default
end

function LuckyBlockService:_getActiveBlockCount(plot: Instance): number
	local count = 0
	for _, child in plot:GetChildren() do
		if child:IsA("Model") then
			count += 1
		end
	end
	return count
end

function LuckyBlockService:_canSpawnAtPosition(plot: Instance, position: Vector3, paddingSq: number): boolean
	for _, child in plot:GetChildren() do
		if child:IsA("Model") then
			local existing = child:GetPivot().Position
			local dx = existing.X - position.X
			local dz = existing.Z - position.Z
			local distSq = dx * dx + dz * dz
			if distSq < paddingSq then
				return false
			end
		end
	end
	return true
end

function LuckyBlockService:_getTemplateFromSpawnType(spawnType: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		return nil
	end

	local luckyBlocks = assets:FindFirstChild("Lucky Blocks")
	if not luckyBlocks then
		return nil
	end

	local direct = luckyBlocks:FindFirstChild(spawnType)
	if direct and direct:IsA("Model") then
		return direct
	end

	local fallback = luckyBlocks:FindFirstChild(DEFAULT_SPAWN_TYPE)
	if fallback and fallback:IsA("Model") then
		return fallback
	end

	return nil
end

function LuckyBlockService:_spawnOne(plot: Instance)
	local spawnPart = plot:FindFirstChild("SpawnPart")
	if not spawnPart or not spawnPart:IsA("BasePart") then
		return
	end

	local spawnType = spawnPart:GetAttribute("SpawnType")
	if typeof(spawnType) ~= "string" or spawnType == "" then
		spawnType = DEFAULT_SPAWN_TYPE
	end

	local template = self:_getTemplateFromSpawnType(spawnType)
	if not template then
		warn(`[LuckyBlockService] Missing lucky block template for SpawnType "{spawnType}"`)
		return
	end

	local block = template:Clone()
	block.Parent = plot

	local currentPivot = block:GetPivot()
	local currentRotation = currentPivot - currentPivot.Position
	local _, size = block:GetBoundingBox()
	local y = spawnPart.Size.Y * 0.5 + size.Y * 0.5 + SPAWN_CLEARANCE
	local spawnPadding = self:_getSpawnPartAttribute(spawnPart, "SpawnPadding", DEFAULT_SPAWN_PADDING, 0)
	local spawnPaddingSq = spawnPadding * spawnPadding

	local spawnPosition = nil
	for _ = 1, MAX_SPAWN_POSITION_ATTEMPTS do
		local x = random:NextNumber(-spawnPart.Size.X * 0.5, spawnPart.Size.X * 0.5)
		local z = random:NextNumber(-spawnPart.Size.Z * 0.5, spawnPart.Size.Z * 0.5)
		local candidate = (spawnPart.CFrame * CFrame.new(x, y, z)).Position
		if self:_canSpawnAtPosition(plot, candidate, spawnPaddingSq) then
			spawnPosition = candidate
			break
		end
	end

	if not spawnPosition then
		block:Destroy()
		return
	end

	local spawnCFrame = CFrame.new(spawnPosition) * currentRotation
	block:PivotTo(spawnCFrame)
	local now = workspace:GetServerTimeNow()
	local despawnAfter = self:_getSpawnPartAttribute(spawnPart, "DespawnAfter", DEFAULT_DESPAWN_AFTER, 0)
	local despawnJitter = self:_getSpawnPartAttribute(spawnPart, "DespawnJitter", DEFAULT_DESPAWN_JITTER, 0)
	if despawnJitter > 0 then
		despawnAfter += random:NextNumber(-despawnJitter, despawnJitter)
		despawnAfter = math.max(1, despawnAfter)
	end
	block:SetAttribute("SpawnedAt", now)
	block:SetAttribute("DespawnAfter", despawnAfter)
	block:SetAttribute("DespawnAt", now + despawnAfter)
	block:SetAttribute("SpawnType", spawnType)
	block:SetAttribute("Rarity", LuckyBlockRarityConstants.getRarityFromSpawnType(spawnType))
	self:_initializeBlock(block, spawnType)
	self:_playSpawnAnimation(block, spawnCFrame, size.Y * 0.5)

	task.delay(despawnAfter, function()
		if block.Parent ~= nil then
			block:Destroy()
		end
	end)
end

function LuckyBlockService:_pivotForScale(
	basePivot: CFrame,
	halfHeight: number,
	targetScale: number,
	baseScale: number
): CFrame
	local scaleFactor = targetScale / math.max(baseScale, 0.001)
	local liftCompensation = halfHeight * (scaleFactor - 1)
	return basePivot + basePivot.UpVector * liftCompensation
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

function LuckyBlockService:_playSpawnAnimation(block: Model, basePivot: CFrame, halfHeight: number)
	local baseScale = block:GetScale()
	local startScale = baseScale * SPAWN_START_SCALE
	local overshootScale = baseScale * SPAWN_OVERSHOOT_SCALE

	spr.stop(block)
	block:ScaleTo(startScale)
	block:PivotTo(self:_pivotForScale(basePivot, halfHeight, startScale, baseScale))

	spr.target(block, 0.72, 7.5, {
		Scale = overshootScale,
		Pivot = self:_pivotForScale(basePivot, halfHeight, overshootScale, baseScale),
	})

	task.delay(SPAWN_OVERSHOOT_DELAY, function()
		if block.Parent == nil then
			return
		end

		spr.target(block, 0.9, 6, {
			Scale = baseScale,
			Pivot = basePivot,
		})
	end)
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

function LuckyBlockService:_runSpawner()
	task.wait()
	while true do
		local anyMissing = false
		for plot, _ in self._plotService:GetAssignedPlots() do
			local spawnPart = plot:FindFirstChild("SpawnPart")
			if spawnPart and spawnPart:IsA("BasePart") then
				local minActive = self:_getSpawnPartAttribute(spawnPart, "MinActiveBlocks", MIN_ACTIVE_BLOCKS, 0)
				minActive = math.floor(minActive)
				local activeCount = self:_getActiveBlockCount(plot)
				if activeCount < minActive then
					self:_spawnOne(plot)
					anyMissing = true
				end
			end
		end
		task.wait(if anyMissing then DEFAULT_SPAWN_INTERVAL else 1)
	end
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

	local damage = self:_getEquippedToolStrength(player) or DAMAGE_PER_HIT
	local newHealth = math.max(0, health - damage)
	typedBlock:SetAttribute("Health", newHealth)
	self:_emitHitParticles(typedBlock)
	local blocksAwarded = random:NextInteger(BLOCKS_PER_HIT_MIN, BLOCKS_PER_HIT_MAX)
	if self._dataService then
		self._dataService:AddBlocks(player, blocksAwarded)
	end
	local broke = newHealth <= 0
	if broke then
		self:_playBreakAnimationAndDestroy(typedBlock)
	end

	return true, broke, blocksAwarded
end

return LuckyBlockService

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Shared = ReplicatedStorage.Shared
local Knit = require(Packages.Knit)
local spr = require(Shared.Spr)

local BREAK_RANGE_SQ = 8 * 8
local HIT_COOLDOWN = 0.12
local DEFAULT_MAX_HEALTH = 100
local DAMAGE_PER_HIT = 10
local DEFAULT_SPAWN_INTERVAL = 8
local MIN_SPAWN_INTERVAL = 0.2
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

local random = Random.new()

local LuckyBlockService = Knit.CreateService({
	Name = "LuckyBlockService",
	Client = {},
})

function LuckyBlockService:KnitInit()
	self._lastHitAt = {}
	self._boundContainer = nil
	self._containerConn = nil
	self._spawnThread = nil
end

function LuckyBlockService:KnitStart()
	self:_bindLuckyBlockContainer()
	workspace.ChildAdded:Connect(function(child)
		if child:IsA("Folder") and child.Name == "Lucky Blocks" then
			self:_bindLuckyBlockContainer()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._lastHitAt[player] = nil
	end)

	self._spawnThread = task.spawn(function()
		self:_runSpawner()
	end)
end

function LuckyBlockService:_getSpawnInterval(): number
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if spawnPart and spawnPart:IsA("BasePart") then
		local attr = spawnPart:GetAttribute("SpawnInterval")
		if typeof(attr) == "number" and attr >= MIN_SPAWN_INTERVAL then
			return attr
		end
	end
	return DEFAULT_SPAWN_INTERVAL
end

function LuckyBlockService:_getDespawnAfter(): number
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if spawnPart and spawnPart:IsA("BasePart") then
		local attr = spawnPart:GetAttribute("DespawnAfter")
		if typeof(attr) == "number" and attr > 0 then
			return attr
		end
	end
	return DEFAULT_DESPAWN_AFTER
end

function LuckyBlockService:_getDespawnJitter(): number
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if spawnPart and spawnPart:IsA("BasePart") then
		local attr = spawnPart:GetAttribute("DespawnJitter")
		if typeof(attr) == "number" and attr >= 0 then
			return attr
		end
	end
	return DEFAULT_DESPAWN_JITTER
end

function LuckyBlockService:_getMinimumActiveBlocks(): number
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if spawnPart and spawnPart:IsA("BasePart") then
		local attr = spawnPart:GetAttribute("MinActiveBlocks")
		if typeof(attr) == "number" and attr >= 0 then
			return math.floor(attr)
		end
	end
	return MIN_ACTIVE_BLOCKS
end

function LuckyBlockService:_getSpawnPadding(): number
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if spawnPart and spawnPart:IsA("BasePart") then
		local attr = spawnPart:GetAttribute("SpawnPadding")
		if typeof(attr) == "number" and attr >= 0 then
			return attr
		end
	end
	return DEFAULT_SPAWN_PADDING
end

function LuckyBlockService:_getActiveBlockCount(container: Folder): number
	local count = 0
	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			count += 1
		end
	end
	return count
end

function LuckyBlockService:_canSpawnAtPosition(container: Folder, position: Vector3, paddingSq: number): boolean
	for _, child in container:GetChildren() do
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

function LuckyBlockService:_spawnOne()
	local container = workspace:FindFirstChild("Lucky Blocks")
	local spawnPart = workspace:FindFirstChild("SpawnPart")
	if not container or not container:IsA("Folder") then
		return
	end
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
	block.Parent = container

	local currentPivot = block:GetPivot()
	local currentRotation = currentPivot - currentPivot.Position
	local _, size = block:GetBoundingBox()
	local y = spawnPart.Size.Y * 0.5 + size.Y * 0.5 + SPAWN_CLEARANCE
	local spawnPadding = self:_getSpawnPadding()
	local spawnPaddingSq = spawnPadding * spawnPadding

	local spawnPosition = nil
	for _ = 1, MAX_SPAWN_POSITION_ATTEMPTS do
		local x = random:NextNumber(-spawnPart.Size.X * 0.5, spawnPart.Size.X * 0.5)
		local z = random:NextNumber(-spawnPart.Size.Z * 0.5, spawnPart.Size.Z * 0.5)
		local candidate = (spawnPart.CFrame * CFrame.new(x, y, z)).Position
		if self:_canSpawnAtPosition(container, candidate, spawnPaddingSq) then
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
	local despawnAfter = self:_getDespawnAfter()
	local despawnJitter = self:_getDespawnJitter()
	if despawnJitter > 0 then
		despawnAfter += random:NextNumber(-despawnJitter, despawnJitter)
		despawnAfter = math.max(1, despawnAfter)
	end
	block:SetAttribute("SpawnedAt", now)
	block:SetAttribute("DespawnAfter", despawnAfter)
	block:SetAttribute("DespawnAt", now + despawnAfter)
	self:_initializeBlock(block)
	self:_playSpawnAnimation(block, spawnCFrame, size.Y * 0.5)

	task.delay(despawnAfter, function()
		if block.Parent ~= nil then
			block:Destroy()
		end
	end)
end

function LuckyBlockService:_pivotForScale(basePivot: CFrame, halfHeight: number, targetScale: number, baseScale: number): CFrame
	local scaleFactor = targetScale / math.max(baseScale, 0.001)
	local liftCompensation = halfHeight * (scaleFactor - 1)
	return basePivot + basePivot.UpVector * liftCompensation
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

function LuckyBlockService:_runSpawner()
	local container = workspace:FindFirstChild("Lucky Blocks")
	local initialMissing = INITIAL_SPAWN_COUNT
	if container and container:IsA("Folder") then
		initialMissing = math.max(0, INITIAL_SPAWN_COUNT - self:_getActiveBlockCount(container))
	end

	for _ = 1, initialMissing do
		self:_spawnOne()
	end

	while true do
		task.wait(self:_getSpawnInterval())
		container = workspace:FindFirstChild("Lucky Blocks")
		if container and container:IsA("Folder") then
			local minActive = self:_getMinimumActiveBlocks()
			local activeCount = self:_getActiveBlockCount(container)
			local missing = math.max(0, minActive - activeCount)
			for _ = 1, missing do
				self:_spawnOne()
			end
		end
	end
end

function LuckyBlockService:_bindLuckyBlockContainer()
	local container = workspace:FindFirstChild("Lucky Blocks")
	if not container then
		return
	end
	if self._boundContainer == container then
		return
	end

	if self._containerConn then
		self._containerConn:Disconnect()
		self._containerConn = nil
	end
	self._boundContainer = container

	for _, child in container:GetChildren() do
		if child:IsA("Model") then
			self:_initializeBlock(child)
		end
	end

	self._containerConn = container.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			self:_initializeBlock(child)
		end
	end)
end

function LuckyBlockService:_initializeBlock(block: Model)
	local maxHealth = block:GetAttribute("MaxHealth")
	if typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		maxHealth = DEFAULT_MAX_HEALTH
		block:SetAttribute("MaxHealth", maxHealth)
	end

	local health = block:GetAttribute("Health")
	if typeof(health) ~= "number" then
		health = maxHealth
	end
	block:SetAttribute("Health", math.clamp(health, 0, maxHealth))
end

function LuckyBlockService:_isValidBlock(block: Instance): boolean
	if not block or not block:IsA("Model") then
		return false
	end

	local container = workspace:FindFirstChild("Lucky Blocks")
	if not container then
		return false
	end

	return block.Parent == container
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

function LuckyBlockService.Client:TryHitBlock(player: Player, block: Instance): boolean
	return self.Server:_tryHitBlock(player, block)
end

function LuckyBlockService:_tryHitBlock(player: Player, block: Instance): boolean
	if not self:_isValidBlock(block) then
		return false
	end

	local typedBlock = block :: Model
	if not self:_canHitBlock(player, typedBlock) then
		return false
	end

	local maxHealth = typedBlock:GetAttribute("MaxHealth")
	if typeof(maxHealth) ~= "number" or maxHealth <= 0 then
		maxHealth = DEFAULT_MAX_HEALTH
		typedBlock:SetAttribute("MaxHealth", maxHealth)
	end

	local health = typedBlock:GetAttribute("Health")
	if typeof(health) ~= "number" then
		health = maxHealth
	end

	health = math.clamp(health, 0, maxHealth)
	if health <= 0 then
		return false
	end

	local newHealth = math.max(0, health - DAMAGE_PER_HIT)
	typedBlock:SetAttribute("Health", newHealth)

	return true
end

return LuckyBlockService

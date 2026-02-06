local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

local random = Random.new()

local CameraShakeController = Knit.CreateController({
	Name = "CameraShakeController",
})

function CameraShakeController:KnitInit()
	self._shakes = {} -- list of active shakes
end

--[[
	Shake the camera.

	intensity – max offset in studs (default 0.3)
	duration  – how long the shake lasts in seconds (default 0.15)
	frequency – how many times per second the offset changes (default 25)
]]
function CameraShakeController:Shake(intensity: number?, duration: number?, frequency: number?)
	local shake = {
		intensity = intensity or 0.3,
		duration = duration or 0.15,
		frequency = frequency or 25,
		elapsed = 0,
	}
	table.insert(self._shakes, shake)
end

function CameraShakeController:KnitStart()
	RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local totalOffset = Vector3.zero
		local i = 1
		while i <= #self._shakes do
			local shake = self._shakes[i]
			shake.elapsed += dt

			if shake.elapsed >= shake.duration then
				table.remove(self._shakes, i)
			else
				local alpha = 1 - (shake.elapsed / shake.duration) -- fade out
				local mag = shake.intensity * alpha
				totalOffset += Vector3.new(
					random:NextNumber(-mag, mag),
					random:NextNumber(-mag, mag),
					0
				)
				i += 1
			end
		end

		if totalOffset ~= Vector3.zero then
			camera.CFrame *= CFrame.new(totalOffset)
		end
	end)
end

return CameraShakeController

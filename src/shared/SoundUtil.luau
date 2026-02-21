local SoundService = game:GetService("SoundService")

local SoundUtil = {}

function SoundUtil.playFromSoundsFolder(soundName: string): Sound?
	local soundsFolder = SoundService:FindFirstChild("Sounds")
	if not soundsFolder then
		return nil
	end

	local soundTemplate = soundsFolder:FindFirstChild(soundName)
	if not soundTemplate or not soundTemplate:IsA("Sound") then
		return nil
	end

	local soundClone = soundTemplate:Clone()
	soundClone.Parent = soundsFolder
	soundClone:Play()

	soundClone.Ended:Once(function()
		soundClone:Destroy()
	end)

	return soundClone
end

function SoundUtil.playDirectFromSoundsFolder(soundName: string, restartIfPlaying: boolean?): Sound?
	local soundsFolder = SoundService:FindFirstChild("Sounds")
	if not soundsFolder then
		return nil
	end

	local sound = soundsFolder:FindFirstChild(soundName)
	if not sound or not sound:IsA("Sound") then
		return nil
	end

	if restartIfPlaying ~= false then
		sound:Stop()
		sound.TimePosition = 0
	end
	sound:Play()

	return sound
end

return table.freeze(SoundUtil)

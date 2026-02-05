local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

Knit.AddServices(script.Parent.Services)
Knit.Start():catch(warn)

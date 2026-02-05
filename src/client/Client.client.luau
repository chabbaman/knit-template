local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

Knit.AddControllers(script.Parent.Controllers)
Knit.Start():catch(warn)

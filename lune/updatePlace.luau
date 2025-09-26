local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local net = require("@lune/net")
local process = require("@lune/process")
local fs = require("@lune/fs")

-- Helper function to trim whitespace from strings
local function trim(s)
	return s:gsub("^%s+", ""):gsub("%s+$", "")
end

-- Custom function to load environment variables
local function getEnv(filePath)
	local envContent = fs.readFile(filePath)
	if envContent then
		for line in envContent:gmatch("([^\n]+)") do
			-- Ignore comments and empty lines
			if not line:match("^#") and not line:match("^%s*$") then
				local key, value = line:match("([^=]+)=(.*)")
				if key and value then
					process.env[trim(key)] = trim(value)
				end
			end
		end
	end
end

-- Load environment variables from .env file
getEnv("./.env")

-- Error checking for required environment variables
if not process.env.ROBLOSECURITY or not process.env.PLACEID then
	error("ROBLOSECURITY and PLACEID must be set in the .env file.")
end

local cookie = ".ROBLOSECURITY=" .. process.env.ROBLOSECURITY .. "; Domain=.roblox.com"
local myPrivatePlaceId = process.env.PLACEID

print("Fetching latest place file from Roblox...")
local response = net.request({
	url = "https://assetdelivery.roblox.com/v2/assetId/" .. tostring(myPrivatePlaceId),
	headers = {
		Cookie = cookie,
	},
})

if response.statusCode ~= 200 then
	error("Failed to fetch asset info. Status code: " .. response.statusCode .. "\nBody: " .. response.body)
end

local responseTable = serde.decode("json", response.body)
local responseLocation = responseTable.locations[1].location

local placeFile = net.request({
	url = responseLocation,
}).body

fs.writeFile("oldGame.rbxl", placeFile)

local oldGame = roblox.deserializePlace(placeFile)
print("Successfully downloaded and deserialized the existing game.")

print("Building new game from codebase using Rojo...")
process.exec("rojo", { "build", "-o", "codebaseGame.rbxl" })

local codebaseGame = roblox.deserializePlace(fs.readFile("codebaseGame.rbxl"))
print("Successfully built and deserialized the codebase game.")

print("Starting merge process...")
-- Iterate through all the top-level children (services) of the codebase game.

local services = {
	"Workspace",
	"Lighting",
	"MaterialService",
	"ReplicatedFirst",
	"ReplicatedStorage",
	"ServerScriptService",
	"ServerStorage",
	"StarterGui",
	"StarterPack",
	"StarterPlayer",
	"Teams",
	"SoundService",
	"TextChatService",
	"TestService",
}

for _, service in ipairs(services) do
	print(service)
	-- Check if a service with the same name already exists in the old game.
	local existingService = oldGame:FindFirstChild(service)
  local codebaseService = codebaseGame:GetService(service)

	if existingService then
		print("Service found:", service, "- Merging children.")
		if service == "StarterPlayer" then
			-- Handle StarterPlayer properties specifically
			local existingSCS = existingService:FindFirstChild("StarterCharacterScripts")
			local existingSPS = existingService:FindFirstChild("StarterPlayerScripts")
			local newSCS = codebaseService:FindFirstChild("StarterCharacterScripts")
			local newSPS = codebaseService:FindFirstChild("StarterPlayerScripts")

			if existingSCS and newSCS then
				existingSCS:ClearAllChildren()
				for _, child in pairs(newSCS:GetChildren()) do
					child.Parent = existingSCS
				end
			end
			if existingSPS and newSPS then
				existingSPS:ClearAllChildren()
				for _, child in pairs(newSPS:GetChildren()) do
					child.Parent = existingSPS
				end
			end
		else
			for _, child in pairs(codebaseService:GetChildren()) do
				child.Parent = existingService
			end
		end
	else
		-- If the service does not exist, move the entire service.
		print("Service not found:", service, "- Adding to oldGame.")
		codebaseService.Parent = oldGame
	end
end

print("Merging complete. Saving combined place file to disk as 'merged_place.rbxl'...")
fs.writeFile("merged_place.rbxl", roblox.serializePlace(oldGame))
print("Done!")

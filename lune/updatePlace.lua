local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local net = require("@lune/net")
local process = require("@lune/process")
local fs = require("@lune/fs")

local ROBLOSECURITY: string = fs.readFile("lune/cookie")

local cookie = ".ROBLOSECURITY=" .. ROBLOSECURITY .. "; Domain=.roblox.com"

local myPrivatePlaceId = 1234567890

local response = net.request({
  url = "https://assetdelivery.roblox.com/v2/assetId/" .. tostring(myPrivatePlaceId),
  headers = {
    Cookie = cookie,
  },
})

local responseTable = serde.decode("json", response.body)
-- print(responseTable)
local responseLocation = responseTable.locations[1].location
-- print("Download link to place: " .. responseLocation)/
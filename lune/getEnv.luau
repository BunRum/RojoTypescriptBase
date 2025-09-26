local process = require("@lune/process")
local fs = require("@lune/fs")

local function trim(s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

return function (filePath)
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
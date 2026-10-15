--[[
  LUCKY HUB - Online Lua Key System
  Owner      : LUCKY HATHUNGO WALA
  Channel    : @LUCKY_HUB_DEV
  Bot        : @HATHUNGOWALABOT
  Features   : HWID Lock + Time Control (1h → 1y)
]]

local KeySystem = {
	Config = {
		ServerURL   = "https://your-key-worker.workers.dev/check",  -- Your Key System Worker URL
		LicenseKey  = "LUCKY-XXXX-XXXX-XXXX-XXXX",                 -- User's Key
	},
	IsValid = false,
	ExpireTime = 0
}

-- ===================== UTILS =====================
local function Log(msg)
	print(string.format("[LUCKY_HUB_KEY] [%s] %s", os.date("%H:%M:%S"), tostring(msg)))
end

local function Notify(msg)
	if _G.LUCKYHUBNotify then
		pcall(_G.LUCKYHUBNotify, msg)
	else
		print(msg)
	end
end

local function GetModule(name)
	local loaded = package and package.loaded and package.loaded[name]
	if loaded then return loaded end
	local ok, mod = pcall(require, name)
	return ok and mod or nil
end

-- ===================== HWID =====================
local function GetHWID()
	local hwid = "unknown"

	pcall(function()
		if _G.Client then
			if type(_G.Client.GetDeviceId) == "function" then
				hwid = tostring(_G.Client.GetDeviceId())
			elseif type(_G.Client.GetAndroidId) == "function" then
				hwid = tostring(_G.Client.GetAndroidId())
			elseif _G.Client.DeviceId then
				hwid = tostring(_G.Client.DeviceId)
			end
		end

		if (hwid == "unknown" or hwid == "") and _G.DataMgr then
			if _G.DataMgr.deviceInfo and _G.DataMgr.deviceInfo.deviceId then
				hwid = tostring(_G.DataMgr.deviceInfo.deviceId)
			end
		end
	end)

	if hwid == "unknown" or hwid == "" then
		hwid = "FALLBACK_" .. tostring(os.time()) .. math.random(1000, 9999)
	end

	return hwid
end

-- ===================== KEY CHECK =====================
function KeySystem.Check(callback)
	local http = GetModule("client.slua.logic.http.http_manager")
	if not http or type(http.Post) ~= "function" then
		Notify("[KEY] HTTP Manager not found")
		if callback then callback(false, "HTTP not available") end
		return
	end

	local hwid = GetHWID()
	Log("Checking key... HWID: " .. hwid)

	local body = string.format('{"key":"%s","hwid":"%s"}', KeySystem.Config.LicenseKey, hwid)

	http:Post(
		KeySystem.Config.ServerURL,
		{ ["Content-Type"] = "application/json" },
		body,
		nil,
		function(success, _, response)
			local valid = false
			local message = "Unknown error"

			if success and response then
				if tostring(response):find('"status":%s*true') then
					valid = true
					message = "Key Valid"

					local expire = response:match('"expires":(%d+)')
					if expire then
						KeySystem.ExpireTime = tonumber(expire) or 0
					end
				else
					local err = response:match('"message":"(.-)"')
					message = err or "Invalid / Expired / Banned / HWID Mismatch"
				end
			else
				message = "Cannot connect to Key Server"
			end

			KeySystem.IsValid = valid

			if valid then
				Notify("[KEY] ✓ Key Accepted - System Unlocked")
				Log("Key valid until: " .. (KeySystem.ExpireTime > 0 and os.date("%Y-%m-%d %H:%M", KeySystem.ExpireTime/1000) or "Unknown"))
			else
				Notify("[KEY] ✗ " .. message)
				Log("Key check failed: " .. message)
			end

			if callback then
				callback(valid, message)
			end
		end,
		12
	)
end

-- ===================== QUICK CHECK =====================
function KeySystem.IsAuthorized()
	return KeySystem.IsValid == true
end

-- ===================== INIT =====================
function KeySystem.Init(callback)
	Log("Initializing LUCKY HUB Key System...")
	Notify("[KEY] Checking license...")

	KeySystem.Check(function(valid, msg)
		if callback then
			callback(valid, msg)
		end
	end)
end

-- Auto start
KeySystem.Init()

-- Make it global
_G.LuckyHubKeySystem = KeySystem

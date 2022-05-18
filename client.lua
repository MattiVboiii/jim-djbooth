local QBCore = exports['qb-core']:GetCoreObject()
local PlayerData = {}
local Targets = {}
local xSound = exports.xsound
local Props = {}

AddEventHandler('onResourceStart', function(r) if (GetCurrentResourceName() ~= r) then return end PlayerData = QBCore.Functions.GetPlayerData() end)
AddEventHandler('QBCore:Client:OnPlayerLoaded', function() PlayerData = QBCore.Functions.GetPlayerData() end)
RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo) PlayerData.job = JobInfo end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() PlayerData = {} end)

CreateThread(function()
	for i = 1, #Config.Locations do
		if Config.Locations[i].enableBooth then
			local RequireJob = Config.Locations[i].job 
			if RequireJob == "public" then RequireJob = nil end
			Targets["Booth"..i] =
			exports['qb-target']:AddCircleZone("Booth"..i, Config.Locations[i].coords, 0.6, {name="Booth"..i, debugPoly=Config.Debug, useZ=true, },
				{ options = { { event = "qb-djbooth:client:playMusic", icon = "fab fa-youtube", label = "DJ Booth", job = RequireJob, zone = i, }, }, distance = 2.0 })
			if Config.Locations[i].prop then
				RequestModel(Config.Locations[i].prop) while not HasModelLoaded(Config.Locations[i].prop) do Citizen.Wait(1) end
				Props[#Props+1] = CreateObject(Config.Locations[i].prop, Config.Locations[i].coords,false,false,false)
				SetEntityHeading(Props[#Props], math.random(1,359)+0.0)
				FreezeEntityPosition(Props[#Props], true)
			end
		end
	end
end)

RegisterNetEvent("qb-djbooth:client:playMusic", function(data)
	local booth = ""
	for k, v in pairs(Config.Locations) do if #(GetEntityCoords(PlayerPedId()) - v["coords"]) <= v["radius"] then booth = v["job"]..k end end
	local song = { playing = "", duration = "", timeStamp = "",	duration = "", url = "", icon = "", header = "", txt = "🔇 No Song Playing", volume = "" }		
	local p = promise.new()
	QBCore.Functions.TriggerCallback('qb-djbooth:songInfo', function(cb) p:resolve(cb)end)
	previousSongs = Citizen.Await(p)
	
	-- Grab song info and build table
	if xSound:soundExists(booth) then
		song = {
			playing = xSound:isPlaying(booth),
			timeStamp = "",
			url = xSound:getLink(booth),
			icon = "https://img.youtube.com/vi/"..string.sub(xSound:getLink(booth), - 11).."/mqdefault.jpg",
			header = "",
			txt = xSound:getLink(booth),
			volume = ": "..math.ceil(xSound:getVolume(booth)*100).."%"
		}
		if xSound:isPlaying(booth) then song.header = "Currently Playing: " end
		if xSound:isPaused(booth) then song.header = "Currently Paused: " end
		if xSound:getMaxDuration(booth) == 0 then song.timeStamp = "🔴 Live" end
		if xSound:getMaxDuration(booth) > 0 then
			local timestamp = (xSound:getTimeStamp(booth) * 10)
			local mm = (timestamp // (60 * 10)) % 60.
			local ss = (timestamp // 10) % 60.			
			timestamp = string.format("%02d:%02d", mm, ss)
			local duration = (xSound:getMaxDuration(booth) * 10)
			mm = (duration // (60 * 10)) % 60.
			ss = (duration // 10) % 60.
			duration = string.format("%02d:%02d", mm, ss)
			song.timeStamp = "("..timestamp.."/"..duration..")"
			if xSound:isPlaying(booth) then song.timeStamp = "🔊 "..song.timeStamp else song.timeStamp = "🔇 "..song.timeStamp end
		end
	end
	
	local musicMenu = {}
	musicMenu[#musicMenu+1] = { isMenuHeader = true, header = '<img src=https://cdn-icons-png.flaticon.com/512/1384/1384060.png width=20px></img>&nbsp; DJ Booth', txt = "" }
	musicMenu[#musicMenu+1] = { isMenuHeader = true, icon = song.icon, header = song.header, txt = song.txt.."<br>"..song.timeStamp }
	musicMenu[#musicMenu+1] = { icon = "fas fa-circle-xmark", header = "", txt = "Close", params = { event = "qb-menu:client:closemenu" } }
	musicMenu[#musicMenu+1] = { icon = "fab fa-youtube", header = "Play a song", txt = "Enter a youtube URL", params = { event = "qb-djbooth:client:musicMenu", args = { zoneNum = data.zone } } }
	if previousSongs[booth] then 
		musicMenu[#musicMenu+1] = { icon = "fas fa-clock-rotate-left", header = "Song History", txt = "View previous songs", params = { event = "qb-djbooth:client:history", args = { history = previousSongs[booth], zoneNum = data.zone } } }
	end
	if xSound:soundExists(booth) then
		if xSound:isPlaying(booth) then
			musicMenu[#musicMenu+1] = { icon = "fas fa-pause", header = "Pause Music", txt = "Pause music", params = { isServer = true, event = "qb-djbooth:server:pauseMusic", args = { zoneNum = data.zone } } }
		elseif xSound:isPaused(booth) then
			musicMenu[#musicMenu+1] = { icon = "fas fa-play", header = "Resume Music", txt = "Resume music", params = { isServer = true, event = "qb-djbooth:server:resumeMusic", args = { zoneNum = data.zone } } }
		end
		musicMenu[#musicMenu+1] = { icon = "fas fa-volume-off", header = "Volume"..song.volume, txt = "Change volume", params = { event = "qb-djbooth:client:changeVolume", args = { zoneNum = data.zone,  } } }
		musicMenu[#musicMenu+1] = { icon = "fas fa-stop", header = "Stop music", txt = "Turn off the music", params = { isServer = true, event = "qb-djbooth:server:stopMusic", args = { zoneNum = data.zone } } }
	end
	exports["qb-menu"]:openMenu(musicMenu)
	song = nil
end)

RegisterNetEvent("qb-djbooth:client:history", function(data)
	local musicMenu = {}
	musicMenu[#musicMenu+1] = { icon = "fas fa-clock-rotate-left", isMenuHeader = true, header = "<img src=https://cdn-icons-png.flaticon.com/512/1384/1384060.png width=20px></img>&nbsp; DJ Booth", txt = "History - Press to play" }
	musicMenu[#musicMenu+1] = { icon = "fas fa-circle-arrow-left", header = "", txt = "Back", params = { event = "qb-djbooth:client:playMusic", args = { job = data.job, zone = data.zoneNum } } }
	for i = #data.history, 1, -1 do
		musicMenu[#musicMenu+1] = { icon = "https://img.youtube.com/vi/"..string.sub(data.history[i], - 11).."/mqdefault.jpg", header = "", txt = data.history[i], params = { event = "qb-djbooth:client:historyPlay", args = { song = data.history[i], zoneNum = data.zoneNum } } }
	end
	exports["qb-menu"]:openMenu(musicMenu)
end)

RegisterNetEvent('qb-djbooth:client:historyPlay', function(data) TriggerServerEvent('qb-djbooth:server:playMusic', data.song, data.zoneNum) end)

RegisterNetEvent('qb-djbooth:client:musicMenu', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = 'Song Selection',
        submitText = "Submit",
        inputs = { { type = 'text', isRequired = true, name = 'song', text = 'YouTube URL' } } })
    if dialog then
        if not dialog.song then return end
		-- Attempt to correct link if missing "youtube" as some scripts use just the video id at the end
		if not string.find(dialog.song, "youtu") then dialog.song = "https://www.youtube.com/watch?v="..dialog.song end
		TriggerEvent("QBCore:Notify", "Loading link: "..dialog.song)
        TriggerServerEvent('qb-djbooth:server:playMusic', dialog.song, data.zoneNum)
    end
end)

RegisterNetEvent('qb-djbooth:client:changeVolume', function(data)
    local dialog = exports['qb-input']:ShowInput({
        header = 'Music Volume',
        submitText = "Submit",
        inputs = { { type = 'text', isRequired = true,  name = 'volume', text = "Min: 0 - Max: 100" } } })
    if dialog then
        if not dialog.volume then return end
		-- Automatically correct from numbers to be numbers xsound understands
		dialog.volume = (dialog.volume / 100)
		-- Don't let numbers go too high or too low
		if dialog.volume <= 0.01 then dialog.volume = 0.01 end
		if dialog.volume > 1.0 then dialog.volume = 1.0 end
		TriggerEvent("QBCore:Notify", "Setting booth audio to: "..math.ceil(dialog.volume * 100).."%", "success")
        TriggerServerEvent('qb-djbooth:server:changeVolume', dialog.volume, data.zoneNum)
    end
end)

AddEventHandler('onResourceStop', function(r) 
	if r ~= GetCurrentResourceName() then return end
	for k, v in pairs(Targets) do exports['qb-target']:RemoveZone(k) end
	for i = 1, #Props do DeleteEntity(Props[i]) end
end)
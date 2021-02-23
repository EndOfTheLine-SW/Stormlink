g_savedata = {}
pwait={}
last_vehicle={}
boardlist={} 
zones_arrival={}
zones_departure ={}
v_seats={}
v_cap ={}
pedtype = {1,3,5,6,7,2,9,11}

function onCreate(is_world_create)
	if is_world_create then
		g_savedata["pwait"]={}
		g_savedata["v_seats"]={}
		g_savedata["pmanifest"]={}
		g_savedata["pdata"] = {["setpop"] = 5, ["ptarget"] = 0, ["pdelivered"] = 0, ["pdays"] = 7,["pbonus"]=true}
	end

	pwait=g_savedata.pwait
	pdata = g_savedata.pdata
	v_seats=g_savedata.v_seats
	pmanifest=g_savedata.pmanifest
	activestations=g_savedata.activestations

	zones_departure = server.getZones("type=spawnzone")
	zones_arrival = server.getZones("type=arrivalzone")
	server.announce("[Server]", "Passenger Mod Scripts reloaded.",-1)

end

function onTick()
-- Check Date and reload waiting peds on new day/decrease health of old peds
if not date then
	date = server.getDateValue()
else
	if date ~= server.getDateValue() then
		pdata.pdays = pdata.pdays-1
		if pdata.pdays <=0 then
		pdata.pdays = 7
		pdata.pbonus = true
		spawnPassengers(spawnpop)
		

		else
		if pdata.pbonus then
		server.notify(user_peer_id,"New Day", pdata.pdays .." Days left to deliver all passengers and claim your bonus. There are "..#pwait .." Passengers still waiting for pickup. Make sure to check on the ".. #pmanifest .." passengers onboard or enroute!", 1)
		else
		server.notify(user_peer_id,"New Day", pdata.pdays .." Days left before passengers reset and you qualify for bonuses again. There are "..#pwait .." Passengers still waiting for pickup. Make sure to check on the ".. #pmanifest .." passengers onboard or enroute!", 1)
		end
		end
		date = server.getDateValue()
		passSatisfaction()
		g_savedata.pdata=pdata
		
	end
end
--[[ Check if stopped or sufficiently slow, update zones if need be
if not pos then
pos = server.getPlayerPos(peer_id)
end
oldpos = pos
pos = server.getPlayerPos(peer_id)
if matrix.distance(pos,oldpos) <0.008 and not stopped then
	server.announce("[Server]", "Stopped")
	stopped = true
elseif matrix.distance(pos,oldpos) >0.008 and stopped then
	server.announce("[Server]", "Moving")
	stopped = false	
end  ]]
end


function onCustomCommand(full_message, user_peer_id, is_admin, is_auth, command, one, two, three, four, five)
-- SPAWNING COMMANDS
vehicle = last_vehicle[user_peer_id]
command = string.lower(command)
if one then
one = string.lower(one)
end

	if (command == "?openstation")then
	
		if not one then
			server.notify(user_peer_id,"Station Info Needed", "Missing name of station to open.", 2)
		else
			
			local success = false
			for i, station in pairs(zones_arrival) do
				if station.name == one then
					success = true
				end
			end
			if success then
			
				local exists = false
				for i, station in pairs(activestations) do
					if station == one then
						exists = true
					end
				end
				if exists then
					server.notify(user_peer_id,"Station Already Open", one.." Station is already open!", 2)
				else
					local cost = 3000
					
					if server.getCurrency()-cost <=0 and server.getGameSettings().infinite_money==false then
					server.notify(user_peer_id,"Cannot Afford Purchase", "Insufficient Funds to purchase a new station. Each station costs $".. cost .. " to open.", 2)
					else
					server.setCurrency(server.getCurrency()-cost, server.getResearchPoints())
					table.insert(activestations, one)
					g_savedata.activestations = activestations
					server.notify(user_peer_id,"New Station Opened", one .. " Station has now been opened! Reloading Passengers...", 4)
					spawnPassengers(pdata.setpop)
					end
				end
			else
				server.notify(user_peer_id,"Station Not Found", one .." Station cannot be found. Check map to see station names", 2)
			end
		end
	

	elseif (command == "?closestation")then
  
		if not one then
			server.notify(user_peer_id,"Station Info Needed", "Missing name of station to close.", 2)
		else
			local success = false
			for i, station in pairs(activestations) do
				if station == one then
					table.remove(activestations, i)
					success = true
				end
			end
			if success then
				server.notify(user_peer_id,"Station Closed", one .. " Station has been closed. Passengers hope service will be restored in the future.", 4)
			else
				server.notify(user_peer_id,"Station Not Found", one .." Station cannot be found. Check the name of the station on the map", 2)
			end
		end
	


	elseif (command == "?reloadpeds")then
		if not one then
			else pdata.setpop = one
		end
		spawnPassengers(pdata.setpop)
		pdata.ptarget = pdata.ptarget+#pmanifest
		pdata.pdelivered = 0
		g_savedata.pdata=pdata
	
	

	elseif (command == "?despawnpeds")then	
				for id,passenger in pairs(pwait) do
					server.despawnObject(passenger.id, true)

        end
        for id,passenger in pairs(pmanifest) do
					v_seats[passenger.seat] = false
					server.despawnObject(passenger.id, true)
				end
			pmanifest ={}
      pwait={}
			g_savedata.v_seats = v_seats
			g_savedata.pwait = pwait
			g_savedata.pmanifest = pmanifest
	
	
	-- LOADING / UNLOADING COMMANDS
	
elseif (command == "?pload") then
		if not vehicle then
		novehicle()
		
		elseif not v_seats[vehicle.id*1000] then
		server.notify(user_peer_id,"Unknown Capacity", "Vehicle capacity is undefined. Set vehicle capacity with command ?pcap.", 2)
		elseif not one then
		server.notify(user_peer_id,"Station Info Needed", "Missing name of destination. E.G. ?pload camodo will load passengers going to Camodo.", 2)
		else
		v_zonestatus = "Enroute"
		v_transform = server.getVehiclePos(vehicle.id)
		v_x, v_y, v_z = matrix.position(v_transform)
		--	server.announce("[Server]", "Vehicle coordinates" .. v_x .. ",".. v_y .. ",".. v_z)
		for stationzone_index,stationzone in pairs(zones_arrival) do
			stationzone=zones_arrival[stationzone_index]
			inzone = server.isInZone(v_transform, stationzone.name)
			if inzone then
			v_zonestatus = stationzone.name
			end
		end
		if v_zonestatus == "Enroute" then
		server.notify(user_peer_id,"Enroute", "Vehicle is enroute; Cannot load. Try getting closer to the terminal.", 2)
		else
		v_dest = one		
		boardlist={}
		passcount = 0
		for passlist_id,passenger in pairs (pwait) do
			--passenger = pwait[passlist_id]
			passloc=server.getObjectPos(passenger.id)

			if ((passenger.destination == v_dest or v_dest == "all") and passenger.origin == v_zonestatus and passenger.seat==0) then
				passcount = passcount + 1
				boardlist[passcount] = {["waitindex"]=passlist_id, ["id"] = passenger.id, ["destination"] = passenger.destination, ["type"] = "new"}
				
			end
			
			
			
		end
		for manifest_id,passenger in pairs (pmanifest) do
			--passenger = pwait[passlist_id]
			passloc=server.getObjectPos(passenger.id)
			if ((passenger.destination == v_dest or v_dest == "all") and server.isInZone(passloc, v_zonestatus) and vehicle.id ~= math.floor(passenger.seat/1000)) then
				passcount = passcount + 1
				boardlist[passcount] = {["manifestindex"]=manifest_id, ["id"] = passenger.id, ["destination"] = passenger.destination, ["type"] = "transfer"}
				
			end
			
			
			
		end
		
		
		if passcount == 0 then
			server.notify(user_peer_id,"No Passengers!", "No passengers at " .. v_zonestatus .. " for " .. v_dest, 2)

		else
		local boarding = true
		local boardcount = #boardlist

		-- make list of empty seats
			local openseats = {}
			n = 1
			for i = 1,v_seats[vehicle.id*1000] do
				seatid = vehicle.id*1000+i
				if not v_seats[seatid] then
					openseats[n] = seatid
					n = n+1
				end
			end				
	
		while boarding do
			--get seat to load passenger into
		
			if (#openseats <=0) then
				server.notify(user_peer_id,"Vehicle Full!", "Your vehicle is full!" .. boardcount .. " passengers not loaded.", 2)

				boarding=false
			else
				seatnum = math.random(#openseats)
				seatid = table.remove(openseats, seatnum)
				seatnum =seatid-(vehicle.id*1000)
				if not v_seats[seatid] then
						seatname = "Seat"..seatnum
						boardped=boardlist[boardcount]			
						server.setCharacterSeated(boardped.id, vehicle.id, seatname)

						--server.announce("[Crew]", boardped.id .. " is now sitting in " ..seatname)
						v_seats[seatid] = true
						seatlook=false						
						
						if boardped.type == "transfer" then
						v_seats[pmanifest[boardped.manifestindex].seat]= false
						pmanifest[boardped.manifestindex].seat = seatid
						
						else
						pwait[boardped.waitindex].seat = seatid
						table.insert(pmanifest, table.remove(pwait,boardped.waitindex))
						
						
						end
						boardcount = boardcount-1
							if boardcount == 0  then
								boarding=false
								server.notify(user_peer_id,"Boarding Complete", #boardlist-boardcount .. " passengers now on board to "..v_dest, 4)
							end
						--end
					end
				end
			end
		
		g_savedata.v_seats = v_seats
		g_savedata.pmanifest = pmanifest
		end
		end
		end

			
			

		
		
		-- ****************************Unloading************************************************************	
		elseif (command == "?punload") then
		

			if not vehicle then
			novehicle()
		else
			v_zonestatus = "Enroute"
			v_transform = server.getVehiclePos(vehicle.id)
			v_x, v_y, v_z = matrix.position(v_transform)
			--	server.announce("[Server]", "Vehicle coordinates" .. v_x .. ",".. v_y .. ",".. v_z)
			for stationzone_index,stationzone in pairs(zones_arrival) do
				stationzone=zones_arrival[stationzone_index]
				inzone = server.isInZone(v_transform, stationzone.name)
				if inzone then
					v_zonestatus = stationzone.name
				end
			end
			if v_zonestatus == "Enroute" then
				server.notify(user_peer_id,"Enroute", "Vehicle is enroute; Cannot unload. Try getting closer to the terminal.", 2)
			else
			
				
				local passcount = 0
				local paid = 0
				for i=#pmanifest,1,-1 do
					passenger = pmanifest[i]
					if v_zonestatus == passenger.destination then
							passloc=server.getObjectPos(passenger.id)
							if server.isInZone(passloc, v_zonestatus) then
								paid = paid + passenger.fare
								passcount = passcount + 1
								server.despawnObject(passenger.id, true)
								pdata.pdelivered = pdata.pdelivered+1
								v_seats[passenger.seat] = false
                				table.remove(pmanifest, i)
							end
					end
				end
				if paid >0 then
        server.notify(user_peer_id,"Arrival", passcount.." passengers disembarked at " .. v_zonestatus ..". Total fare collected = $"..paid,4)
				server.setCurrency(paid + server.getCurrency(), server.getResearchPoints()+1)
        else
        server.notify(user_peer_id,"Arrival", "No passengers disembarked at " .. v_zonestatus,4)
        end
        g_savedata.v_seats = v_seats
				g_savedata.pmanifest = pmanifest	
				
				-- BONUS FOR ALL PASSENGERS DELIVERED
				if #pmanifest==0 and #pwait==0 and pdata.ptarget >0 then
					local stationcount = #activestations
					if pdata.pbonus == true then
						
						local bonus = stationcount*2000
						local bonusrp = stationcount*2
						server.setCurrency(bonus + server.getCurrency(), bonusrp+server.getResearchPoints())
						server.notify(user_peer_id,"All Passengers Delivered!", "Congradulations! All ".. pdata.ptarget .." passengers have been delivered across your network of " ..stationcount.." stations. You have been awarded a bonus of $".. bonus.. " and "..bonusrp.. " Research Points. Bonus requalification after refresh in "..pdata.pdays.." days. Passengers at all stations have been refreshed.",4)
						pdata.pbonus = false
						g_savedata.pdata = pdata
					else
						server.notify(user_peer_id,"All Passengers Delivered!", "All ".. pdata.ptarget .." passengers have been delivered across your network of " ..stationcount.." stations. No bonus awarded; Bonus requalification after refresh in "..pdata.pdays.." days. Passengers at all stations have been refreshed.",4)
				end
				spawnPassengers(spawnpop)
				end			
			end
	
		end
	
	
	
	
	elseif (command == "?pcap")then
		
		if not vehicle then
		novehicle()
		return
		end
		one = tonumber(one)
		if not one then
			server.notify(user_peer_id,"Missing Vehicle Capacity Number", "Vehicle Capacity missing. Include your capacity after the command as a number. E.G. ?pcap 20 will set capacity to 20 passengers", 2)
		return
		else
			local vehicle_id =last_vehicle[user_peer_id].id
			v_cap[vehicle_id] = one
			v_seats[vehicle_id*1000]=one
			for i = 1, one do
				seatid = vehicle_id*1000+i
		--	server.announce("server", seatid)
				v_seats[seatid] = false
			end
		end
		g_savedata.v_seats = v_seats
		
		server.notify(user_peer_id, "Capacity Updated", "New Capacity: " ..v_cap[last_vehicle[user_peer_id].id], 5)
	
	
		-- DEBUG COMMANDS
	elseif (command == "?pmanifest")
		then
	
		printTable(pmanifest, "Passenger Manifest")
	
		elseif (command == "?pwaiting")
		then
	
		printTable(pwait, "Waiting Passengers")
	
	elseif (command == "?liststations")
		then
	
		printTable(activestations, "Open Stations")
	
	elseif (command == "?listarrivalzones")
		then
	
		printTable(zones_arrival, "Arrival Zones")
	
	elseif (command == "?phelp")
		then
		server.announce("[StormLink Help]", "Note: All passenger vehicles must have seats numbered sequentially as follows: Seat1, Seat2, Seat3, etc. The Active Vehicle is the last vehicle you've sat in. You can only load and transport passengers using the commands below. See Workshop Description for examples.\n\n COMMANDS: \n\n ?pcap ## - Sets the Active Vehicle's capacity to ##\n\n ?pload stationname - Loads the active vehicle with passengers with destination stationname \n\n ?punload - Unloads all passengers going to the station that the vehicle is currently at\n ?openstation stationname - Activates a new station at stationname for passengers to use for $3000\n\n ?closestation stationname - Closes a station so passengers cannot use it.\n\n ?reloadpeds ## - Reloads all waiting passengers. ## is an optional number to set the number of passengers per spawning zone, useful for optimization.\n\n ?despawnpeds - removes all passengers and resets passenger lists, both waiting and enroute. Use in emergencies if game is really slow or passengers are doing odd things.",user_peer_id)
		
	

else
server.notify(user_peer_id,"Unrecognized Command", command .." is not a recognized Stormlink command. Please try again. Use ?phelp for a list of recognized commands, or see the documentation in the Workshop Description.", 2)
end
end


-- FUNCTIONS
function onPlayerSit(peer_id, vehicle_id, seat_name)
--		if (not last_vehicle[peer_id].id) then 
			last_vehicle[peer_id] = {["id"] = vehicle_id}
			if not v_seats[vehicle_id*1000] then
				server.notify(peer_id, "Vehicle Capacity Needed", "Cannot find Capacity Data for this vehicle. Program this vehicle's capacity with ?pcap (E.G. ?pcap 20 sets vehicle capacity to 20 seats", 7)
			else
		end

end

	
--**************************************************************************]]	
function onToggleMap(peer_id, is_open)
if is_open then
	for i, station in pairs(zones_arrival) do
		station=zones_arrival[i]
		if not station.mapid then
			station.mapid = server.getMapID()
		end

		x,y,z = matrix.position(station.transform)
		
		local success = false
		for i, active in pairs(activestations) do
			if active == station.name then
				success = true
			end
		end
		if success then
			station.pwaiting = ""
			for j, deststation in pairs (zones_arrival) do

				mapicon = 3
				local destcount = 0
				destline = ""
				for k, ped in pairs(pwait) do
					ped=pwait[k]
					if ped.destination == deststation.name and ped.origin == station.name and ped.seat == 0 then
						destcount = destcount+1
						fare = ped.fare
					end

				end
				if destcount ~=0 then
					destline = destcount .. " to " .. deststation.name .. " for $" .. fare .. "\n"
				end
				if destline ~= nil then
					station.pwaiting = station.pwaiting .. destline
				end

			end
		else
			mapicon = 8
			station.pwaiting = "Station is Closed. Open for $3000 with command ?openstation stationname"
		end
		server.addMapObject(-1, station.mapid, 0, mapicon, x, z, 0, 0, 0, 0, station.name, 0, station.pwaiting)
	end
else
	for i, station in pairs(zones_arrival) do
		station=zones_arrival[i]
		server.removeMapID(-1, station.mapid)
	end
end

end



function spawnPassengers(spawnpop)
if pwait then
	for id, passenger in pairs(pwait) do
		--passenger=pwait[id]
      	if passenger.seat == 0 then
	  	--pwait[id].origin = 'despawned'
      	v_seats[passenger.seat] = false
      	server.despawnObject(passenger.id, true)
		end
	end
end
pwait={}
pdata.pdead=false
pdata.ptarget=0
for i, spawnzone in pairs(zones_departure) do
	
	local success = false
	for i, active in pairs(activestations) do
		if active == spawnzone.name then
			success = true
		end
	end
	if success then	
	destname = spawnzone.name
	while spawnzone.name == destname do
		i = math.random(1, #zones_arrival)
		destzone = zones_arrival[i]
		local success = false
		for i, active in pairs(activestations) do
			if active == destzone.name then
				success = true
			end
		end
		if success then
		destname=destzone.name
		end
	end
	
	for n=1,pdata.setpop do

			x,y,z = matrix.position(spawnzone.transform)
			x = x+(math.sin(math.random()*100)-0.5*2)
			z = z+(math.cos(math.random()*100)-0.5*2)
			spawncoords = matrix.translation(x,y,z)

			fareseed = math.ceil(matrix.distance(spawnzone.transform, destzone.transform)/1000)
			fare = math.ceil((fareseed^(fareseed/80)+10*fareseed)/10)*10
			passinfo = pedtype[math.random(#pedtype)]
			passId = server.spawnCharacter(spawncoords, passinfo)
			pdata.ptarget = pdata.ptarget + 1			
			local pwaitline = {["id"] = passId, ["origin"] = spawnzone.name, ["destination"] = destzone.name, ["fare"] = fare, ["seat"] = 0}
			table.insert(pwait,pwaitline)
		end
--	server.announce("[Server]", spawnpop.." Passengers from " ..spawnzone.name .." to " ..destzone.name .. " for $" ..fare)
	
	end
	

	end
--	pdata.pdays = 7
	pdata.pdelivered = 0
	g_savedata.pdata = pdata
	g_savedata.pwait = pwait
	if pdata.pbonus then
		server.notify(user_peer_id,"Passengers Refreshed", "Waiting Passengers have been refreshed at all open terminals. There are "..#pwait.." Passengers waiting for transport. Check your map for updated destinations. Make sure to check on the ".. #pmanifest .." additional passengers still onboard or enroute. "..pdata.pdays.." days left to deliver them all for your bonus!", 1)
	else
		server.notify(user_peer_id,"Passengers Refreshed", "Waiting Passengers have been refreshed at all open terminals. There are "..#pwait.." Passengers waiting for transport. Check your map for updated destinations. Make sure to check on the ".. #pmanifest .." additional passengers still onboard or enroute. "..pdata.pdays.." days left before you requalify for your bonus!", 1)
	end

end

function passSatisfaction()
	for manifestindex=#pmanifest, 1,-1 do
		local dead = false
		local passenger = pmanifest[manifestindex]
		hp,incap,dead = server.getCharacterData(passenger.id)
		server.setCharacterData(passenger.id, hp-30,true,false) 
		if incap or dead or hp-30<0 then
			v_seats[passenger.seat] = false
    		server.despawnObject(passenger.id, true)
			table.remove(pmanifest,manifestindex)
			if pdata.pbonus == true then
			server.notify(user_peer_id,"Passenger Fatality", "A passenger has died. Bonus has been cancelled this week.",4)
			end
			pdata.pbonus = false
		end
	end
g_savedata.pwait = pwait
g_savedata.pdata = pdata
end

function activestation(zones)
	for i, active in pairs(activestations) do
		if active == zones.name then
			return true
		end
	end
	return false
end
function tableLength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

-- recursively outputs the contents of a table to the chat window for debugging purposes.
-- name is the name that should be displayed for the root of the table being passed in.
-- m is an optional parameter used when the function recurses to specify a margin string that will be prepended before printing for readability
function printTable(table, name, m)
	local margin = m or ""

	if tableLength(table) == 0 then
		server.announce("", margin .. name .. " = {}")
	else
		server.announce("", margin .. name .. " = {")
		
		for k, v in pairs(table) do
			local vtype = type(v)

			if vtype == "table" then
				printTable(v, k, margin .. "    ")
			elseif vtype == "string" then
				server.announce("", margin .. "    " .. k .. " = \"" .. tostring(v) .. "\",")
			elseif vtype == "number" or vtype == "function" or vtype == "boolean" then
				server.announce("", margin .. "    " .. k .. " = " .. tostring(v) .. ",")
			else
				server.announce("", margin .. "    " .. k .. " = " .. tostring(v) .. " (" .. type(v) .. "),")
			end
		end

		server.announce("", margin .. "},")
	end
end

function onPlayerJoin(steam_id, name, peer_id, is_admin, is_auth)
	if not g_savedata.activestations then
		local startpos = server.getPlayerPos(peer_id)
		local startx, starty, startz = matrix.position(startpos)

		
		if starty >= 80000 or startz >=80000 then
			g_savedata["activestations"]={"arctichub","endo", "trinite", "arcticvillage"}
		else 
			if startx < -8000 then
				g_savedata["activestations"]={"camodo","spycakes","donkk","key"}
		
			else
				g_savedata["activestations"]={"sawyern","hospital","olsen","holt"}
			end
		end
		
		activestations=g_savedata.activestations
		server.notify(peer_id,"Welcome to Stormlink!", "  Congradulations! You've been awarded a contract to transport passengers in the world of Stormworks. You have 1 week to deliver all passengers to their destinations. If you finish early, you'll get a bonus. Open more stations and expand your network to get bigger bonuses! For full documentation of the Stormlink mod, please read the workshop description. Thanks for playing!", 4)
		spawnPassengers(spawnpop)
		server.announce("[Stormlink Info]","Thanks for playing the StormLink Passenger Mod! Note that you must name each passenger seat sequentially, I.E. Seat1, Seat2, Seat3, etc. to carry passengers. You must use loading and unloading commands at stations in order to carry passengers and get paid. \n Commands are given using the chat window. Press enter to open the chat, then type in your command. Note that correct spelling matters!. For a full list of commands, type ?phelp in chat.", peer_id)
	end
end

function novehicle()
server.notify(user_peer_id,"No Active Vehicle", "You haven't activated a vehicle yet. Sit in your vehicle to activate it.", 2)
end	
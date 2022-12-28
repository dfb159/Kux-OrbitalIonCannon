require "modules.tools"
require "modules.luaext"
require "modules.ion-cannon-table"
local mod_gui = require("mod-gui")

UiElementDefinitions = {
	["ion-cannon-button"] = {type="button", style = "ion-cannon-button-style"}
}

ModGui = {}

local on_gui_checked_state_changed = function(event)
	local checkbox = event.element
	if checkbox.name == "show" then
		global.goToFull[event.player_index] = false
		global.permissions[-1] = checkbox.state
		open_GUI(game.players[event.player_index])
	elseif checkbox.name == "ion-cannon-auto-target-enabled" then
		global.goToFull[event.player_index] = false
		global.permissions[-2] = checkbox.state
		open_GUI(game.players[event.player_index])
	else
		local index = tonumber(checkbox.name)
		if checkbox.parent.name == "ion-cannon-admin-panel-table" then
			Permissions.setPermission(index, checkbox.state)
			if index == 0 then
				Permissions.setAll(checkbox.state)
				global.goToFull[event.player_index] = false
				open_GUI(game.players[event.player_index])
			end
		end
	end
end

--- Called when LuaGuiElement is clicked.
-- element :: LuaGuiElement: The clicked element.
-- player_index :: uint: The player who did the clicking.
-- button :: defines.mouse_button_type: The mouse button used if any.
-- alt :: boolean: If alt was pressed.
-- control :: boolean: If control was pressed.
-- shift :: boolean: If shift was pressed.
local on_gui_click = function(event)
	local player = game.players[event.element.player_index]
	local force = player.force
	local name = event.element.name
	local surfaceName
	if name == "ion-cannon-button" then
		open_GUI(player)
		return
	elseif name == "add-ion-cannon" then
		surfaceName = addIonCannon(force, player.surface)
		global.IonCannonLaunched = true
		script.on_nth_tick(60, process_60_ticks)
		for i, player in pairs(force.connected_players) do
			init_GUI(player)
			playSoundForPlayer("ion-cannon-charging", player)
		end
		force.print({"ion-cannons-in-orbit", surfaceName, countOrbitingIonCannons(force, player.surface)})
		return
	elseif name == "add-five-ion-cannon" then
		surfaceName = addIonCannon(force, player.surface)
		addIonCannon(force, player.surface)
		addIonCannon(force, player.surface)
		addIonCannon(force, player.surface)
		addIonCannon(force, player.surface)
		global.IonCannonLaunched = true
		script.on_nth_tick(60, process_60_ticks)
		for i, player in pairs(force.connected_players) do
			init_GUI(player)
			playSoundForPlayer("ion-cannon-charging", player)
		end
		force.print({"ion-cannons-in-orbit", surfaceName, countOrbitingIonCannons(force, player.surface)})
		return
	elseif name == "remove-ion-cannon" then
		if #GetCannonTableFromForce(force) > 0 then
			table.remove(GetCannonTableFromForce(force))
			for i, player in pairs(force.connected_players) do
				update_GUI(player)
			end
			force.print({"ion-cannon-removed"})
		else
			player.print({"no-ion-cannons"})
		end
		return
	elseif name == "recharge-ion-cannon" then
		ReduceIonCannonCooldowns(settings.global["ion-cannon-cooldown-seconds"].value);
	end
end

ModGui.initEvents = function ()
	script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
	script.on_event(defines.events.on_gui_click, on_gui_click)
end

function getUiElement(parent, name, createIfNotExist)
	--print("getUiElement",name)
	if not parent.object_name then
		parent = findUiElementByName(parent[1], parent[2], createIfNotExist)
	end
	if parent == nil then return nil end

	local element = parent[name]
	if element then return element end
	if not createIfNotExist then return nil end
	local definition = UiElementDefinitions[name]
	if not definition then error("Definition not found. Name: '"..name.."'") end
	definition["name"]=name
	definition["index"]=nil
	print("create "..definition["type"].." '"..definition["name"].."'")
	return parent.add(definition)
end

function findUiElementByName(player, name, createIfNotExist)
	if name == "ion-cannon-button" then return getUiElement(mod_gui.get_button_flow(player), name, createIfNotExist) end
	error("Unknwon element. Name: '"..name.."'")
end

function destroyUiElement(player, name)
	local element = findUiElementByName(player, name, false)
	if not element then return end
	element.parent[name].destroy()
end

function init_GUI(player)
	--print("init_GUI")
	--TODO is called every 60 seconds!

	local ict = GetCannonTableFromForce(player.force)
	if ict == nil or #ict == 0 and not settings.global["ion-cannon-cheat-menu"].value then
		local frame = player.gui.left["ion-cannon-stats"]
		if frame then frame.destroy() end
		if player.gui.top["ion-cannon-button"] then player.gui.top["ion-cannon-button"].destroy() end
		destroyUiElement(player,"ion-cannon-button")
	else
		findUiElementByName(player, "ion-cannon-button", true)
	end
end

local createAdminPanel =function(parent)
	-- parent: frame
	local adminPanel = parent.add{type = "table", column_count = 3, name = "ion-cannon-admin-panel-table"}

	-- 1st row
	adminPanel.add{type = "label", caption = {"player-names"}}
	adminPanel.add{type = "label", caption = {"allowed"}}
	adminPanel.add{type = "label", caption = ""}

	-- 2nd row
	adminPanel.add{type = "label", caption = {"toggle-all"}}
	adminPanel.add{type = "checkbox", state = global.permissions[0], name = "0"}
	adminPanel.add{type = "label", caption = ""}

	-- player rows
	for _, player in pairs(game.players) do
		adminPanel.add{type = "label", caption = player.name }
		adminPanel.add{type = "checkbox", state = Permissions.getPermission(player.index), name = player.index .. ""}
		adminPanel.add{type = "label", caption = iif(player.admin," [Admin]","") }
	end

	return adminPanel
end

function open_GUI(player)
	local frame = player.gui.left["ion-cannon-stats"]
	local force = player.force
	local forceName = force.name
	local player_index = player.index
	if frame and global.goToFull[player_index] then
		frame.destroy()
	else
		if global.goToFull[player_index] and #GetCannonTableFromForce(force) < 40 then
			global.goToFull[player_index] = false
			if frame then
				frame.destroy()
			end
			frame = player.gui.left.add{type = "frame", name = "ion-cannon-stats", direction = "vertical"}
			frame.add{type = "label", caption = {"ion-cannon-details-full"}}
			frame.add{type = "table", column_count = 2, name = "ion-cannon-table"}
			for i = 1, #GetCannonTableFromForce(force) do
				frame["ion-cannon-table"].add{type = "label", caption = {"ion-cannon-num", i}}
				if GetCannonTableFromForce(force)[i][2] == 1 then
					frame["ion-cannon-table"].add{type = "label", caption = {"ready"}}
				else
					frame["ion-cannon-table"].add{type = "label", caption = {"cooldown", GetCannonTableFromForce(force)[i][1]}}
				end
			end
		else
			global.goToFull[player_index] = true
			if frame then
				frame.destroy()
			end
			frame = player.gui.left.add{type = "frame", name = "ion-cannon-stats", direction = "vertical"}
			frame.add{type = "label", caption = {"ion-cannon-details-compact"}}
			if player.admin then
				frame.add{type = "table", column_count = 2, name = "ion-cannon-admin-panel-header"}
				frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-admin-panel-show"}}
				frame["ion-cannon-admin-panel-header"].add{type = "checkbox", state = global.permissions[-1], name = "show"}
				-- frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-cheat-menu-show"}}
				--TODO WTF? if global.permissions[-2] == nil then global.permissions[-2] = settings.global["ion-cannon-auto-targeting"].value end
				-- frame["ion-cannon-admin-panel-header"].add{type = "checkbox", state = global.permissions[-2], name = "cheats"}
				if frame["ion-cannon-admin-panel-header"]["show"].state then
					createAdminPanel(frame)
				end
				-- if frame["ion-cannon-admin-panel-header"]["cheats"].state then
				if settings.global["ion-cannon-cheat-menu"].value then
					frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-cheat-one"}}
					frame["ion-cannon-admin-panel-header"].add{type = "button", name = "add-ion-cannon", style = "ion-cannon-button-style"}
					frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-cheat-five"}}
					frame["ion-cannon-admin-panel-header"].add{type = "button", name = "add-five-ion-cannon", style = "ion-cannon-button-style"}
					frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-remove-one"}}
					frame["ion-cannon-admin-panel-header"].add{type = "button", name = "remove-ion-cannon", style = "ion-cannon-remove-button-style"}
					frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"ion-cannon-cheat-recharge-all"}}
					frame["ion-cannon-admin-panel-header"].add{type = "button", name = "recharge-ion-cannon", style = "ion-cannon-button-style"}
				end
				frame["ion-cannon-admin-panel-header"].add{type = "label", caption = {"mod-setting-name.ion-cannon-auto-targeting"}}
				frame["ion-cannon-admin-panel-header"].add{type = "checkbox", state = global.permissions[-2], name = "ion-cannon-auto-target-enabled"}
			end
			frame.add{type = "table", column_count = 1, name = "ion-cannon-table"}
			frame["ion-cannon-table"].add{type = "label", caption = {"ion-cannons-in-orbit", player.surface.name, #GetCannonTableFromForce(force)}}
			frame["ion-cannon-table"].add{type = "label", caption = {"ion-cannons-ready", countIonCannonsReady(force, player.surface)}}
			if countIonCannonsReady(force, player.surface) < #GetCannonTableFromForce(force) then
				frame["ion-cannon-table"].add{type = "label", caption = {"time-until-next-ready", timeUntilNextReady(force, player.surface)}}
			end
		end
	end
end

function update_GUI(player)
	init_GUI(player)
	local statsFrame = player.gui.left["ion-cannon-stats"]
	if not statsFrame then return end

	local force = player.force
	--local forceName = force.name
	local playerIndex = player.index

	local cannonTable = statsFrame["ion-cannon-table"]
	if cannonTable then cannonTable.destroy() end

	if not global.goToFull[playerIndex] then
		--if false then --TODO configuration
		--	cannonTable = createFullCannonTable(player)
		--else
			cannonTable = createFullCannonTableFiltered(player)
		--end
	else
		cannonTable = statsFrame.add{type = "table", column_count = 1, name = "ion-cannon-table"}
		--cannonTable.add{type = "label", caption = {"ion-cannons-in-orbit", #GetCannonTableFromForce(force)}}
		local numCannons = 0
		if false then
			numCannons =  #GetCannonTableFromForce(force)
		else
			for i = 1, #GetCannonTableFromForce(force) do
				if player.surface.name == GetCannonTableFromForce(force)[i][3] then numCannons=numCannons+1 end
			end
		end

		cannonTable.add{type = "label", caption = {"ion-cannons-in-orbit", player.surface.name, numCannons}}
		cannonTable.add{type = "label", caption = {"ion-cannons-ready", countIonCannonsReady(force, player.surface)}}
		if countIonCannonsReady(force, player.surface) < countOrbitingIonCannons(force, player.surface) then
			cannonTable.add{type = "label", caption = {"time-until-next-ready", timeUntilNextReady(force, player.surface)}}
		end
	end
end

function createFullCannonTableFiltered(player)
	local statsFrame = player.gui.left["ion-cannon-stats"]
	local force = player.force
	local cannonTable = statsFrame.add{type = "table", column_count = 2, name = "ion-cannon-table"}
	for i = 1, #GetCannonTableFromForce(force) do
		if player.surface.name == GetCannonTableFromForce(force)[i][3] then
			cannonTable.add{type = "label", caption = {"ion-cannon-num", i}}
			if GetCannonTableFromForce(force)[i][2] == 1 then
				cannonTable.add{type = "label", caption = {"ready"}}
			else
				cannonTable.add{type = "label", caption = {"cooldown", GetCannonTableFromForce(force)[i][1]}}
			end
		end
	end
	return cannonTable
end

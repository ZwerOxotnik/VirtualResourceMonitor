---@class VRM : module
local M = {}


--#region Global data
local mod_data

---@class force_VRM_elements
---@type table<integer, table<string, LuaGuiElement[]>>
local force_VRM_elements
--#endregion


--#region Settings
local update_tick = settings.global["VRM_update-tick"].value
--#endregion


--#region Constants
local tostring = tostring
local DRAG_HANDLER = {type = "empty-widget", style = "flib_dialog_footer_drag_handle", name = "drag_handler"}
local TITLEBAR_FLOW = {type = "flow", style = "flib_titlebar_flow", name = "titlebar"}
local call = remote.call
local SCROLL_PANE = {
	type = "scroll-pane",
	name = "scroll-pane",
	horizontal_scroll_policy = "never"
}
--#endregion


--#region utils


-- TODO: add localization
function format_number(number)
    if number < 1000 then
		return tostring(number)
    elseif number < 1000000 then
		return string.format("%.1fK", number / 1e3)
    elseif number < 1000000000 then
		return string.format("%.1fM", number / 1e6)
    elseif number < 1000000000000 then
		return string.format("%.1fB", number / 1e9)
    end
	return string.format("%.1fT", number / 1e12)
end

---@param player LuaPlayer
---@param force LuaForce?
function clear_player_data(player, force)
	local player_index = player.index
	force = force or player.force
	local force_data = force_VRM_elements[force.index]
	for _, elements in pairs(force_data) do
		for i = #elements, 1, -1 do
			local element = elements[i]
			if not element.valid then
				table.remove(elements, i)
			elseif element.player_index == player_index then
				table.remove(elements, i)
				break
			end
		end
	end
end

---@param player LuaPlayer
function fill_VRM_table(player)
	if player.gui.screen.VRM_frame == nil then
		return
	end

	local VRM_table = player.gui.screen.VRM_frame.VRM_sub_frame["scroll-pane"].VRM_table
	clear_player_data(player)
	VRM_table.clear()

	local force_index = player.force.index
	local _VRM_elements = force_VRM_elements[force_index]
	local VBR_general_data = call("EasyAPI", "get_virtual_base_resources_general_data")
	local virtual_base_resources = call("EasyAPI", "get_virtual_base_resources_by_force_index", force_index)
	local label_text_data = {type = "label", caption = nil}
	local label_value_data = {type = "label", caption = nil}
	for name, value in pairs(virtual_base_resources) do
		local _VBR_general_data = VBR_general_data[name]
		if _VBR_general_data and _VBR_general_data.VRM_label then
			label_text_data.caption = _VBR_general_data.VRM_label
			VRM_table.add(label_text_data)
			label_value_data.caption = format_number(value)
			---@type LuaGuiElement
			local amount_elem = VRM_table.add(label_value_data)
			local __VRM_elements = _VRM_elements[name]
			__VRM_elements[#__VRM_elements+1] = amount_elem
		end
	end
end

---@param player LuaPlayer
function create_VRM_frame(player)
	local screen = player.gui.screen
	local main_frame = screen.VRM_frame
	if main_frame then return end

	main_frame = screen.add{type = "frame", name = "VRM_frame", style = "borderless_frame", direction = "vertical"}
	main_frame.location = {x = player.display_resolution.width - 702, y = 272}

	local flow = main_frame.add(TITLEBAR_FLOW)
	flow.style.padding = 0
	local drag_handler = flow.add(DRAG_HANDLER)
	drag_handler.drag_target = main_frame
	drag_handler.style.margin = 0
	flow.style.horizontal_spacing = 0
	drag_handler.style.width = 27
	drag_handler.style.height = 20
	drag_handler.style.horizontally_stretchable = false

	local VRM_frame = main_frame.add{type = "frame", name = "VRM_sub_frame", style = "VRM_frame", direction = "vertical"}
	local scroll_pane = VRM_frame.add(SCROLL_PANE) -- TODO: improve style!
	scroll_pane.style.padding = 9
	scroll_pane.style.right_padding = 0
	scroll_pane.style.maximal_height = 300
	scroll_pane.add{type = "table", name = "VRM_table", style = "VRM_table", column_count = 2}

	fill_VRM_table(player)
end

--#endregion


--#region Functions of events

function update_VRM_table()
	local virtual_base_resources = call("EasyAPI", "get_all_virtual_base_resources")
	for force_index, force_data in pairs(force_VRM_elements) do
		local force_resources = virtual_base_resources[force_index]
		for name, elements in pairs(force_data) do
			local text_value = format_number(force_resources[name])
			for i = #elements, 1, -1 do
				local element = elements[i]
				if element.valid then
					element.caption = text_value
				end
			end
		end
	end
end

local function on_player_left_game(event)
	local player_index = event.player_index

	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	clear_player_data(player)
end

local function on_player_joined_game(event)
	local player_index = event.player_index

	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	fill_VRM_table(player)
end

local function on_player_changed_force(event)
	local player_index = event.player_index

	local player = game.get_player(player_index)
	if not (player and player.valid) then return end

	local prev_force = event.force
	if prev_force.valid then
		clear_player_data(player, prev_force)
	end
	fill_VRM_table(player)
end

local function on_player_created(event)
	local player = game.get_player(event.player_index)
	if not (player and player.valid) then return end

	create_VRM_frame(player)
end

local mod_settings = {
	["VRM_update-tick"] = function(value)
		if value == 60 * 60 then
			settings.global["VRM_update-tick"] = {value = value + 1}
			return
		end

		script.on_nth_tick(update_tick, nil)
		M.on_nth_tick[update_tick] = nil
		update_tick = value
		handle_tick_events()
	end
}
local function on_runtime_mod_setting_changed(event)
	local setting_name = event.setting
	local f = mod_settings[setting_name]
	if f == nil then return end
	f(settings.global[setting_name].value)
end

--#endregion


--#region Pre-game stage

function handle_tick_events()
	script.on_nth_tick(update_tick, update_VRM_table)
	M.on_nth_tick[update_tick] = update_VRM_table
end

local function link_data()
	mod_data = global.VRM
	if mod_data == nil then return end
	force_VRM_elements = mod_data.force_VRM_elements
end

local function update_global_data()
	global.VRM = global.VRM or {}
	mod_data = global.VRM
	mod_data.force_VRM_elements = {}

	link_data()

	if not game then return end

	-- Fill forces in mod_data.force_VRM_elements
	local virtual_base_resources = call("EasyAPI", "get_all_virtual_base_resources")
	for _, force in pairs(game.forces) do
		if force.valid then
			local force_index = force.index
			force_VRM_elements[force_index] = force_VRM_elements[force_index] or {}
			local _force_VRM_elements = force_VRM_elements[force_index]
			for name in pairs(virtual_base_resources[force_index]) do
				local data = _force_VRM_elements[name]
				if data == nil then
					_force_VRM_elements[name] = {}
				end
			end
		end
	end

	-- Fix main frame
	for _, player in pairs(game.players) do
		if player.valid then
			local VRM_frame = player.gui.screen.VRM_frame
			if not VRM_frame then
				create_VRM_frame(player)
			end
		end
	end
end

local function add_remote_interface()
	-- https://lua-api.factorio.com/latest/LuaRemote.html
	remote.remove_interface("VirtualResourceMonitor") -- For safety
	remote.add_interface("VirtualResourceMonitor", {})
end

M.on_init = function()
	update_global_data()
	handle_tick_events()
end

M.on_configuration_changed = function(event)
	update_global_data()
	handle_tick_events()

	-- local mod_changes = event.mod_changes["Players_info"]
	-- if not (mod_changes and mod_changes.old_version) then return end

	-- local old_version = tonumber(string.gmatch(mod_changes.old_version, "%d+.%d+")())
end

M.on_load = link_data
M.add_remote_interface = add_remote_interface


--#endregion


M.events = {
	[defines.events.on_player_created] = on_player_created,
	[defines.events.on_pre_player_removed] = on_player_left_game,
	[defines.events.on_player_left_game] = on_player_left_game,
	[defines.events.on_player_joined_game] = on_player_joined_game,
	[defines.events.on_player_changed_force] = on_player_changed_force,
	[defines.events.on_runtime_mod_setting_changed] = on_runtime_mod_setting_changed
}

M.on_nth_tick = {
	[60 * 60] = function()
		-- TODO: refactor! Add new events to EasyAPI!
		local do_refill_UI = false
		local virtual_base_resources = call("EasyAPI", "get_all_virtual_base_resources")
		for _, force in pairs(game.forces) do
			if force.valid then
				local force_index = force.index
				force_VRM_elements[force_index] = force_VRM_elements[force_index] or {}
				local _force_VRM_elements = force_VRM_elements[force_index]
				for name in pairs(virtual_base_resources[force_index]) do
					local data = _force_VRM_elements[name]
					if data == nil then
						_force_VRM_elements[name] = {}
						do_refill_UI = true
					end
				end
			end
		end

		if do_refill_UI then
			for _, player in pairs(game.connected_players) do
				if player.valid then
					fill_VRM_table(player)
				end
			end
		end
	end
}


return M

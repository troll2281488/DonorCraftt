local modname = core.get_current_modname()
local S = core.get_translator(modname)

mcl_credits = {
	players = {},
	description = S("A survival sandbox game by Donorcraft"),
	people = dofile(core.get_modpath(modname) .. "/people.lua"),
}

local function add_hud_element(def, huds, y)
	def.alignment = {x = 0, y = 0}
	def.position = {x = 0.5, y = 0}
	def.offset = {x = 0, y = y}
	def.z_index = 1001
	local id = huds.player:hud_add(def)
	table.insert(huds.ids, id)
	huds.moving[id] = y
	return id
end

function mcl_credits.show(player)
	local name = player:get_player_name()
	if mcl_credits.players[name] then
		return
	end
	-- Keep upstream attribution unobtrusive during play. Full author lists and
	-- license details remain available in CREDITS.md and LEGAL.md.
	local huds = {
		new = true,
		player = player,
		moving = {},
		ids = {},
	}
	local id = player:hud_add({
		type = "text",
		text = S("Donorcraft is based on Mineclonia • see CREDITS.md for authors"),
		position = {x = 1, y = 1},
		alignment = {x = -1, y = -1},
		offset = {x = -12, y = -12},
		number = 0xB8B8B8,
		z_index = 1001,
	})
	table.insert(huds.ids, id)
	mcl_credits.players[name] = huds
end

function mcl_credits.hide(player)
	local name = player:get_player_name()
	local huds = mcl_credits.players[name]
	if huds then
		for _, id in pairs(huds.ids) do
			player:hud_remove(id)
		end
	end
	mcl_credits.players[name] = nil
end

core.register_on_leaveplayer(function(player)
	mcl_credits.players[player:get_player_name()] = nil
end)

core.register_globalstep(function(_)
	for _, huds in pairs(mcl_credits.players) do
		local player = huds.player
		local control = player:get_player_control()
		if not huds.new and control.sneak then
			mcl_credits.hide(player)
		else
			local moving = {}
			local any
			for id, y in pairs(huds.moving) do
				y = y - 1

				if control.jump then
					y = y - 2
					if control.aux1 then
						y = y - 5
					end
				end

				if y > -100 then
					if id == huds.icon then
						y = math.max(400, y)
					else
						any = true
					end
					player:hud_change(id, "offset", {x = 0, y = y})
					moving[id] = y
				end
			end
			if not any then
				mcl_credits.hide(player)
			end
			huds.moving = moving
		end
		huds.new = false
	end
end)

core.register_chatcommand("endcredits", {
	description = S("Show Donorcraft attribution"),
	func = function(name, _)
		mcl_credits.show(core.get_player_by_name(name))

		return true
	end,
})

-- Give cubic blocks a three-dimensional cube preview in inventories.
-- Only inventory_image is changed; world node geometry and textures are untouched.
core.register_on_mods_loaded(function()
  for name, def in pairs(core.registered_nodes) do
    if def.drawtype == "normal" and type(def.tiles) == "table" then
      local function image_at(index)
        local tile = def.tiles[index] or def.tiles[1]
        if type(tile) == "table" then
          tile = tile.name or tile.image
        end
        if type(tile) == "string" then
          return tile
        end
      end
      local top = image_at(1)
      local side_a = image_at(3)
      local side_b = image_at(4) or side_a
      if top and side_a and side_b then
        core.override_item(name, {
          inventory_image = core.inventorycube(top, side_a, side_b),
        })
      end
    end
  end
end)

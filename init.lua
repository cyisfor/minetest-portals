-- portals is a C API to some sqlite stuff (see src/portals.c)

portals.setup(minetest.get_worldpath().."/portals.sqlite")
local inspect = dofile(minetest.get_modpath('multinode')..'/inspect.lua')

minetest.register_node(
   "portals:generator", 
   {
      description = "Portal Pair Generator",
      tiles = {"portals_generator.png"},
      is_ground_content = true,
      groups = {},
      on_place = 
         function(itemstack, placer, pointed_thing)
            if pointed_thing.type ~= "node" then
               return itemstack
            end
            local orangepos = pointed_thing.above;
            if minetest.env:get_node(orangepos).name ~= "air" then
               minetest.chat_send_player(
                  placer:get_player_name(),
                  "Must create your portal on top of something.")
               return itemstack
            end
            
            local bluepos = nil;
            
            for dx = -1,1,2 do
               for dz = -1,1,2 do
                  local pos = {x=orangepos.x+dx,y=orangepos.y,z=orangepos.z+dz}
                  local name = minetest.env:get_node(pos).name
                  if name == "air" then
                     bluepos = pos
                     break
                  end
               end
               if bluepos then break end
            end
            if bluepos == nil then
               minetest.chat_send_player(
                  placer:get_player_name(),
                  "Portals can only be created on a reasonably flat surface.")
               return itemstack
            end

            local orange,blue = portals.create()
            print("portals created: "..inspect({orange,blue}))
            print("posses "..inspect({orangepos,bluepos}))
            minetest.env:add_node(orangepos,{type="node",name="portals:orange"})
            minetest.env:get_meta(orangepos):set_string('text',orange)
            minetest.env:add_node(bluepos,{type="node",name="portals:blue"})
            minetest.env:get_meta(bluepos):set_string('text',blue)
            itemstack:take_item(1)
            return itemstack
         end
   })

local portalz = {}

local function registerPortal(color)
   local name = "portals:"..color
   local image = "portals_"..color..".png"
   table.insert(portalz,name)
   minetest.register_node(
      name,
      {
         description = "Portal",
         tiles = { image },
         drawtype = "signlike",
         paramtype2 = "wallmounted",
         selection_box = {
            type = "wallmounted",
         },
         paramtype = "light",
         sunlight_propagates = true,
         light_source = 3, -- just enough to glow
         stack_max = 1,
         inventory_image = image,
         metadata_name = "sign",

         walkable=false,
         groups = {cracky=3,dig_immediate=1,flammable=1},
         on_place = 
            function(itemstack, placer, pointed_thing)
               local id = itemstack:get_metadata()
               if id then
                  print("placing id "..id)
               else
                  print("portal with no id oh no!")
                  itemstack:clear()
                  return
               end
               local pos = pointed_thing.above
               itemstack = minetest.item_place(itemstack, placer, pointed_thing)
               if itemstack:is_empty() then
                  portals.set_thisside(id,pos.x,pos.y,pos.z)
                  local meta = minetest.env:get_meta(pos)
                  meta:set_string('text',id)
                  meta:set_string('infotext',id)
               end
               return itemstack
            end,
         on_destruct = 
            function(pos, node, digger)
               local id = minetest.env:get_meta(pos):get_string('text')
               portals.disable(id)
            end,
         on_dig =
            function(pos, node, digger)
               local id = minetest.env:get_meta(pos):get_string('text')
               local leftovers = digger:get_inventory():add_item("main",{name=node.name,count=1,wear=0,metadata=id})
               if leftovers:is_empty() then
                  print("digging id "..id)
                  minetest.env:remove_node(pos)
                  return true
               else
                  minetest.chat_send_player(
                     digger:get_player_name(),
                     "Portal: Your inventory is full! I won't fit!")
               end
            end
         
      })
end

registerPortal("orange")
registerPortal("blue")

local function isSpace(pos)
   local node = minetest.env:get_node(pos)
   local info = minetest.registered_nodes[node.name]
   if info == nil then return false end
   return info.walkable == false
end

local function spaceNearby(pos)
   for dx = 2,4,1 do
      for xsign = -1,1,2 do
         for dz = 2,4,1 do
            for zsign = -1,1,2 do
               for dy = -1,2,1 do
                  local newpos = {x=pos.x+dx*xsign,
                                  y=pos.y+dy,
                                  z=pos.z+dz*zsign}
                  if isSpace(newpos) and isSpace({x=newpos.x,y=newpos.y+1,z=newpos.z}) then
                     return newpos
                  end
               end
            end
         end
      end
   end
end

minetest.register_abm(
   {
      nodenames = portalz,
      interval = 1.0,
      chance = 1,
      action = 
         function(pos, node, active_object_count, active_object_count_wider)
            local objs = minetest.env:get_objects_inside_radius(pos, 1)
            for k, player in pairs(objs) do
               if player.get_player_name ~= nil then 
                  local id = minetest.env:get_meta(pos):get_string("text")
                  local x,y,z = portals.find_otherside(id)
                  if x == nil then return end
                  if x == 0 and y == 0 and z == 0 then return end
                  local target = spaceNearby({x=x,y=y,z=z})
                  if target ~= nil then
                     minetest.sound_play("portals_teleport", {pos = pos, gain = 1.0, max_hear_distance = 10,})
                     player:moveto(target, false)
                     minetest.sound_play("portals_teleport", {pos = target, gain = 1.0, max_hear_distance = 10,})
                  end
               end
            end
         end
   })




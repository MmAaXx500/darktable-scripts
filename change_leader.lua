--[[
]]
--[[
CHANGE LEADER
allows you to change the leaders in the selected groups based on the file type or modification
note: you need to reload the collection or expand and collapse the groups
]]

local dt = require "darktable"
local du = require "lib/dtutils"

local MODULE = "change_leader"

du.check_min_api_version("7.0.0", MODULE)

local script_data = {}

GUI = {
  box = {},
  mode_combo = {},
  prefer_modified = {},
  exec_selected = {},
  exec_collection = {},
}

local chg_ldr = {}
chg_ldr.event_registered = false
chg_ldr.module_installed = false

script_data.destroy = nil
script_data.destroy_method = nil
script_data.restart = nil


local function install_module()
  if not chg_ldr.module_installed then
    dt.print_log(MODULE .. ": installing module")
    dt.register_lib(
      MODULE,              -- Module name
      "change leader",     -- Visible name
      true,                -- expandable
      false,               -- resetable
      {[dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER", 700}},   -- containers
      GUI.box,
      nil, -- view_enter
      nil  -- view_leave
    )
    chg_ldr.module_installed = true
    dt.print_log(MODULE .. ": module installed" )
  end
end

local function find_group_leader(images, mode, prefer_mod)
  local candidate_img = nil
  for _, img in ipairs(images) do
    dt.print_log(MODULE .. ": checking image " .. img.id .. " named "  .. img.filename)

    if prefer_mod and img.is_altered then
      dt.print_log(MODULE .. ": found modified " .. img.filename)
      return img
    elseif mode == "jpg/jpeg" then
      if string.match(img.filename, "[jJ][pP][eE]?[gG]$") then
        dt.print_log(MODULE .. ": found jpg/jpeg " .. img.filename)
        if not candidate_img then
          candidate_img = img
        end
      end
    elseif mode == "raw" then
      if img.is_raw and img.duplicate_index == 0 then
        dt.print_log(MODULE .. ": found raw " .. img.filename)
        if not candidate_img then
          candidate_img = img
        end
      end
    elseif mode == "ldr" then
      if img.is_ldr then
        dt.print_log(MODULE .. ": found ldr " .. img.filename)
        if not candidate_img then
          candidate_img = img
        end
      end
    elseif mode == "hdr" then
      if img.is_hdr then
        dt.print_log(MODULE .. ": found hdr " .. img.filename)
        if not candidate_img then
          candidate_img = img
        end
      end
    else
      dt.print_error(MODULE .. ": unrecognized mode " .. mode)
      return nil
    end

    if candidate_img and not prefer_mod then
      return candidate_img
    end
  end

  if prefer_mod then
    dt.print_log(MODULE .. ": no modified image found, falling back to mode selection")
    return candidate_img
  else
    return nil
  end
end

local function process_image_groups(images)
  if #images < 1 then
    dt.print("No images selected.")
    dt.print_log(MODULE .. ": no images seletected, returning...")
  else
    local groups = {}
    local group_count = 0
    for _,img in ipairs(images) do
      local group_images = img:get_group_members()
      if not group_images then
        dt.print_log(MODULE .. ": " .. img.filename .. " is not grouped")
      elseif #group_images == 1 then
        dt.print_log(MODULE .. ": only one image in group for image " .. img.filename)
      else
        if not groups[group_images[1].group_leader.id] then
          group_count = group_count + 1
          groups[group_images[1].group_leader.id] = group_images
        end
      end
    end

    if group_count < 1 then
      dt.print("No images to process")
      return
    end    

    local mode = GUI.mode.value
    local prefer_modified = GUI.prefer_modified.value
    for leader_id, group_imgs in pairs(groups) do
      dt.print_log(MODULE .. ": processing group " .. leader_id)
      local leader = find_group_leader(group_imgs, mode, prefer_modified)
      if leader then
        dt.print_log(MODULE .. ": setting " .. group_imgs[1].group_leader.filename .. " as leader")
        leader:make_group_leader()
      else
        dt.print("No leader found for group " .. group_imgs[1].group_leader.filename)
        dt.print_log(MODULE .. ": no leader found for group " .. group_imgs[1].group_leader.filename)
      end
    end
  end
end

local function destroy()
  dt.gui.libs[MODULE].visible = false
end

local function restart()
  dt.gui.libs[MODULE].visible = true
end


GUI.mode = dt.new_widget("combobox"){
  label = "select new group leader",
  tooltip = "select type of image to be group leader",
  selected = 1,
  "jpg/jpeg", "raw", "ldr", "hdr",
}

GUI.exec_selected = dt.new_widget("button"){
  label = "Execute on selected",
  clicked_callback = function()
    process_image_groups(dt.gui.action_images)
  end
}

GUI.exec_collection = dt.new_widget("button"){
  label = "Execute on collection",
  clicked_callback = function()
    process_image_groups(dt.collection)
  end
}


GUI.prefer_modified = dt.new_widget("check_button"){
  label = "Prefer modified",
  tooltip = "Make the first modified image as leader. If none is modified use selected type.",
  value = true,
}

GUI.box = dt.new_widget("box"){
  orientation = "vertical",
  GUI.mode,
  GUI.prefer_modified,
  GUI.exec_selected,
  GUI.exec_collection,
}


if dt.gui.current_view().id == "lighttable" then
  install_module()
else
  if not chg_ldr.event_registered then
    dt.register_event(
      "view-changed",
      function(event, old_view, new_view)
        if new_view.name == "lighttable" and old_view.name == "darkroom" then
          install_module()
         end
      end
    )
    chg_ldr.event_registered = true
  end
end

script_data.destroy = destroy
script_data.destroy_method = "hide"
script_data.restart = restart
script_data.show = restart

return script_data

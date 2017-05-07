local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group
local plot = import('/mods/EcoPredict/modules/plot.lua')
local helpers = import('/mods/EcoPredict/modules/helpers.lua')

 
-- resolution of heatmap

local resolution_pxperpx = 20 -- how large a single heatmap pixel should be

local res_w = 1
local res_h = 1

local screen_grid_widget
local screen_grid_widget_pixels = {}
local grid_data = {}

local heatmap_render_thread
local data_has_changed = true

function createUI(parent)
	LOG("---------------------> creating Heatmap Ui")

	local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
	--LOG("view object:")
	--helpers.LOG_OBJ(view, true)

	screen_grid_widget = Group(parent)
	
	screen_grid_widget.Left:Set(0)
	screen_grid_widget.Top:Set(0)
	
	screen_grid_widget.Width:Set(view.Width())
	screen_grid_widget.Height:Set(view.Height())
	

	screen_grid_widget.Depth:Set(-99) -- below everything else

	res_w = math.floor(view.Width() / resolution_pxperpx)
	res_h = math.floor(view.Height() / resolution_pxperpx)

	local w = screen_grid_widget.Width() / res_w
	local h = screen_grid_widget.Height() / res_h
	for x = 1, res_w do
		screen_grid_widget_pixels[x] = {}
		grid_data[x] = {}
		for y = 1, res_h do
			screen_grid_widget_pixels[x][y] = plot.draw_box(screen_grid_widget, (x-1)*w, (y-1)*h, x*w, y*h, '30ff0000')
			grid_data[x][y] = 0
		end
	end

	heatmap_render_thread = ForkThread(show_heatmap_thread)
end



local reclaim_cache = {}

function updateReclaim(reclaim)
	for id, data in reclaim do
        if not data.mass then
            reclaim_cache[id] = nil
        else
            reclaim_cache[id] = data
        end
	end
	data_has_changed = true
end




function update_grid_data()

	local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera

	if table.empty(grid_data) or not view then
		return
	end

	
	-- clear table
	for x = 1, res_w do
		for y = 1, res_h do
			grid_data[x][y] = 0
		end
	end

	
	for _, r in reclaim_cache do
		-- project onto screen
		local proj = view:Project(Vector(r.position[1], r.position[2], r.position[3]))

		-- if on screen
        if proj.x >= 0 and proj.y >= 0 and proj.x <= view.Width() and proj.y <= view.Height() then

			local idx_x = math.floor(proj.x / view.Width()  * res_w) + 1
			local idx_y = math.floor(proj.y / view.Height() * res_h) + 1

			if idx_x > 0 and idx_y > 0 and idx_x <= res_w and idx_y <= res_h then
				grid_data[idx_x][idx_y] = grid_data[idx_x][idx_y] + r.mass
			end
        end
	end

	data_has_changed = false
end



function plot_grid_data()

if table.empty(grid_data) then
	return
end


local min_val = 999999
local max_val = 0

for x = 1, res_w do
	for y = 1, res_h do
		local d = grid_data[x][y]
		if min_val > d then
			min_val = d
		end
		if max_val < d then
			max_val = d
		end
	end
end

for x = 1, res_w do
	for y = 1, res_h do
		local value = (grid_data[x][y] - min_val) / (max_val - min_val)
		screen_grid_widget_pixels[x][y]:SetSolidColor(string.format("%02x", value*255)..'ff0000')
	end
end

end






function show_heatmap_thread(watch_key)
    local view = import('/lua/ui/game/worldview.lua').viewLeft
    local camera = GetCamera("WorldCamera")

	LOG("camera:")
	helpers.LOG_OBJ(camera, true)

    --InitReclaimGroup(view)

    --while view.ShowingReclaim and (not watch_key or IsKeyDown(watch_key)) do
	local OldZoom
	local OldPosition
	while true do
        local zoom = camera:GetZoom()
        local position = camera:GetFocusPosition()
        if data_has_changed
            or view.NewViewing
            or OldZoom ~= zoom
            or OldPosition[1] ~= position[1]
            or OldPosition[2] ~= position[2]
            or OldPosition[3] ~= position[3] then
                
				update_grid_data()
				plot_grid_data()

				OldZoom = zoom
                OldPosition = position
                data_has_changed = false
        end

        view.NewViewing = false

        WaitFrames(1)
    end

	--[[
    if not IsDestroyed(view) then
        view.ReclaimThread = nil
        view.ReclaimGroup:Hide()
    end
	--]]
end
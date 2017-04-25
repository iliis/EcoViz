local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local Group = import('/lua/maui/group.lua').Group



local colors = {
	mass     = 'ffc6fb08',
	energy   = 'ffffc300',
	stall    = 'ffff3900',
	overflow = 'ffe8fd9a'
}



function draw_box(parent, x1, y1, x2, y2, color, depth_offset)
	b = Bitmap(parent)
	b:SetSolidColor(color)
	
	if x1 < x2 then
		b.Left:Set(x1)
		b.Right:Set(x2)
	else
		b.Left:Set(x2)
		b.Right:Set(x1)
	end
	
	if y1 < y2 then
		b.Top:Set(y1)
		b.Bottom:Set(y2)
	else
		b.Top:Set(y2)
		b.Bottom:Set(y1)
	end
	
	if not depth_offset then
		depth_offset = 1
	end

	b.Depth:Set(function() return parent.Depth() + depth_offset end)

	return b
end


-- assumes x1 < x2
-- base_y is the lower border of the graph (i.e. position of the x-axis (y=0))
-- the y axis points upwards, i.e. towards *smaller* screen-y-coordinates
function draw_line(parent, x1, base_y, y1, x2, y2)
	local b = Bitmap(parent, '/mods/ecopredict/textures/ramp_mass.png')
	b.Depth:Set(function() return parent.Depth() + 1 end)
	b.Left:Set(x1)
	b.Bottom:Set(base_y)
	b.Top:Set(base_y - math.max(y1,y2))
	b.Right:Set(x2)
	
	
	--LOG("plotting from "..tostring(x1)..":"..tostring(y1).." to "..tostring(x2)..":"..tostring(y2))
	
	if y1 < y2 then
		b:SetUV(y1/y2, 0, 1, 1)
	elseif y1 > y2 then
		b:SetUV(1, 0, y2/y1, 1)
	else
		b:SetUV(0.5, 0.5, 1, 1)
	end
end


-- pos_x/y are screen coordinates of zero, i.e. the lower left corner
-- assumes 'data_x' is sorted!
-- fits data vertically into parent
function draw_plot(parent, pos_x, pos_y, height, data_x, data_y, limit_y)

-- appearantly, all widgets need valid position & size, even if they are dummy-objects
plot_widget = Group(parent)
plot_widget.Left:Set(0)
plot_widget.Top:Set(0)
plot_widget.Height:Set(1)
plot_widget.Width:Set(1)


local max_x = nil
for _, x in data_x do
	if not max_x or x > max_x then
		max_x = x
	end
end



if not limit_y then
	local max_y = nil
	for _, y in data_y do	
		if not max_y or y > max_y then
			max_y = y
		end
	end
	limit_y = max_y
end

--[[
LOG("left: "..tostring(parent.Left()))
for k, v in getmetatable(parent.Left) do
	LOG("["..tostring(k).."] = "..tostring(v))
end
--]]

local last_x = 0
local last_y = nil
for i = 1,table.getn(data_x) do

	local x = data_x[i]
	local y = data_y[i] / limit_y * height

	--LOG("datapoint: "..tostring(x)..":"..tostring(y))

	if not last_y then
		last_y = y
	end

	if last_x < x then

		if last_y < 0 then
			-- prevent glitches between overflowing ('-2') and normal
			last_y = y
		end

		if y > 0 then
			draw_line(plot_widget, last_x+pos_x, pos_y, last_y, x+pos_x, y)
		else
			local color = colors.stall
			if data_y[i] < -1 then
				color = colors.overflow
			end
			draw_box(plot_widget, last_x+pos_x, pos_y, x+pos_y, pos_y-height, color)
		end
	end

	last_x = x
	last_y = y
end

return plot_widget

end
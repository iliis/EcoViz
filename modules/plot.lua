local Bitmap = import('/lua/maui/bitmap.lua').Bitmap


function draw_box(parent, x1, y1, x2, y2, color)
	b = Bitmap(parent)
	b:SetSolidColor(color)
	
	if x1 < x2 then
		b.Top:Set(x1)
		b.Bottom:Set(x2)
	else
		b.Top:Set(x2)
		b.Bottom:Set(x1)
	end
	
	if y1 < y2 then
		b.Left:Set(y1)
		b.Right:Set(y2)
	else
		b.Left:Set(y2)
		b.Right:Set(y1)
	end
	
	b.Depth:Set(function() return parent.Depth() + 1 end)
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


-- assumes 'data_x' is sorted!
function draw_plot(parent, data_x, data_y)

local max_x = nil
for _, x in data_x do
	if not max_x or x > max_x then
		max_x = x
	end
end

local max_y = nil
for _, y in data_y do	
	if not max_y or y > max_y then
		max_y = y
	end
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
	local y = data_y[i]

	--LOG("datapoint: "..tostring(x)..":"..tostring(y))

	if not last_y then
		last_y = y
	end

	if last_x < x then
		draw_line(parent, last_x+parent.Left(), parent.Bottom(), last_y, x+parent.Left(), y)
	end

	last_x = x
	last_y = y
end


end
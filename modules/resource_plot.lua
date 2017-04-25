local LayoutHelpers = import('/lua/maui/layouthelpers.lua') 
local Button = import('/lua/maui/button.lua').Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')


local plot = import('/mods/EcoPredict/modules/plot.lua')




function LOG_OBJ(obj, indentation)

	if not indentation then
		indentation = ""
	end

	if type(obj) == "table" then

		--LOG(indentation.."properties of "..tostring(obj))
		
		for k, v in obj do
			LOG(indentation.."\t"..tostring(k).." = "..tostring(v))
			if type(v) == "table" then
				LOG_OBJ(v, indentation.."\t")
			end
		end
	else
		LOG(tostring(obj))
	end
end



function SolidBackground(parent, control, color)
	background = Bitmap(control)
	background:SetSolidColor(color)
	background.Top:Set(control.Top)
	background.Left:Set(control.Left)
	background.Right:Set(control.Right)
	background.Bottom:Set(control.Bottom)
	background.Depth:Set(function() return parent.Depth() + 1 end)
end



-- widget size
local W = 500
local H = 100




local data_x = {}
local data_y = {}
local plot_widget = nil
local resource_plot_widget = nil
local current_time = 0

function CreateModUI(parent)

	LOG("creating resource plot UI")

	--local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
	--local parent = GetFrame(0)
	
	--local border_bg = UIUtil.SkinnableFile('/game/avatar-factory-panel/avatar-s-e-f_bmp.dds')
	
	resource_plot_widget = Bitmap(parent)
	resource_plot_widget:SetSolidColor('40000000') -- format: ARGB
	
	resource_plot_widget.Left:Set(400)
	resource_plot_widget.Top:Set(110)
	resource_plot_widget.Height:Set(H)
    resource_plot_widget.Width:Set(W)
	
	
	--[[
	resource_plot_widget.foobar = UIUtil.CreateText(resource_plot_widget, 'Hallo Welt', 10, UIUtil.bodyFont)
	resource_plot_widget.foobar:SetColor('white')
    -- resource_plot_widget.foobar:SetDropShadow(true)
	LayoutHelpers.AtTopIn(resource_plot_widget.foobar, resource_plot_widget, 1)
    LayoutHelpers.AtLeftIn(resource_plot_widget.foobar, resource_plot_widget, 2)
	-- SolidBackground(resource_plot_widget, resource_plot_widget.foobar, '77000040')
	--]]
	
	-- reset plot data
	data_x = {}
	data_y = {}
	current_time = 0

	
	--plot_widget = plot.draw_plot(resource_plot_widget, {0, 100, 180, 190, 200, 300, 400, 450, 500}, {50, 30, 30, 0, 100, 120, 0, 0, 20})
	
	
	return resource_plot_widget
end


--[[
INFO:         income = table: 29D3BB90
INFO:                 MASS = 0.10000000149012
INFO:                 ENERGY = 1
INFO:         maxStorage = table: 29D3B758
INFO:                 MASS = 650
INFO:                 ENERGY = 5000
INFO:         reclaimed = table: 29D3BDC0
INFO:                 MASS = 0
INFO:                 ENERGY = 0
INFO:         lastUseRequested = table: 29D3B820
INFO:                 MASS = 0
INFO:                 ENERGY = 0
INFO:         lastUseActual = table: 29D3BA50
INFO:                 MASS = 0
INFO:                 ENERGY = 0
INFO:         stored = table: 29D3BC08
INFO:                 MASS = 650
INFO:                 ENERGY = 5000
--]]




function update()
	--LOG("updating resource usage")

	-- calculate new values

	local econData = GetEconomyTotals()
    local simFrequency = GetSimTicksPerSecond()

	if current_time < W then
		current_time = current_time + 1
		table.insert(data_x, current_time)
	else
		-- shift data
		table.remove(data_y, 1)
	end

	local function DisplayEconData(tableID)
        local maxStorageVal		= econData["maxStorage"][tableID]
        local storedVal			= econData["stored"][tableID]
        local incomeVal			= econData["income"][tableID]
        local lastRequestedVal	= econData["lastUseRequested"][tableID]
        local lastActualVal		= econData["lastUseActual"][tableID]

		local requestedAvg	= math.min(lastRequestedVal * simFrequency, 999999)
		local actualAvg		= math.min(lastActualVal * simFrequency, 999999)
		local incomeAvg		= math.min(incomeVal * simFrequency, 999999)

		local rateVal = 0
        if storedVal > 0.5 then
            rateVal = math.ceil(incomeAvg - actualAvg)
        else
            rateVal = math.ceil(incomeAvg - requestedAvg)
        end

		if rateVal < 0 then
			if storedVal <= 2 then
				-- we're stalling!
				table.insert(data_y, -1)
			else
				table.insert(data_y, storedVal)
			end
		else
			if storedVal >= maxStorageVal then
				-- we're overflowing!
				table.insert(data_y, -2)
			else
				table.insert(data_y, storedVal)
			end
		end
	end

	DisplayEconData("MASS")

	-- actually plot data

	if plot_widget != nil then
		plot_widget:Destroy()
		plot_widget = nil
	end

	
	plot_widget = plot.draw_plot(resource_plot_widget, data_x, data_y, econData.maxStorage.MASS)

	--LOG_OBJ(econData)
end

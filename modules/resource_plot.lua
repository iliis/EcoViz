local LayoutHelpers = import('/lua/maui/layouthelpers.lua') 
local Button = import('/lua/maui/button.lua').Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')


local plot = import('/mods/EcoPredict/modules/plot.lua')
local heatmap = import('/mods/EcoPredict/modules/heatmap.lua')
local helpers = import('/mods/EcoPredict/modules/helpers.lua')

local Units = import('/mods/common/units.lua')



local eco_types    = {'MASS', 'ENERGY'}
local eco_types_sc = {'mass', 'energy'}





function SolidBackground(parent, control, color)
	background = Bitmap(control)
	background:SetSolidColor(color)
	background.Top:Set(control.Top)
	background.Left:Set(control.Left)
	background.Right:Set(control.Right)
	background.Bottom:Set(control.Bottom)
	background.Depth:Set(function() return parent.Depth() + 1 end)
end


local Select = import('/mods/common/select.lua')
function get_all_units()

	-- return cached list of units (updated every 5 seconds or so?)
	-- return Units.Get()

	local units = nil
	Select.Hidden(function()
        units = {}
        UISelectionByCategory("ALLUNITS", false, false, false, false)
        for _, u in GetSelectedUnits() or {} do
            units[u:GetEntityId()] = u
        end
    end)
	return units
end


-- "<LOC uel0105_desc>Engineer" --> "Engineer"
function format_description(desc)
--return string.match(desc, '<.*>(.*)')
--return desc:find('>')
s, n = desc:gsub('<.*>', '')
return s
end



-- widget size
local W = 500
local H = 100


local history_perc = 0.2 -- how much of the graph plots past data

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
	
	-- draw a vertical line to indicate the present
	plot.draw_box(resource_plot_widget,
		resource_plot_widget.Left()+W*history_perc-1,
		resource_plot_widget.Top(),
		resource_plot_widget.Left()+W*history_perc+1,
		resource_plot_widget.Bottom(),
		'ff0000ff', -- some nice shade of blue ;)
		10 -- draw it above plot itself
	)




	local us = get_all_units()
	for _, unit in us do
		LOG("------------------------------------------------")
		LOG(unit:GetBlueprint().Description)
		LOG("------------------------")
		helpers.LOG_OBJ(Units.Data(unit))
		--LOG("---- methods:")
		--helpers.LOG_OBJ(unit, true)

		--LOG("---- eco data:")
		--helpers.LOG_OBJ(unit:GetEconData())
		LOG("---- work progress:", unit:GetWorkProgress())
		LOG("---- command queue:")
		for _, cmd in unit:GetCommandQueue() do
			LOG("\t> command:")
			LOG("\t\t"..repr(cmd))
			--helpers.LOG_OBJ(cmd, false, "\t")
			--LOG("\t\tfunctions():")
			--helpers.LOG_OBJ(cmd, true,  "\t")
			--LOG("\t\tblueprint:")
			--helpers.LOG_OBJ(cmd.Blueprint)
		end

		if unit:GetFocus() then
			LOG("---- focus: "..format_description(unit:GetFocus():GetBlueprint().Description))
		end
		--LOG_OBJ(unit:GetFocus())
		--LOG_OBJ(unit:GetFocus(), true)

		LOG("---- assisting me:")
		helpers.LOG_OBJ(GetAssistingUnitsList(unit))
		--helpers.LOG_OBJ(unit:GetFocus(), true)
		
		--LOG("---- blueprint:")
		--helpers.LOG_OBJ(unit:GetBlueprint())

		--LOG("---- by ID:")
		--u = GetUnitById(unit:GetEntityId())
		--helpers.LOG_OBJ(u)
		--helpers.LOG_OBJ(u, true)
		--helpers.LOG_OBJ(u:GetEconData())
		
		
		
		-- get build queue for current unit:
		LOG("---- factory queue:")
		helpers.LOG_OBJ(SetCurrentFactoryForQueueDisplay(unit))


		unit:SetCustomName(format_description(unit:GetBlueprint().Description))
	end

	LOG("sim ticks / second: "..tostring(GetSimTicksPerSecond()))

	-- TODO: hot to import this sim function? helpers.LOG_OBJ(GetUnitBlueprintByName('ueb1101'))


	heatmap.createUI(parent)

	
	return resource_plot_widget
end





 --[[ unit:
INFO: <LOC uel0001_desc>Armored Command Unit
INFO: ------------------------
INFO:         is_idle = false
INFO:         econ = table: 29F4DD48
INFO:                 massRequested = 8
INFO:                 energyConsumed = 70
INFO:                 energyProduced = 10
INFO:                 massConsumed = 8
INFO:                 massProduced = 1
INFO:                 energyRequested = 70
INFO:         assisters = 0
INFO:         assisting = 1
INFO:         build_rate = 20
INFO:         bonus = 1
INFO: ---- methods:
INFO:         GetEntityId = cfunction: 27CB4D80
INFO:         GetWorkProgress = cfunction: 27CB3640
INFO:         GetCommandQueue = cfunction: 27CB35C0
INFO:         GetFocus = cfunction: 27CB4300
INFO:         GetHealth = cfunction: 27CB4180
INFO:         SetCustomName = cfunction: 27CB4000
INFO:         GetMissileInfo = cfunction: 27CB3580
INFO:         CanAttackTarget = cfunction: 27CB4E40
INFO:         GetStat = cfunction: 27CB3380
INFO:         HasSelectionSet = cfunction: 27CB4100
INFO:         GetBuildRate = cfunction: 27CB4200
INFO:         GetFootPrintSize = cfunction: 27CB4E00
INFO:         GetSelectionSets = cfunction: 27CB4140
INFO:         IsOverchargePaused = cfunction: 27CB4240
INFO:         IsAutoMode = cfunction: 27CB4C80
INFO:         IsDead = cfunction: 27CB4280
INFO:         RemoveSelectionSet = cfunction: 27CB40C0
INFO:         GetUnitId = cfunction: 27CB4DC0
INFO:         GetArmy = cfunction: 27CB3700
INFO:         __index = table: 25945EB0
INFO:         IsStunned = cfunction: 27CB3340
INFO:         ProcessInfo = cfunction: 27CB4CC0
INFO:         IsAutoSurfaceMode = cfunction: 27CB4C40
INFO:         IsInCategory = cfunction: 27CB33C0
INFO:         HasUnloadCommandQueuedUp = cfunction: 27CB4D00
INFO:         GetShieldRatio = cfunction: 27CB3680
INFO:         GetCustomName = cfunction: 27CB4040
INFO:         IsIdle = cfunction: 27CB42C0
INFO:         GetMaxHealth = cfunction: 27CB41C0
INFO:         IsRepeatQueue = cfunction: 27CB4C00
INFO:         GetBlueprint = cfunction: 27CB4D40
INFO:         GetFuelRatio = cfunction: 27CB36C0
INFO:         GetEconData = cfunction: 27CB3600
INFO:         GetPosition = cfunction: 27CB3740
INFO:         GetCreator = cfunction: 27CB3780
INFO:         AddSelectionSet = cfunction: 27CB4080
INFO:         GetGuardedEntity = cfunction: 27CB37C0
--]]






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



function on_user_sync(sync)

--[[
if sync.CameraRequests and not table.emtpy(sync.CameraRequests) then
	LOG("CAMERA REQUEST!")
	helpers.LOG_OBJ(sync.CameraRequests)
end
--]]

if not table.empty(sync.Reclaim) then
	heatmap.updateReclaim(sync.Reclaim)
end


local print = false
for k, v in sync do
	if type(v) != 'table' or table.getn(v) > 0 then
		print = true
		break
	end
end

if print then
	LOG("--------------------------- on user sync:")
	helpers.LOG_OBJ(sync)
	helpers.LOG_OBJ(sync, true)
end
end




function update()
	--LOG("updating resource usage")

	-- calculate new values

	-- economy totals are in resources/tick! (unit values are in resources/second, i.e. 10*resources/tick)
	local econData = GetEconomyTotals()
    local simFrequency = GetSimTicksPerSecond()

	if current_time < W*history_perc then
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

		-- copied from lua/ui/game/economy.lua
		-- convert from resource/tick to resource/second
		local requestedAvg	= math.min(lastRequestedVal * simFrequency, 999999)
		local actualAvg		= math.min(lastActualVal	* simFrequency, 999999)
		local incomeAvg		= math.min(incomeVal		* simFrequency, 999999)

		--  not exactly sure why this is required ;)
		local rateVal = 0
        if storedVal > 0.5 then
            rateVal = math.ceil(incomeAvg - actualAvg)
        else
            rateVal = math.ceil(incomeAvg - requestedAvg)
        end

		if rateVal < 0 then
			if storedVal <= 0 then
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
		-- end copy

		return rateVal, storedVal, maxStorageVal
	end

	rate_mass, stored_mass, max_mass_storage = DisplayEconData("MASS")

	-- actually plot data

	if plot_widget != nil then
		plot_widget:Destroy()
		plot_widget = nil
	end


	plot_widget = plot.draw_plot(resource_plot_widget,
		resource_plot_widget.Left() + W*history_perc - current_time,
		resource_plot_widget.Bottom(),
		resource_plot_widget.Height(),
		data_x, data_y, econData.maxStorage.MASS)


	-- now try to predict the future development

	local data_predict_x = {}
	local data_predict_y = {}
	for t = 1, W*(1-history_perc) do
		table.insert(data_predict_x, t)

		mass = stored_mass + t/simFrequency*rate_mass -- convert back to mass/tick, TODO: do everything in seconds
		if mass > max_mass_storage then
			mass = -2 -- overflow
		elseif mass <= 0 then
			mass = -1 -- stall
		end

		table.insert(data_predict_y, mass)
	end

	-- actually plot our predictions
	plot.draw_plot(plot_widget,
		resource_plot_widget.Left() + W*history_perc,
		resource_plot_widget.Bottom(),
		resource_plot_widget.Height(),
		--data_x, data_y, econData.maxStorage.MASS)
		data_predict_x, data_predict_y, econData.maxStorage.MASS)

	

	for _, resource in eco_types_sc do

		local income_total = 0
		local requested_total = 0
		local consumed_total = 0

		for _, unit in Units.Get() do
			data = Units.Data(unit)
			if data.econ then
				income_total    = income_total	  + data.econ[resource..'Produced']
				requested_total = requested_total + data.econ[resource..'Requested']
				consumed_total  = consumed_total  + data.econ[resource..'Consumed']
			else
				LOG("unit "..unit:GetBlueprint().Description.." has no econ data")
				helpers.LOG_OBJ(data)
			end
		end

		--if resource == 'mass' then
		--LOG(resource..":\tincome: "..tostring(income_total).."\trequested: "..tostring(requested_total).."\tconsumed: "..tostring(consumed_total).."\tin-cons: "..tostring(income_total-consumed_total).."\treq-cons: "..tostring(requested_total-consumed_total))
		--end
	end

	--helpers.LOG_OBJ(GetEconomyTotals())

end
--[[
INFO:         econ = table: 29F4DD48
INFO:                 massRequested = 8
INFO:                 energyConsumed = 70
INFO:                 energyProduced = 10
INFO:                 massConsumed = 8
INFO:                 massProduced = 1
INFO:                 energyRequested = 70
--]]
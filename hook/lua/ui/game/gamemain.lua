local Button = import('/lua/maui/button.lua').Button
local LayoutHelpers = import('/lua/maui/layouthelpers.lua') 
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap

local originalCreateUI = CreateUI 

local widget = nil


function load_mod()

  if widget then
	widget:Destroy()
  end

  widget = Group(GetFrame(0))
  widget.Left:Set(0)
  widget.Top:Set(0)
  widget.Width:Set(0)
  widget.Height:Set(0)
  
  --local rplot = import('/mods/EcoPredict/modules/resource_plot.lua')
  --rplot.CreateModUI(widget)
  
end

--[[
function beat_func()
	if widget then
		local rplot = import('/mods/EcoPredict/modules/resource_plot.lua')
		rplot.update()
	end
end
--]]


function create_button(parent, x, y, text)
	button = Button(parent,
		'/textures/ui/common/dialogs/standard_btn/standard_btn_up.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_down.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_over.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_dis.dds')

	button.Depth:Set(99)

	button.Left:Set(x)
	button.Top:Set(y)
	--button.Width:Set(108)
	--button.Height:Set(41)

	button:EnableHitTest(true)
	
	
	button.label = UIUtil.CreateText(button, text, 10, UIUtil.bodyFont)
	button.label:SetColor('white')
    button.label:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(button.label, button)

	return button
end



function CreateUI(isReplay) 
	originalCreateUI(isReplay) 
 
  
  

  
	#KeyMapper.SetUserKeyAction('reload_ecopredict_ui', {action =  'import(\'/mods/EcoPredict/modules/resource_plot.lua\').CreateModUI()', category = 'user', order = 4})
  
	load_mod()

	--AddBeatFunction(beat_func)
  
	create_button(GetFrame(0), 400, 60, 'reload mod').OnClick = function (self, modifiers)
		LOG("reloading eco viz")
		load_mod()
	end

	
	create_button(GetFrame(0), 510, 60, 'hide mod').OnClick = function (self, modifiers)
		LOG("hiding eco viz")
		if widget then
			widget:Destroy()
			widget = nil
		end
	end

end






		
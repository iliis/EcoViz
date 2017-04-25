local Button = import('/lua/maui/button.lua').Button
local LayoutHelpers = import('/lua/maui/layouthelpers.lua') 


local originalCreateUI = CreateUI 

local widget = nil
function CreateUI(isReplay) 
  originalCreateUI(isReplay) 
 
  #AddBeatFunction(UpdateAllUnits)
  
  widget = import('/mods/EcoPredict/modules/resource_plot.lua').CreateModUI()
  #KeyMapper.SetUserKeyAction('reload_ecopredict_ui', {action =  'import(\'/mods/EcoPredict/modules/resource_plot.lua\').CreateModUI()', category = 'user', order = 4})
  
  
  
	reload_button = Button(GetFrame(0),
		'/textures/ui/common/dialogs/standard_btn/standard_btn_up.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_down.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_over.dds',
		'/textures/ui/common/dialogs/standard_btn/standard_btn_dis.dds')

	reload_button.Depth:Set(99)

	reload_button.Left:Set(400)
	reload_button.Top:Set(60)

	reload_button.OnClick = function (self, modifiers)
		LOG("reloading resource predictor")
		widget:Destroy()
		widget = import('/mods/EcoPredict/modules/resource_plot.lua').CreateModUI()
	end
	reload_button:EnableHitTest(true)
	
	
	reload_button.label = UIUtil.CreateText(reload_button, 'reload mod', 10, UIUtil.bodyFont)
	reload_button.label:SetColor('white')
    reload_button.label:SetDropShadow(true)
	LayoutHelpers.AtCenterIn(reload_button.label, reload_button)

end






		
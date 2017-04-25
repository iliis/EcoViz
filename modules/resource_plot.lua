local LayoutHelpers = import('/lua/maui/layouthelpers.lua') 
local Button = import('/lua/maui/button.lua').Button
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local UIUtil = import('/lua/ui/uiutil.lua')

local plot = import('/mods/EcoPredict/modules/plot.lua')


function SolidBackground(parent, control, color)
	background = Bitmap(control)
	background:SetSolidColor(color)
	background.Top:Set(control.Top)
	background.Left:Set(control.Left)
	background.Right:Set(control.Right)
	background.Bottom:Set(control.Bottom)
	background.Depth:Set(function() return parent.Depth() + 1 end)
end

local colors = {
	mass     = 'ffc6fb08',
	energy   = 'ffffc300',
	stall    = 'ffff3900',
	overflow = 'fffffb08'
}

-- widget size
local W = 500
local H = 100





function CreateModUI()

	LOG("creating resource plot UI")

	--local parent = import('/lua/ui/game/borders.lua').GetMapGroup()
	local parent = GetFrame(0)
	
	--local border_bg = UIUtil.SkinnableFile('/game/avatar-factory-panel/avatar-s-e-f_bmp.dds')
	
	widget = Bitmap(parent)
	widget:SetSolidColor('40000000') -- format: ARGB
	
	widget.Left:Set(400)
	widget.Top:Set(310)
	widget.Height:Set(H)
    widget.Width:Set(W)
	
	
	
	widget.foobar = UIUtil.CreateText(widget, 'Hallo Welt', 10, UIUtil.bodyFont)
	widget.foobar:SetColor('white')
    -- widget.foobar:SetDropShadow(true)
	LayoutHelpers.AtTopIn(widget.foobar, widget, 1)
    LayoutHelpers.AtLeftIn(widget.foobar, widget, 2)
	-- SolidBackground(widget, widget.foobar, '77000040')
	
	
	plot.draw_plot(widget, {0, 100, 180, 190, 200, 300, 400, 450, 500}, {50, 30, 30, 0, 100, 120, 0, 0, 20})
	
	
	return widget
end
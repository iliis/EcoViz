local helpers = import('/mods/EcoViz/modules/helpers.lua')
local bubble = import('/mods/EcoViz/modules/bubbleplot.lua')

local NUM_LAYERS = 10

local reclaim_bubble_plot = nil

function UpdateLabels()
  local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
  
  if ReclaimChanged then
    reclaim_bubble_plot:updateValues(Reclaim)
  end
  
  reclaim_bubble_plot:renderLabels(MaxLabels, view)
end


local orig_initReclaimGroup = InitReclaimGroup
function InitReclaimGroup(view)
  orig_initReclaimGroup(view)

  if not reclaim_bubble_plot then
    reclaim_bubble_plot = bubble.BubblePlot(Reclaim, 'mass', NUM_LAYERS, view.ReclaimGroup, 'ffc6fb08')
  end
end
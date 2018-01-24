local helpers = import('/mods/EcoViz/modules/helpers.lua')
local bubble = import('/mods/EcoViz/modules/bubbleplot.lua')



local reclaim_bubble_plot = nil

function UpdateLabels()
  local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
  
  -- Layer for reclaim GUI
  -- view.ReclaimGroup
  
  if ReclaimChanged then
    for _, r in Reclaim do
      r.value = r.mass
    end
    
    if reclaim_bubble_plot then
      reclaim_bubble_plot:updateValues(Reclaim)
    end
  end
  
  reclaim_bubble_plot:renderLabels(MaxLabels)
end


local orig_initReclaimGroup = InitReclaimGroup
function InitReclaimGroup(view)
  orig_initReclaimGroup(view)

  if not reclaim_bubble_plot or IsDestroyed(reclaim_bubble_plot) then
    reclaim_bubble_plot = bubble.BubbleLayer(view.ReclaimGroup, view, 'ffc6fb08')
    reclaim_bubble_plot:updateValues(Reclaim)
  end
end
local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap
local helpers = import('/mods/EcoViz/modules/helpers.lua')

---------------------------------------------------------------------------------------------------
-- GLOBAL PARAMETERS

local BUBBLE_BORDER_WIDTH = 2 -- in pixels
local BUBBLE_BORDER_COLOR = 'ff000000'
local BUBBLE_MIN_SIZE = 5 -- in pixels

-- everything closer than that will be merged into one blob
local max_screen_dist = 10 -- in pixels

local zoom_size_mult = 150
local zoom_size_const = 1.2
-- size = sqrt(mass)*(zoom_size_modifier/zoom+zoom_size_const)

-- used to calculate on-screen distances based on world coordinates when no view is available
-- this is used to cluster points when generating the layers
-- one world unit was 18 pixels for me at zoom=5, but this probably depends on the resolution!
local WORLD_DIST_TO_PX = 18 *5 * 10

local LabelPool = {} -- Stores labels up too MaxLabels

---------------------------------------------------------------------------------------------------

function table.last_idx(t)
  local last = nil
  for k, v in t do
    if v then
      last = k
    end
  end
  return last
end

function table.pop_last(t)
  local N = table.last_idx(t)
  local obj = t[N]
  t[N] = nil
  return obj
end

function table.getsize_nonnil(t)
  if type(t) != 'table' then return end
  local size = 0
  for k, v in t do
    if v then
      size = size + 1
    end
  end
  return size
end

---------------------------------------------------------------------------------------------------
--[[

This library plots a generic bubble plot.

API:

BubblePlot.init(zoom_layer_count, max_widget_count, color)

BubblePlot.generate(List[ValueObject])

Widgets hierarchy:

- root
   - zoom_layer1
      bubble1
      bubble2
      ...
   - zoom_layer2
      bubble1
      bubble2
      ...

]]--
---------------------------------------------------------------------------------------------------
-- represents a single value with position in the world (such as a single reclaim object or a single pgen)
--[[
ValueObject = Class() {
	__init = function(self, id, world_position, value)
		self.id = id
		self.world_position = world_position
		self.value = value
	end,

	DistanceTo = function(self, other)
		return VDist3(self.world_position, other.world_position)
	end,
}
--]]

---------------------------------------------------------------------------------------------------

BubblePointLabel = Class(Group) {
  __init = function(self, parent, viewport, bubble_point, color)
    Group.__init(self, parent)
    
    self.viewport = viewport
    
    self.bubble_point = bubble_point
    
    self.size = 10
    
    self:SetNeedsFrameUpdate(true)
    self:DisableHitTest(true)
    
    self.lbl_fill = Bitmap(self)
    self.lbl_fill:SetSolidColor(color)
    LayoutHelpers.AtCenterIn(self.lbl_fill, self)
    self.lbl_fill.Height:Set(10)
    self.lbl_fill.Width :Set(10)
    self.lbl_fill.Top :Set(0)
    self.lbl_fill.Left:Set(0)
    self.lbl_fill:DisableHitTest(true)
    self:Update()
    
    self.lbl_border = Bitmap(self)
    self.lbl_border:SetSolidColor(BUBBLE_BORDER_COLOR)
    --LayoutHelpers.AtCenterIn(self.lbl_border, self.lbl_fill)
    self.lbl_border.Left  :Set(function() return self.lbl_fill.Left()-BUBBLE_BORDER_WIDTH end)
    self.lbl_border.Top   :Set(function() return self.lbl_fill.Top() -BUBBLE_BORDER_WIDTH end)
    self.lbl_border.Height:Set(function() return self.lbl_fill.Height()+BUBBLE_BORDER_WIDTH*2 end)
    self.lbl_border.Width :Set(function() return self.lbl_fill.Width() +BUBBLE_BORDER_WIDTH*2 end)
    self.lbl_border.Depth :Set(function() return self.lbl_fill.Depth()-1 end) -- border should be behind green box
    self.lbl_border:DisableHitTest(true)
    
    self.Top:   Set(function() return self.lbl_border.Top() end)
    self.Left:  Set(function() return self.lbl_border.Left() end)
    self.Width: Set(function() return self.lbl_border.Width() end)
    self.Height:Set(function() return self.lbl_border.Height() end)
    
    self:DisableHitTest(true)
  end,
  
  IsInView = function(self)
    return self.viewport:HitTest(self.screen_pos.x, self.screen_pos.y)
  end,
  
  SetData = function(self, bubble_point)
    self.bubble_point = bubble_point
    if self:IsHidden() then
      self:Show()
    end
    self:Update()
  end,
  
  Update = function(self)
    self.screen_pos = self.viewport:Project(self.bubble_point.weighted_pos)
    -- align label to pixels
    self.screen_pos.x = math.round(self.screen_pos.x)
    self.screen_pos.y = math.round(self.screen_pos.y)
    
    local camera = GetCamera("WorldCamera") -- TODO: store a reference to camera instead of 'getting' it on every update?
    
    -- use integer size
    self.size = math.round(math.max(BUBBLE_MIN_SIZE, math.sqrt(self.bubble_point:value()) * (zoom_size_mult / camera:GetZoom() + zoom_size_const)))
    self.lbl_fill.Width :Set(self.size)
    self.lbl_fill.Height:Set(self.size)
    self.lbl_fill.Left:Set(self.screen_pos.x - math.round(self.size/2))
    self.lbl_fill.Top :Set(self.screen_pos.y - math.round(self.size/2))
	end,

  OnFrame = function(self, delta)
      self:Update()
  end,
  
  OnHide = function(self, hidden)
    self:SetNeedsFrameUpdate(not hidden)
  end,
}
---------------------------------------------------------------------------------------------------
-- a single 'Bubble' (rendered as a square label)

BubblePoint = Class() {
	__init = function(self, viewport, world_position, color, self_value)
    self.viewport = viewport
    self.proj = nil
    self.world_pos    = world_position
    self.weighted_pos = world_position
    self.children = {}
    self.parent = nil
    
    helpers.ASSERT_VECT(world_position)
    
    self.self_value  = self_value
    self.total_value = self_value
  end,
  
  value = function(self)
    return self.total_value
  end,
  
  weightedPos = function(self)
    local pos_sum   = VMult(self.world_pos, self.self_value)
    local value_sum = self.self_value
    
    for _, c in self.children do
      pos_sum   = VAdd(pos_sum, VMult(c.world_pos, c:value()))
      --LOG("adding " .. helpers.vectostr(c.world_pos) .. " * " .. tostring(c:value()) .. " = " .. helpers.vectostr(pos_sum))
      value_sum = value_sum + c:value()
    end
    
    if value_sum ~= 0 then
      local result = VMult(pos_sum, 1/value_sum)
      --LOG("result: " .. helpers.vectostr(result))
      return result
    else
      return self.world_pos
    end
  end,
  
  IsInView = function(self)
    local screen_pos = self.viewport:Project(self.weighted_pos)
    -- TODO: take size into account
    return self.viewport:HitTest(screen_pos.x, screen_pos.y)
  end,
  
  SetValue = function(self, value)
    if value ~= self.self_value then
      self.self_value = value
      self:Update()
    end
  end,
  
  AddChild = function(self, child)
    if child == self or child.parent == self then
      WARN("Trying to append child to itself or its own parent!")
      return
    end
    
    local oldn = table.getsize(self.children)
    
    table.insert(self.children, child)
    child.parent = self
    
    if oldn+1 ~= table.getsize(self.children) then
      helpers.RAISE_EXCEPTION("AddChild failed!")
    end
  end,
  
  ChildCount = function(self)
    --LOG("AddChild: have now " .. tostring(table.getsize(self.children)) .. " children")
    return table.getsize(self.children)
  end,
  
  Update = function(self)
    self.total_value = self.self_value
    for id, c in self.children do
      if c and c:value() ~= 0 then
        self.total_value = self.total_value + c:value()
      else
        --LOG("deleting child " .. tostring(id) .. " because: " .. tostring(c) .. " IsDestroyed? " .. tostring(IsDestroyed(c)) .. " value: " .. tostring(c:value()))
        self.children[id] = nil
      end
    end
    
    if self.parent then
      self.parent:Update()
      
      if self.total_value == 0 then
        -- this bubble plopped, remove myself from tree
        self.parent = nil
      end
    end
    
    self.weighted_pos = self:weightedPos()
  end,

}

---------------------------------------------------------------------------------------------------
-- a single zoom-level consisting of many (possibly aggregated) BubblePoints
-- can render those points as labels, taking visibility into account

BubbleLayer = Class() {
	__init = function(self, gui_parent, viewport, color, zoom_min, zoom_max)
    
    self.gui_parent = gui_parent
    self.viewport = viewport
    self.color = color
    
    self.bubble_points = {}
    
    self.zoom_min = zoom_min
    self.zoom_max = zoom_max
  end,
  
  isInZoomRange = function(self, zoom)
    if self.zoom_min and zoom < self.zoom_min then
      return false
    end
    
    if self.zoom_max and zoom > self.zoom_max then
      return false
    end
    
    return true
  end,
  
  updateValues = function(self, data)
    local data_cnt = 0
    for id, d in data do
      data_cnt = data_cnt + 1
      local bubble = self.bubble_points[id]
      if d.value then
        
        if bubble == nil then
          
          if d.position[1] == nil then
            LOG("invalid position!")
            helpers.LOG_OBJ(d)
            LOG("pos:")
            helpers.LOG_OBJ(d.position)
          end
          
          bubble = BubblePoint(self.viewport, d.position, self.color, d.value)
          self.bubble_points[id] = bubble
        end
        
        bubble:SetValue(d.value)
      else
        if bubble then
          bubble:SetValue(0)
          self.bubble_points[id] = nil
        end
      end
    end
    
    -- build tree
    LOG("clustering layer...")
    self:clusterPoints()
    
    --LOG("updated with " .. tostring(data_cnt) .. " datapoints")
  end,
  
  -- group points into clusters
  clusterPoints = function(self)
    local zoom = (self.zoom_min + self.zoom_max)/2
    --local zoom_sq = zoom*zoom
    
    local close_enough = function(p1, p2)
      -- TODO: use VDist3sq and do away with math.sqrt() somehow
      local dist = VDist3(p1.weighted_pos, p2.weighted_pos) * WORLD_DIST_TO_PX
      local good = dist / zoom  <  max_screen_dist + math.sqrt(p1:value()) + math.sqrt(p2:value())
      
      --[[
      if good then
        LOG(tostring(p1) .. " - " .. tostring(p2) .. ": distance = " .. tostring(dist) .. " / zoom = " .. tostring(dist/zoom) .. " <= " .. tostring(max_screen_dist + math.sqrt(p1:value()) + math.sqrt(p2:value())))
      end
      --]]
      
      return good
    end
    
    local new_points = {}
    while not table.empty(self.bubble_points) do
      -- pop a point and create cluster with it
      local pivot = table.pop_last(self.bubble_points)
      
      --LOG("empty? " .. tostring(table.empty(self.bubble_points)) .. ", number of elements: " .. tostring(table.getsize_nonnil(self.bubble_points)))
      --LOG("clustering based on " .. tostring(pivot))
      
      if pivot == nil then
        continue
      end
      
      local cluster = BubblePoint(self.viewport, Vector(0,0,0), self.color, 0)
      cluster:AddChild(pivot)
      
      -- find points that are close to 'pt' and merge them
      for idx, p in self.bubble_points do
        if close_enough(p, pivot) then
          cluster:AddChild(p)
          self.bubble_points[idx] = nil
        end
      end
      
      if cluster:ChildCount() == 1 then
        -- no need to create cluster for a single point
        table.insert(new_points, pivot)
      else
        cluster:Update()
        table.insert(new_points, cluster)
      end
      
      --LOG("     = " .. tostring(cluster:ChildCount()))
      
      
      --cluster.weighted_pos = pivot.world_pos
      --LOG(" --> clustered " .. tostring(table.getsize(cluster.children)) .. " points into one at " .. tostring(cluster.weighted_pos.x) .. ", " .. tostring(cluster.weighted_pos.y))
      --LOG("     = " .. tostring(cluster:ChildCount()))
      
    end
    
    self.bubble_points = new_points
    
    LOG(" -> clustered into " .. tostring(table.getsize(new_points)) .. " clusters")
  end,
  
  renderLabels = function(self, MaxLabels)
    local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
    
    local onScreenIndex = 1
    local onScreenLabels = {}

    -- One might be tempted to use a binary insert; however, tests have shown that it takes about 140x more time
    for _, r in self.bubble_points do
        if r:IsInView() then
            onScreenLabels[onScreenIndex] = r
            onScreenIndex = onScreenIndex + 1
        end
    end

    table.sort(onScreenLabels, function(a, b) return a:value() > b:value() end)

    -- Create/Update as many reclaim labels as we need
    local labelIndex = 1
    for _, r in onScreenLabels do
        if labelIndex > MaxLabels then
            break
        end
        
        local label = LabelPool[labelIndex]
        -- TODO: IsDestroyed(): check if *RECLAIM* object still exists in game!
        -- does IsDestroyed() really what it should here??? or are we *always* creating a new label?
        if label and IsDestroyed(label) then
          label = nil
        end
        
        if not label then
            --label = CreateReclaimLabel(view.ReclaimGroup, r)
            label = BubblePointLabel(self.gui_parent, view, r, self.color)
            LabelPool[labelIndex] = label
        end

        label:SetData(r)
        labelIndex = labelIndex + 1
    end
    
    
    LOG("rendered " .. tostring(labelIndex) .. " labels from " .. tostring(table.getsize(onScreenLabels))
      .. " points on screen from " .. tostring(table.getsize(self.bubble_points)) .. " points in current layer")

    -- Hide labels we didn't use
    for index = labelIndex, MaxLabels do
        local label = LabelPool[index]
        if label then
            if IsDestroyed(label) then
                LabelPool[index] = nil
            elseif not label:IsHidden() then
                label:Hide()
            end
        end
    end
    
  end,
}

---------------------------------------------------------------------------------------------------
-- full, hierarchical bubble plot

BubblePlot = Class() {
  __init = function(self, layer_count, gui_parent, viewport, color)
    
    local camera = GetCamera("WorldCamera")
    local min_zoom = camera:GetMinZoom()-1
    local max_zoom = camera:GetMaxZoom()+10
    
    self.layers = {}
    for layer_idx = 0, layer_count-1 do
      
      local zoom_range = (max_zoom-min_zoom) / layer_count
      local min_z = min_zoom + layer_idx * zoom_range
      local max_z = min_z + zoom_range
            
      --LOG("building layer No. " .. tostring(layer_idx) .. " for range " .. tostring(min_z) .. " to " .. tostring(max_z))
      
      self.layers[layer_idx] = BubbleLayer(gui_parent, viewport, color, min_z, max_z)
    end
  end,
  
  renderLabels = function(self, MaxLabels)
    local zoom = GetCamera("WorldCamera"):GetZoom()
    -- find layer which corresponds to current zoom level
    for idx, layer in self.layers do
      if layer:isInZoomRange(zoom) then
        layer:renderLabels(MaxLabels)
        return
      end
    end
    
    WARN("BubblePlot:renderLabels(): Did not find a layer which corresponds to zoom level of " .. tostring(zoom))
  end,
  
  updateValues = function(self, data)
    for _, layer in self.layers do
      layer:updateValues(data)
    end
  end,
}

---------------------------------------------------------------------------------------------------

-- OLD CODE:
--[[
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

function BuildTree(self, values)
	while table.length(values) > 1 do
		-- find closest pair
		local obj_A = nil
		local obj_B = nil
		local best_dist = nil

		for _, v in values do
			if obj_A == nil then
				obj_A = v
			else
				if (v == obj_A) then
					WARN("Error: found item twice in 'values' of BuildTree()")
				end

				local dist = obj_A:DistanceTo(v)
				if best_dist == nil or best_dist > dist then
					best_dist = dist
					obj_B = v
				end
			end
		end

		-- remove pair and put them into new group
		values[obj_A] = nil
		values[obj_B] = nil

		local new_group = ValueObjectGroup({obj_A, obj_B}, best_dist)
		values[new_group] = new_group
	end
		
	-- set root to first=last item in 'values'
	for _, v in values do
		return v
	end
end

---------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------

ValueObjectGroup = Class() {
	__init = function(self, _children, max_dist)
		self.world_position = nil
		self.value = nil

		self.max_dist = max_dist

		self.parent = nil -- TODO: not required?
		self.children = {}

		for c in _children do
			self:AddChild(c)
		end
		self:updateWeightedPosition()
	end,

	DistanceTo = function(self, other)
		return VDist3(self.world_position, other.world_position)
	end,

	updateWeightedPosition = function(self)
		self.world_position = Vector(0,0,0)
		self.value = 0

		for child in self.children:
			self.world_position = VAdd(self.world_position, VMult(child.world_position, child.value))
			self.value = self.value + child.value
		end

		self.world_position = VMult(self.world_position, 1/self.value)
	end,

	AddChild = function(self, child)
		if not self.children[child] then -- don't add it twice
			self.children[child] = child
			child.parent = self
		end
	end,

	RemoveChild = function(self, child)
		if self.children[child] then
			self.children[child] = nil
			child.parent = nil
		end
	end
}
--]]
---------------------------------------------------------------------------------------------------



---------------------------------------------------------------------------------------------------
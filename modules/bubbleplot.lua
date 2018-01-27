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
-- this is a fudge factor! adjust until it looks good ;)
-- the smaller this value, the more aggressive the clustering (i.e. more points will be grouped into one)
local WORLD_DIST_TO_PX = 18 * 5 * 15

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

TODO: this docu is a bit outdated!

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
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------

BubblePointLabel = Class(Group) {
  __init = function(self, parent, viewport, bubble_point, color)
    Group.__init(self, parent)
    
    self.viewport = viewport
    
    self.bubble_point = bubble_point
    helpers.ASSERT_VECT_NONZERO(self.bubble_point.weighted_pos)
    
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
  
  -------------------------------------------------------------------------------------------------
  
  IsInView = function(self)
    return self.viewport:HitTest(self.screen_pos.x, self.screen_pos.y)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  SetData = function(self, bubble_point)
    self.bubble_point = bubble_point
    helpers.ASSERT_VECT_NONZERO(self.bubble_point.weighted_pos)
    if self:IsHidden() then
      self:Show()
    end
    self:Update()
  end,
  
  -------------------------------------------------------------------------------------------------
  
  Update = function(self)
    helpers.ASSERT_VECT_NONZERO(self.bubble_point.weighted_pos)
    
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
  
  -------------------------------------------------------------------------------------------------

  OnFrame = function(self, delta)
      self:Update()
  end,
  
  -------------------------------------------------------------------------------------------------
  
  OnHide = function(self, hidden)
    self:SetNeedsFrameUpdate(not hidden)
  end,
}

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- a single 'Bubble' (rendered as a square label)

BubblePoint = Class() {
	__init = function(self, world_position, color, self_value)
    self.proj = nil
    self.world_pos    = world_position
    self.weighted_pos = world_position
    self.children = {}
    self.parent = nil
    
    helpers.ASSERT_VECT(world_position)
    
    self.self_value  = self_value
    self.total_value = self_value
  end,
  
  -------------------------------------------------------------------------------------------------
  
  value = function(self)
    return self.total_value
  end,
  
  -------------------------------------------------------------------------------------------------
  
  weightedPos = function(self)
    local pos_sum   = VMult(self.world_pos, self.self_value)
    local value_sum = self.self_value
    
    for _, c in self.children do
       helpers.ASSERT_VECT(pos_sum)
      pos_sum   = VAdd(pos_sum, VMult(c.weighted_pos, c:value()))
      --LOG("adding " .. helpers.vectostr(c.world_pos) .. " * " .. tostring(c:value()) .. " = " .. helpers.vectostr(pos_sum))
      value_sum = value_sum + c:value()
    end
    
    if value_sum ~= 0 then
      local result = VMult(pos_sum, 1/value_sum)
      if result[1] == 0 then
        WARN("invalid result in weighted pos:")
        LOG("result: " .. helpers.vectostr(result))
        LOG("pos_sum: " .. helpers.vectostr(pos_sum))
        LOG("value_sum: " .. tostring(value_sum))
        helpers.LOG_OBJ(self)
      end
      helpers.ASSERT_VECT_NONZERO(result)
      return result
    else
      --WARN('value sum is 0 in BubblePoint::weightedPos()')
      return self.world_pos
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  
  IsInView = function(self, viewport)
    local screen_pos = viewport:Project(self.weighted_pos)
    -- TODO: take size into account
    return viewport:HitTest(screen_pos.x, screen_pos.y)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  DistTo = function(self, other)
    helpers.ASSERT_VECT_NONZERO(self.weighted_pos)
    helpers.ASSERT_VECT_NONZERO(other.weighted_pos)
    
    return VDist3(self.weighted_pos, other.weighted_pos)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  SetValue = function(self, value)
    if value ~= self.self_value then
      self.self_value = value
      self:UpdateTotalValue()
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  
  AddChild = function(self, child)
    if child == self or child.parent == self then
      helpers.RAISE_EXCEPTION("Trying to append child to itself or its own parent!")
      return
    end
    
    if table.find(self.children, child) == nil then
      table.insert(self.children, child)
    else
      WARN("Trying to append child twice!")
      LOG("self:")
      helpers.LOG_OBJ(self)
      LOG("child:")
      helpers.LOG_OBJ(child)
    end
    
    child.parent = self
  end,
  
  -------------------------------------------------------------------------------------------------
  
  RemoveChild = function(self, child)
    local idx = table.find(self.children, child)
    if not idx then
      WARN("Cannot remove child: not a child of this node!")
      return
    end
    child.parent = nil
    self.children[idx] = nil
  end,
  
  -------------------------------------------------------------------------------------------------
  
  ChildCount = function(self)
    --LOG("AddChild: have now " .. tostring(table.getsize(self.children)) .. " children")
    return table.getsize(self.children)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  UpdateTotalValue = function(self)
    self.total_value = self.self_value
    for id, c in self.children do
      if c and c:value() ~= 0 then
        self.total_value = self.total_value + c:value()
      else
        --LOG("deleting child " .. tostring(id) .. " because: " .. tostring(c) .. " IsDestroyed? " .. tostring(IsDestroyed(c)) .. " value: " .. tostring(c:value()))
        self.children[id] = nil
      end
    end
    
    --[[
    if self.parent then
      self.parent:UpdateTotalValue()
      
      if self.total_value == 0 then
        -- this bubble plopped, remove myself from tree
        self.parent = nil
      end
    end
    --]]
    
    self.weighted_pos = self:weightedPos()
    helpers.ASSERT_VECT(self.weighted_pos)
  end,
}

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- a single zoom-level consisting of many (possibly aggregated) BubblePoints
-- can render those points as labels, taking visibility into account

BubbleLayer = Class() {
	__init = function(self, gui_parent, color, zoom_min, zoom_max)
    
    self.gui_parent = gui_parent
    self.color = color
    self.parent_layer = nil
    
    self.bubble_points = {}
    
    self.zoom_min = zoom_min
    self.zoom_max = zoom_max
    self.zoom = (self.zoom_min + self.zoom_max)/2
  end,
  
  -------------------------------------------------------------------------------------------------
  
  isInZoomRange = function(self, z)
    if self.zoom_min and z < self.zoom_min then
      return false
    end
    
    if self.zoom_max and z > self.zoom_max then
      return false
    end
    
    return true
  end,
  
  -------------------------------------------------------------------------------------------------
  
  -------------------------------------------------------------------------------------------------
  
  close_enough = function(self, dist, p1, p2)
    
    helpers.ASSERT(dist)
    helpers.ASSERT(p1)
    helpers.ASSERT(p2)
    
    -- TODO: use VDist3sq and do away with math.sqrt() somehow
    
    local good = dist * WORLD_DIST_TO_PX / self.zoom  <  max_screen_dist + math.sqrt(p1:value()) + math.sqrt(p2:value())
    
    --LOG(tostring(good) .. ": " .. tostring(p1) .. " - " .. tostring(p2) .. ": distance = " .. tostring(dist) .. " / zoom = " .. tostring(dist/zoom) .. " < " .. tostring(max_screen_dist + math.sqrt(p1:value()) + math.sqrt(p2:value())))
    
    return good
  end,
  
  -------------------------------------------------------------------------------------------------
  
  find_closest = function(self, bubble)
    helpers.ASSERT(bubble)
    
    local best_pt = nil
    local best_dist = nil
    
    for idx, b in self.bubble_points do
      if b ~= bubble then
        local dist = bubble:DistTo(b)
        if not best_dist or best_dist > dist then
          best_dist = dist
          best_pt = b
        end
      end
    end
    
    if best_dist and self:close_enough(best_dist, bubble, best_pt) then
      return best_pt
    else
      return nil
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  -- search for a point from layer below in this layer
  --[[
  find_child = function(self, bubble)
    helpers.ASSERT(bubble)
    for c_idx, c in self.bubble_points do
      if table.find(c.children, bubble) then
        return c_idx
      end
    end
    return nil
  end,
  
  -------------------------------------------------------------------------------------------------
  
  reclusterPointRecursively = function(self, node_current)
    LOG("reclustering " .. tostring(node_current) .. " with value " .. tostring(node_current:value()))
    
    -- remove current node from tree
    
  end,
  
  
  -- TODO: document this!
  reclusterPointRecursively_orig = function(self, node_child)
    
    LOG("reclustering " .. tostring(node_child) .. " with value " .. tostring(node_child:value()))
    
    -- check if new bubble (child) is already part of this layer
    local local_idx = self:find_child(node_child)
    if local_idx then
      
      -- recluster bubble by splitting it into components
      -- TODO: this assumes bubble is a *cluster* (i.e. has self_value = 0)
      
      local node_current = self.bubble_points[local_idx]
      
      LOG(" --> splitting up existing cluster into " .. tostring(table.getsize(node_current.children)) .. " points")
      
      
      local node_parent = node_current.parent
     
      -- remove curent node from this layer
      self.bubble_points[local_idx] = nil
      
      -- check if we can remove it entirely
      node_current:UpdateTotalValue()
      
      if node_current:value() == 0 then
        LOG(" --> removing cluster as it only contains single bubble which was removed")
        
        if node_parent then
          helpers.ASSERT(self.parent_layer)
          self.parent_layer:reclusterPointRecursively(node_current)
        end
        
        return
      end
      
      -- remove old cluster from tree
      if node_parent then
        node_parent:RemoveChild(node_current)
        node_parent:UpdateTotalValue() -- required if no children get clustered to node_parent
      else
        helpers.ASSERT(not self.parent_layer)
      end
      
      -- now add children again
      local new_clusters = {}
      for _, c in node_current.children do
        if c:value() ~= 0 then
          helpers.ASSERT_VECT_NONZERO(c.weighted_pos)
          LOG("    --> reinserting child with value " .. tostring(c:value()))
          
          table.insert(new_clusters, self:clusterNewPointIntoLayer(c))
        end
      end
      
      if self.parent_layer then
        LOG("recusrively recluster those again in parent")
        for _, new_cluster in new_clusters do
          self.parent_layer:reclusterPointRecursively(new_cluster)
        end
        
        if not table.find(new_clusters, node_parent) then
          self.parent_layer:reclusterPointRecursively(node_parent)
        end
      end
    else
      
      if node_child:value() == 0 then
        LOG(" --> not adding, value is zero")
      else
        
        -- add bubble to existing/new cluster in this layer
        LOG(" --> adding as new point")
        node_child = self:clusterNewPointIntoLayer(node_child)
        if self.parent_layer then
          LOG("recusrively adding new cluster")
          self.parent_layer:reclusterPointRecursively(chnode_childild)
        end
      end
    end
  end,
  --]]
  
  -------------------------------------------------------------------------------------------------
  -- merge two bubble points into one (B into A)
  -- doesn't change rest of tree (apart from parent/children)
  
  mergeNodes = function(self, A, B)
    helpers.ASSERT(A ~= B)
    
    if A.parent ~= B.parent then
      -- nodes in the same layer always have both or neither a parent
      helpers.ASSERT(A.parent)
      helpers.ASSERT(B.parent)
      helpers.ASSERT(self.parent_layer)
      self.parent_layer:mergeNodes(A.parent, B.parent)
    end
      
    -- delete B from parent
    if B.parent then
      B.parent:RemoveChild(B)
    end
    
    -- delete from current layer
    self.bubble_points[table.find(self.bubble_points, B)] = nil
    
    -- add all children from B to A
    for _, c in B.children do
      A:AddChild(c)
    end
    
    LOG("merging B (" .. tostring(B) .. " = " .. tostring(B:value()) .. ") into A (" .. tostring(A) .. " = " .. tostring(A:value()) .. ") -> ")
    
    A:UpdateTotalValue()
    LOG("    -> A = " .. tostring(B:value()))
    
    return A
  end,
  
  -------------------------------------------------------------------------------------------------
  -- check if 'bubble' can be merged with any neighbors and check reslting parents as well
  mergeRecursively = function(self, bubble)
    helpers.ASSERT(bubble)
    
    -- update, in case no closest value will be found
    -- and to make sure weighted_pos is up-to-date
    bubble:UpdateTotalValue()
    
    while true do
      local closest = self:find_closest(bubble)
      if not closest then
        break
      else
        self:mergeNodes(bubble, closest)
      end
    end
    
    if self.parent_layer then
      self.parent_layer:mergeRecursively(bubble.parent)
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  -- insert bubble from layer below into current layer
  -- either merges it into existing cluster (and updates their parents if recursive=true)
  -- or creates a new bubble in current layer (and inserts it into parent layer if recursive=true)
  
  clusterChildIntoLayer = function(self, point, recursive)
    
    helpers.ASSERT_VECT_NONZERO(point.weighted_pos)
    
    LOG("clustering new point " .. tostring(point) .. " with value = " .. tostring(point:value()) .. " recursive? " .. tostring(recursive))
    
    local cluster = self:find_closest(point)
    
    --LOG("clustering piont " .. tostring(point) .. " into layer with " .. tostring(table.getsize(self.bubble_points)) .. " clusters")
    --LOG(" -> found close enough: " .. tostring(cluster))
    
    if cluster ~= nil and point.parent == cluster then
      WARN("invalid point to add, already added!")
    end
    
    local new_cluster = false
    if not cluster then
      new_cluster = true
      -- no existing cluster found where we could add this point, create new one
      cluster = BubblePoint(Vector(0,0,0), self.color, 0)
      table.insert(self.bubble_points, cluster)
      LOG(" --> adding to new cluster " .. tostring(cluster))
    else
      LOG(" --> adding to existing cluster " .. tostring(cluster) .. " with value = " .. tostring(cluster:value()) .. " and " .. tostring(table.getsize(cluster.children)) .. " children")
    end
    
    cluster:AddChild(point)
    cluster:UpdateTotalValue()
    helpers.ASSERT_VECT_NONZERO(cluster.weighted_pos)
    
    LOG("     --> cluster now has value = " .. tostring(cluster:value()) .. " and " .. tostring(table.getsize(cluster.children)) .. " children")
    
    if recursive then
      if new_cluster then
        -- we created a new cluster in current layer -> insert into parent layer too
        if self.parent_layer then
          self.parent_layer:clusterChildIntoLayer(cluster, true)
        end
      else
        -- we enlarged 'cluster', maybe it now merges with neighbors
        self:mergeRecursively(cluster)
      end
    end
    
    return cluster
  end,
  
  -------------------------------------------------------------------------------------------------
  -- destroy all points in bubbles and re-add them to current layer
  -- recursively to this to their parents too
  
  reclusterPoints = function(self, bubbles)
    
    LOG("reclustering " .. tostring(table.getsize(bubbles)) .. " points:")
    
    local affected_parents = {}
    for _, b in bubbles do
      
      LOG("     > recluster " .. tostring(b) .. " = " .. tostring(b:value()))
    
      local idx = table.find(self.bubble_points, b)
      helpers.ASSERT(idx)
      
      -- remove from current layer
      self.bubble_points[idx] = nil
      
      -- remove from parents
      if b.parent then
        local parent = b.parent
        LOG("       affected parent from removing parent:" .. tostring(parent))
        affected_parents[parent] = true
        parent:RemoveChild(b)
      end
      
      -- re-add children
      for _, c in b.children do
        local node = self:clusterChildIntoLayer(c, false)
        
        -- node can either be a new cluster (node.parent == nil), in which case we have to add it to parent layer first
        -- or it is an existing cluster, in which case we have to recluster its parent
        if node.parent then
          LOG("       affected parent from clusterChild into current layer:" .. tostring(node.parent))
          affected_parents[node.parent] = true
        else
          if self.parent_layer then
            -- don't add it recursively, as we might merge (and therefore delete) on of the affected_parents
            -- inserting it into parent layer even as a new cluster (without parent) is okay tough, as reclusterPoints()
            -- would remove the parent again anyway
            local n = self.parent_layer:clusterChildIntoLayer(node, false)
            helpers.ASSERT(n == node.parent)
            affected_parents[n] = true
            LOG("       affected parent from clusterChild into parent layer:" .. tostring(n))
            -- recursion should make parent of node valid
          end
        end
      end
    end
    
    -- convert key-list to normal value-list
    local affected_parents_list = {}
    for k, _ in affected_parents do
      table.insert(affected_parents_list, k)
    end
    
    -- no affected parents IFF no parent layer
    helpers.ASSERT(table.empty(affected_parents_list) == (self.parent_layer == nil))
    
    -- recluster their parents
    if self.parent_layer then
      self.parent_layer:reclusterPoints(affected_parents_list)
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  -- remove point and recluster parents
  
  removePoint = function(self, bubble)
    LOG("removing " .. tostring(bubble) .. " = " .. tostring(bubble:value()) .. " from layer")
    
    local idx = table.find(self.bubble_points, bubble)
    helpers.ASSERT(idx)
    
    -- remove from current layer
    self.bubble_points[idx] = nil
    
    -- remove from parents
    if bubble.parent then
      local parent = bubble.parent
      parent:RemoveChild(bubble)
      self.parent_layer:reclusterPoints({parent})
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  
  -- group points into clusters
  clusterPoints = function(self, data)
    helpers.ASSERT_UNIQUE_SET(data)
    
    LOG("clustering layer with " .. tostring(table.getsize(data)) .. " datapoints and zoom = " .. tostring(self.zoom))
    --local zoom_sq = zoom*zoom
    
    
    data = table.copy(data) -- create shallow copy so we can remove elements
    
    self.bubble_points = {} -- clear existing clustering
    while not table.empty(data) do
      -- pop a point and create cluster with it
      local pivot = table.pop_last(data)
      
      --LOG("empty? " .. tostring(table.empty(self.bubble_points)) .. ", number of elements: " .. tostring(table.getsize_nonnil(self.bubble_points)))
      --LOG("clustering based on " .. tostring(pivot))
      
      if pivot == nil then
        continue
      end
      
      self:clusterChildIntoLayer(pivot, false)
    end
    
    LOG(" -> clustered into " .. tostring(table.getsize(self.bubble_points)) .. " clusters")
    helpers.ASSERT_UNIQUE_SET(self.bubble_points)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  renderLabels = function(self, MaxLabels, viewport)
    --local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
    
    local onScreenIndex = 1
    local onScreenLabels = {}

    -- One might be tempted to use a binary insert; however, tests have shown that it takes about 140x more time
    for _, r in self.bubble_points do
      helpers.ASSERT_VECT_NONZERO(r.weighted_pos)
      if r:IsInView(viewport) then
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
            helpers.ASSERT_VECT_NONZERO(r.weighted_pos)
            -- (parent, viewport, bubble_point, color)
            label = BubblePointLabel(self.gui_parent, viewport, r, self.color)
            LabelPool[labelIndex] = label
        end

        label:SetData(r)
        labelIndex = labelIndex + 1
    end
    
    
    --LOG("rendered " .. tostring(labelIndex) .. " labels from " .. tostring(table.getsize(onScreenLabels))
    --  .. " points on screen from " .. tostring(table.getsize(self.bubble_points)) .. " points in current layer")

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
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- full, hierarchical bubble plot

BubblePlot = Class() {
  __init = function(self, data, data_field, layer_count, gui_parent, color)
    
    local camera = GetCamera("WorldCamera")
    local min_zoom = camera:GetMinZoom()-1
    local max_zoom = camera:GetMaxZoom()+10
    
    self.raw_data = nil
    self.raw_data_field = data_field
    self.raw_data_to_bubble0 = {} -- keep a mapping from 'data' entries to bubbles in layer 0
    -- this assumes data entries are kept static! (i.e. don't change address/id)
    
    self.color = color
    
    self.layers = {}
    for layer_idx = 0, layer_count-1 do
      
      local zoom_range = (max_zoom-min_zoom) / layer_count
      local min_z = min_zoom + layer_idx * zoom_range
      local max_z = min_z + zoom_range
            
      --LOG("building layer No. " .. tostring(layer_idx) .. " for range " .. tostring(min_z) .. " to " .. tostring(max_z))
      
      self.layers[layer_idx] = BubbleLayer(gui_parent, color, min_z, max_z)
      if layer_idx > 0 then
        self.layers[layer_idx-1].parent_layer = self.layers[layer_idx]
      end
    end
    
    self:buildTree(data)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  renderLabels = function(self, MaxLabels, viewport)
    local zoom = GetCamera("WorldCamera"):GetZoom()
    -- find layer which corresponds to current zoom level
    for idx, layer in self.layers do
      if layer:isInZoomRange(zoom) then
        --LOG("rendering layer " .. tostring(idx) .. " with " .. tostring(table.getsize(layer.bubble_points)) .. " datapoints")
        layer:renderLabels(MaxLabels, viewport)
        return
      end
    end
    
    WARN("BubblePlot:renderLabels(): Did not find a layer which corresponds to zoom level of " .. tostring(zoom))
  end,
  
  -------------------------------------------------------------------------------------------------
  --[[
  addNewValue = function(self, datapoint)
    local bubble = BubblePoint(datapoint.position, self.color, datapoint[self.raw_data_field])
    table.insert(self.layers[0].bubble_points, bubble)
    --datapoint.bubble_ref = bubble
    
    self.layers[1]:reclusterPointRecursively( self.layers[1]:clusterNewPointIntoLayer(bubble) )
    
  end,
  
  -------------------------------------------------------------------------------------------------
  
  removeValue = function(self, datapoint)
    helpers.ASSERT(datapoint.bubble_ref)
    
    local bubble = datapoint.bubble_ref
    local bubble_idx = table.find(self.layers[0].bubble_points, bubble)
    
    -- remove from layer 0
    self.layers[0].bubble_points[bubble_idx] = nil
    
    -- remove from tree
    
    local parent = bubble.parent
    helpers.ASSERT(parent)
    parent:RemoveChild(bubble)
    parent:UpdateTotalValue()
    self.layers[1]:reclusterPointRecursively(parent)
    
  end,
  --]]
  
  removeValue = function(self, datapoint)
    
    local bubble = self.raw_data_to_bubble0[datapoint]
    
    helpers.ASSERT(bubble)
    helpers.ASSERT(table.find(self.layers[0].bubble_points, bubble))
    
    LOG("<<<<<<<<<<< BubblePlot: removing value " .. tostring(bubble) .. " = " .. tostring(bubble:value()))
    
    self.layers[0]:removePoint(bubble)
    self.raw_data_to_bubble0[datapoint] = nil
  end,
  
  -------------------------------------------------------------------------------------------------
  
  addNewValue = function(self, datapoint)
    local bubble = BubblePoint(datapoint.position, self.color, datapoint[self.raw_data_field])
    self.raw_data_to_bubble0[datapoint] = bubble
    
    LOG(">>>>>>>>>>>> BubblePlot: adding new value " .. tostring(bubble) .. " = " .. tostring(bubble.self_value))
    
    -- insert into basic layer
    table.insert(self.layers[0].bubble_points, bubble)
    
    -- recursively update parents
    self.layers[1]:clusterChildIntoLayer(bubble, true)
  end,
  
  -------------------------------------------------------------------------------------------------
  
  updateValues = function(self, data)
    if table.empty(data) then
      WARN('got empty dataset for BubblePlot::updateValues(), not updating')
      return
    end
    
    -- mark datapoints that are still in 'data' and remove everything that isn't anymore
    local raw_data_still_exists = {}
    for id, d in self.raw_data do
      raw_data_still_exists[id] = false
    end
    
    LOG("############### BubblePlot: updating bubble plot with " .. tostring(table.getsize(data)) .. " datapoints")
    
    for id, d in data do
      raw_data_still_exists[id] = true
      local orig = self.raw_data[id]
      if orig == nil then
        LOG("no previous data for " .. tostring(id) .. " = " .. tostring(d) .. " -> adding new value = " .. tostring(d[self.raw_data_field]))
        self.raw_data[id] = d
        self:addNewValue(d)
      elseif d == nil or d[self.raw_data_field] == 0 then
        local val = nil
        if d then
          val = d[self.raw_data_field]
        end
        LOG("--------- datapoint " .. tostring(id) .. " seems to have gone: " .. tostring(d) .. " val[" .. tostring(self.raw_data_field) .. "] = " .. tostring(val))
        self:removeValue(orig)
        self.raw_data[id] = nil
      elseif d[self.raw_data_field] ~= orig[self.raw_data_field] then
        -- TODO: handle changes. Probably not necessary tough, as FAF doesn't send updates to existing points (just add/removes) for reclaim
        WARN("BubblePlot: Cannot handle changes yet!")
      end
    end
    
    for id, exists in raw_data_still_exists do
      if not exists then
        local orig = self.raw_data[id]
        LOG("--------- datapoint " .. tostring(id) .. " seems to have gone (no entry in data): " .. tostring(orig) .. " val[" .. tostring(self.raw_data_field) .. "] = " .. tostring(orig[self.raw_data_field]))
        self:removeValue(orig)
        self.raw_data[id] = nil
      else
        LOG("--------- datapoint " .. tostring(id) .. " still exists")
      end
    end
  end,
  
  -------------------------------------------------------------------------------------------------
  
  buildTree = function(self, data)
    if table.empty(data) then
      WARN('got empty dataset for BubblePlot::updateValues(), not updating')
      return
    end
    
    LOG("got new data! rebuilding tree...")
    self.raw_data = table.copy(data)
    
    helpers.ASSERT_UNIQUE_SET(self.raw_data)
    
    -- buil first layer directly from raw data
    
    -- clear first layer
    self.layers[0].bubble_points = {}
    
    -- insert points from data
    for id, d in self.raw_data do
      LOG("buildTree: adding id " .. tostring(id))
      local bubble = BubblePoint(d.position, self.color, d[self.raw_data_field])
      table.insert(self.layers[0].bubble_points, bubble)
      self.raw_data_to_bubble0[d] = bubble
    end
    
    LOG("layer 0: is unique?")
    helpers.ASSERT_UNIQUE_SET(self.layers[0].bubble_points)
    helpers.ASSERT_UNIQUE_SET(self.layers[0].bubble_points)
    
    -- cluster up from first layer
    for i, l in self.layers do
      if i == 0 then
        continue
      end
    
      LOG("clustering layer " .. tostring(i))
      l:clusterPoints(self.layers[i-1].bubble_points) -- cluster up from prev. layer
    end
  end,
}

---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
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
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
-- zoomed in: 30
-- zoomed out: 700

local LabelPool = {} -- Stores labels up too MaxLabels

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
    self:Update()
    
    self.lbl_border = Bitmap(self)
    self.lbl_border:SetSolidColor(BUBBLE_BORDER_COLOR)
    --LayoutHelpers.AtCenterIn(self.lbl_border, self.lbl_fill)
    self.lbl_border.Left  :Set(function() return self.lbl_fill.Left()-BUBBLE_BORDER_WIDTH end)
    self.lbl_border.Top   :Set(function() return self.lbl_fill.Top() -BUBBLE_BORDER_WIDTH end)
    self.lbl_border.Height:Set(function() return self.lbl_fill.Height()+BUBBLE_BORDER_WIDTH*2 end)
    self.lbl_border.Width :Set(function() return self.lbl_fill.Width() +BUBBLE_BORDER_WIDTH*2 end)
    self.lbl_border.Depth :Set(function() return self.lbl_fill.Depth()-1 end) -- border should be behind green box
    
    self.Top:   Set(function() return self.lbl_border.Top() end)
    self.Left:  Set(function() return self.lbl_border.Left() end)
    self.Width: Set(function() return self.lbl_border.Width() end)
    self.Height:Set(function() return self.lbl_border.Height() end)
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
    self.screen_pos = self.viewport:Project(self.bubble_point.world_pos)
    
    local camera = GetCamera("WorldCamera") -- TODO: store a reference to camera instead of 'getting' it on every update?
    -- TODO: viewport has function ZoomScale()
    
    self.size = math.max(BUBBLE_MIN_SIZE, math.sqrt(self.bubble_point:value()) * (zoom_size_mult / camera:GetZoom() + zoom_size_const))
    self.lbl_fill.Width :Set(self.size)
    self.lbl_fill.Height:Set(self.size)
    self.lbl_fill.Left:Set(self.screen_pos.x - self.size/2)
    self.lbl_fill.Top :Set(self.screen_pos.y - self.size/2)
	end,

  SetWorldPosition = function(self, position)
      self.world_pos = position or {}
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
    self.world_pos = world_position
    self.children = {}
    
    self.self_value  = self_value
    self.total_value = self_value
  end,
  
  value = function(self)
    return self.total_value
  end,
  
  IsInView = function(self)
    screen_pos = self.viewport:Project(self.world_pos)
    return self.viewport:HitTest(screen_pos.x, screen_pos.y)
  end,

}

---------------------------------------------------------------------------------------------------
-- a single zoom-level consisting of many (possibly aggregated) BubblePoints
-- can render those points as labels, taking visibility into account

BubbleLayer = Class() {
	__init = function(self, parent, viewport, color)
    
    self.parent = parent
    self.viewport = viewport
    self.color = color
    
    self.bubble_points = {}
  end,
  
  updateValues = function(self, data)
    local data_cnt = 0
    for id, d in data do
      data_cnt = data_cnt + 1
      if d.value then
        local bubble = self.bubble_points[id]
        
        if bubble == nil then
          bubble = BubblePoint(self.viewport, d.position, self.color, d.value)
          self.bubble_points[id] = bubble
        end
        
        bubble.total_value = d.value -- TODO
      else
        self.bubble_points[id] = nil
      end
    end
    
    LOG("updated with " .. tostring(data_cnt) .. " datapoints")
  end,
  
  renderLabels = function(self, MaxLabels)
    local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera
    
    local onScreenReclaimIndex = 1
    local onScreenReclaims = {}

    -- One might be tempted to use a binary insert; however, tests have shown that it takes about 140x more time
    for _, r in self.bubble_points do
        if r:IsInView() then
            onScreenReclaims[onScreenReclaimIndex] = r
            onScreenReclaimIndex = onScreenReclaimIndex + 1
        end
    end

    table.sort(onScreenReclaims, function(a, b) return a:value() > b:value() end)

    -- Create/Update as many reclaim labels as we need
    local labelIndex = 1
    for _, r in onScreenReclaims do
        if labelIndex > MaxLabels then
            break
        end
        
        local label = LabelPool[labelIndex]
        if label and IsDestroyed(label) then
            label = nil
        end
        
        if not label then
            --label = CreateReclaimLabel(view.ReclaimGroup, r)
            label = BubblePointLabel(view.ReclaimGroup, view, r, self.color)
            LabelPool[labelIndex] = label
        end

        label:SetData(r)
        labelIndex = labelIndex + 1
    end
    
    
    --LOG("rendered " .. tostring(labelIndex) .. " labels from " .. tostring(table.getn(onScreenReclaims))
    --  .. " points on screen from " .. tostring(table.getn(self.bubble_points)) .. " points in DB")

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

-- OLD CODE:

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
--[[
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
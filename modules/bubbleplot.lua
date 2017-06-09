local LayoutHelpers = import('/lua/maui/layouthelpers.lua')
local Group = import('/lua/maui/group.lua').Group
local Bitmap = import('/lua/maui/bitmap.lua').Bitmap


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




local ValueObject = Class() {
	__init = function(self, id, world_position, value)
		self.id = id
		self.world_position = world_position
		self.value = value
	end,

	DistanceTo = function(self, other)
		return VDist3(self.world_position, other.world_position)
	end,
}


local ValueObjectGroup = Class() {
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


local WorldLabel = Class(Group) {
	__init = function(self, parent, position)
        Group.__init(self, parent)
        self.parent = parent
        self.proj = nil
        self:SetPosition(position)
		self.children = {}
		self.self_value = 0
		self.total_value = 0
		
        self.Top:Set(0)
        self.Left:Set(0)
        self.Width:Set(25)
        self.Height:Set(25)
        self:SetNeedsFrameUpdate(true)
    end,

    Update = function(self)
        local view = self.parent.view
        local proj = view:Project(self.position)
        LayoutHelpers.AtCenterIn(self, self.parent, proj.x - self.Width() / 2, proj.y - self.Height() / 2 + 1)
        self.proj = {x=proj.x, y=proj.y }
	end,

    SetPosition = function(self, position)
        self.position = position or {}
    end,

    OnFrame = function(self, delta)
        self:Update()
    end
}
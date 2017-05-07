
-- everything closer than that will be merged into one blob
local max_screen_dist = 10 -- in pixels


local zoom_size_mult = 150
local zoom_size_const = 1.2
-- size = sqrt(mass)*(zoom_size_modifier/zoom+zoom_size_const)
-- zoomed in: 30
-- zoomed out: 700

-- Creates an empty reclaim label
function CreateReclaimLabel(view)
    local label = WorldLabel(view, Vector(0, 0, 0))

	--import('/mods/EcoPredict/modules/helpers.lua').LOG_OBJ(view.view)
	--import('/mods/EcoPredict/modules/helpers.lua').LOG_OBJ(view.view, true)

    label.mass = Bitmap(label)
    label.mass:SetSolidColor('c0c6fb08')
    LayoutHelpers.AtCenterIn(label.mass, label)
    label.mass.Height:Set(14)
    label.mass.Width:Set(14)
	label.Height:Set(1)
	label.Width:Set(1)

    
    label:DisableHitTest(true)
    label.OnHide = function(self, hidden)
        self:SetNeedsFrameUpdate(not hidden)
    end

    label.Update = function(self)
        local view = self.parent.view
        local proj = view:Project(self.position)

		local camera = GetCamera("WorldCamera")

		if self.oldMass then
			local m = math.sqrt(self.oldMass) * (zoom_size_mult / camera:GetZoom() + zoom_size_const)
			if m < 5 then
				m = 5
			end
			self.mass.Width:Set(m)
			self.mass.Height:Set(m)
		end

        LayoutHelpers.AtLeftTopIn(self, self.parent, proj.x - self.Width() / 2, proj.y - self.Height() / 2 + 1)
        self.proj = {x=proj.x, y=proj.y }

    end

    label.DisplayReclaim = function(self, r)
        if self:IsHidden() then
            self:Show()
        end
        self:SetPosition(getWeightedPosition(r))
        if r.mass ~= self.oldMass then
			local m = math.sqrt(r.mass)
            self.mass.Width:Set(m)
			self.mass.Height:Set(m)
            self.oldMass = r.mass
        end
    end

    label:Update()

    return label
end




function OnScreen(view, pos)
    local proj = view:Project(Vector(pos[1], pos[2], pos[3]))
    return not (proj.x < 0 or proj.y < 0 or proj.x > view.Width() or proj.y > view:Height())
end

function OnScreenDistance(view, posA, posB)
	local projA = view:Project(Vector(posA[1], posA[2], posA[3]))
	local projB = view:Project(Vector(posB[1], posB[2], posB[3]))
	return VDist2(projA.x, projA.y, projB.x, projB.y)
end



function createCluster(reclaim)
	cluster = table.deepcopy(reclaim)
	cluster.weighted_position = Vector(cluster.position[1] * cluster.mass, cluster.position[2] * cluster.mass, cluster.position[3] * cluster.mass)
	return cluster
end

function getWeightedPosition(cluster)
	local pos = cluster.weighted_position
	return Vector(pos[1] / cluster.mass, pos[2] / cluster.mass, pos[3] / cluster.mass)
end


function closeEnoughToMerge(cluster, reclaim, distance)
	-- TODO: use actual screen size, i.e. incorporate zoom
	return distance < math.sqrt(cluster.mass) + math.sqrt(reclaim.mass) + max_screen_dist
end


function UpdateLabels()
    local view = import('/lua/ui/game/worldview.lua').viewLeft -- Left screen's camera

    local clusterIndex = 1
    local clusteredReclaim = {}

    -- One might be tempted to use a binary insert; however, tests have shown that it takes about 140x more time
    for _, r in Reclaim do

		r.onScreen = OnScreen(view, r.position)
		if r.onScreen then

			if table.empty(clusteredReclaim) then
				clusteredReclaim[clusterIndex] = createCluster(r)
			else
				-- find closest cluster
				local idx = 0
				local closest_idx  = nil
				local closest_dist = 9999999
				for _, cluster in clusteredReclaim do
					idx = idx + 1
					local dist = OnScreenDistance(view, getWeightedPosition(cluster), r.position)
					if dist < closest_dist then
						closest_dist = dist
						closest_idx = idx
					end
				end

				-- merge with cluster if close enough
				if closest_idx and closeEnoughToMerge(clusteredReclaim[closest_idx], r, closest_dist) then
					
					cluster = clusteredReclaim[closest_idx]

					-- update mass
					cluster.mass = cluster.mass + r.mass

					-- update position
					local pos = cluster.weighted_position
					pos[1] = pos[1] + r.position[1] * r.mass
					pos[2] = pos[2] + r.position[2] * r.mass
					pos[3] = pos[3] + r.position[3] * r.mass
				else
					-- create new cluster
					clusterIndex = clusterIndex + 1
					clusteredReclaim[clusterIndex] = createCluster(r)
				end
			end
		end
    end

    table.sort(clusteredReclaim, function(a, b) return a.mass > b.mass end)

    -- Create/Update as many reclaim labels as we need
    local labelIndex = 1
    for _, r in clusteredReclaim do
        if labelIndex > MaxLabels then
            break
        end

        if not LabelPool[labelIndex] then
            LabelPool[labelIndex] = CreateReclaimLabel(view.ReclaimGroup, r)
        end

        local label = LabelPool[labelIndex]
        label:DisplayReclaim(r)
        labelIndex = labelIndex + 1
    end

    -- Hide labels we didn't use
    for index = labelIndex, MaxLabels do
        local label = LabelPool[index]
        if label and not label:IsHidden() then
            label:Hide()
        end
    end
end
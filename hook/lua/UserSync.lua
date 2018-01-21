local oldOnSync = OnSync

OnSync = function()
    oldOnSync()
    --import('/mods/EcoViz/modules/resource_plot.lua').on_user_sync(Sync)
end

local oldOnSync = OnSync

OnSync = function()
    oldOnSync()
    import('/mods/EcoPredict/modules/resource_plot.lua').on_user_sync(Sync)
end

if global.playerdata then
    for _, pdata in pairs(global.playerdata) do
        if pdata.hovering_entities then
            for _, ent in pairs(pdata.hovering_entities) do
                ent.destroy()
            end
        end
    end

    global.playerdata = {}
end

local addonName = ...

-- Let Escape close the standalone macro editor like a native Blizzard panel.
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, addonName .. "Frame")
end

--// Venus Lib - Photon API Remake
--// Remade using Photon API render system
--// Features:
--// - Full UI library with tabs, sections, buttons, toggles, sliders, dropdowns, color pickers, keybinds, boxes, labels, separators
--// - Config system with save/load/delete (game-specific and universal)
--// - Theme system with custom themes and auto-loading
--// - Background image support via SetBackgroundImage()
--// - All rendering done through Photon's render API
--// - File-based config and theme storage

local library = {}
library.flags = {}
library.connections = {}
library.open = true
library.currenttheme = "Default"
library.folder = "venus_lib"
library.extension = "json"
library.theme = {}
library.configignores = {}
library.backgroundtexture = nil
library.notifications = {} -- Notification system

-- Theme definitions
local themes = {
    Default = {
        ["Accent"] = color(0.2, 0.6, 1, 1),
        ["Window Background"] = color(0.1, 0.1, 0.1, 1),
        ["Window Border"] = color(0.2, 0.2, 0.2, 1),
        ["Tab Background"] = color(0.12, 0.12, 0.12, 1),
        ["Tab Border"] = color(0.25, 0.25, 0.25, 1),
        ["Tab Toggle Background"] = color(0.15, 0.15, 0.15, 1),
        ["Section Background"] = color(0.08, 0.08, 0.08, 1),
        ["Section Border"] = color(0.2, 0.2, 0.2, 1),
        ["Text"] = color(1, 1, 1, 1),
        ["Disabled Text"] = color(0.5, 0.5, 0.5, 1),
        ["Object Background"] = color(0.15, 0.15, 0.15, 1),
        ["Object Border"] = color(0.25, 0.25, 0.25, 1),
        ["Dropdown Option Background"] = color(0.2, 0.2, 0.2, 1),
    },
    Midnight = {
        ["Accent"] = color(0.4, 0.2, 0.8, 1),
        ["Window Background"] = color(0.05, 0.05, 0.1, 1),
        ["Window Border"] = color(0.15, 0.15, 0.25, 1),
        ["Tab Background"] = color(0.08, 0.08, 0.15, 1),
        ["Tab Border"] = color(0.2, 0.2, 0.3, 1),
        ["Tab Toggle Background"] = color(0.1, 0.1, 0.18, 1),
        ["Section Background"] = color(0.06, 0.06, 0.12, 1),
        ["Section Border"] = color(0.15, 0.15, 0.25, 1),
        ["Text"] = color(1, 1, 1, 1),
        ["Disabled Text"] = color(0.6, 0.6, 0.7, 1),
        ["Object Background"] = color(0.1, 0.1, 0.18, 1),
        ["Object Border"] = color(0.2, 0.2, 0.3, 1),
        ["Dropdown Option Background"] = color(0.15, 0.15, 0.25, 1),
    }
}

-- Utility functions
local utility = {}

function utility.round(num, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(num * mult + 0.5) / mult
end

function utility.clamp(val, min, max)
    return math.min(math.max(val, min), max)
end

function utility.lerp(a, b, t)
    return a + (b - a) * t
end

function utility.color_to_table(c)
    return {r = c.r, g = c.g, b = c.b, a = c.a}
end

function utility.table_to_color(t)
    return color(t.r or 1, t.g or 1, t.b or 1, t.a or 1)
end

function utility.hex_to_color(hex)
    hex = hex:gsub("#", "")
    local r = tonumber("0x" .. hex:sub(1, 2)) / 255
    local g = tonumber("0x" .. hex:sub(3, 4)) / 255
    local b = tonumber("0x" .. hex:sub(5, 6)) / 255
    return color(r, g, b, 1)
end

function utility.color_to_hex(c)
    local r = math.floor(c.r * 255)
    local g = math.floor(c.g * 255)
    local b = math.floor(c.b * 255)
    return string.format("#%02X%02X%02X", r, g, b)
end

function utility.is_point_in_rect(pos, rect_pos, rect_size)
    return pos.x >= rect_pos.x and pos.x <= rect_pos.x + rect_size.x and
           pos.y >= rect_pos.y and pos.y <= rect_pos.y + rect_size.y
end

function utility.get_text_size(text, size)
    -- Approximate text size calculation
    return vector2(text:len() * size * 0.6, size * 1.2)
end

-- UI Element base class
local UIElement = {}
UIElement.__index = UIElement

function UIElement.new()
    local self = setmetatable({}, UIElement)
    self.visible = true
    self.position = vector2(0, 0)
    self.size = vector2(100, 100)
    self.zindex = 1
    self.children = {}
    return self
end

function UIElement:SetPosition(pos)
    self.position = pos
end

function UIElement:SetSize(siz)
    self.size = siz
end

function UIElement:SetVisible(vis)
    self.visible = vis
end

function UIElement:AddChild(child)
    table.insert(self.children, child)
end

-- Window class
local Window = {}
Window.__index = Window

function Window.new(name, sizeX, sizeY, theme_name)
    local self = setmetatable({}, Window)
    self.name = name
    self.sizeX = sizeX or 600
    self.sizeY = sizeY or 650
    self.position = vector2(100, 100)
    self.dragging = false
    self.drag_offset = vector2(0, 0)
    self.tabs = {}
    self.current_tab = nil
    self.tab_buttons = {}
    self.tab_y_offset = 30
    self.sections = {}
    self.open = true
    
    -- Set theme with error handling
    local success, err = pcall(function()
        library:SetTheme(theme_name or "Default")
    end)
    
    if not success then
        -- If theme setting fails, use hardcoded Default theme
        library.currenttheme = "Default"
        library.theme = {}
        for k, v in pairs(themes["Default"]) do
            library.theme[k] = v
        end
        log.add("Theme load failed, using Default: " .. tostring(err), color(1, 1, 0, 1))
    end
    
    -- Ensure theme is initialized
    if not library.theme or not next(library.theme) then
        library.currenttheme = "Default"
        library.theme = {}
        for k, v in pairs(themes["Default"]) do
            library.theme[k] = v
        end
    end
    
    return self
end

function Window:Tab(name)
    local tab = {
        name = name,
        sections = {},
        visible = false
    }
    
    table.insert(self.tabs, tab)
    
    if not self.current_tab then
        self.current_tab = tab
        tab.visible = true
    end
    
    local tab_types = {}
    
    function tab_types:Section(options)
        local section = {
            name = options.Name or "Section",
            side = options.Side or "Left",
            elements = {},
            y_offset = 0,
            padding = 4
        }
        
        table.insert(tab.sections, section)
        
        local section_types = {}
        
        function section_types:Label(text)
            local label = {
                type = "label",
                text = text,
                element = UIElement.new()
            }
            
            table.insert(section.elements, label)
            
            local label_types = {}
            function label_types:Set(new_text)
                label.text = new_text
            end
            
            return label_types
        end
        
        function section_types:Button(options)
            local button = {
                type = "button",
                name = options.Name or "Button",
                callback = options.Callback or function() end,
                element = UIElement.new(),
                hovered = false,
                pressed = false
            }
            
            table.insert(section.elements, button)
            
            local button_types = {}
            function button_types:SetName(new_name)
                button.name = new_name
            end
            
            return button_types
        end
        
        function section_types:Toggle(options)
            local toggle = {
                type = "toggle",
                name = options.Name or "Toggle",
                flag = options.Flag or "",
                value = options.Default or false,
                callback = options.Callback or function() end,
                element = UIElement.new(),
                hovered = false,
                colorpickers = {},
                keybinds = {},
                sliders = {},
                dropdowns = {}
            }
            
            if toggle.flag ~= "" then
                library.flags[toggle.flag] = toggle.value
            end
            
            table.insert(section.elements, toggle)
            
            local toggle_types = {}
            
            function toggle_types:Toggle(bool)
                if bool ~= nil then
                    toggle.value = bool
                    if toggle.flag ~= "" then
                        library.flags[toggle.flag] = toggle.value
                    end
                    toggle.callback(toggle.value)
                else
                    toggle.value = not toggle.value
                    if toggle.flag ~= "" then
                        library.flags[toggle.flag] = toggle.value
                    end
                    toggle.callback(toggle.value)
                end
            end
            
            function toggle_types:ColorPicker(options)
                local picker = {
                    type = "colorpicker",
                    default = options.Default or color(1, 1, 1, 1),
                    defaultalpha = options.DefaultAlpha or 1,
                    flag = options.Flag or "",
                    value = options.Default or color(1, 1, 1, 1),
                    callback = options.Callback or function() end,
                    element = UIElement.new(),
                    open = false
                }
                
                if picker.flag ~= "" then
                    library.flags[picker.flag] = picker.value
                end
                
                table.insert(toggle.colorpickers, picker)
                
                local picker_types = {}
                function picker_types:Set(color)
                    picker.value = color
                    if picker.flag ~= "" then
                        library.flags[picker.flag] = picker.value
                    end
                    picker.callback(picker.value)
                end
                
                return picker_types
            end
            
            function toggle_types:Keybind(options)
                local keybind = {
                    type = "keybind",
                    default = options.Default or nil,
                    blacklist = options.Blacklist or {},
                    flag = options.Flag or "",
                    mode = options.Mode or "Toggle",
                    value = options.Default or nil,
                    callback = options.Callback or function() end,
                    element = UIElement.new(),
                    waiting = false
                }
                
                if keybind.flag ~= "" then
                    library.flags[keybind.flag] = keybind.value
                end
                
                table.insert(toggle.keybinds, keybind)
                
                local keybind_types = {}
                function keybind_types:Set(key)
                    keybind.value = key
                    if keybind.flag ~= "" then
                        library.flags[keybind.flag] = keybind.value
                    end
                    keybind.callback(keybind.value, true)
                end
                
                return keybind_types
            end
            
            function toggle_types:Slider(options)
                local slider = {
                    type = "slider",
                    text = options.Text or "[value]",
                    min = options.Min or 0,
                    max = options.Max or 100,
                    float = options.Float or 1,
                    flag = options.Flag or "",
                    value = options.Default or options.Min or 0,
                    callback = options.Callback or function() end,
                    element = UIElement.new(),
                    dragging = false
                }
                
                if slider.flag ~= "" then
                    library.flags[slider.flag] = slider.value
                end
                
                table.insert(toggle.sliders, slider)
                
                local slider_types = {}
                function slider_types:Set(val)
                    slider.value = utility.clamp(val, slider.min, slider.max)
                    if slider.flag ~= "" then
                        library.flags[slider.flag] = slider.value
                    end
                    slider.callback(slider.value)
                end
                
                return slider_types
            end
            
            function toggle_types:Dropdown(options)
                local dropdown = {
                    type = "dropdown",
                    content = options.Content or {},
                    max = options.Max or nil,
                    scrollable = options.Scrollable or false,
                    scrollingmax = options.ScrollingMax or 5,
                    flag = options.Flag or "",
                    value = options.Default or (options.Max and {} or nil),
                    callback = options.Callback or function() end,
                    element = UIElement.new(),
                    open = false,
                    scroll = 0
                }
                
                if dropdown.flag ~= "" then
                    library.flags[dropdown.flag] = dropdown.value
                end
                
                table.insert(toggle.dropdowns, dropdown)
                
                local dropdown_types = {}
                function dropdown_types:Set(val)
                    if dropdown.max then
                        if type(val) == "table" then
                            dropdown.value = val
                        else
                            dropdown.value = {}
                        end
                    else
                        dropdown.value = val
                    end
                    if dropdown.flag ~= "" then
                        library.flags[dropdown.flag] = dropdown.value
                    end
                    dropdown.callback(dropdown.value)
                end
                
                function dropdown_types:Refresh(content)
                    dropdown.content = content
                end
                
                function dropdown_types:Add(item)
                    table.insert(dropdown.content, item)
                end
                
                function dropdown_types:Remove(item)
                    for i, v in ipairs(dropdown.content) do
                        if v == item then
                            table.remove(dropdown.content, i)
                            break
                        end
                    end
                end
                
                return dropdown_types
            end
            
            return toggle_types
        end
        
        function section_types:Slider(options)
            local slider = {
                type = "slider",
                name = options.Name or "Slider",
                text = options.Text or "[value]",
                min = options.Min or 0,
                max = options.Max or 100,
                float = options.Float or 1,
                flag = options.Flag or "",
                value = options.Default or options.Min or 0,
                callback = options.Callback or function() end,
                element = UIElement.new(),
                dragging = false
            }
            
            if slider.flag ~= "" then
                library.flags[slider.flag] = slider.value
            end
            
            table.insert(section.elements, slider)
            
            local slider_types = {}
            function slider_types:Set(val)
                slider.value = utility.clamp(val, slider.min, slider.max)
                if slider.flag ~= "" then
                    library.flags[slider.flag] = slider.value
                end
                slider.callback(slider.value)
            end
            
            return slider_types
        end
        
        function section_types:Dropdown(options)
            local dropdown = {
                type = "dropdown",
                name = options.Name or "Dropdown",
                content = options.Content or {},
                max = options.Max or nil,
                scrollable = options.Scrollable or false,
                scrollingmax = options.ScrollingMax or 5,
                flag = options.Flag or "",
                value = options.Default or (options.Max and {} or nil),
                callback = options.Callback or function() end,
                element = UIElement.new(),
                open = false,
                scroll = 0
            }
            
            if dropdown.flag ~= "" then
                library.flags[dropdown.flag] = dropdown.value
            end
            
            table.insert(section.elements, dropdown)
            
            local dropdown_types = {}
            function dropdown_types:Set(val)
                if dropdown.max then
                    if type(val) == "table" then
                        dropdown.value = val
                    else
                        dropdown.value = {}
                    end
                else
                    dropdown.value = val
                end
                if dropdown.flag ~= "" then
                    library.flags[dropdown.flag] = dropdown.value
                end
                dropdown.callback(dropdown.value)
            end
            
            function dropdown_types:Refresh(content)
                dropdown.content = content
            end
            
            function dropdown_types:Add(item)
                table.insert(dropdown.content, item)
            end
            
            function dropdown_types:Remove(item)
                for i, v in ipairs(dropdown.content) do
                    if v == item then
                        table.remove(dropdown.content, i)
                        break
                    end
                end
            end
            
            return dropdown_types
        end
        
        function section_types:ColorPicker(options)
            local picker = {
                type = "colorpicker",
                name = options.Name or "Color Picker",
                default = options.Default or color(1, 1, 1, 1),
                defaultalpha = options.DefaultAlpha or 1,
                flag = options.Flag or "",
                value = options.Default or color(1, 1, 1, 1),
                callback = options.Callback or function() end,
                element = UIElement.new(),
                open = false,
                colorpickers = {}
            }
            
            if picker.flag ~= "" then
                library.flags[picker.flag] = picker.value
            end
            
            table.insert(section.elements, picker)
            
            local picker_types = {}
            function picker_types:Set(color)
                picker.value = color
                if picker.flag ~= "" then
                    library.flags[picker.flag] = picker.value
                end
                picker.callback(picker.value)
            end
            
            function picker_types:ColorPicker(options)
                local nested_picker = {
                    type = "colorpicker",
                    default = options.Default or color(1, 1, 1, 1),
                    defaultalpha = options.DefaultAlpha or 1,
                    flag = options.Flag or "",
                    value = options.Default or color(1, 1, 1, 1),
                    callback = options.Callback or function() end,
                    element = UIElement.new(),
                    open = false
                }
                
                if nested_picker.flag ~= "" then
                    library.flags[nested_picker.flag] = nested_picker.value
                end
                
                table.insert(picker.colorpickers, nested_picker)
                
                local nested_types = {}
                function nested_types:Set(color)
                    nested_picker.value = color
                    if nested_picker.flag ~= "" then
                        library.flags[nested_picker.flag] = nested_picker.value
                    end
                    nested_picker.callback(nested_picker.value)
                end
                
                return nested_types
            end
            
            return picker_types
        end
        
        function section_types:Keybind(options)
            local keybind = {
                type = "keybind",
                name = options.Name or "Keybind",
                default = options.Default or nil,
                blacklist = options.Blacklist or {},
                flag = options.Flag or "",
                value = options.Default or nil,
                callback = options.Callback or function() end,
                element = UIElement.new(),
                waiting = false
            }
            
            if keybind.flag ~= "" then
                library.flags[keybind.flag] = keybind.value
            end
            
            table.insert(section.elements, keybind)
            
            local keybind_types = {}
            function keybind_types:Set(key)
                keybind.value = key
                if keybind.flag ~= "" then
                    library.flags[keybind.flag] = keybind.value
                end
                keybind.callback(keybind.value, true)
            end
            
            return keybind_types
        end
        
        function section_types:Box(options)
            local box = {
                type = "box",
                name = options.Name or "Box",
                placeholder = options.Placeholder or "",
                flag = options.Flag or "",
                value = options.Default or "",
                callback = options.Callback or function() end,
                element = UIElement.new(),
                focused = false,
                text = options.Default or ""
            }
            
            if box.flag ~= "" then
                library.flags[box.flag] = box.value
            end
            
            table.insert(section.elements, box)
            
            local box_types = {}
            function box_types:Set(text)
                box.text = text
                box.value = text
                if box.flag ~= "" then
                    library.flags[box.flag] = box.value
                end
                box.callback(box.value)
            end
            
            return box_types
        end
        
        function section_types:Separator(text)
            local separator = {
                type = "separator",
                text = text or "",
                element = UIElement.new()
            }
            
            table.insert(section.elements, separator)
            
            local separator_types = {}
            function separator_types:Set(new_text)
                separator.text = new_text
            end
            
            return separator_types
        end
        
        return section_types
    end
    
    return tab_types
end

function Window:Close()
    self.open = not self.open
    library.open = self.open
end

function Window:Unload()
    self.open = false
    library.open = false
end

-- Library functions
function library:Watermark(str)
    local watermark = {
        text = str,
        visible = true,
        position = vector2(16, 16)
    }
    
    local watermark_types = {}
    
    function watermark_types:Set(new_text)
        watermark.text = new_text
    end
    
    function watermark_types:Hide()
        watermark.visible = not watermark.visible
    end
    
    library.watermark = watermark
    
    return watermark_types
end

function library:Load(options)
    local name = options.Name or "UI"
    local sizeX = options.SizeX or 600
    local sizeY = options.SizeY or 650
    local theme = options.Theme or "Default"
    local extension = options.Extension or "json"
    local folder = options.Folder or "venus_lib"
    local toggle_key = options.ToggleKey or 0x2D -- INSERT key by default (0x2D)
    
    library.folder = folder
    library.extension = extension
    library.open = true -- Ensure GUI is open by default
    
    local window = Window.new(name, sizeX, sizeY, theme)
    library.window = window
    window.open = true -- Ensure window is open
    
    -- Auto-load themes (non-critical, won't fail if files don't exist)
    library:LoadThemes()
    
    -- Auto-load last config if exists (non-critical, won't fail if files don't exist)
    local last_config_file = library.folder .. "/last_config.txt"
    if file.exists(last_config_file) then
        local success, last_config = pcall(function()
            return file.read(last_config_file)
        end)
        
        if success and last_config and last_config ~= "" then
            local config_file = library.folder .. "/" .. tostring(get_placeid()) .. "/" .. last_config .. "." .. library.extension
            if file.exists(config_file) then
                local config_success, config_err = pcall(function()
                    library:LoadConfig(last_config)
                end)
                if not config_success then
                    -- Config load failed, but don't stop initialization
                    log.add("Failed to load last config: " .. tostring(config_err), color(1, 1, 0, 1))
                end
            end
        end
    end
    
    -- Add toggle keybind
    library.toggle_key = toggle_key
    hook.addkey(toggle_key, "venus_lib_toggle", function(toggle)
        if toggle then
            library:Close()
        end
    end)
    
    -- Center window on screen
    local screen_size = get_screen_size()
    window.position = vector2(screen_size.x / 2 - sizeX / 2, screen_size.y / 2 - sizeY / 2)
    
    -- Initialize render hook if not already added
    if not library.render_initialized then
        library.render_initialized = true
        -- Render hook is already added at the end of the file
    end
    
    log.add("Venus Lib loaded! Press INSERT to toggle GUI", color(0, 1, 0, 1))
    library:Notify("Venus Lib loaded! Press INSERT to toggle", 3, "success")
    
    return window
end

function library:ConfigIgnore(flag)
    table.insert(library.configignores, flag)
end

function library:SaveConfig(name, universal)
    if type(name) ~= "string" or name:len() < 2 then
        return false, "improper name"
    end
    
    name = name:gsub("%s", "_")
    
    local configtbl = {}
    local placeid = universal and "universal" or tostring(get_placeid())
    
    for flag, value in pairs(library.flags) do
        local should_ignore = false
        for _, ignored in ipairs(library.configignores) do
            if flag == ignored then
                should_ignore = true
                break
            end
        end
        
        if not should_ignore then
            if type(value) == "table" and value.r and value.g and value.b then
                -- Color
                configtbl[flag] = {
                    type = "color",
                    r = value.r,
                    g = value.g,
                    b = value.b,
                    a = value.a or 1
                }
            else
                configtbl[flag] = value
            end
        end
    end
    
    local config_json = table_to_JSON(configtbl)
    local filepath = library.folder .. "/" .. placeid .. "/" .. name .. "." .. library.extension
    
    file.write(filepath, config_json)
    
    -- Save as last config
    file.write(library.folder .. "/last_config.txt", name)
    
    -- Update config index
    local index_file = library.folder .. "/" .. placeid .. "/_index.txt"
    local index_tbl = {}
    if file.exists(index_file) then
        local index_data = file.read(index_file)
        index_tbl = JSON_to_table(index_data) or {}
    end
    local found = false
    for _, v in ipairs(index_tbl) do
        if v == name then
            found = true
            break
        end
    end
    if not found then
        table.insert(index_tbl, name)
    end
    file.write(index_file, table_to_JSON(index_tbl))
    
    return true
end

function library:LoadConfig(name, universal)
    if type(name) ~= "string" or name:len() < 1 then
        return false
    end
    
    local placeid = universal and "universal" or tostring(get_placeid())
    local filepath = library.folder .. "/" .. placeid .. "/" .. name .. "." .. library.extension
    
    if file.exists(filepath) then
        local success, config_data = pcall(function()
            return file.read(filepath)
        end)
        
        if success and config_data then
            local configtbl = JSON_to_table(config_data)
            
            if configtbl then
                for flag, value in pairs(configtbl) do
                    if library.flags[flag] ~= nil then
                        if type(value) == "table" and value.type == "color" then
                            library.flags[flag] = color(value.r, value.g, value.b, value.a or 1)
                        else
                            library.flags[flag] = value
                        end
                    end
                end
                
                -- Save as last config
                pcall(function()
                    file.write(library.folder .. "/last_config.txt", name)
                end)
                
                return true
            end
        end
    end
    
    return false
end

function library:DeleteConfig(name, universal)
    local placeid = universal and "universal" or tostring(get_placeid())
    local filepath = library.folder .. "/" .. placeid .. "/" .. name .. "." .. library.extension
    
    if file.exists(filepath) then
        file.overwrite(filepath, "")
        
        -- Update config index
        local index_file = library.folder .. "/" .. placeid .. "/_index.txt"
        if file.exists(index_file) then
            local index_data = file.read(index_file)
            local index_tbl = JSON_to_table(index_data) or {}
            for i, v in ipairs(index_tbl) do
                if v == name then
                    table.remove(index_tbl, i)
                    break
                end
            end
            file.write(index_file, table_to_JSON(index_tbl))
        end
        
        return true
    end
    
    return false
end

function library:GetConfigs(universal)
    local configs = {}
    local placeid = universal and "universal" or tostring(get_placeid())
    
    -- Use config index file
    local index_file = library.folder .. "/" .. placeid .. "/_index.txt"
    
    if file.exists(index_file) then
        local index_data = file.read(index_file)
        local index_tbl = JSON_to_table(index_data)
        if index_tbl then
            for _, name in ipairs(index_tbl) do
                -- Verify config still exists
                local filepath = library.folder .. "/" .. placeid .. "/" .. name .. "." .. library.extension
                if file.exists(filepath) then
                    table.insert(configs, name)
                end
            end
        end
    end
    
    return configs
end

function library:Close()
    library.open = not library.open
    if library.window then
        library.window.open = library.open
    end
    if library.open then
        log.add("GUI opened (Press INSERT to toggle)", color(0, 1, 0, 1))
        library:Notify("GUI opened", 2, "success")
    else
        log.add("GUI closed (Press INSERT to toggle)", color(1, 1, 0, 1))
        library:Notify("GUI closed", 2, "info")
    end
end

function library:ChangeThemeOption(option, color)
    library.theme[option] = color
end

function library:OverrideTheme(tbl)
    for option, color in pairs(tbl) do
        library.theme[option] = color
    end
end

function library:SetTheme(theme)
    library.currenttheme = theme
    
    if themes[theme] then
        library.theme = {}
        for k, v in pairs(themes[theme]) do
            library.theme[k] = v
        end
    else
        -- Load from file
        local filepath = library.folder .. "/themes/" .. theme .. ".json"
        if file.exists(filepath) then
            local success, theme_data = pcall(function()
                return file.read(filepath)
            end)
            
            if success and theme_data then
                local themetbl = JSON_to_table(theme_data)
                
                if themetbl then
                    library.theme = {}
                    for option, hex in pairs(themetbl) do
                        library.theme[option] = utility.hex_to_color(hex)
                    end
                else
                    -- Fallback to Default theme if parsing fails
                    library:SetTheme("Default")
                end
            else
                -- Fallback to Default theme if file read fails
                library:SetTheme("Default")
            end
        else
            -- Fallback to Default theme if file doesn't exist
            if theme ~= "Default" then
                library:SetTheme("Default")
            else
                -- Even Default should have a theme, use hardcoded one
                library.theme = {}
                for k, v in pairs(themes["Default"]) do
                    library.theme[k] = v
                end
            end
        end
    end
end

function library:GetThemes()
    local theme_list = {"Default", "Midnight"}
    
    -- Load custom themes from file
    local themes_folder = library.folder .. "/themes"
    local index_file = themes_folder .. "/_index.txt"
    
    if file.exists(index_file) then
        local index_data = file.read(index_file)
        local index_tbl = JSON_to_table(index_data)
        if index_tbl then
            for _, name in ipairs(index_tbl) do
                table.insert(theme_list, name)
            end
        end
    end
    
    return theme_list
end

function library:LoadThemes()
    -- Auto-load themes from themes folder
    local themes_folder = library.folder .. "/themes"
    local index_file = themes_folder .. "/_index.txt"
    
    if file.exists(index_file) then
        local index_data = file.read(index_file)
        local index_tbl = JSON_to_table(index_data)
        if index_tbl then
            for _, theme_name in ipairs(index_tbl) do
                local theme_file = themes_folder .. "/" .. theme_name .. ".json"
                if file.exists(theme_file) then
                    local theme_data = file.read(theme_file)
                    local themetbl = JSON_to_table(theme_data)
                    if themetbl then
                        themes[theme_name] = {}
                        for option, hex in pairs(themetbl) do
                            themes[theme_name][option] = utility.hex_to_color(hex)
                        end
                    end
                end
            end
        end
    end
end

function library:SaveCustomTheme(name)
    if type(name) ~= "string" or name:len() < 2 then
        return false
    end
    
    if themes[name] then
        name = name .. "1"
    end
    
    local themetbl = {}
    for option, color in pairs(library.theme) do
        themetbl[option] = utility.color_to_hex(color)
    end
    
    local theme_json = table_to_JSON(themetbl)
    local themes_folder = library.folder .. "/themes"
    local filepath = themes_folder .. "/" .. name .. ".json"
    
    file.write(filepath, theme_json)
    
    -- Update index
    local index_file = themes_folder .. "/_index.txt"
    local index_tbl = {}
    if file.exists(index_file) then
        local index_data = file.read(index_file)
        index_tbl = JSON_to_table(index_data) or {}
    end
    table.insert(index_tbl, name)
    file.write(index_file, table_to_JSON(index_tbl))
    
    return true
end

function library:SetBackgroundImage(filename)
    if file.exists(filename) then
        library.backgroundtexture = render.load_texture(filename)
        return true
    end
    return false
end

function library:Notify(text, duration, notif_type)
    duration = duration or 3
    notif_type = notif_type or "info" -- "info", "success", "warning", "error"
    
    table.insert(library.notifications, {
        text = text,
        duration = duration,
        start_time = get_unixtime(),
        type = notif_type,
        alpha = 0,
        target_alpha = 1
    })
end

function library:Unload()
    library.open = false
    if library.window then
        library.window.open = false
    end
    hook.remove("render", "venus_lib_render")
end

-- Render system
local mouse_pos = vector2(0, 0)
local mouse_down = false
local mouse_clicked = false
local keys_pressed = {}

hook.add("render", "venus_lib_render", function()
    -- Always update mouse position for input handling
    mouse_pos = input.get_mouse_position()
    
    -- Draw notifications (always visible, even when GUI is closed)
    local notification_y = 40
    for i = #library.notifications, 1, -1 do
        local notif = library.notifications[i]
        local time_passed = get_unixtime() - notif.start_time
        
        if time_passed > notif.duration then
            notif.target_alpha = 0
        end
        
        -- Smooth alpha transition
        notif.alpha = notif.alpha + (notif.target_alpha - notif.alpha) * 0.1
        
        if notif.target_alpha == 0 and notif.alpha < 0.01 then
            table.remove(library.notifications, i)
        else
            local notif_text_size = utility.get_text_size(notif.text, 12)
            local notif_size = vector2(notif_text_size.x + 20, 24)
            local notif_pos = vector2(10, notification_y)
            
            -- Notification background
            local bg_color = library.theme["Window Background"] or color(0.1, 0.1, 0.1, 1)
            local border_color = library.theme["Accent"] or color(0.2, 0.6, 1, 1)
            
            -- Color based on type
            if notif.type == "success" then
                border_color = color(0, 1, 0, notif.alpha)
            elseif notif.type == "warning" then
                border_color = color(1, 1, 0, notif.alpha)
            elseif notif.type == "error" then
                border_color = color(1, 0, 0, notif.alpha)
            else
                border_color = color(border_color.r, border_color.g, border_color.b, notif.alpha)
            end
            
            render.add_rect_filled(
                notif_pos,
                vector2(notif_pos.x + notif_size.x, notif_pos.y + notif_size.y),
                color(bg_color.r, bg_color.g, bg_color.b, notif.alpha),
                2
            )
            
            render.add_rect(
                notif_pos,
                vector2(notif_pos.x + notif_size.x, notif_pos.y + notif_size.y),
                border_color,
                2,
                1
            )
            
            -- Accent bar
            render.add_rect_filled(
                notif_pos,
                vector2(notif_pos.x + 3, notif_pos.y + notif_size.y),
                border_color,
                0
            )
            
            -- Notification text
            local text_color = library.theme["Text"] or color(1, 1, 1, 1)
            render.add_text(
                vector2(notif_pos.x + 8, notif_pos.y + 4),
                notif.text,
                color(text_color.r, text_color.g, text_color.b, notif.alpha),
                12,
                false
            )
            
            notification_y = notification_y + notif_size.y + 4
        end
    end
    
    -- Check if GUI should be visible
    if not library.open or not library.window then
        return
    end
    
    local window = library.window
    local screen_size = get_screen_size()
    
    -- Draw background texture if set
    if library.backgroundtexture then
        render.add_texture(
            library.backgroundtexture.id,
            vector2(0, 0),
            screen_size,
            0.3
        )
    end
    
    -- Draw watermark
    if library.watermark and library.watermark.visible then
        local wm_text = library.watermark.text
        local wm_size = utility.get_text_size(wm_text, 13)
        local wm_pos = library.watermark.position
        
        render.add_rect_filled(
            wm_pos,
            vector2(wm_pos.x + wm_size.x + 16, wm_pos.y + 20),
            library.theme["Window Background"],
            2
        )
        
        render.add_rect(
            wm_pos,
            vector2(wm_pos.x + wm_size.x + 16, wm_pos.y + 20),
            library.theme["Accent"],
            2,
            1
        )
        
        render.add_text(
            vector2(wm_pos.x + 8, wm_pos.y + 3),
            wm_text,
            library.theme["Text"],
            13,
            true
        )
    end
    
    -- Draw window (only if library and window are both open)
    if window.open and library.open then
        local win_pos = window.position
        local win_size = vector2(window.sizeX, window.sizeY)
        
        -- Window background
        render.add_rect_filled(
            win_pos,
            vector2(win_pos.x + win_size.x, win_pos.y + win_size.y),
            library.theme["Window Background"],
            3
        )
        
        -- Window border
        render.add_rect(
            win_pos,
            vector2(win_pos.x + win_size.x, win_pos.y + win_size.y),
            library.theme["Accent"],
            3,
            2
        )
        
        render.add_rect(
            vector2(win_pos.x + 1, win_pos.y + 1),
            vector2(win_pos.x + win_size.x - 1, win_pos.y + win_size.y - 1),
            library.theme["Window Border"],
            2,
            1
        )
        
        -- Window title
        render.add_text(
            vector2(win_pos.x + 6, win_pos.y + 4),
            window.name,
            library.theme["Text"],
            13,
            true
        )
        
        -- Tab buttons
        local tab_y = win_pos.y + 24
        local tab_x = win_pos.x + 8
        local tab_width = (win_size.x - 16) / #window.tabs
        
        for i, tab in ipairs(window.tabs) do
            local tab_pos = vector2(tab_x + (i - 1) * tab_width, tab_y)
            local tab_size = vector2(tab_width, 18)
            
            if tab == window.current_tab then
                render.add_rect_filled(
                    tab_pos,
                    vector2(tab_pos.x + tab_size.x, tab_pos.y + tab_size.y),
                    library.theme["Tab Toggle Background"],
                    2
                )
            end
            
            render.add_rect(
                tab_pos,
                vector2(tab_pos.x + tab_size.x, tab_pos.y + tab_size.y),
                library.theme["Tab Border"],
                2,
                1
            )
            
            render.add_text(
                vector2(tab_pos.x + tab_size.x / 2, tab_pos.y + 2),
                tab.name,
                library.theme["Text"],
                12,
                true
            )
            
            -- Tab click detection
            if mouse_clicked and utility.is_point_in_rect(mouse_pos, tab_pos, tab_size) then
                window.current_tab = tab
                for _, t in ipairs(window.tabs) do
                    t.visible = (t == tab)
                end
            end
        end
        
        -- Draw current tab content
        if window.current_tab then
            local content_y = tab_y + 20
            local content_height = win_size.y - 40
            local left_x = win_pos.x + 8
            local right_x = win_pos.x + win_size.x / 2 + 4
            local section_width = (win_size.x - 24) / 2
            
            for _, section in ipairs(window.current_tab.sections) do
                local section_x = section.side == "Left" and left_x or right_x
                local section_pos = vector2(section_x, content_y + section.y_offset)
                local section_size = vector2(section_width, 200) -- Dynamic height
                
                -- Section background
                render.add_rect_filled(
                    section_pos,
                    vector2(section_pos.x + section_size.x, section_pos.y + section_size.y),
                    library.theme["Section Background"],
                    2
                )
                
                render.add_rect(
                    section_pos,
                    vector2(section_pos.x + section_size.x, section_pos.y + section_size.y),
                    library.theme["Section Border"],
                    2,
                    1
                )
                
                -- Section title
                render.add_text(
                    vector2(section_pos.x + 4, section_pos.y + 2),
                    section.name,
                    library.theme["Text"],
                    12,
                    false
                )
                
                -- Draw elements
                local element_y = section_pos.y + 20
                for _, element in ipairs(section.elements) do
                    element_y = element_y + 2
                    
                    if element.type == "label" then
                        render.add_text(
                            vector2(section_pos.x + 4, element_y),
                            element.text,
                            library.theme["Text"],
                            12,
                            false
                        )
                        element_y = element_y + 16
                    elseif element.type == "button" then
                        local btn_pos = vector2(section_pos.x + 4, element_y)
                        local btn_size = vector2(section_size.x - 8, 24)
                        local hovered = utility.is_point_in_rect(mouse_pos, btn_pos, btn_size)
                        
                        render.add_rect_filled(
                            btn_pos,
                            vector2(btn_pos.x + btn_size.x, btn_pos.y + btn_size.y),
                            hovered and library.theme["Accent"] or library.theme["Object Background"],
                            2
                        )
                        
                        render.add_rect(
                            btn_pos,
                            vector2(btn_pos.x + btn_size.x, btn_pos.y + btn_size.y),
                            library.theme["Object Border"],
                            2,
                            1
                        )
                        
                        render.add_text(
                            vector2(btn_pos.x + btn_size.x / 2, btn_pos.y + 4),
                            element.name,
                            library.theme["Text"],
                            12,
                            true
                        )
                        
                        if mouse_clicked and hovered then
                            element.callback()
                            library:Notify(element.name .. " clicked", 2, "info")
                        end
                        
                        element_y = element_y + 28
                    elseif element.type == "toggle" then
                        local toggle_pos = vector2(section_pos.x + 4, element_y)
                        local toggle_size = vector2(section_size.x - 8, 20)
                        local hovered = utility.is_point_in_rect(mouse_pos, toggle_pos, toggle_size)
                        
                        -- Toggle background
                        render.add_rect_filled(
                            toggle_pos,
                            vector2(toggle_pos.x + toggle_size.x, toggle_pos.y + toggle_size.y),
                            library.theme["Object Background"],
                            2
                        )
                        
                        -- Toggle switch
                        local switch_size = 16
                        local switch_x = toggle_pos.x + toggle_size.x - switch_size - 4
                        local switch_y = toggle_pos.y + 2
                        
                        if element.value then
                            render.add_rect_filled(
                                vector2(switch_x, switch_y),
                                vector2(switch_x + switch_size, switch_y + switch_size),
                                library.theme["Accent"],
                                8
                            )
                        else
                            render.add_rect_filled(
                                vector2(switch_x, switch_y),
                                vector2(switch_x + switch_size, switch_y + switch_size),
                                library.theme["Disabled Text"],
                                8
                            )
                        end
                        
                        render.add_text(
                            vector2(toggle_pos.x + 4, toggle_pos.y + 2),
                            element.name,
                            library.theme["Text"],
                            12,
                            false
                        )
                        
                        if mouse_clicked and hovered then
                            element.value = not element.value
                            if element.flag ~= "" then
                                library.flags[element.flag] = element.value
                            end
                            element.callback(element.value)
                            library:Notify(element.name .. " " .. (element.value and "enabled" or "disabled"), 2, element.value and "success" or "info")
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "slider" then
                        local slider_pos = vector2(section_pos.x + 4, element_y)
                        local slider_width = section_size.x - 8
                        local slider_height = 20
                        
                        -- Slider track
                        render.add_rect_filled(
                            slider_pos,
                            vector2(slider_pos.x + slider_width, slider_pos.y + slider_height),
                            library.theme["Object Background"],
                            2
                        )
                        
                        -- Slider fill
                        local fill_width = (element.value - element.min) / (element.max - element.min) * slider_width
                        render.add_rect_filled(
                            slider_pos,
                            vector2(slider_pos.x + fill_width, slider_pos.y + slider_height),
                            library.theme["Accent"],
                            2
                        )
                        
                        -- Slider handle
                        local handle_x = slider_pos.x + fill_width - 4
                        render.add_circle_filled(
                            vector2(handle_x, slider_pos.y + slider_height / 2),
                            6,
                            library.theme["Text"]
                        )
                        
                        -- Slider text
                        local display_text = element.name and (element.name .. ": " .. utility.round(element.value, element.float)) or element.text:gsub("%[value%]", utility.round(element.value, element.float))
                        render.add_text(
                            vector2(slider_pos.x + 4, slider_pos.y + 2),
                            display_text,
                            library.theme["Text"],
                            11,
                            false
                        )
                        
                        -- Slider dragging
                        if mouse_down and utility.is_point_in_rect(mouse_pos, slider_pos, vector2(slider_width, slider_height)) then
                            local percent = (mouse_pos.x - slider_pos.x) / slider_width
                            element.value = utility.clamp(element.min + percent * (element.max - element.min), element.min, element.max)
                            if element.float < 1 then
                                element.value = math.floor(element.value / element.float) * element.float
                            end
                            if element.flag ~= "" then
                                library.flags[element.flag] = element.value
                            end
                            element.callback(element.value)
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "dropdown" then
                        local dropdown_pos = vector2(section_pos.x + 4, element_y)
                        local dropdown_width = section_size.x - 8
                        local dropdown_height = 20
                        
                        render.add_rect_filled(
                            dropdown_pos,
                            vector2(dropdown_pos.x + dropdown_width, dropdown_pos.y + dropdown_height),
                            library.theme["Object Background"],
                            2
                        )
                        
                        render.add_rect(
                            dropdown_pos,
                            vector2(dropdown_pos.x + dropdown_width, dropdown_pos.y + dropdown_height),
                            library.theme["Object Border"],
                            2,
                            1
                        )
                        
                        local display_text = element.name or "Dropdown"
                        if element.value then
                            if element.max then
                                display_text = #element.value > 0 and table.concat(element.value, ", ") or "None"
                            else
                                display_text = tostring(element.value)
                            end
                        end
                        
                        render.add_text(
                            vector2(dropdown_pos.x + 4, dropdown_pos.y + 2),
                            display_text,
                            library.theme["Text"],
                            11,
                            false
                        )
                        
                        -- Dropdown arrow
                        render.add_text(
                            vector2(dropdown_pos.x + dropdown_width - 16, dropdown_pos.y + 2),
                            element.open and "▲" or "▼",
                            library.theme["Text"],
                            10,
                            false
                        )
                        
                        if mouse_clicked and utility.is_point_in_rect(mouse_pos, dropdown_pos, vector2(dropdown_width, dropdown_height)) then
                            element.open = not element.open
                        end
                        
                        -- Dropdown options
                        if element.open then
                            local options_height = math.min(#element.content, element.scrollable and element.scrollingmax or #element.content) * 20
                            local options_pos = vector2(dropdown_pos.x, dropdown_pos.y + dropdown_height)
                            
                            render.add_rect_filled(
                                options_pos,
                                vector2(options_pos.x + dropdown_width, options_pos.y + options_height),
                                library.theme["Dropdown Option Background"],
                                2
                            )
                            
                            render.add_rect(
                                options_pos,
                                vector2(options_pos.x + dropdown_width, options_pos.y + options_height),
                                library.theme["Object Border"],
                                2,
                                1
                            )
                            
                            local start_idx = element.scrollable and element.scroll or 1
                            local end_idx = math.min(start_idx + (element.scrollable and element.scrollingmax or #element.content) - 1, #element.content)
                            
                            for i = start_idx, end_idx do
                                local option = element.content[i]
                                local option_y = options_pos.y + (i - start_idx) * 20
                                local option_pos = vector2(options_pos.x, option_y)
                                
                                if utility.is_point_in_rect(mouse_pos, option_pos, vector2(dropdown_width, 20)) then
                                    render.add_rect_filled(
                                        option_pos,
                                        vector2(option_pos.x + dropdown_width, option_pos.y + 20),
                                        library.theme["Accent"],
                                        0
                                    )
                                end
                                
                                local checkmark = ""
                                if element.max then
                                    for _, val in ipairs(element.value or {}) do
                                        if val == option then
                                            checkmark = "✓ "
                                            break
                                        end
                                    end
                                else
                                    if element.value == option then
                                        checkmark = "✓ "
                                    end
                                end
                                
                                render.add_text(
                                    vector2(option_pos.x + 4, option_pos.y + 2),
                                    checkmark .. option,
                                    library.theme["Text"],
                                    11,
                                    false
                                )
                                
                                if mouse_clicked and utility.is_point_in_rect(mouse_pos, option_pos, vector2(dropdown_width, 20)) then
                                    if element.max then
                                        local found = false
                                        for idx, val in ipairs(element.value or {}) do
                                            if val == option then
                                                table.remove(element.value, idx)
                                                found = true
                                                break
                                            end
                                        end
                                        if not found and #(element.value or {}) < element.max then
                                            table.insert(element.value, option)
                                        end
                                    else
                                        element.value = option
                                        element.open = false
                                    end
                                    if element.flag ~= "" then
                                        library.flags[element.flag] = element.value
                                    end
                                    element.callback(element.value)
                                end
                            end
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "colorpicker" then
                        local picker_pos = vector2(section_pos.x + 4, element_y)
                        local picker_width = section_size.x - 8
                        local picker_height = 20
                        
                        render.add_rect_filled(
                            picker_pos,
                            vector2(picker_pos.x + picker_width, picker_pos.y + picker_height),
                            library.theme["Object Background"],
                            2
                        )
                        
                        render.add_rect(
                            picker_pos,
                            vector2(picker_pos.x + picker_width, picker_pos.y + picker_height),
                            library.theme["Object Border"],
                            2,
                            1
                        )
                        
                        -- Color preview
                        local preview_size = 16
                        render.add_rect_filled(
                            vector2(picker_pos.x + 4, picker_pos.y + 2),
                            vector2(picker_pos.x + 4 + preview_size, picker_pos.y + 2 + preview_size),
                            element.value,
                            0
                        )
                        
                        render.add_text(
                            vector2(picker_pos.x + 24, picker_pos.y + 2),
                            element.name or "Color Picker",
                            library.theme["Text"],
                            11,
                            false
                        )
                        
                        if mouse_clicked and utility.is_point_in_rect(mouse_pos, picker_pos, vector2(picker_width, picker_height)) then
                            element.open = not element.open
                        end
                        
                        -- Color picker UI (simplified - would need full implementation)
                        if element.open then
                            -- Placeholder for color picker UI
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "keybind" then
                        local keybind_pos = vector2(section_pos.x + 4, element_y)
                        local keybind_width = section_size.x - 8
                        local keybind_height = 20
                        
                        render.add_rect_filled(
                            keybind_pos,
                            vector2(keybind_pos.x + keybind_width, keybind_pos.y + keybind_height),
                            library.theme["Object Background"],
                            2
                        )
                        
                        render.add_rect(
                            keybind_pos,
                            vector2(keybind_pos.x + keybind_width, keybind_pos.y + keybind_height),
                            library.theme["Object Border"],
                            2,
                            1
                        )
                        
                        local display_text = element.name or "Keybind"
                        if element.value then
                            display_text = display_text .. ": " .. tostring(element.value)
                        end
                        if element.waiting then
                            display_text = display_text .. " (Press key...)"
                        end
                        
                        render.add_text(
                            vector2(keybind_pos.x + 4, keybind_pos.y + 2),
                            display_text,
                            library.theme["Text"],
                            11,
                            false
                        )
                        
                        if mouse_clicked and utility.is_point_in_rect(mouse_pos, keybind_pos, vector2(keybind_width, keybind_height)) then
                            element.waiting = true
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "box" then
                        local box_pos = vector2(section_pos.x + 4, element_y)
                        local box_width = section_size.x - 8
                        local box_height = 20
                        
                        render.add_rect_filled(
                            box_pos,
                            vector2(box_pos.x + box_width, box_pos.y + box_height),
                            library.theme["Object Background"],
                            2
                        )
                        
                        render.add_rect(
                            box_pos,
                            vector2(box_pos.x + box_width, box_pos.y + box_height),
                            element.focused and library.theme["Accent"] or library.theme["Object Border"],
                            2,
                            1
                        )
                        
                        local display_text = element.text
                        if display_text == "" then
                            display_text = element.placeholder
                            render.add_text(
                                vector2(box_pos.x + 4, box_pos.y + 2),
                                display_text,
                                library.theme["Disabled Text"],
                                11,
                                false
                            )
                        else
                            render.add_text(
                                vector2(box_pos.x + 4, box_pos.y + 2),
                                display_text,
                                library.theme["Text"],
                                11,
                                false
                            )
                        end
                        
                        if mouse_clicked then
                            element.focused = utility.is_point_in_rect(mouse_pos, box_pos, vector2(box_width, box_height))
                        end
                        
                        element_y = element_y + 24
                    elseif element.type == "separator" then
                        render.add_line(
                            vector2(section_pos.x + 4, element_y),
                            vector2(section_pos.x + section_size.x - 4, element_y),
                            library.theme["Object Border"],
                            1
                        )
                        if element.text and element.text ~= "" then
                            render.add_text(
                                vector2(section_pos.x + section_size.x / 2, element_y - 8),
                                element.text,
                                library.theme["Text"],
                                10,
                                true
                            )
                        end
                        element_y = element_y + 12
                    end
                end
                
                section.y_offset = section.y_offset + 0 -- Will be calculated dynamically
            end
        end
        
        -- Window dragging
        local title_bar = vector2(win_pos.x, win_pos.y)
        local title_size = vector2(win_size.x, 24)
        
        if mouse_down and utility.is_point_in_rect(mouse_pos, title_bar, title_size) then
            if not window.dragging then
                window.dragging = true
                window.drag_offset = vector2(mouse_pos.x - win_pos.x, mouse_pos.y - win_pos.y)
            else
                window.position = vector2(mouse_pos.x - window.drag_offset.x, mouse_pos.y - window.drag_offset.y)
            end
        else
            window.dragging = false
        end
    end
    
    mouse_clicked = false
end)

-- Input handling
hook.addkey(0x01, "mouse_left", function(toggle)
    if toggle then
        mouse_down = true
        mouse_clicked = true
    else
        mouse_down = false
    end
end)

-- Store library in global for external loading
-- This allows the library to be loaded via http.get and run_string
-- Check if the storage variable exists (was initialized by the loader)
if __VENUS_LIB_STORAGE ~= nil then
    __VENUS_LIB_STORAGE = library
end

-- Return library
return library

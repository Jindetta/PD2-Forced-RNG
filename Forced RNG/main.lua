local this = {
    default_index = 1,
    user = Steam:userid(),
    override_keys = {nil, "b", "g"},
    custom_mutator_key = "MutatorForcedRNG",
    is_debug = true,
    file_wrapper = function(file, mode, data, clbk)
        local f, r = io.open(file, mode)
        if type(f) == "userdata" then
            if type(clbk) == "function" then
                r = {clbk(f)}
            end
            f:close()

            if r and #r ~= 0 then
                return unpack(r)
            end
        end
        return data
    end,
    current_job_data = function()
        local g, c = Global.job_manager and Global.job_manager.current_job or {}, Global.level_data or {}
        return g.job_wrapper_id or g.job_id, g.current_stage, c.level_id
    end,
    required_mutator_is_active = function(this)
        local m = Global.mutators and Global.mutators.mutator_values
        return m and m[this.custom_mutator_key] and m[this.custom_mutator_key].enabled
    end,
    create_escape_divider = function(menu, item)
        item =
            menu:create_item(
            {
                size = 8,
                type = "MenuItemDivider",
                no_text = true
            },
            {
                name = item
            }
        )
        menu:add_item(item)
    end,
    menu = {
        id = "menu_force_rng_mod",
        desc = "menu_force_rng_mod_desc",
        mutator_desc = "menu_force_rng_mod_longdesc",
        reset_id = "menu_force_rng_reset",
        reset_desc = "menu_force_rng_reset_desc",
        levels_list_id = "menu_force_rng_levels_list",
        levels_list_desc = "menu_force_rng_levels_list_desc",
        escapes_list_id = "menu_force_rng_escapes_list",
        escapes_list_desc = "menu_force_rng_escapes_list_desc",
        chat_announce_id = "menu_force_rng_chat_announce",
        chat_announce_desc = "menu_force_rng_chat_announce_desc",
        global_override_id = "menu_force_rng_global_override",
        global_override_desc = "menu_force_rng_global_override_desc",
        global_override_items = {
            "menu_force_rng_global_override_defaults",
            "menu_force_rng_global_override_worst_possible",
            "menu_force_rng_global_override_best_possible",
            "menu_force_rng_global_override_per_stage_basis",
            "menu_force_rng_global_override_per_heist_basis"
        },
        announce_worst = "announce_force_rng_worst_possible_msg",
        announce_best = "announce_force_rng_best_possible_msg",
        error_not_implemented = "error_force_rng_not_implemented",
        error_dialog_mutator = "error_force_rng_dialog_mutator",
        dialog_yes = "dialog_force_rng_confirm_yes",
        dialog_no = "dialog_force_rng_confirm_no"
    }
}

if not ForcedRNG then
    ForcedRNG = ForcedRNG or {}
    ForcedRNG.lang_path = ModPath .. "localization/"
    ForcedRNG.scripts_path = ModPath .. "scripts.json"
    ForcedRNG.settings_path = SavePath .. "force_rng.json"
    ForcedRNG.update_url = "https://gist.githubusercontent.com/Jindetta/b5ef0126785931ac5d2c41a7f3eff7f4/raw"

    function ForcedRNG:language()
        local system_key = SystemInfo:language():key()
        local blt_index = LuaModManager:GetLanguageIndex()
        local blt_supported, system_language, blt_language = {
            "english",
            "chinese_traditional",
            "german",
            "spanish",
            "french",
            "indonesian",
            "turkish",
            "russian",
            "chinese_simplified"
        }

        for key, name in ipairs(file.GetFiles(self.lang_path) or {}) do
            key = name:gsub("%.json$", ""):lower()

            if blt_supported[blt_index] == key then
                blt_language = self.lang_path .. name
            end

            if key ~= "english" and system_key == key:key() then
                system_language = self.lang_path .. name
                break
            end
        end

        return system_language or blt_language or ""
    end

    function ForcedRNG:import()
        this.file_wrapper(
            self.settings_path,
            "r",
            nil,
            function(f)
                local valid, data = pcall(json.decode, f:read("*a"))
                if valid and type(data) == "table" then
                    self._settings = data
                end
            end
        )
    end

    function ForcedRNG:export()
        this.file_wrapper(
            self.settings_path,
            "w+",
            nil,
            function(f)
                f:write(json.encode(self._settings))
            end
        )
    end

    function ForcedRNG:get(key, default_value)
        if type(self._settings and self._settings[this.user]) == "table" then
            return self._settings[this.user][tostring(key)] == nil and default_value or
                self._settings[this.user][tostring(key)]
        end
    end

    function ForcedRNG:set(key, value)
        if type(self._settings and self._settings[this.user]) == "table" then
            self._settings[this.user][tostring(key)] = value
        end
    end

    function ForcedRNG:update_version(version_nr)
        return this.file_wrapper(
            self.scripts_path,
            "r",
            false,
            function(f)
                local valid, data = pcall(json.decode, f:read("*a"))
                if valid and type(data) == "table" and type(data.version) == "number" then
                    return type(version_nr) == "number" and data.version < version_nr
                end
            end
        )
    end

    function ForcedRNG:override_key(level, stage)
        local key = self:get("override", this.default_index)
        if type(key) == "number" and key > #this.override_keys then
            key =
                self:get_level_data(
                {
                    hashed = true,
                    level_name = level,
                    stage_nr = type(stage) == "number" and stage,
                    heists_only = tostring(this.menu.global_override_items[key]):find("heist") ~= nil,
                    escapes = not stage
                }
            )
            return this.override_keys[self:get(key)]
        end
        return this.override_keys[key]
    end

    function ForcedRNG:element_info(elements, key, current_level_id)
        if type(elements.escapes) == "table" and type(current_level_id) == "string" then
            if current_level_id:find("^escape_") ~= nil then
                if self:get("escapes") then
                    for name, element in pairs(elements.escapes) do
                        if current_level_id:find(name) ~= nil then
                            return element
                        end
                    end
                end
                return
            end
        end

        local generic_data = type(elements.generics) == "table" and elements.generics[key["="]]
        return type(generic_data) == "table" and generic_data or key
    end

    function ForcedRNG:copy_elements(data)
        if type(data) == "table" then
            for _, v in ipairs(data._ or {}) do
                if type(v["#"]) == "table" and type(v["@"]) == "table" then
                    for _, id in ipairs(v["#"]) do
                        data[tostring(id)] = v["@"]
                    end
                end
            end
            data._ = nil
        end
        return data
    end

    function ForcedRNG:load_elements(core_instance)
        return this.file_wrapper(
            self.scripts_path,
            "r",
            nil,
            function(f)
                local valid, data = pcall(json.decode, f:read("*a"))
                if valid and type(data and data.levels) == "table" then
                    local job_id, stage_nr, level_id, element, key = this.current_job_data()
                    if type(core_instance) == "string" and type(data.instances) == "table" then
                        if type(data.instances[core_instance]) == "table" then
                            element, key = data.instances[core_instance], self:override_key(job_id, stage_nr)
                        end
                    elseif self:get("escapes") and tostring(level_id):find("^escape_") ~= nil then
                        element, key = self:element_info(data, nil, level_id), self:override_key(level_id)
                    elseif type(data.levels[job_id] and data.levels[job_id][stage_nr]) == "table" then
                        if
                            type(data.levels[job_id][stage_nr]["?"]) == "string" and
                                level_id:find(data.levels[job_id][stage_nr]["?"]) ~= nil
                         then
                            stage_nr =
                                data.levels[job_id][data.levels[job_id][stage_nr]["+"]] and
                                data.levels[job_id][stage_nr]["+"] or
                                stage_nr
                        end

                        element, key =
                            self:element_info(data, data.levels[job_id][stage_nr], level_id),
                            self:override_key(job_id, stage_nr)
                    end

                    if job_id ~= "crime_spree" and type(element) == "table" then
                        self:set_loaded_status(key, element)
                        return self:copy_elements(element[key])
                    end
                end
            end
        )
    end

    function ForcedRNG:return_rng_types(level_data, key, combined_table)
        if not combined_table then
            combined_table = self:element_info(level_data, key) or {}

            return {
                has_bad_rng = type(combined_table[this.override_keys[2]]) == "table",
                has_good_rng = type(combined_table[this.override_keys[3]]) == "table"
            }
        end

        combined_table = {}

        for k, v in ipairs(key) do
            if type(v) == "table" then
                k = self:element_info(level_data, v)
                combined_table.has_bad_rng = combined_table.has_bad_rng or type(k[this.override_keys[2]]) == "table"
                combined_table.has_good_rng = combined_table.has_good_rng or type(k[this.override_keys[3]]) == "table"
            end
        end

        return combined_table
    end

    function ForcedRNG:get_level_data(filter_data)
        filter_data = type(filter_data) == "table" and filter_data or {}

        return this.file_wrapper(
            self.scripts_path,
            "r",
            {},
            function(f)
                local valid, data = pcall(json.decode, f:read("*a"))
                if valid and type(data and data.levels) == "table" then
                    local levels_data, td, rng_types = {}, tweak_data.narrative, {}

                    for k, v in pairs(data.levels) do
                        if type(td.jobs[k]) == "table" and td.jobs[k].name_id then
                            local heist, stages = td.jobs[k].name_id, type(v) == "table" and #v or 1
                            local heist_name = filter_data.hashed and heist:key() or heist

                            if not filter_data.heists_only and stages > 1 then
                                if filter_data.list_everything then
                                    levels_data[#levels_data + 1] = heist_name
                                end

                                for i = 1, stages do
                                    local stage = heist .. "_d" .. i
                                    stage = filter_data.hashed and stage:key() or stage

                                    if filter_data.return_types then
                                        rng_types[stage] = self:return_rng_types(data, v[i])
                                    end

                                    if filter_data.stage_info and not filter_data.return_types then
                                        levels_data[#levels_data + 1] = {
                                            name = stage,
                                            heist = heist,
                                            stage = v[i]["#"] or i,
                                            title = v[i]["$"]
                                        }
                                    else
                                        levels_data[#levels_data + 1] = stage
                                    end

                                    if filter_data.level_name == k and filter_data.stage_nr == i then
                                        return stage, rng_types[stage]
                                    end
                                end
                            elseif not filter_data.stages_only then
                                levels_data[#levels_data + 1] = heist_name

                                if filter_data.return_types then
                                    rng_types[heist_name] = self:return_rng_types(data, v, stages)
                                end

                                if filter_data.level_name == k then
                                    return heist_name, rng_types[heist_name]
                                end
                            end
                        end
                    end

                    if filter_data.list_everything or filter_data.escapes then
                        levels_data.escapes = {}
                        for k, v in pairs(data.escapes) do
                            local level_td = tweak_data.levels["escape_" .. k]
                            if type(level_td) == "table" and level_td.name_id then
                                local escape = level_td.name_id
                                local escape_name = filter_data.hashed and escape:key() or escape

                                if filter_data.return_types then
                                    rng_types[escape_name] = self:return_rng_types(data, v)
                                end

                                if filter_data.list_everything then
                                    levels_data[#levels_data + 1] = escape_name
                                else
                                    levels_data.escapes[#levels_data.escapes + 1] = escape_name
                                end

                                if tostring(filter_data.level_name):find("^escape_" .. k) ~= nil then
                                    return escape_name, rng_types[escape_name]
                                end
                            end
                        end

                        if type(filter_data.sort) == "function" then
                            table.sort(levels_data.escapes, filter_data.sort)
                        end
                    end

                    if type(filter_data.sort) == "function" then
                        table.sort(levels_data, filter_data.sort)
                    end

                    return levels_data, rng_types
                end
            end
        )
    end

    function ForcedRNG:set_loaded_status(value, element)
        if type(element and element[value]) == "table" and next(element[value]) then
            self._current_rng_data = {
                chat_color = value == this.override_keys[3] and Color.green or Color.red,
                chat_msg = value == this.override_keys[3] and this.menu.announce_best or this.menu.announce_worst
            }
        end
    end

    function ForcedRNG:setup(hook)
        self._settings = self._settings or {}
        self._settings[this.user] = self._settings[this.user] or {}

        if not self._loaded then
            self:import()
            self._loaded = true

            if not managers.dlc and not tweak_data then
                require("lib/managers/dlcmanager")
                managers.dlc = DLCManager:new()
                require("lib/tweak_data/tweakdata")
            end

            self:set("escapes", self:get("escapes", true))
            self:set("announce", self:get("announce", false))
            self:set("override", self:get("override", this.default_index))
            for _, hash in ipairs(self:get_level_data({hashed = true, list_everything = true})) do
                self:set(hash, self:get(hash, this.default_index))
            end

            if not this.is_debug and not Global.__coresetup_bootdone then
                dohttpreq(
                    self.update_url,
                    function(json_data)
                        local valid, data = pcall(json.decode, json_data)
                        if valid and type(data) == "table" and self:update_version(data.version) then
                            this.file_wrapper(
                                self.scripts_path,
                                "w+",
                                nil,
                                function(f)
                                    f:write(json_data)
                                end
                            )
                        end
                    end
                )
            end
        end

        if hook == "lib/managers/menumanager" then
            function self:create_level_list(override_value)
                local menu = MenuHelper:GetMenu(this.menu.levels_list_id)
                if type(menu and menu._items) == "table" then
                    menu:clean_items()

                    local level_data, rng_data = {
                        heists_only = override_value == #this.menu.global_override_items,
                        list_everything = override_value <= #this.override_keys,
                        escapes = self:get("escapes"),
                        return_types = true,
                        sort = function(a, b)
                            return managers.localization:text(a) < managers.localization:text(b)
                        end
                    }

                    local function new_multichoice_items(rng_types, level)
                        local bad_rng, good_rng

                        if type(rng_types and rng_types[level]) == "table" then
                            bad_rng =
                                rng_types[level].has_bad_rng and
                                {value = 2, _meta = "option", text_id = this.menu.global_override_items[2]}
                            good_rng =
                                rng_types[level].has_good_rng and
                                {value = 3, _meta = "option", text_id = this.menu.global_override_items[3]}
                        end

                        return {
                            type = "MenuItemMultiChoice",
                            {
                                value = 1,
                                _meta = "option",
                                text_id = (good_rng or bad_rng) and this.menu.global_override_items[1] or
                                    this.menu.error_not_implemented
                            },
                            bad_rng or {},
                            good_rng or {}
                        }
                    end

                    level_data, rng_data = self:get_level_data(level_data)
                    for _, level in ipairs(level_data) do
                        local item =
                            menu:create_item(
                            new_multichoice_items(rng_data, level),
                            {
                                text_id = level,
                                name = level:key(),
                                callback = this.menu.id
                            }
                        )

                        item:set_value(self:get(item:name(), this.default_index))
                        menu:add_item(item)
                    end

                    if type(level_data.escapes) == "table" then
                        this.create_escape_divider(menu, "escapes")
                        for _, level in ipairs(level_data.escapes) do
                            local item =
                                menu:create_item(
                                new_multichoice_items(rng_data, level),
                                {
                                    text_id = level,
                                    name = level:key(),
                                    callback = this.menu.id
                                }
                            )

                            item:set_value(self:get(item:name(), this.default_index))
                            menu:add_item(item)
                        end
                    end
                end
            end

            function self:update_settings_gui(reset)
                if reset then
                    self:set("escapes", true)
                    self:set("announce", false)
                    self:set("override", this.default_index)
                    for _, hash in ipairs(self:get_level_data({hashed = true, list_everything = true})) do
                        self:set(hash, this.default_index)
                    end
                end

                local menu = MenuHelper:GetMenu(this.menu.id)
                if type(menu and menu._items) == "table" then
                    local value = self:get("override", this.default_index)

                    for name, item in ipairs(menu._items) do
                        name = item:name()

                        if name == this.menu.global_override_id then
                            item:set_value(value)
                        elseif name == this.menu.escapes_list_id then
                            item:set_value(self:get("escapes") and "on" or "off")
                        elseif name == this.menu.chat_announce_id then
                            item:set_value(self:get("announce") and "on" or "off")
                        elseif name == this.menu.levels_list_id then
                            item:set_enabled(value >= 4 and value <= #this.menu.global_override_items)
                        else
                            self:create_level_list(value)
                        end
                    end
                end
            end

            Hooks:Add(
                "LocalizationManagerPostInit",
                "ForcedRNG_LocalizationInit",
                function(manager)
                    local localization_strings = {
                        [this.menu.id] = "Forced RNG (alpha)",
                        [this.menu.desc] = "Allows host to force best/worst possible RNG for any heist/stage.",
                        [this.menu.mutator_desc] = "Forces specified RNG elements to any heist/stage. Making levels either more manageable or pure hell. This mutator must be enabled in order to load forced mission script elements.",
                        [this.menu.reset_id] = "Reset preferences",
                        [this.menu.reset_desc] = "Change everything back to default.",
                        [this.menu.levels_list_id] = "Select override(s) per heist/stage basis",
                        [this.menu.levels_list_desc] = "Change RNG forcing preferences for specific heist/stage.",
                        [this.menu.escapes_list_id] = "Allow Forced RNG in escape levels",
                        [this.menu.escapes_list_desc] = "Allow Forced RNG to be used in escape levels.",
                        [this.menu.chat_announce_id] = "Chat announcements (host only)",
                        [this.menu.chat_announce_desc] = "Toggle chat announcements on/off.",
                        [this.menu.global_override_id] = "Global override",
                        [this.menu.global_override_desc] = "Global override to force RNG preferences.",
                        [this.menu.global_override_items[1]] = "Skip - Do not force",
                        [this.menu.global_override_items[2]] = "Force RNG: The worst",
                        [this.menu.global_override_items[3]] = "Force RNG: The best",
                        [this.menu.global_override_items[4]] = "Force RNG: Per stage",
                        [this.menu.global_override_items[5]] = "Force RNG: Per heist",
                        [this.menu.announce_worst] = "Forcing the worst possible RNG for this heist/stage.",
                        [this.menu.announce_best] = "Forcing the best possible RNG for this heist/stage.",
                        [this.menu.error_not_implemented] = "Not implemented",
                        [this.menu.error_dialog_mutator] = 'NOTICE: Settings will not have effect until the "Forced RNG" mutator is enabled.',
                        [this.menu.dialog_yes] = "Yes",
                        [this.menu.dialog_no] = "No"
                    }

                    for _, level in ipairs(self:get_level_data({stages_only = true, stage_info = true})) do
                        localization_strings[level.name] =
                            ("%s - %s"):format(
                            manager:text(level.heist),
                            manager:text("menu_day_short", {day = level.stage})
                        )
                        if type(level.title) == "string" then
                            localization_strings[level.name] =
                                localization_strings[level.name] .. " (" .. level.title .. ")"
                        end
                    end

                    manager:add_localized_strings(localization_strings)
                end
            )

            Hooks:Add(
                "MenuManagerSetupCustomMenus",
                "ForcedRNG_SetupCustomMenus",
                function()
                    MenuHelper:NewMenu(this.menu.id)
                    MenuHelper:NewMenu(this.menu.levels_list_id)

                    MenuCallbackHandler[this.menu.id] = function(_, item)
                        if item then
                            local name = item:name()
                            if name == this.menu.global_override_id then
                                self:set("override", item:value())
                                self:update_settings_gui()
                            elseif name == this.menu.escapes_list_id then
                                self:set("escapes", Utils:ToggleItemToBoolean(item))
                                self:update_settings_gui()
                            elseif name == this.menu.chat_announce_id then
                                self:set("announce", Utils:ToggleItemToBoolean(item))
                            elseif name == this.menu.reset_id then
                                QuickMenu:new(
                                    managers.localization:text(this.menu.reset_id),
                                    managers.localization:text(this.menu.reset_desc):gsub("%.$", "?"),
                                    {
                                        {
                                            text = managers.localization:text(this.menu.dialog_yes),
                                            callback = function()
                                                self:update_settings_gui(true)
                                            end
                                        },
                                        {
                                            text = managers.localization:text(this.menu.dialog_no),
                                            is_cancel_button = true
                                        }
                                    },
                                    true
                                )
                            else
                                self:set(name, item:value())
                            end
                        else
                            if
                                not this.is_debug and self:get("override", this.default_index) ~= this.default_index and
                                    not this:required_mutator_is_active()
                             then
                                QuickMenu:new(
                                    managers.localization:text(this.menu.id),
                                    managers.localization:text(this.menu.error_dialog_mutator),
                                    {},
                                    true
                                )
                            end
                            self:export()
                        end
                    end
                end
            )

            Hooks:Add(
                "MenuManagerPopulateCustomMenus",
                "ForcedRNG_PopulateCustomMenus",
                function()
                    MenuHelper:AddToggle(
                        {
                            priority = 7,
                            callback = this.menu.id,
                            id = this.menu.escapes_list_id,
                            title = this.menu.escapes_list_id,
                            desc = this.menu.escapes_list_desc,
                            value = self:get("escapes"),
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            size = 12,
                            priority = 6,
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddMultipleChoice(
                        {
                            priority = 5,
                            callback = this.menu.id,
                            id = this.menu.global_override_id,
                            title = this.menu.global_override_id,
                            desc = this.menu.global_override_desc,
                            items = this.menu.global_override_items,
                            value = self:get("override"),
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            size = 12,
                            priority = 4,
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddButton(
                        {
                            priority = 3,
                            id = this.menu.levels_list_id,
                            title = this.menu.levels_list_id,
                            desc = this.menu.levels_list_desc,
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddDivider(
                        {
                            size = 12,
                            priority = 2,
                            menu_id = this.menu.id
                        }
                    )
                    MenuHelper:AddButton(
                        {
                            priority = 1,
                            id = this.menu.reset_id,
                            title = this.menu.reset_id,
                            desc = this.menu.reset_desc,
                            callback = this.menu.id,
                            menu_id = this.menu.id
                        }
                    )
                end
            )

            Hooks:Add(
                "MenuManagerBuildCustomMenus",
                "ForcedRNG_BuildCustomMenus",
                function(_, nodes)
                    nodes[this.menu.levels_list_id] = MenuHelper:BuildMenu(this.menu.levels_list_id)
                    nodes[this.menu.id] = MenuHelper:BuildMenu(this.menu.id, {back_callback = this.menu.id})
                    MenuHelper:AddMenuItem(nodes.blt_options, this.menu.id, this.menu.id, this.menu.desc)

                    nodes[this.menu.levels_list_id]._parameters.align_line_proportions = 0.575
                    nodes[this.menu.id]:item(this.menu.global_override_id)._parameters.text_offset = 20
                    nodes[this.menu.id]:item(this.menu.levels_list_id)._parameters.next_node = this.menu.levels_list_id
                    self:update_settings_gui()

                    Hooks:Add(
                        "LogicOnSelectNode",
                        "ForcedRNG_SelectNode",
                        function(_, name)
                            if name == this.menu.levels_list_id then
                                local peer =
                                    managers.network:session() and managers.network:session():local_peer() and
                                    managers.network:session():local_peer()
                                nodes[name]._parameters.item_panel_h = (peer and peer:in_lobby()) and 425 or 575
                            end
                        end
                    )
                end
            )
        elseif not this.is_debug and hook == "lib/managers/mutatorsmanager" then
            Hooks:PostHook(
                MutatorsManager,
                "init",
                "ForcedRNG_MutatorsInit",
                function(manager)
                    MutatorForcedRNG = MutatorForcedRNG or class(BaseMutator)
                    MutatorForcedRNG.icon_coords = manager._options_icon_coord
                    MutatorForcedRNG._type = this.custom_mutator_key
                    MutatorForcedRNG.categories = {"gameplay"}
                    MutatorForcedRNG.desc_id = this.menu.desc
                    MutatorForcedRNG.name_id = this.menu.id

                    function MutatorForcedRNG.build_matchmaking_key()
                        return "MutatorEnemyHealth hm 1.0000"
                    end

                    local mutator = MutatorForcedRNG:new(manager)
                    table.insert(manager._mutators, mutator)

                    if Global.mutators.active_on_load[this.custom_mutator_key] then
                        table.insert(manager._active_mutators, {mutator = mutator})
                    end
                end
            )
        elseif LuaNetworking:IsHost() then
            if hook == "lib/managers/menu/missionbriefinggui" then
                Hooks:PostHook(
                    MissionBriefingTabItem,
                    "show",
                    "ForcedRNG_MissionBriefingShow",
                    function()
                        Hooks:RemovePostHook("ForcedRNG_MissionBriefingShow")
                        if self:get("announce") and type(self._current_rng_data) == "table" then
                            DelayedCalls:Add(
                                "ForcedRNG_AnnounceStatus",
                                1,
                                function()
                                    managers.chat:_receive_message(
                                        ChatManager.GAME,
                                        managers.localization:text(this.menu.id),
                                        managers.localization:text(self._current_rng_data.chat_msg),
                                        self._current_rng_data.chat_color
                                    )
                                end
                            )
                        end
                    end
                )
            elseif this.is_debug or this:required_mutator_is_active() then
                local function execute_element_filter(element, base_element)
                    if this._instance_elements and this._instance_elements[element] then
                        element = this._instance_elements[element]
                    elseif this._elements and this._elements[element] then
                        element = this._elements[element]
                    else
                        return
                    end

                    for k, v in pairs(type(base_element) == "table" and element or {}) do
                        if not k:find("^!") then
                            if k == "on_executed" then
                                local data, index = element["!add"] and base_element[k] or {}
                                if not element["!add"] and type(element["!delete"]) == "number" then
                                    data, index = base_element[k], element["!delete"]
                                    table.remove(data, index)
                                end

                                if type(v) == "table" then
                                    for _, t in ipairs(v) do
                                        if type(t) ~= "table" then
                                            t = {id = t}
                                        end
                                        t.delay = t.delay or 0
                                        table.insert(data, index or #data + 1, t)
                                        index = type(index) == "number" and index + 1
                                    end
                                elseif type(v) == "number" then
                                    table.insert(data, index or #data + 1, {delay = 0, id = v})
                                end

                                v = data
                            end

                            base_element[k] = v
                        elseif k == "!i" then
                            if type(v) == "table" then
                                for i, t in ipairs(v) do
                                    v[i] = base_element.on_executed[t]
                                end
                            elseif type(v) == "number" then
                                v = {base_element.on_executed[v]}
                            end

                            base_element.on_executed = v
                        end
                    end
                end

                if hook == "lib/managers/missionmanager" then
                    local __serialize_to_script = MissionManager._serialize_to_script
                    function MissionManager._serialize_to_script(manager, file_type, path)
                        local scripts = __serialize_to_script(manager, file_type, path)
                        if file_type == "mission" then
                            this._elements = this._elements or self:load_elements()
                            for _, script in pairs(this._elements and scripts or {}) do
                                for _, element in ipairs(script.elements or {}) do
                                    execute_element_filter(tostring(element.id), element.values)
                                end
                            end
                        end
                        return scripts
                    end
                    local __element_class = MissionScript._element_class
                    function MissionScript._element_class(script, module, class)
                        module = __element_class(script, module, class)
                        if class == "ElementRandom" then
                            function module._get_random_elements(e)
                                if type(e._values.setup) == "number" then
                                    return table.remove(
                                        e._unused_randoms,
                                        e._values.setup > #e._unused_randoms and 1 or e._values.setup
                                    )
                                end
                                return table.remove(e._unused_randoms, math.random(#e._unused_randoms))
                            end
                        end
                        return module
                    end
                elseif hook == "core/lib/managers/coreworldinstancemanager" then
                    local __serialize_to_script = CoreWorldInstanceManager._serialize_to_script
                    function CoreWorldInstanceManager._serialize_to_script(manager, file_type, path)
                        local scripts = __serialize_to_script(manager, file_type, path)
                        if file_type == "mission" then
                            this._instance_elements = self:load_elements(path:key())
                            for _, script in pairs(this._instance_elements and scripts or {}) do
                                for _, element in ipairs(script.elements or {}) do
                                    execute_element_filter(tostring(element.id), element.values)
                                end
                            end
                        end
                        return scripts
                    end
                end
            end
        end
    end
end

ForcedRNG:setup(RequiredScript)

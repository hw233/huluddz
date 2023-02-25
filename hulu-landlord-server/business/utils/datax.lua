-- ty
local skynet = require "skynet"
local objx = require "objx"
local arrayx = require "arrayx"

local CfgDataType = {
    Default     = 0,    -- 表格数据
    GroupBy     = 1,    -- 分组数据


    GlobalCfg   = 100,    -- 全局数据配置特殊处理
}

local datax = {
    _nilObj = {msg = "获取此对象则就出错了!"},
    _cacheData = {},
    _cfgPath = {
        globalCfg                   = {type = CfgDataType.GlobalCfg, path = "cfg.cfg_global"},

        activity                    = {type = CfgDataType.Default, path = "cfg.cfg_activity"},

        items                       = {type = CfgDataType.Default, path = "cfg.cfg_items"},
        store                       = {type = CfgDataType.Default, path = "cfg.cfg_store"},

        vip                         = {type = CfgDataType.Default, path = "cfg.cfg_vip"},
        vipGroup                    = {type = CfgDataType.GroupBy, path = "cfg.cfg_vip", fields = {"vip_level"}},
        titleRewards                = {type = CfgDataType.GroupBy, path = "cfg.cfg_title_rewards", fields = {"level"}},

        fashion                     = {type = CfgDataType.Default, path = "cfg.cfg_fashion"},
        fashionTypeGroup            = {type = CfgDataType.GroupBy, path = "cfg.cfg_fashion", fields = {"type", "id"}},
        mood                        = {type = CfgDataType.GroupBy, path = "cfg.cfg_mood", fields = {"level"}},
        skill                       = {type = CfgDataType.Default, path = "cfg.cfg_skill"},
        skillBuff                   = {type = CfgDataType.GroupBy, path = "cfg.cfg_skill_buff", fields = {"skill_id", "buff_level"}},

        runeLevel                   = {type = CfgDataType.GroupBy, path = "cfg.cfg_rune_level", fields = {"rune_quality", "level"}},

        roomCost                    = {type = CfgDataType.Default, path = "cfg.cfg_room_cost"},
        roomGroup                   = {type = CfgDataType.GroupBy, path = "cfg.cfg_room_cost", fields = {"game_id", "room_type"}},
        cardTypeGroup               = {type = CfgDataType.GroupBy, path = "cfg.cfg_card_type", fields = {"game_id", "key"}},
        effect                      = {type = CfgDataType.Default, path = "cfg.cfg_effect"},
        effectGroup                 = {type = CfgDataType.GroupBy, path = "cfg.cfg_effect", fields = {"game_id", "fashion_id", "type", "subtype"}},
        effectCodeGroup             = {type = CfgDataType.GroupBy, path = "cfg.cfg_effect_code", fields = {"game_id", "effect_name"}},
        robot                       = {type = CfgDataType.Default, path = "cfg.cfg_robot"},
        init_cards                  = {type = CfgDataType.GroupBy, path = "cfg.cfg_init_cards", fields = {"game_id", "id"}},

        player_avatar               = {type = CfgDataType.Default, path = "cfg.cfg_player_avatar"},
        emoticon                    = {type = CfgDataType.Default, path = "cfg.cfg_emoticon"},

        ad_rewards                  = {type = CfgDataType.Default, path = "cfg.cfg_ad_rewards"},
        announce                    = {type = CfgDataType.Default, path = "cfg.cfg_announce"},

        -- start
        lucky_blind_box             = {type = CfgDataType.Default, path = "cfg.cfg_lucky_blind_box"},
        lucky_blind_box_items       = {type = CfgDataType.Default, path = "cfg.cfg_lucky_blind_box_items"},
        bust_gift                   = {type = CfgDataType.Default, path = "cfg.cfg_bust_gift"},
        shake_discount              = {type = CfgDataType.Default, path = "cfg.cfg_shake_discount"},
        month_cards                 = {type = CfgDataType.Default, path = "cfg.cfg_month_cards"},
        sign_in_14                 = {type = CfgDataType.Default, path = "cfg.cfg_sign_in_14"},
        share                 = {type = CfgDataType.Default, path = "cfg.cfg_share"},
        title                 = {type = CfgDataType.Default, path = "cfg.cfg_title"},
        passcheck             = {type = CfgDataType.Default, path = "cfg.cfg_passcheck"},
        sign_in_7             = {type = CfgDataType.Default, path = "cfg.cfg_sign_7"},
    },

    globalCfg = nil,

    activity = nil,

    vip = nil,
    titleRewards = nil,

    fashionTypeGroup = nil,
    mood = nil,
    skill = nil,
    skillBuff = nil,

    runeLevel = nil,

    roomCost = nil,
    roomGroup = nil,                -- 房间 room_cost 表格分组
    cardTypeGroup = nil,
    effect = nil,
    effectGroup = nil,
    effectCodeGroup = nil,
    robot = nil,
    
    player_avatar   = nil,
    emoticon        = nil,                 -- 表情 emoticon 表格

    bust_gift = nil,
    shake_discount = nil,
    month_cards = nil,
    items = nil,

    lucky_blind_box_items        = nil,
    lucky_blind_box          = nil,
    sign_in_14 = nil,
    sign_in_7 = nil,
    share = nil,
    title = nil,
    passcheck = nil,
}


datax = setmetatable(datax, {__index = function (self, key)
    return datax._getCacheData(key)
end})

datax._getCacheData = function (key)
    local dataInfo = datax._cfgPath[key]
    if dataInfo then
        local data
        if dataInfo.type == CfgDataType.Default then
            data = datax.getCfgData(dataInfo.path)
        elseif dataInfo.type == CfgDataType.GroupBy then
            data = datax.getCfgGroupData(dataInfo.path, dataInfo.fields)
        elseif dataInfo.type == CfgDataType.GlobalCfg then
            data = datax.getCfgGlobal(dataInfo.path)
        end
        if not data then
            skynet.loge("datax._getCacheData error! data is nil.", dataInfo.type, dataInfo.path);
        end
        datax[key] = data
        return data
    else
        skynet.loge("datax._getCacheData error! dataInfo is nil");
    end
    return datax._nilObj
end

datax.getCfgData = function (path)
    local datas
    if path then
        datas = datax._cacheData[path]
        if not datas then
            datas = require(path)
            for key, data in pairs(datas) do
                data.id = key
            end
            datax._cacheData[path] = datas
        end
        if not datas then
            skynet.loge("datax.getCfgData error! data is nil.", path);
        end
    else
        datas = datax._nilObj
        skynet.loge("datax.getCfgData error! path is nil.", path);
    end
    return datas
end

datax.getCfgGroupData = function (path, fields)
    local cacheData
    if path then
        local key = path .. "_" .. table.concat(fields)
        cacheData = datax._cacheData[key]
        if not cacheData then
            cacheData = {}
            local cfgDatas = datax.getCfgData(path)

            local datas, data, k
            for key, cfgData in pairs(cfgDatas) do
                datas = cacheData
                for index, value in ipairs(fields) do
                    if index > 1 then
                        data = datas[k]
                        if not data then
                            data = {}
                            datas[k] = data
                        end
                        datas = data
                    else
                        data = datas
                    end
                    k = cfgData[value]
                end
                data[k] = cfgData
            end
            datax._cacheData[key] = cacheData
        end
    else
        cacheData = datax._nilObj
        skynet.loge("datax.getCfgGroupData error! path is nil.", path);
    end
    return cacheData
end

datax.getCfgGlobal = function (path)
    local cfgDatas = datax.getCfgData(path)
    return table.toObject(cfgDatas, nil, function (key, value)
        return value.global
    end)
end


return datax
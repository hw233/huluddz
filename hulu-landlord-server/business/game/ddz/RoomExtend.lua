local skynet = require "skynet"
local objx = require "objx"
local arrayx = require "arrayx"
local roomData = require "roomData"

return function (mObj)

    mObj.addActionIndex = function ()
        mObj.actionIndex = mObj.actionIndex + 1
        if mObj.actionIndex == 4 then
            mObj.actionIndex = 1
        end
    end

    mObj.setActionPlayerIndex = function (index)
        if index < 1 or index > 3 then
            skynet.loge("setActionPlayerIndex index error! index: ", index)
            return
        end
        mObj.actionIndex = index
    end

    mObj.getActionPlayer = function ()
        return mObj.players[mObj.actionIndex]
    end

    mObj.getActionPlayerNext = function ()
        local actionIndex = mObj.actionIndex + 1
        if actionIndex == 4 then
            actionIndex = 1
        end
        return mObj.players[actionIndex]
    end

    mObj.getPlayer = function (id)
        for _, player in ipairs(mObj.players) do
            if player.id == id then
                return player
            end
        end
    end

    mObj.getFarmerArr = function ()
        local arr = {}
        for _, player in ipairs(mObj.players) do
            if not player.isLandlord then
                table.insert(arr, player)
            end
        end
        return arr
    end

    mObj.getCfg = function ()
        return mObj.cfgData
    end

    mObj.getMultipleMax = function ()
        local top = mObj.cfgData.capped_num
        for _, player in ipairs(mObj.players) do
            if player.doubleMaxMultiple and player.doubleMaxMultiple > 1 then
                top = top * 2
            end
        end
        return top
    end



end
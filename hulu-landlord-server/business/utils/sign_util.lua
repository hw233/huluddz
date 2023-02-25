local M = {}

function M.sort_tbl_by_key(t)
    local tt = {}
    for k,v in pairs(t) do
      if v ~= '' then
        table.insert(tt, {k = k, v = v})
      end
    end

    table.sort(tt, function (a, b)
      return a.k < b.k
    end)
    return tt
end

function M.sign_table2str(tab)
    local res_tab = {}
    
    for _, v in ipairs(tab) do
        if v.v and v.v ~= "" then
            table.insert(res_tab, string.format('%s=%s', v.k, v.v))
        end
    end

    return table.concat(res_tab, "&")
end

return M
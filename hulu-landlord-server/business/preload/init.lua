require "preload.dump"
require "preload.error"
require "preload.string"
require "preload.table"
require "preload.landlord"
require "define"

-- by excel, see conftbl
require "preload.cft"




function BITSET(n, i, flag)
	if flag == 0 then
		local m = ~(1<<(i-1))
		return m & n
	else
		assert(flag == 1)
		return (1 << (i-1)) | n
	end
end

function BITGET(n, i)
	return (n >> (i-1) &1)
end


function COMBINE(n, n2)
	return (n<<8) + n2
end

function DIVISION(n)
	return n>>8, n&0xff
end

function EnumAlias(t)
	local t1 = {}
	for k,v in pairs(t) do
		t1[v] = k
	end
	return setmetatable({}, {
		__index = function (self, key)
			return t1[key] or t[key]
		end
	})
end
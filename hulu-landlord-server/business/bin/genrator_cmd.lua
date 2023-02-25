-- package.path = "./"
require "lfs"



local s2c =""
local c2s =""

local function reConnectStr(str)
    local find_space = string.find(str," ")
    if find_space then
        print("find_space",find_space)
        local msg = string.sub(str,1,find_space-1)
        local id = string.sub(str,find_space)
        print(string.format("%s = \"%s\" ,-- %s",msg,msg,id))
        return string.format("%s = \"%s\" ,-- %s",msg,msg,id)
    end
    return str    
end

local function append_str(str,_append)
    str = str .._append.."\n"
    return str
end

local function readFile(path)
    local f = assert(io.open(path, 'r'))
    local string = f:read("*all")
    f:close()
    return string
end

--按行读取
local function readFileLine(path)
    local f = assert(io.open(path, 'r'))
    if f then
        local cmd_type = 0
        for line in f:lines() do           
            if string.find(line, '%.') then               
                cmd_type = 0 
            elseif string.find(line, "response") or string.find(line, "request") or string.find(line,"return") then
            elseif string.find(line, "local c2s ") then
                cmd_type = 1
            elseif string.find(line, "local s2c ")  then
                cmd_type = 2
            elseif  cmd_type ==1 and string.find(line, "{")   then    
                c2s = append_str(c2s,reConnectStr(line))          
            elseif  cmd_type ==2 and string.find(line, "{")   then    
                s2c = append_str(s2c,reConnectStr(line))   
            else
                -- print("find else there")   
                -- print(line) 
            --     out_str = append_str(out_str,line)     
            end
        end
    end    
    f:close()
end


local function writeFile(path, str)
    local f = assert(io.open(path, 'w'))
    f:write(string.format("return {\n %s \n}",str))
    
    f:close()
end





local function start(path)  
    
    local fileName_Col = {}
    for fileName in lfs.dir(path) do
        if fileName ~= "." and fileName ~= ".." and string.find(fileName, "(.lua)")  then
            if string.find(fileName, "_") ~= nil then
                print("file:",fileName)
                print(string.sub(fileName,1,4))
                table.insert(fileName_Col,fileName)               
                -- out_str = append_str(out_str,readFile(path.."/"..fileName))         
                -- out_str = append_str(out_str,string.format("filename %s ",fileName))
            end
        end
    end

    table.sort(fileName_Col,
        function(a,b)
            return tonumber(string.sub(a,1,4))<tonumber(string.sub(b,1,4))
        end )

    for _,_filename in ipairs(fileName_Col) do
        readFileLine(path.."/".._filename)
    end
    

    -- out_str = append_str(out_str,"len : "..#c2s)     
    local out_str=""
    c2s = string.gsub(c2s,"{","")
    c2s = string.gsub(c2s,"}","")

    s2c = string.gsub(s2c,"{","")
    s2c = string.gsub(s2c,"}","")

    out_str = append_str(out_str,string.format("c2s ={\n%s},",c2s)) 
    out_str = append_str(out_str,"\n\n") 
    out_str = append_str(out_str,string.format("s2c ={\n%s}",s2c)) 
    writeFile("../sproto/cmdLua.lua",out_str)
end

start("../sproto")
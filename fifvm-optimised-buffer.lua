local gpu = require('component').gpu

local gpu_set, gpu_setbg, gpu_setfg, gpu_fill,gpu_bitblt = gpu.set, gpu.setBackground, gpu.setForeground, gpu.fill, gpu.bitblt
local unicode_char = require('unicode').char
local string_sub, string_byte = string.sub, string.byte
local table_concat = table.concat -- haha microoptimization go .. < {} bbrbr
local os_sleep = os.sleep

local argv = {...} 

local handle = io.open(argv[1], "rb")

handle:read(6)
local w,h = string_byte(handle:read(1)), string_byte(handle:read(1))
gpu.setResolution(w,h)
local buff = gpu.allocateBuffer(w, h)
gpu.setActiveBuffer(buff)


local step = os.clock
local start = step()
local i = 1
local data = {}
while true do
  local s = handle:read(1024)
  if s ~= nil then
    data[i] = s
  i = i + 1
  else break end
end
data = table_concat(data)
local stop = step()
local loadtime = stop-start

local offset = 1

local sleeptime = 0
local os_sleep = function(t) os.sleep(t) sleeptime = sleeptime + t end
local gpustring = {} -- reusage
local function generatePI(pixelInfo)
	local len = #pixelInfo
	--local gpustring = {} -- new local each time : garbage
	local gpustring = gpustring
    for i=1,len do
      gpustring[i] = unicode_char(string_byte(string_sub(pixelInfo, i, i)) + 0x2800)
    end
	return table_concat(gpustring,"",1,len)
end
local start = step()
while true do
  local instruction = string_byte(string_sub(data, offset, offset), 1)
  offset = offset + 1
 -- print(instruction)
  if instruction == 0x01 then
    local data = string_sub(data, offset, offset + 2)
    offset = offset + 3
    gpu_setbg(
    string_byte(data, 1) * 0x10000 + -- r
    string_byte(data, 2) * 0x100 + -- g
    string_byte(data, 3) ) -- b
  elseif instruction == 0x02 then
    local data = string_sub(data, offset, offset + 2)
    offset = offset + 3
    gpu_setfg(
    string_byte(data, 1) * 0x10000 + -- r
    string_byte(data, 2) * 0x100 + -- g
    string_byte(data, 3) ) -- b
  elseif instruction == 0x10 then
    local cords = string_sub(data, offset, offset + 1)
    offset = offset + 2
    local size = string_byte(string_sub(data, offset, offset))
    offset = offset + 1
    gpu_set(
    string_byte(cords, 1) + 1, -- x
    string_byte(cords, 2) + 1, -- y
    generatePI(string_sub(data, offset, offset + size - 1))) -- string
	offset = offset + size
  elseif instruction == 0x11 then
    local cords = string_sub(data, offset, offset + 4)
    offset = offset + 5
    gpu_fill(
    string_byte(cords, 1) + 1, -- x
    string_byte(cords, 2) + 1, -- y
    string_byte(cords, 3), -- w
    string_byte(cords, 4), -- h
    unicode_char(0x2800 + string_byte(cords, 5))) -- filler
  elseif instruction == 0x12 then    
    --os_sleep(string_byte(string_sub(data, offset, offset)) / 100)
	offset = offset + 1
	gpu_bitblt(0, 1, 1, w, h, buff)
  elseif instruction == 0x13 then
    local cords = string_sub(data, offset ,offset + 1)
    offset = offset + 2
    local size = string_byte(string_sub(data,offset,offset))
    offset = offset + 1
    gpu.set(
    string_byte(cords, 1) + 1, -- x
    string_byte(cords, 2) + 1, -- y
    generatePI(string_sub(data, offset, offset + size - 1)), true) -- string, isVertical
	offset = offset + size
  elseif instruction == 0x20 then break end
end

gpu.setActiveBuffer(0)
gpu_bitblt(0, 1, 1, w, h, buff)
gpu.freeBuffer(buff)


local stop = step()
local executiontime = stop - start
print(("Benchmark : chad fifvm : startup %05f : execution %05f : sleep %05f"):format(loadtime,executiontime,sleeptime))

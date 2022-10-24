local skynet = require "skynet"
local mt19937 = require "xlib.mt19937"


skynet.start(function()
    -- random seed
    mt19937.init(tostring(os.time()):reverse():sub(1, 6))
    -- random integer of range [1, 1000)
    for i = 1, 10 do
        print(mt19937.randi(1, 1000))
    end
    -- random real of range [0, 1)
    for j = 1, 10 do
        print(mt19937.randr())
    end
    skynet.exit()
end)
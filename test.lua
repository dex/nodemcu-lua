--i2c.setup(0, 2, 1, i2c.SLOW)
--lcd = dofile("rgb_lcd.lua")()
--lcd:begin(16, 2, 0)
--lcd:setRGB(0, 255, 100)
lcd:createChar(0, {0x0, 0x0, 0x11, 0x11, 0x0, 0x11, 0x0e, 0})
_, t, h = dht.read(3)
lcd:clear()
lcd:setCursor(0, 0)
lcd:print("Temperture: " .. t .. " ")
lcd:write(0)
lcd:setCursor(0, 1)
lcd:print("Humidity: " .. h .. "")

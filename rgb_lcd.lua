--
-- rgb_lcd.lua
--
-- Author: Dex Chen
-- 2016-8-6
--
-- LUA script version of rgb LCD
-- Based on Loovee's cpp version 
-- 
-- The MIT License (MIT)
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.1  USA
--

-- Device I2C Arress
local LCD_ADDRESS = bit.rshift(0x7c, 1)
local RGB_ADDRESS = bit.rshift(0xc4, 1)

-- color define 
local color_def = {
    WHITE = 0,
    RED   = 1,
    GREEN = 2,
    BLUE  = 3,
}

local reg_def = {
    REG_RED    = 0x04,        -- pwm2
    REG_GREEN  = 0x03,        -- pwm1
    REG_BLUE   = 0x02,        -- pwm0

    REG_MODE1  = 0x00,
    REG_MODE2  = 0x01,
    REG_OUTPUT = 0x08,
}

local lcd_def = {
    -- commands
    LCD_CLEARDISPLAY   = 0x01,
    LCD_RETURNHOME     = 0x02,
    LCD_ENTRYMODESET   = 0x04,
    LCD_DISPLAYCONTROL = 0x08,
    LCD_CURSORSHIFT    = 0x10,
    LCD_FUNCTIONSET    = 0x20,
    LCD_SETCGRAMADDR   = 0x40,
    LCD_SETDDRAMADDR   = 0x80,

    -- flags for display entry mode
    LCD_ENTRYRIGHT          = 0x00,
    LCD_ENTRYLEFT           = 0x02,
    LCD_ENTRYSHIFTINCREMENT = 0x01,
    LCD_ENTRYSHIFTDECREMENT = 0x00,

    -- flags for display on/off control
    LCD_DISPLAYON  = 0x04,
    LCD_DISPLAYOFF = 0x00,
    LCD_CURSORON   = 0x02,
    LCD_CURSOROFF  = 0x00,
    LCD_BLINKON    = 0x01,
    LCD_BLINKOFF   = 0x00,

    -- flags for display/cursor shift
    LCD_DISPLAYMOVE = 0x08,
    LCD_CURSORMOVE  = 0x00,
    LCD_MOVERIGHT   = 0x04,
    LCD_MOVELEFT    = 0x00,

    -- flags for function set
    LCD_8BITMODE = 0x10,
    LCD_4BITMODE = 0x00,
    LCD_2LINE    = 0x08,
    LCD_1LINE    = 0x00,
    LCD_5x10DOTS = 0x04,
    LCD_5x8DOTS  = 0x00,
}

local i2c_send_byte = function(dta)
    i2c_send_byteS(dta)
end

local i2c_send_byteS = function(...)
    i2c.start(0)
    i2c.address(0, LCD_ADDRESS, i2c.TRANSMITTER) -- transmit to device #4
    i2c.write(0, unpack(arg))
    i2c.stop(0)                                 -- stop transmitting
end

local setReg = function(addr, dta)
    i2c.start(0)
    i2c.address(0, RGB_ADDRESS, i2c.TRANSMITTER) -- transmit to device #4
    i2c.write(0, addr, dta)
    i2c.stop(0)                                 -- stop transmitting
end

local delayMicroseconds = function(ms)
    tmr.delay(ms)
end

local begin = function(self, cols, lines, dotsize) 

    --Wire.begin();
    
    if lines > 1 then
        self._displayfunction = bit.bor(self._displayfunction, lcd_def.LCD_2LINE)
    end

    self._numlines = lines
    self._currline = 0

    -- for some 1 line displays you can select a 10 pixel high font
    if dotsize ~= 0 and lines == 1 then
        self._displayfunction = bit.bor(self._displayfunction, lcd_def.LCD_5x10DOTS)
    end

    -- SEE PAGE 45/46 FOR INITIALIZATION SPECIFICATION!
    -- according to datasheet, we need at least 40ms after power rises above 2.7V
    -- before sending commands. Arduino can turn on way befer 4.5V so we'll wait 50
    delayMicroseconds(50000)

    -- this is according to the hitachi HD44780 datasheet
    -- page 45 figure 23

    -- Send function set command sequence
    self:command(bit.bor(lcd_def.LCD_FUNCTIONSET, self._displayfunction))
    delayMicroseconds(4500)  -- wait more than 4.1ms

    -- second try
    self:command(bit.bor(lcd_def.LCD_FUNCTIONSET, self._displayfunction))
    delayMicroseconds(150)

    -- third go
    self:command(bit.bor(lcd_def.LCD_FUNCTIONSET, self._displayfunction))


    -- finally, set # lines, font size, etc.
    self:command(bit.bor(lcd_def.LCD_FUNCTIONSET, self._displayfunction))

    -- turn the display on with no cursor or blinking default
    self._displaycontrol = bit.bor(self._displaycontrol, lcd_def.LCD_DISPLAYON, lcd_def.LCD_CURSOROFF, lcd_def.LCD_BLINKOFF)
    self:display()

    -- clear it off
    self:clear()

    -- Initialize to default text direction (for romance languages)
    self._displaymode = bit.bor(self._displaymode, lcd_def.LCD_ENTRYLEFT, lcd_def.LCD_ENTRYSHIFTDECREMENT)
    -- set the entry mode
    self:command(bit.bor(lcd_def.LCD_ENTRYMODESET, self._displaymode))
    
    
    -- backlight init
    setReg(reg_def.REG_MODE1, 0)
    -- set LEDs controllable by both PWM and GRPPWM registers
    setReg(reg_def.REG_OUTPUT, 0xFF)
    -- set MODE2 values
    -- 0010 0000 -> 0x20  (DMBLNK to 1, ie blinky mode)
    setReg(reg_def.REG_MODE2, 0x20)
    
    --self:setColorWhite()
    self:setColorAll()

end

-- high level commands, for the user! 
local clear = function(self)
    self:command(lcd_def.LCD_CLEARDISPLAY)    -- clear display, set cursor position to zero
    delayMicroseconds(2000)           -- this command takes a long time!
end

local home = function(self)
    self:command(lcd_def.LCD_RETURNHOME)      -- set cursor position to zero
    delayMicroseconds(2000)           -- this command takes a long time!
end

local setCursor = function(self, col, row)
    if row == 0 then
	col = bit.bor(col, 0x80)
    else
	col = bit.bor(col, 0xc0)
    end
    local dta = {0x80, col}

    i2c_send_byteS(unpack(dta))
end

-- Turn the display on/off (quickly)
local noDisplay = function(self)
    self._displaycontrol = bit.band(self._displaycontrol, bit.bnot(lcd_def.LCD_DISPLAYON))
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

local display = function(self)
    self._displaycontrol = bit.bor(self._displaycontrol, lcd_def.LCD_DISPLAYON)
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

-- Turns the underline cursor on/off
local noCursor = function(self)
    self._displaycontrol = bit.band(self._displaycontrol, bit.bnot(lcd_def.LCD_CURSORON))
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

local cursor = function(self)
    self._displaycontrol = bit.bor(self._displaycontrol, lcd_def.LCD_CURSORON)
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

-- Turn on and off the blinking cursor
local noBlink = function(self)
    self._displaycontrol = bit.band(self._displaycontrol, bit.bnot(lcd_def.LCD_BLINKON))
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

local blink = function(self)
    self._displaycontrol = bit.bor(self._displaycontrol, lcd_def.LCD_BLINKON)
    self:command(bit.bor(lcd_def.LCD_DISPLAYCONTROL, self._displaycontrol))
end

-- These commands scroll the display without changing the RAM
local scrollDisplayLeft = function(self)
    self:command(bit.bor(lcd_def.LCD_CURSORSHIFT, lcd_def.LCD_DISPLAYMOVE, lcd_def.LCD_MOVELEFT))
end

local scrollDisplayRight = function(self)
    self:command(bit.bor(lcd_def.LCD_CURSORSHIFT, lcd_def.LCD_DISPLAYMOVE, lcd_def.LCD_MOVERIGHT))
end

-- This is for text that flows Left to Right
local leftToRight = function(self)
    self._displaymode = bit.bor(self._displaymode, lcd_def.LCD_ENTRYLEFT)
    self:command(bit.bor(lcd_def.LCD_ENTRYMODESET, self._displaymode))
end

-- This is for text that flows Right to Left
local rightToLeft = function(self)
    self._displaymode = bit.band(self._displaymode, bit.bnot(lcd_def.LCD_ENTRYLEFT))
    self:command(bit.bor(lcd_def.LCD_ENTRYMODESET, self._displaymode))
end

-- This will 'right justify' text from the cursor
local autoscroll = function(self)
    self._displaymode = bit.bor(self._displaymode, lcd_def.LCD_ENTRYSHIFTINCREMENT)
    self:command(bit.bor(lcd_def.LCD_ENTRYMODESET, self._displaymode))
end

-- This will 'left justify' text from the cursor
local noAutoscroll = function(self)
    self._displaymode = bit.band(self._displaymode, bit.bnot(lcd_def.LCD_ENTRYSHIFTINCREMENT))
    self:command(bit.bor(lcd_def.LCD_ENTRYMODESET, self._displaymode))
end

-- Allows us to fill the first 8 CGRAM locations
-- with custom characters
local createChar = function(self, location, charmap)
    location = bit.band(location, 0x7) -- we only have 8 locations 0-7
    self:command(bit.bor(lcd_def.LCD_SETCGRAMADDR, bit.lshift(location, 3)))
    
    local dta = {0x40}
    for i = 0,7 do dta[#dta+1] = charmap[i] end
    i2c_send_byteS(unpack(dta))
end

-- Control the backlight LED blinking
local blinkLED = function(self)
    -- blink period in seconds = (<reg 7> + 1) / 24
    -- on/off ratio = <reg 6> / 256
    setReg(0x07, 0x17)  -- blink every second
    setReg(0x06, 0x7f)  -- half on, half off
end

local noBlinkLED = function(self)
    setReg(0x07, 0x00)
    setReg(0x06, 0xff)
end

-- mid level commands, for sending data/cmds 

-- send command
local command = function(self, value)
    i2c_send_byteS(0x80, value)
end

-- send data
local write = function(self, value)
    i2c_send_byteS(0x40, value)
    return 1 -- assume sucess
end

local setRGB = function(self, r, g, b)
    setReg(reg_def.REG_RED, r)
    setReg(reg_def.REG_GREEN, g)
    setReg(reg_def.REG_BLUE, b)
end

local setPWM = function(self, color, pwm)
    setReg(color, pwm)
end

local color_define = {
    {255, 255, 255},            -- white
    {255, 0, 0},                -- red
    {0, 255, 0},                -- green
    {0, 0, 255},                -- blue
}

local setColor = function(self, color)
    if color > 3 then return end
    self:setRGB(color_define[color+1][1], color_define[color+1][2], color_define[color+1][3])
end

local setColorAll = function(self)
    self:setRGB(0, 0, 0)
end

local setColorWhite = function(self)
    self:setRGB(255, 255, 255)
end

local print = function(self, str)
    for i = 1, #str do
	c = str:sub(i,i)
	self:write(c)
    end
end

local init = function(self)
    self._displayfunction = 0
    self._displaycontrol = 0
    self._displaymode = 0
    self._numlines = 0
    self._currline = 0
end

-- instance metatable
local meta = {
  __index = {
      init = init,
      begin = begin,
      clear = clear,
      home = home,
      noDisplay = noDisplay,
      display = display,
      noBlink = noBlink,
      blink = blink,
      noCursor = noCursor,
      cursor = cursor,
      scrollDisplayLeft = scrollDisplayLeft,
      scrollDisplayRight = scrollDisplayRight,
      leftToRight = leftToRight,
      rightToLeft = rightToLeft,
      autoscroll = autoscroll,
      noAutoscroll = noAutoscroll,
      createChar = createChar,
      setCursor = setCursor,
      write = write,
      command = command,
      setRGB = setRGB,
      setPWM = setPWM,
      setColor = setColor,
      setColorAll = setColorAll,
      setColorWhite = setColorWhite,
      blinkLED = blinkLED,
      noBlinkLED = noBlinkLED,
      print = print,
  },
}

-- create new LCD1602 instance
return function()
  local self = setmetatable({
      _displayfunction,
      _displaycontrol,
      _displaymode,
      _numlines,
      _currline,
  }, meta)
  self:init()
  return self
end

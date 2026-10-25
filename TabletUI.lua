#include "Math.lua"
#include "Settings.lua"

TabletUI = {}
TabletUI.__index = TabletUI

TabletUI.Status = {
  HIDDEN = 1,
  SHOWN = 2,
  HIDING = 3,
  SHOWING = 4,
}

TabletUI.ScreenState = {
  OFF = 1,
  BOOTING = 2,
  SETTINGS = 3,
}

TabletUI.Config = {
  FRAME_W = 1600,
  FRAME_H = 900,
  FRAME_RADIUS = 20,
  MARGINS = 40,
  FLASH_LINE_H = 8,

  OFFSET_HIDDEN = -1000,
  OFFSET_SHOWN = 50,

  MOVE_TIME = 0.35,
  CRT_TIME = 0.2,
  BOOT_LINE_DELAY = 0.05,
  BOOT_PAUSE_TIME = 0.5,

  COLOR_TABLET_FRAME = { 0.1, 0.1, 0.1 },
  COLOR_TABLET_SHADOW = { 0.03, 0.03, 0.08 },
  COLOR_SCREEN_OUTLINE = { 0.07, 0.07, 0.07 },
  COLOR_LOCK_BUTTON = { 0.2, 0.2, 0.2 },

  COLOR_FLASH_USB = { 0.25, 0.25, 0.25 },
  COLOR_FLASH_USB_SIDE = { 0.2, 0.2, 0.2 },
  COLOR_FLASH_CASE = { 0.13, 0.13, 0.13 },
  COLOR_FLASH_CASE_SIDE = { 0.08, 0.08, 0.08 },
  COLOR_FLASH_LED_ON = { 0.8, 0.0, 0.0 },
  COLOR_FLASH_LED_OFF = { 0.1, 0.0, 0.0 },

  COLOR_BG_OFF = { 0.02, 0.02, 0.02 },
  COLOR_BG_ON = { 0.04, 0.14, 0.06 },
  COLOR_TEXT = { 0.25, 0.95, 0.40 },
}

TabletUI.BootLog = {
  "==========================",
  "AURORA TACTICAL SYSTEMS",
  "ENVIRONMENT INITIALIZATION",
  "==========================",
  "",
  "BOARD SERIAL : [REDACTED]",
  "BIOS VERSION : v5.01.26",
  "BUILD : ATS-04-2326",
  "BOOT MODE : SECURE",
  "",
  "Verifying RAM integrity... 65536MB [OK]",
  "Verifying GRAM integrity... 4192MB [OK]",
  "Mounting virtual root filesystem...",
  "Entry point: 0xFF800000 [OK]",
  "Loading kernel module: atse2ev2.ko... [OK]",
  "Loading kernel module: atscomsec.ko... [OK]",
  "Loading kernel module: atsdbgsc.ko... [SKIPPED]",
  "Initializing encrypted uplink... [OK]",
  "Starting graphical shell...",
}

function TabletUI.new()
  local obj = {
    __type = "TabletUI",

    status = TabletUI.Status.HIDDEN,
    screenState = TabletUI.ScreenState.OFF,

    -- Animation progress
    moveProgress = 0.0,
    crtProgress = 0.0,
    bootTimer = 0.0,

    settings = Settings.load()
  }

  return setmetatable(obj, TabletUI)
end

function TabletUI:reloadSettings()
  self.settings = Settings.load()
end

function TabletUI:show()
  if self.status == TabletUI.Status.HIDDEN or self.status == TabletUI.Status.HIDING then
    self.status = TabletUI.Status.SHOWING
  end
end

function TabletUI:hide()
  if self.status == TabletUI.Status.SHOWN or self.status == TabletUI.Status.SHOWING then
    self.status = TabletUI.Status.HIDING
    self.screenState = TabletUI.ScreenState.OFF
  end
end

function TabletUI:toggle()
  if self.status == TabletUI.Status.HIDDEN or self.status == TabletUI.Status.HIDING then
    self:show()
  else
    self:hide()
  end
end

function TabletUI:_update(deltaTime)
  -- Handle slide and turning screen on/off
  if self.status == TabletUI.Status.SHOWING then
    if self.moveProgress < 1.0 then
      self.moveProgress = Math.clamp(self.moveProgress + deltaTime / TabletUI.Config.MOVE_TIME, 0.0, 1.0)
    elseif self.crtProgress < 1.0 then
      self.crtProgress = Math.clamp(self.crtProgress + deltaTime / TabletUI.Config.CRT_TIME, 0.0, 1.0)
      if self.crtProgress >= 1.0 then
        self.status = TabletUI.Status.SHOWN
        self.screenState = TabletUI.ScreenState.BOOTING
        self.bootTimer = 0.0
      end
    end
  elseif self.status == TabletUI.Status.HIDING then
    if self.crtProgress > 0.0 then
      self.crtProgress = Math.clamp(self.crtProgress - deltaTime / TabletUI.Config.CRT_TIME, 0.0, 1.0)
    elseif self.moveProgress > 0.0 then
      self.moveProgress = Math.clamp(self.moveProgress - deltaTime / TabletUI.Config.MOVE_TIME, 0.0, 1.0)
      if self.moveProgress <= 0.0 then
        self.status = TabletUI.Status.HIDDEN
      end
    end
  end

  -- Handle boot
  if self.status == TabletUI.Status.SHOWN and self.screenState == TabletUI.ScreenState.BOOTING then
    self.bootTimer = self.bootTimer + deltaTime
    local bootDuration = (#TabletUI.BootLog * TabletUI.Config.BOOT_LINE_DELAY) + TabletUI.Config.BOOT_PAUSE_TIME
    if self.bootTimer >= bootDuration then
      self.screenState = TabletUI.ScreenState.SETTINGS
    end
  end
end

function TabletUI:render(deltaTime)
  if self.status == TabletUI.Status.HIDDEN then
    return
  end

  if self.status == TabletUI.Status.SHOWN then
    UiMakeInteractive()
  end

  self:_update(deltaTime)

  local width, height = UiWidth(), UiHeight()
  local cW, cH = UiCenter(), UiMiddle()

  UiPush()
  do
    -- Calculate tablet offset
    local offsetProgress = (self.status == TabletUI.Status.HIDING)
      and Math.easeIn3(self.moveProgress)
      or Math.easeOut3(self.moveProgress)
    local currentOffset = Math.lerp(TabletUI.Config.OFFSET_HIDDEN, TabletUI.Config.OFFSET_SHOWN, offsetProgress)

    -- Render frame
    local tabletX = cW - TabletUI.Config.FRAME_W * 0.5
    local tabletY = height - TabletUI.Config.FRAME_H - currentOffset
    UiTranslate(tabletX, tabletY)
    self:_renderFrame()

    -- Render screen
    local margins = TabletUI.Config.MARGINS
    local canvasW = TabletUI.Config.FRAME_W - margins * 2
    local canvasH = TabletUI.Config.FRAME_H - margins * 2
    local canvasRadius = math.max(1, TabletUI.Config.FRAME_RADIUS - margins)

    UiPush()
    do
      UiTranslate(margins, margins)

      -- Outline
      UiPush()
      local size = 2
      UiTranslate(-size, -size)
      UiColor(unpack(TabletUI.Config.COLOR_SCREEN_OUTLINE))
      UiRoundedRect(canvasW + size * 2, canvasH + size * 2, canvasRadius)
      UiPop()

      -- Background
      UiColor(unpack(TabletUI.Config.COLOR_BG_OFF))
      UiRoundedRect(canvasW, canvasH, canvasRadius)

      -- Content
      UiClipRect(canvasW, canvasH)
      if self.status == TabletUI.Status.SHOWN then
        self:_renderContent(canvasW, canvasH, canvasRadius)
      else
        self:_renderFlash(canvasW, canvasH, canvasRadius)
      end
    end
    UiPop()
  end
  UiPop()
end

function TabletUI:_renderFrame()
  -- Button
  UiPush()
  UiTranslate(100, -10)
  UiColor(unpack(TabletUI.Config.COLOR_LOCK_BUTTON))
  UiRoundedRect(100, 20, 5)
  UiPop()

  -- Frame Side
  UiPush()
  UiColor(unpack(TabletUI.Config.COLOR_TABLET_SHADOW))
  UiRoundedRect(TabletUI.Config.FRAME_W + 7, TabletUI.Config.FRAME_H + 9, TabletUI.Config.FRAME_RADIUS)
  UiPop()

  -- Flash drive: USB
  UiPush()
  UiTranslate(TabletUI.Config.FRAME_W + 3, TabletUI.Config.FRAME_H - 200)

  UiColor(unpack(TabletUI.Config.COLOR_FLASH_USB_SIDE))
  UiRect(15, 65)

  UiColor(unpack(TabletUI.Config.COLOR_FLASH_USB))
  UiRect(15, 60)

  -- Flash drive: CASE
  UiTranslate(15, -10)
  UiColor(unpack(TabletUI.Config.COLOR_FLASH_CASE_SIDE))
  UiRoundedRect(300, 85, 5)

  UiColor(unpack(TabletUI.Config.COLOR_FLASH_CASE))
  UiRoundedRect(300, 80, 5)

  -- -- Flash drive: LED
  local time = math.floor(GetTime())
  UiTranslate(15, 10)
  if (time * 0.8) % 2 == 0 then UiColor(unpack(TabletUI.Config.COLOR_FLASH_LED_ON))
  else UiColor(unpack(TabletUI.Config.COLOR_FLASH_LED_OFF))
  end

  UiRoundedRect(8, 8, 1)
  UiPop()

  -- Frame
  UiPush()
  UiColor(unpack(TabletUI.Config.COLOR_TABLET_FRAME))
  UiRoundedRect(TabletUI.Config.FRAME_W, TabletUI.Config.FRAME_H, TabletUI.Config.FRAME_RADIUS)
  UiPop()
end

function TabletUI:_renderFlash(canvasW, canvasH, canvasRadius)
  -- 0.0 - 0.25: dot -> horizontal line
  -- 0.25 - 1.0: expand vertically
  local hProgress = Math.clamp(self.crtProgress / 0.25, 0.0, 1.0)
  local vProgress = Math.clamp((self.crtProgress - 0.25) / 0.75, 0.0, 1.0)
  vProgress = Math.easeOut3(vProgress)

  local crtW = canvasW * hProgress
  local crtH = math.max(4, canvasH * vProgress)
  --local crtH = canvasH * vProg

  -- background expanding from center
  UiPush()
  UiAlign("center middle")
  UiTranslate(canvasW * 0.5, canvasH * 0.5)
  UiColor(unpack(TabletUI.Config.COLOR_BG_ON))
  UiRoundedRect(crtW, crtH, canvasRadius)

  -- flash line
  if self.crtProgress < 0.95 then
    local alpha = 1.0 - vProgress
    UiColor(0.5, 1.0, 0.6, alpha)
    UiRect(crtW, math.max(2, TabletUI.Config.FLASH_LINE_H * alpha))
  end
  UiPop()
end

function TabletUI:_renderContent(canvasW, canvasH, canvasRadius)
  -- background
  UiPush()
  UiColor(unpack(TabletUI.Config.COLOR_BG_ON))
  UiRoundedRect(canvasW, canvasH, canvasRadius)
  UiPop()

  -- screen
  if self.screenState == TabletUI.ScreenState.BOOTING then
    self:_renderBootScreen(canvasW, canvasH)
  elseif self.screenState == TabletUI.ScreenState.SETTINGS then
    self:_renderSettingsScreen(canvasW, canvasH)
  end
end

function TabletUI:_renderBootScreen(canvasW, canvasH)
  UiPush()

  UiTranslate(40, 40)
  UiColor(unpack(TabletUI.Config.COLOR_TEXT))
  UiAlign("left top")
  UiFont("regular.ttf", 26)

  local lineCount = math.min(#TabletUI.BootLog, math.floor(self.bootTimer / TabletUI.Config.BOOT_LINE_DELAY))

  -- Text
  for i = 1, lineCount do
    UiText("> " .. TabletUI.BootLog[i])
    UiTranslate(0, 36)
  end

  -- Cursor
  if math.floor(self.bootTimer * 8) % 2 == 0 then
    UiText("> _")
  else
    UiText(">")
  end

  UiPop()
end

local function TextButton(w, h, text, bgColor, hoverColor, pressColor, textColor)
  UiPush()
  -- TODO Color filters on hover not working, no color setting method, UiTextButton ignores size. This is bullshit
  -- Also, check against clipping
  if UiIsMouseInRect(w, h) then UiColor(unpack(hoverColor))
  else UiColor(unpack(bgColor))
  end
  UiRect(w, h)

  UiAlign("center middle")
  UiTranslate(w * 0.5, h * 0.5)
  UiColor(unpack(textColor))
  UiText(text)
  UiPop()

  return UiBlankButton(w, h)
end

local function Slider(value, min, max, width, thumbSize)
  UiPush()
  UiRect(width, 2)

  UiSliderThumbSize(thumbSize, thumbSize)
  UiAlign("center middle")

  local range = max - min
  local normalizedValue = (value - min) / range
  local normalizedResult = UiSlider("MOD/img/thumb.png", "x", normalizedValue * width, 0, width) / width
  UiPop()

  return normalizedResult * range + min
end

function TabletUI:_renderSettingsScreen(screenW, screenH)
  UiPush()
  do
    local margins = 60
    UiAlign("top left")
    UiTranslate(margins, margins)
    local canvasW, canvasH = screenW - 2 * margins, screenH - 2 * margins

    -- Header
    UiFont("bold.ttf", 44)
    UiColor(unpack(TabletUI.Config.COLOR_TEXT))
    UiText("SYSTEM CONFIGURATION")

    -- Power button
    UiPush()
    UiTranslate(canvasW - 160, 0)
    UiFont("bold.ttf", 24)
    if TextButton(160, 48, "POWER OFF", {0.1, 0.3, 0.15}, {0.15, 0.45, 0.2}, {0.05, 0.2, 0.1}, TabletUI.Config.COLOR_TEXT) then
      self:hide()
    end
    UiPop()

    -- Separator
    UiTranslate(0, 60)
    UiColor(0.15, 0.50, 0.22)
    UiRect(canvasW, 3)
    UiTranslate(0, 40)

    -- === Settings ===
    local rowHeight = 64
    local rowPadding = 20
    local rowMargins = 20
    local sliderWidth = 300

    UiFont("regular.ttf", 28)
    UiColor(unpack(TabletUI.Config.COLOR_TEXT))

    -- Helpers
    local function SliderOption(label, value, min, max, precision)
      precision = precision or 3
      UiPush()
      do
        -- Background
        UiColor(0.06, 0.20, 0.09)
        UiRect(canvasW, rowHeight)

        -- Label
        UiPush()
        do
          UiTranslate(rowPadding, rowHeight * 0.5)
          UiAlign("left middle")
          UiColor(unpack(TabletUI.Config.COLOR_TEXT))
          UiText(label)
        end
        UiPop()

        UiPush()
        do
          -- Slider
          UiColor(unpack(TabletUI.Config.COLOR_TEXT))
          UiTranslate(canvasW - sliderWidth - rowPadding, rowHeight * 0.5)
          value = Slider(value, min, max, 300, 20)

          -- Value
          local valueString = string.format("%."..precision.."f", value)
          local w, h = UiMeasureText(0, valueString)

          UiAlign("left middle")
          UiTranslate(-w - rowPadding, 0)
          UiText(valueString)
        end
        UiPop()
      end
      UiPop()

      return value
    end

    local function TriggerButtonOption(label, value)
      UiPush()
      do
        -- Background
        UiColor(0.06, 0.20, 0.09)
        UiRect(canvasW, rowHeight)

        -- Label
        UiPush()
        do
          UiTranslate(rowPadding, rowHeight * 0.5)
          UiAlign("left middle")
          UiColor(unpack(TabletUI.Config.COLOR_TEXT))
          UiText(label)
        end
        UiPop()

        UiPush()
        do
          local text = value and "ENABLED" or "DISABLED"
          local w, h = UiMeasureText(0, text)
          local color = value and {0.1, 0.3, 0.15} or {0.03, 0.10, 0.05}
          local hoverColor = value and {0.15, 0.45, 0.2} or {0.10, 0.35, 0.15}

          UiTranslate(canvasW - 130 - rowPadding, rowHeight * 0.5 - 22)
          local pressed = TextButton(130, 44, text, color, hoverColor, {0.05, 0.2, 0.1}, TabletUI.Config.COLOR_TEXT)
          if pressed then
            value = not value
          end
        end
        UiPop()
      end
      UiPop()

      return value
    end

    -- Options
    self.settings.sensitivityX = SliderOption("Sensitivity X", self.settings.sensitivityX, 0, 2)
    UiTranslate(0, rowHeight + rowMargins)
    self.settings.sensitivityY = SliderOption("Sensitivity Y", self.settings.sensitivityY, 0, 2)
    UiTranslate(0, rowHeight + rowMargins)
    self.settings.fastBoot = TriggerButtonOption("Fast boot algorithm", self.settings.fastBoot)
    UiTranslate(0, rowHeight + rowMargins)

    self.settings.spawnDistance = SliderOption("Launch distance", self.settings.spawnDistance, 0, 2000, 0)
    UiTranslate(0, rowHeight + rowMargins)
    self.settings.spawnHeight = SliderOption("Launch altitude", self.settings.spawnHeight, 25, 500, 0)
    UiTranslate(0, rowHeight + rowMargins)
    self.settings.detonationTimer = SliderOption("Detonation timer", self.settings.detonationTimer, 0, 3, 2)
    UiTranslate(0, rowHeight + rowMargins)
    self.settings.penetrationThreshold = SliderOption("Penetration threshold", self.settings.penetrationThreshold, 0, 1)
    UiTranslate(0, rowHeight + rowMargins)

    Settings.save(self.settings)
  end
  UiPop()
end

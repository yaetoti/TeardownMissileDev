ControlsWidget = {}
ControlsWidget.__index = ControlsWidget
ControlsWidget.WIDTH = 250
ControlsWidget.HEIGHT = 220

function ControlsWidget.new()
  local obj = {
    __type = "ControlsWidget",
    pitch = 0.0,
    yaw = 0.0,
    roll = 0.0,
    propulsion = 0.0
  }

  return setmetatable(obj, ControlsWidget)
end

function ControlsWidget:draw()
  local cornerSize = 5
  local borderSize = 3
  local pitchRectSize = 150

  UiPush()
  do
    -- Background border
    UiColor(0.21, 0.21, 0.21)
    UiRoundedRect(ControlsWidget.WIDTH + 2 * borderSize, ControlsWidget.HEIGHT + 2 * borderSize, cornerSize + borderSize * 0.5)

    -- Background
    UiTranslate(borderSize, borderSize)
    UiColor(0.08, 0.08, 0.08)
    UiRoundedRect(ControlsWidget.WIDTH, ControlsWidget.HEIGHT, cornerSize)

    -- Pitch / Yaw indicator
    UiPush()
    do
      local canvasW, canvasH = pitchRectSize, pitchRectSize

      UiColor(1, 1, 1)
      UiTranslate(34, 47)

      -- Background
      UiColor(0.13, 0.13, 0.13)
      UiRect(canvasW, canvasH)

      -- Outline
      UiColor(1, 1, 1)
      UiRectOutline(canvasW, canvasH, borderSize)

      -- Inner outline
      UiTranslate(borderSize, borderSize)
      canvasW = canvasW - 2 * borderSize
      canvasH = canvasH - 2 * borderSize

      UiColor(0.39, 0.39, 0.39)
      UiRectOutline(canvasW, canvasH, borderSize)

      -- Axes
      UiTranslate(borderSize, borderSize)
      canvasW = canvasW - 2 * borderSize
      canvasH = canvasH - 2 * borderSize

      UiPush()
      UiTranslate(canvasW * 0.5 - 1, 0)
      UiRect(2, canvasW)
      UiPop()

      UiPush()
      UiTranslate(0, canvasH * 0.5 - 1)
      UiRect(canvasH, 2)
      UiPop()

      -- Pitch / Yaw circle
      local circleRadius = 8
      canvasW = canvasW - 2 * circleRadius
      canvasH = canvasH - 2 * circleRadius

      UiColor(1, 1, 1)
      UiTranslate(canvasW * (self.yaw + 1) * 0.5, canvasH * (self.pitch + 1) * 0.5)
      UiCircle(circleRadius)
    end

    UiPop()

    -- Roll indicator
    UiPush()
    do
      UiColor(1, 1, 1)
      UiTranslate(34, 25)
      UiRect(pitchRectSize, 2)

      local circleRadius = 10
      local lineThickness = 2
      UiTranslate(pitchRectSize * (self.roll + 1) * 0.5 - circleRadius, -circleRadius + lineThickness * 0.5)
      UiCircle(circleRadius)
    end
    UiPop()

    -- Propulsion indicator
    UiPush()
    do
      UiTranslate(215, 47)
      UiColor(0.39, 0.39, 0.39)
      UiRect(6, pitchRectSize)

      UiColor(1, 1, 1)
      UiTranslate(-7, pitchRectSize - pitchRectSize * self.propulsion)
      UiRect(20, borderSize)

    end
    UiPop()
  end
  UiPop()
end
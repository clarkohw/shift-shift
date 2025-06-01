local threshold = 0.25
local lastShift  = 0
local prevFlags  = {}

hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
  if hs.application.frontmostApplication():bundleID() ~= "com.google.Chrome" then
    prevFlags = e:getFlags()
    return false
  end

  local flags = e:getFlags()

  if flags.shift and not prevFlags.shift then
    local now = hs.timer.secondsSinceEpoch()
    if now - lastShift < threshold then
      hs.eventtap.keyStroke({"cmd","shift"}, "A")
    end
    lastShift = now
  end

  prevFlags = flags
  return false
end):start()
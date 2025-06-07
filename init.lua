local threshold = 0.25
local lastShift  = 0
local prevFlags  = {}
local eventTap = nil

-- Logging function with timestamp
local function log(message)
    print(string.format("[%s] %s", os.date("%H:%M:%S"), message))
end

-- Debug: Log application switches
local appWatcher = hs.application.watcher.new(function(appName, eventType, appObject)
    if eventType == hs.application.watcher.activated then
        if appObject then
            log(string.format("App activated - Name: %s, Bundle ID: %s", appName, appObject:bundleID()))
        end
    end
end)
appWatcher:start()

-- Function to check if event tap is still enabled
local function checkEventTapStatus()
    if eventTap and not eventTap:isEnabled() then
        log("WARNING: Event tap was disabled! Attempting to restart...")
        eventTap:start()
        if eventTap:isEnabled() then
            log("Event tap successfully restarted")
        else
            log("ERROR: Failed to restart event tap")
        end
    end
end

-- Create the event tap
eventTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
    -- Check if event tap is still enabled (defensive programming)
    if not eventTap:isEnabled() then
        log("ERROR: Event tap is disabled during callback!")
        return false
    end
    
    -- Get current frontmost application
    local frontApp = hs.application.frontmostApplication()
    if not frontApp then
        log("WARNING: No frontmost application detected")
        prevFlags = e:getFlags()
        return false
    end
    
    local bundleID = frontApp:bundleID()
    log(string.format("Event received - Frontmost app: %s (%s)", 
        frontApp:name() or "Unknown", bundleID or "No bundle ID"))
    
    -- Only proceed if Chrome or Slack is frontmost
    if bundleID ~= "com.google.Chrome" and bundleID ~= "com.tinyspeck.slackmacgap" then
        log("Not Chrome or Slack - ignoring event")
        prevFlags = e:getFlags()
        return false
    end
    
    local flags = e:getFlags()
    log(string.format("Flags - Current shift: %s, Previous shift: %s", 
        tostring(flags.shift), tostring(prevFlags.shift)))
    
    -- Detect shift key press (not release)
    if flags.shift and not prevFlags.shift then
        local now = hs.timer.secondsSinceEpoch()
        local timeSinceLastShift = now - lastShift
        
        log(string.format("Shift pressed! Time since last shift: %.3f seconds (threshold: %.3f)", 
            timeSinceLastShift, threshold))
        
        if timeSinceLastShift < threshold then
            if bundleID == "com.google.Chrome" then
                log("Double-shift detected in Chrome! Triggering Cmd+Shift+A")
                hs.eventtap.keyStroke({"cmd","shift"}, "A")
            elseif bundleID == "com.tinyspeck.slackmacgap" then
                log("Double-shift detected in Slack! Triggering Cmd+G")
                hs.eventtap.keyStroke({"cmd"}, "G")
            end
        else
            log("Single shift (outside threshold)")
        end
        
        lastShift = now
        log(string.format("Updated lastShift timestamp to: %.3f", lastShift))
    end
    
    prevFlags = flags
    return false
end)

-- Start the event tap with logging
if eventTap:start() then
    log("Event tap started successfully")
else
    log("ERROR: Failed to start event tap!")
end

-- Set up a timer to periodically check event tap status
hs.timer.doEvery(30, function()
    checkEventTapStatus()
    log(string.format("Status check - Event tap enabled: %s", 
        tostring(eventTap and eventTap:isEnabled())))
end)

-- Log initial state
log("Script initialized with the following settings:")
log(string.format("  Threshold: %.3f seconds", threshold))
log(string.format("  Chrome action: Cmd+Shift+A"))
log(string.format("  Slack action: Cmd+G"))

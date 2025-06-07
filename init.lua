-- Configuration
local config = {
    -- Time threshold for double-shift detection (in seconds)
    threshold = 0.25,
    
    -- Application specific configurations
    apps = {
        chrome = {
            bundleID = "com.google.Chrome",
            action = {
                modifiers = {"cmd", "shift"},
                key = "A",
                description = "Open tab search"
            }
        },
        slack = {
            bundleID = "com.tinyspeck.slackmacgap",
            action = {
                modifiers = {"cmd"},
                key = "G",
                description = "Open search"
            }
        }
    },
    
    -- Logging configuration
    logging = {
        enabled = true,
        checkInterval = 30  -- Status check interval in seconds
    }
}

local lastShift = 0
local prevFlags = {}
local eventTap = nil

-- Coroutine for event handling
local eventCoroutine = nil

-- Logging function with timestamp - only log when debug is enabled
local debug = false
local function log(message)
    if debug then
        print(string.format("[%s] %s", os.date("%H:%M:%S"), message))
    end
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

-- Helper function to find app config by bundle ID
local function getAppConfigByBundleID(bundleID)
    for _, app in pairs(config.apps) do
        if app.bundleID == bundleID then
            return app
        end
    end
    return nil
end

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

-- Create the event tap with coroutine
local function createEventTap()
    eventCoroutine = coroutine.wrap(function()
        eventTap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, function(e)
            -- Check if event tap is still enabled
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
            
            -- Check if the current app is configured
            local appConfig = getAppConfigByBundleID(bundleID)
            if not appConfig then
                log("App not configured - ignoring event")
                prevFlags = e:getFlags()
                return false
            end
            
            local flags = e:getFlags()
            
            -- Detect shift key press (not release)
            if flags.shift and not prevFlags.shift then
                local now = hs.timer.secondsSinceEpoch()
                local timeSinceLastShift = now - lastShift
                
                if timeSinceLastShift < config.threshold then
                    log(string.format("Double-shift detected in %s! Triggering %s", 
                        frontApp:name(), appConfig.action.description))
                    
                    -- Use direct event posting for better performance
                    hs.eventtap.event.newKeyEvent(appConfig.action.modifiers, appConfig.action.key, true):post()
                    hs.timer.usleep(1000) -- Minimal delay
                    hs.eventtap.event.newKeyEvent(appConfig.action.modifiers, appConfig.action.key, false):post()
                end
                
                lastShift = now
            end
            
            prevFlags = flags
            coroutine.applicationYield()
            return false
        end)
        
        if eventTap:start() then
            log("Event tap started successfully")
        else
            log("ERROR: Failed to start event tap!")
        end
    end)
    
    eventCoroutine()
end

-- Start the event tap
createEventTap()

-- Set up a timer to periodically check event tap status
hs.timer.doEvery(config.logging.checkInterval, function()
    checkEventTapStatus()
    log(string.format("Status check - Event tap enabled: %s", 
        tostring(eventTap and eventTap:isEnabled())))
end)

-- Log initial state
log("Script initialized with the following settings:")
log(string.format("  Threshold: %.3f seconds", config.threshold))
for name, app in pairs(config.apps) do
    log(string.format("  %s: %s (%s)", 
        name:gsub("^%l", string.upper),
        app.action.description,
        table.concat(app.action.modifiers, "+") .. "+" .. app.action.key))
end

--- === WindowCache ===
---
--- Utility for quickly retrieving windows
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/WindowCache.spoon.zip
---
--- This uses a hs.window.filter to maintain a Least Recently Used cache which
--- can be searched either by window title or application name. This is useful
--- for automations which benefit from quick access to windows.
---
--- This was implemented based entirely off of the source of
--- [hs_select_window.spoon](https://github.com/dmgerman/hs_select_window.spoon)
--- and split out to be used across other Spoons.
--- 
--- Example Usage (Using [SpoonInstall](https://zzamboni.org/post/using-spoons-in-hammerspoon/)):
--- spoon.SpoonInstall:andUse(
---   "WindowCache",
---   {
---     start = true
---   }
--- )
local WindowCache = {}

WindowCache.__index = WindowCache

-- Metadata
WindowCache.name = "WindowCache"
WindowCache.version = "0.1"
WindowCache.author = "Adam Miller <adam@adammiller.io>"
WindowCache.homepage = "https://github.com/adammillerio/WindowCache.spoon"
WindowCache.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowCache.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
WindowCache.logger = nil

--- WindowCache.logLevel
--- Variable
--- WindowCache specific log level override, see hs.logger.setLogLevel for options.
WindowCache.logLevel = nil

--- WindowCache.windowFilter
--- Variable
--- Main hs.window.filter. This is what is used to enumerate and maintain the window
--- cache. It is a copy of the "default" window filter with WindowCache specific
--- sort order and callback configurations applied in the start method.
WindowCache.windowFilter = nil

--- WindowCache.currentWindows
--- Variable
--- Table containing the window cache, ordered by the time it was added to the
--- cache.
WindowCache.currentWindows = nil

--- WindowCache.subscribedFunctions
--- Variable
--- Table containing all subscribed instance callbacks for the window filter, used
--- during shutdown.
WindowCache.subscribedFunctions = nil

--- WindowCache:init()
--- Method
--- Spoon initializer method for WindowCache.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function WindowCache:init()
    self.currentWindows = {}
    self.subscribedFunctions = {}
end

--- WindowCache:findWindowByTitle(title)
--- Method
--- Find a window by title.
---
--- Parameters:
---  * title - title of the window to find
---
--- Returns:
---  * The `hs.window` object if found, `nil` otherwise
function WindowCache:findWindowByTitle(title)
    for i, currentWindow in ipairs(self.currentWindows) do
        if string.find(currentWindow:title(), title) then
            return currentWindow
        end
    end

    return nil
end

--- WindowCache:focusWindowByTitle(title)
--- Method
--- Find a window by title and focus it.
---
--- Parameters:
---  * title - title of the window to focus
---
--- Returns:
---  * The `hs.window` object focused if found, `nil` otherwise
function WindowCache:focusWindowByTitle(title)
    window = self:findWindowByTitle(title)

    if window then window:focus() end

    return window
end

--- WindowCache:findWindowByApp(appName)
--- Method
--- Find the last opened window by application name.
---
--- Parameters:
---  * appName - name of the application to find
---
--- Returns:
---  * The `hs.window` object if found, `nil` otherwise
function WindowCache:findWindowByApp(appName)
    for i, currentWindow in ipairs(self.currentWindows) do
        if string.find(currentWindow:application():name(), appName) then
            return currentWindow
        end
    end

    return nil
end

--- WindowCache:focusWindowByApp(appName)
--- Method
--- Find the last opened window by application name and focus it.
---
--- Parameters:
---  * appName - name of the application to find
---
--- Returns:
---  * The `hs.window` object focused if found, `nil` otherwise
function WindowCache:focusWindowByApp(appName)
    window = self:findWindowByApp(appName)

    if window then window.focus() end

    return window
end

-- Handler for a new window, which adds it to the cache in the first position.
function WindowCache:_callbackWindowCreated(window, appName, event)
    self.logger.vf("Caching created window %s", window)
    table.insert(self.currentWindows, 1, window)
end

-- Handler for a closed window, which removes it from the cache.
function WindowCache:_callbackWindowDestroyed(window, appName, event)
    for i, currentWindow in ipairs(self.currentWindows) do
        if currentWindow == window then
            self.logger.vf("Removing destroyed window: %s", window)
            table.remove(self.currentWindows, i)

            return
        end
    end

    -- No cached window.
    self.logger.wf("Could not find destroyed window in cache: %s", window)
end

-- Handler for an existing window being focused, which removes it from the table
-- at it's previous position and places it in front.
function WindowCache:_callbackWindowFocused(window, appName, event)
    self.logger.vf("Window focused: %s", window)
    self:_callbackWindowDestroyed(window, appName, "windowDestroyed")
    self:_callbackWindowCreated(window, appName, "windowCreated")
end

-- Utility function to allow for subscribing to callbacks at the instance level.
-- Creates a partial function with the callback call, including the instance, and
-- inserts it in a table to be unsubscribed later. Inputs are the hs.window.filter
-- event type, and the callback function.
function WindowCache:_subscribe(event, callback)
    partialFunction = hs.fnutils.partial(callback, self)
    self.windowFilter:subscribe(event, partialFunction)
    table.insert(self.subscribedFunctions, partialFunction)
end

-- Utility function to load all windows into the cache on initial load.
function WindowCache:_initialize()
    for i, window in ipairs(self.windowFilter:getWindows()) do
        self:_callbackWindowCreated(window, window:application():name(),
                                    "windowCreated")
    end
end

--- WindowCache:start()
--- Method
--- Spoon start method for WindowCache.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Configures the window filter, initializes the cache with all existing
---    windows, and then subscribes to all window related events to be cached.
function WindowCache:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("WindowCache")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting WindowCache")

    self.logger.v("Starting window filter")
    self.windowFilter = hs.window.filter.new(false)

    -- The {} instead of () is important here, this specifically includes windows
    -- in all spaces and not just the current space.
    self.windowFilter:setDefaultFilter{}
    self.windowFilter:setSortOrder(hs.window.filter.sortByFocusedLast)

    -- Initialize window cache.
    self:_initialize()

    -- Subscribe to the window events that relate to caching.
    self:_subscribe(hs.window.filter.windowCreated, self._callbackWindowCreated)
    self:_subscribe(hs.window.filter.windowDestroyed,
                    self._callbackWindowDestroyed)
    self:_subscribe(hs.window.filter.windowFocused, self._callbackWindowFocused)
end

--- WindowCache:stop()
--- Method
--- Spoon stop method for WindowCache.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Unsubscribes the window filter from all subscribed functions.
function WindowCache:stop()
    self.logger.v("Stopping WindowCache")

    self.logger.v("Stopping window filter")
    self.windowFilter:unsubscribe(nil, self.subscribedFunctions)
end

return WindowCache

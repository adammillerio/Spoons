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
WindowCache.version = "0.0.4"
WindowCache.author = "Adam Miller <adam@adammiller.io>"
WindowCache.homepage = "https://github.com/adammillerio/WindowCache.spoon"
WindowCache.license = "MIT - https://opensource.org/licenses/MIT"

--- WindowCache.staleWindowCheckInterval
--- Variable
--- Interval in seconds between checks for "stale" windows to be removed from
--- the cache.
WindowCache.staleWindowCheckInterval = 300

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

--- WindowCache.windowsBySpace
--- Variable
--- Table containing per-Space window caches, keyed off of Mission Control Space ID,
--- which can be used for retrieving Space-specific instances of apps and windows.
WindowCache.windowsBySpace = nil

--- WindowCache.staleWindowCheckTimer
--- Variable
--- hs.timer periodically running _checkForStaleWindows every staleWindowCheckInterval.
WindowCache.staleWindowCheckTimer = nil

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
    self.windowsBySpace = {}
end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function WindowCache:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

--- WindowCache:findWindowByTitle(title[, spaceID])
--- Method
--- Find a window by title.
---
--- Parameters:
---  * title - title of the window to find
---  * spaceID - optional ID of Space to access Space-specific cache for
---
--- Returns:
---  * The `hs.window` object if found, `nil` otherwise
function WindowCache:findWindowByTitle(title, spaceID)
    local currentWindows = nil

    if spaceID then
        -- Attempt to load space specific cache.
        currentWindows = self.windowsBySpace[spaceID]
        if not currentWindows then
            -- No cache for this space, return nil.
            return nil
        end
    else
        -- Use main cache.
        currentWindows = self.currentWindows
    end

    for i, currentWindow in ipairs(currentWindows) do
        if string.find(currentWindow:title(), title) then
            return currentWindow
        end
    end

    return nil
end

--- WindowCache:focusWindowByTitle(title[, spaceID])
--- Method
--- Find a window by title and focus it.
---
--- Parameters:
---  * title - title of the window to focus
---  * spaceID - optional ID of Space to access Space-specific cache for
---
--- Returns:
---  * The `hs.window` object focused if found, `nil` otherwise
function WindowCache:focusWindowByTitle(title, spaceID)
    window = self:findWindowByTitle(title, spaceID)

    if window then window:focus() end

    return window
end

--- WindowCache:findWindowByApp(appName[, spaceID])
--- Method
--- Find the last opened window by application name.
---
--- Parameters:
---  * appName - name of the application to find
---  * spaceID - optional ID of Space to access Space-specific cache for
---
--- Returns:
---  * The `hs.window` object if found, `nil` otherwise
function WindowCache:findWindowByApp(appName, spaceID)
    local currentWindows = nil

    if spaceID then
        -- Attempt to load space specific cache.
        currentWindows = self.windowsBySpace[spaceID]
        if not currentWindows then
            -- No cache for this space, return nil.
            return nil
        end
    else
        -- Use main cache.
        currentWindows = self.currentWindows
    end

    for i, currentWindow in ipairs(currentWindows) do
        local windowApp = currentWindow:application()
        if windowApp == nil then
            -- This is probably a "stale" window that will be pruned by the stale
            -- window checker soon, so skip it.
            self.logger
                .wf("Skipping stale window %s", hs.inspect(currentWindow))
            goto continue
        end

        if string.find(windowApp:name(), appName) then
            return currentWindow
        end

        ::continue::
    end

    return nil
end

--- WindowCache:waitForWindowByApp(appName, fn[, interval, spaceID])
--- Method
--- Wait for cached window in appName every interval and run fn when found.
---
--- Parameters:
---  * appName - name of the application to wait for first cached window of
---  * fn - function to run when first cached window is found. This function may
---    take a single argument, the timer itself
---  * interval - How often to check for cached window, defaults to 1 second.
---  * spaceID - optional ID of Space to access Space-specific cache for
---
--- Returns:
---  * The started `hs.timer` instance.
function WindowCache:waitForWindowByApp(appName, fn, interval, spaceID)
    return hs.timer.waitUntil(function()
        return self:findWindowByApp(appName, spaceID) ~= nil
    end, fn, interval)
end

--- WindowCache:focusWindowByApp(appName[, spaceID])
--- Method
--- Find the last opened window by application name and focus it.
---
--- Parameters:
---  * appName - name of the application to find
---  * spaceID - optional ID of Space to access Space-specific cache for
---
--- Returns:
---  * The `hs.window` object focused if found, `nil` otherwise
function WindowCache:focusWindowByApp(appName, spaceID)
    window = self:findWindowByApp(appName, spaceID)

    if window then window:focus() end

    return window
end

--- WindowCache:getAppNamesForSpace(spaceID)
--- Method
--- Given a spaceID, get a list of all open app names in the space.
---
--- Parameters:
---  * spaceID - ID of an hs.space to retrieve app names for.
---
--- Returns:
---  * A table representing the names of all app names open in the space, ordered
---    by most recent first.
---
--- Notes:
---  * WindowCache window access history does not persist through Hammerspoon reloads.
function WindowCache:getAppNamesForSpace(spaceID)
    local windowsBySpace = self.windowsBySpace[spaceID]
    if not windowsBySpace then
        self.logger.vf("No windows for space: %d", spaceID)
        return {}
    end

    local orderedAppNames = {}
    local appNamesSet = {}
    for _, window in ipairs(windowsBySpace) do
        local windowApp = window:application()
        if not windowApp then
            self.logger.wf("Skipping stale window: %s", window)
            goto continue
        end

        local appName = windowApp:name()
        if not appNamesSet[appName] then
            table.insert(orderedAppNames, appName)
            appNamesSet[appName] = true
        end

        ::continue::
    end

    return orderedAppNames
end

-- Add window to the cache, which places it at the front in in the main
-- currentWindows cache, as well as in any Space-specific caches.
function WindowCache:_addWindowToCache(window)
    self.logger.vf("Adding window to main cache %s", window)
    table.insert(self.currentWindows, 1, window)

    windowSpaces = hs.spaces.windowSpaces(window)
    if not windowSpaces then return end

    self.logger.vf("Caching window in Space(s): %s", hs.inspect(windowSpaces))
    for _, spaceID in ipairs(windowSpaces) do
        windowsBySpace = self.windowsBySpace[spaceID]
        if not windowsBySpace then
            windowsBySpace = {}
            self.windowsBySpace[spaceID] = windowsBySpace
        end

        table.insert(windowsBySpace, 1, window)
    end
end

-- Remove window from the cache, which removes it from the main currentWindows
-- cache, as well as any Space-specific caches.
function WindowCache:_deleteWindowFromCache(window)
    for i, currentWindow in ipairs(self.currentWindows) do
        if currentWindow:id() == window:id() then
            self.logger.vf("Deleting window from main cache: %s", window)
            table.remove(self.currentWindows, i)
            goto continue1
        end

        ::continue1::
    end

    windowSpaces = hs.spaces.windowSpaces(window)
    if not windowSpaces then return end

    self.logger.vf("Removing window from cache in Space(s): %s",
                   hs.inspect(windowSpaces))
    for _, spaceID in ipairs(windowSpaces) do
        windowsBySpace = self.windowsBySpace[spaceID]
        if not windowsBySpace then
            self.logger.vf("No windows in cache for space: %d", spaceID)
            goto continue2
        end

        for i, currentWindow in ipairs(windowsBySpace) do
            if currentWindow:id() == window:id() then
                self.logger.vf("Removing destroyed window in space %d", spaceID)
                table.remove(windowsBySpace, i)
            end
        end

        ::continue2::
    end
end

-- Check for and remove "stale" windows.
-- Sometimes windows seem to more or less be invalidated or disappear without
-- the filter catching them. This ultimately results in weird errors like not
-- being able to retrieve application name for filtering. This function runs every
-- staleWindowCheckInterval seconds to compare the cached windows against the
-- allowed windows from the filter and remove any "stale" matches.
function WindowCache:_checkForStaleWindows()
    -- Build a "set" of all the IDs of windows allowed by the current filter.
    local allWindowSet = {}
    for _, window in ipairs(self.windowFilter:getWindows()) do
        allWindowSet[window:id()] = true
    end

    for i, window in ipairs(self.currentWindows) do
        -- If this window isn't in the "set", delete it.
        if not allWindowSet[window:id()] then
            self.logger.wf("Removing stale window: %s", hs.inspect(window))
            self:_deleteWindowFromCache(window)
        end
    end
end

-- Handler for a new window, which adds it to the cache in the first position.
function WindowCache:_callbackWindowCreated(window, appName, event)
    self.logger.vf("Caching created window %s", window)
    self:_addWindowToCache(window)
end

-- Handler for a closed window, which removes it from the cache.
function WindowCache:_callbackWindowDestroyed(window, appName, event)
    self.logger.vf("Destroying window %s", window)
    self:_deleteWindowFromCache(window)
end

-- Handler for an existing window being focused, which removes it from the cache
-- at it's previous position and places it in front.
function WindowCache:_callbackWindowFocused(window, appName, event)
    self.logger.vf("Window focused: %s", window)
    self:_deleteWindowFromCache(window)
    self:_addWindowToCache(window)
end

-- Utility function to allow for subscribing to callbacks at the instance level.
-- Creates a partial function with the callback call, including the instance, and
-- inserts it in a table to be unsubscribed later. Inputs are the hs.window.filter
-- event type, and the callback function.
function WindowCache:_subscribe(event, callback)
    partialFunction = self:_instanceCallback(callback)
    self.windowFilter:subscribe(event, partialFunction)
    table.insert(self.subscribedFunctions, partialFunction)
end

-- Utility function to load all windows into the cache on initial load.
function WindowCache:_initialize()
    for i, window in ipairs(self.windowFilter:getWindows()) do
        self:_addWindowToCache(window)
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
---    windows, and then subscribes to all window related events to be cached. Also
---    starts the periodic stale window checker.
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

    self.logger.v("Starting stale window checker")
    self.staleWindowCheckTimer = hs.timer.doEvery(self.staleWindowCheckInterval,
                                                  self:_instanceCallback(
                                                      self._checkForStaleWindows))
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
---  * Unsubscribes the window filter from all subscribed functions and stops the
---    stale window checker.
function WindowCache:stop()
    self.logger.v("Stopping WindowCache")

    self.logger.v("Stopping window filter")
    self.windowFilter:unsubscribe(nil, self.subscribedFunctions)

    self.logger.v("Stopping stale window checker")
    if self.staleWindowChecker then self.staleWindowChecker:stop() end
end

return WindowCache

--- === Sweeper ===
---
--- Automatically hide apps that are out of focus.
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/Sweeper.spoon.zip
---
--- This uses a hs.window.filter to detect windows that have gone out of focus. Then,
--- if they are configured to be "swept" in the apps config, they will be automatically
--- hidden if they remain out of focus after sweepCheckInterval (default 15 seconds).
---
--- Example Usage (Using [SpoonInstall](https://zzamboni.org/post/using-spoons-in-hammerspoon/)):
--- spoon.SpoonInstall:andUse(
---   "Sweeper",
---   {
---     start = true
---   }
--- )
local Sweeper = {}

Sweeper.__index = Sweeper

-- Metadata
Sweeper.name = "Sweeper"
Sweeper.version = "0.0.2"
Sweeper.author = "Adam Miller <adam@adammiller.io>"
Sweeper.homepage = "https://github.com/adammillerio/Sweeper.spoon"
Sweeper.license = "MIT - https://opensource.org/licenses/MIT"

--- Sweeper.apps
--- Variable
--- Table containing each application's name and it's desired configuration. The
--- key of each entry is the name of the application, and the value is a
--- configuration table with the following entries:
---  * sweep - If true, this application will be swept.
---  * sweepCheckInterval - Override time in seconds for global `Sweeper.sweepCheckInterval`.
Sweeper.apps = nil

--- Sweeper.sweepCheckInterval
--- Variable
--- Time in seconds to wait after a window loses focus to check if it should be swept.
Sweeper.sweepCheckInterval = 15

--- Sweeper.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
Sweeper.logger = nil

--- Sweeper.logLevel
--- Variable
--- Sweeper specific log level override, see hs.logger.setLogLevel for options.
Sweeper.logLevel = nil

--- Sweeper.windowFilter
--- Variable
--- Main hs.window.filter. This is what is used to detect and action on unfocused
--- windows. It is a copy of the "default" window filter with Sweeper specific
--- sort order and callback configurations applied in the start method.
Sweeper.windowFilter = nil

--- Sweeper.subscribedFunctions
--- Variable
--- Table containing all subscribed instance callbacks for the window filter, used
--- during shutdown.
Sweeper.subscribedFunctions = nil

--- Sweeper:init()
--- Method
--- Spoon initializer method for Sweeper.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Sweeper:init() self.subscribedFunctions = {} end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function Sweeper:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Sweep a window. This checks if the window is still not focused and then hides
-- the application.
-- Input is the hs.window to be swept.
function Sweeper:_sweepWindow(window)
    self.logger.vf("Sweeping window: %s", window)

    local windowApp = window:application()
    if windowApp == nil then
        -- This is probably a "stale" window, so skip it.
        self.logger.wf("Skipping stale window %s", hs.inspect(window))
        return
    end

    if windowApp:isFrontmost() then
        self.logger.vf("Window's app is still in focus, not sweeping: %s",
                       window)
    elseif hs.window.focusedWindow():id() == window:id() then
        self.logger.vf("Window back in focus, not sweeping: %s", window)
    else
        windowApp:hide()
    end
end

-- Initiate a sweep check for a window that has lost focus. This will set a timer
-- for either the global or overridden sweepCheckInterval seconds to perform
-- sweep actions on a window.
-- Inputs are the hs.window and the app config.
function Sweeper:_actionUnfocusedWindow(window, config)
    if config.sweep then
        local sweepCheckInterval = config.sweepCheckInterval
        if not sweepCheckInterval then
            sweepCheckInterval = self.sweepCheckInterval
        end

        self.logger.vf("Registering sweep timer after %d seconds for: %s",
                       sweepCheckInterval, window)
        local sweepTimer = hs.timer.doAfter(sweepCheckInterval,
                                            self:_instanceCallback(
                                                self._sweepWindow, window))
    end
end

-- Handler for a window losing focus. This checks if the window's application is
-- configured for Sweeper and begins to initiate the sweep check if needed.
function Sweeper:_callbackWindowUnfocused(window, appName, event)
    self.logger.vf("Window unfocused: %s", window)

    local app = window:application()
    if app == nil then
        -- This is probably a "stale" window or one that stopped existing
        -- quickly after being unfocused.
        self.logger.wf("Skipping stale window: %s", hs.inspect(currentWindow))
        return
    end

    appName = window:application():name()
    appConfig = self.apps[appName]

    if appConfig then
        self.logger.vf("Sweeping unfocused window for %s: %s", appName, window)
        self:_actionUnfocusedWindow(window, appConfig)
    end
end

-- Utility function to allow for subscribing to callbacks at the instance level.
-- Creates a partial function with the callback call, including the instance, and
-- inserts it in a table to be unsubscribed later. Inputs are the hs.window.filter
-- event type, and the callback function.
function Sweeper:_subscribe(event, callback)
    partialFunction = self:_instanceCallback(callback)
    self.windowFilter:subscribe(event, partialFunction)
    table.insert(self.subscribedFunctions, partialFunction)
end

--- Sweeper:start()
--- Method
--- Spoon start method for Sweeper.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Configures the window filter, and subscribes to all window unfocus events.
function Sweeper:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("Sweeper")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting Sweeper")

    self.logger.v("Starting window filter")
    self.windowFilter = hs.window.filter.new(false)

    -- The {} instead of () is important here, this specifically includes windows
    -- in all spaces and not just the current space.
    self.windowFilter:setDefaultFilter{}
    self.windowFilter:setSortOrder(hs.window.filter.sortByFocusedLast)

    -- Subscribe to window unfocus events for sweep checks.
    self:_subscribe(hs.window.filter.windowUnfocused,
                    self._callbackWindowUnfocused)
end

--- Sweeper:stop()
--- Method
--- Spoon stop method for Sweeper.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Unsubscribes the window filter from all subscribed functions.
function Sweeper:stop()
    self.logger.v("Stopping Sweeper")

    self.logger.v("Stopping window filter")
    self.windowFilter:unsubscribe(nil, self.subscribedFunctions)
end

return Sweeper

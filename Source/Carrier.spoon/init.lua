--- === Carrier ===
---
--- Automatically hide apps that are out of focus.
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/Carrier.spoon.zip
---
--- This uses a hs.window.filter to detect windows that have gone out of focus. Then,
--- if they are configured to be "swept" in the apps config, they will be automatically
--- hidden if they remain out of focus after sweepCheckInterval (default 15 seconds).
--- 
--- README with example usage: [README.md](https://github.com/adammillerio/Carrier.spoon/blob/main/README.md)
local Carrier = {}

Carrier.__index = Carrier

-- Metadata
Carrier.name = "Carrier"
Carrier.version = "0.0.1"
Carrier.author = "Adam Miller <adam@adammiller.io>"
Carrier.homepage = "https://github.com/adammillerio/Carrier.spoon"
Carrier.license = "MIT - https://opensource.org/licenses/MIT"

-- Dependency Spoons
-- EnsureApp is used for handling app movements when showing/hiding.
EnsureApp = spoon.EnsureApp

--- Carrier.apps
--- Variable
--- Table containing each application's name and it's desired configuration. The
--- key of each entry is the name of the application, and the value is a
--- configuration table with the following entries:
---  * carry - If true, this application will be carried on Space change.
Carrier.apps = nil

--- Carrier.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
Carrier.logger = nil

--- Carrier.logLevel
--- Variable
--- Carrier specific log level override, see hs.logger.setLogLevel for options.
Carrier.logLevel = nil

--- Carrier.spaceWatcher
--- Variable
--- hs.spaces.watcher instance used for monitoring for space changes.
Carrier.spaceWatcher = nil

--- Carrier.carryApps
--- Variable
--- Table containing the name of every app to carry on space change.
Carrier.carryApps = nil

--- Carrier:init()
--- Method
--- Spoon initializer method for Carrier.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Carrier:init() self.carryApps = {} end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function Carrier:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Carry all configured apps. This just calls ensureApp on every configured app,
-- disabling focus so they do not show up in front on the new space.
function Carrier:_carryApps()
    for _, app in ipairs(self.carryApps) do
        -- Disable app focus since we don't want that on carry.
        EnsureApp:ensureApp(app, {skipFocus = true})
    end
end

--- Carrier:start()
--- Method
--- Spoon start method for Carrier.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Configures the window filter, and subscribes to all window unfocus events.
function Carrier:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("Carrier")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting Carrier")

    for app, config in pairs(self.apps) do
        -- Build the table of app names to carry (ensure).
        if config.carry then table.insert(self.carryApps, app) end
    end

    -- Set space watcher to call handler on space change.
    self.logger.v("Creating and starting space watcher")
    self.spaceWatcher = hs.spaces.watcher.new(
                            self:_instanceCallback(self._carryApps))

    self.spaceWatcher:start()
end

--- Carrier:stop()
--- Method
--- Spoon stop method for Carrier.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Unsubscribes the window filter from all subscribed functions.
function Carrier:stop()
    self.logger.v("Stopping Carrier")

    self.logger.v("Stopping space watcher")
    self.spaceWatcher:stop()
end

return Carrier

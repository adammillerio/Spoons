--- === MenuBarApps ===
---
--- Control applications from the macOS Menu Bar 
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/MenuBarApps.spoon.zip
---
--- Example Usage (Using [SpoonInstall](https://zzamboni.org/post/using-spoons-in-hammerspoon/)):
--- Create a "P" menu bar item that opens and moves Plexamp and create a "D" menu
--- bar item that opens and maximizes Discord.
--- spoon.SpoonInstall:andUse(
---   "MenuBarApps",
---   {
---     config = {
---       apps = {
---         ["Plexamp"] = {
---           title = "P",
---           action = "move"
---         },
---         ["Discord"] = {
---           title = "D",
---           action = "maximize"
---         }
---       }
---     },
---     start = true
---   }
--- )
local MenuBarApps = {}

MenuBarApps.__index = MenuBarApps

-- Metadata
MenuBarApps.name = "MenuBarApps"
MenuBarApps.version = "0.1"
MenuBarApps.author = "Adam Miller <adam@adammiller.io>"
MenuBarApps.homepage = "https://github.com/adammillerio/MenuBarApps.spoon"
MenuBarApps.license = "MIT - https://opensource.org/licenses/MIT"

-- Dependency Spoons
-- WindowCache is used for quick retrieval of windows when showing/hiding.
WindowCache = spoon.WindowCache

--- MenuBarApps.action.move
--- Constant
--- Move the window to appear under the menu bar item as if it were a menu.

--- MenuBarApps.action.maximize
--- Constant
--- Maximize the application on the current space if it is not maximized already.

local actions = {move = "move", maximize = "maximize"}

for k in pairs(actions) do MenuBarApps[k] = k end -- expose actions

--- MenuBarApps.apps
--- Variable
--- Table containing each application's name and it's desired configuration. The
--- key of each entry is the name of the App as it appears in the title bar, and
--- the value is a configuration table with the following entries:
---     * title - String with title text to display in the menu bar icon itself
---     * action - String with action to take on window when showing. See constants.
MenuBarApps.apps = nil

--- MenuBarApps.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log 
--- level for the messages coming from the Spoon.
MenuBarApps.logger = nil

--- MenuBarApps.logLevel
--- Variable
--- MenuBarApps specific log level override, see hs.logger.setLogLevel for options.
MenuBarApps.logLevel = nil

--- MenuBarApps.menuBars
--- Variable
--- Table containing references to all of the created menu bars.
MenuBarApps.menuBars = nil

--- MenuBarApps:init()
--- Method
--- Spoon initializer method for MenuBarApps.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function MenuBarApps:init() self.menuBars = {} end

-- Handler for a menu bar click.
-- Inputs are the hs.menubar clicked and the configured appName and config.
function MenuBarApps:_menuBarClicked(menuBar, appName, config)
    -- Get app hs.window
    appWindow = WindowCache:findWindowByApp(appName)
    if not appWindow then
        self.logger.ef("%s is not open or hidden", appName)
        return
    end

    -- Get app's application
    app = appWindow:application()

    -- If this window is not the frontmost window, then we need to act on it
    if hs.window.frontmostWindow():id() ~= appWindow:id() then
        -- Move the window to the currently focused space.
        hs.spaces.moveWindowToSpace(appWindow, hs.spaces.focusedSpace())

        -- move mode - This moves the application under the menu bar item so that it
        -- appears like a menu
        if config.action == actions.move then
            -- Get rect representing the frame of the app window
            appWindowFrame = appWindow:frame()
            -- Get rect representing the frame of the menubar item
            appMenuBarFrame = menuBar:frame()

            -- move() only moves in absolute coordinates if a rect is provided, so we
            -- just update the appWindowFrame rect's x coordinate to be such that it is
            -- under the menubar item, aligned to the right.
            appWindowFrame.x = appMenuBarFrame.x -
                                   (appWindowFrame.w - appMenuBarFrame.w)
            -- Do a similar transformation for y
            appWindowFrame.y = appMenuBarFrame.y + appMenuBarFrame.h

            -- Move the window to the desired location
            appWindow:move(appWindowFrame)
            -- maximize mode - This just maxmizes the app if it isn't already
        elseif config.action == actions.maximize then
            if appWindow:isMaximizable() then appWindow:maximize() end
        else
            self.logger.ef("Unknown action %s", config.action)
        end

        app:activate()
    else
        app:hide()
    end
end

-- Utility method for creating a new menu bar and adding it to the table.
-- Inputs are the configured appName and it's config.
function MenuBarApps:_createMenuBar(appName, config)
    self.logger.vf("Creating MenuBar App for \"%s\" with config: %s", appName,
                   hs.inspect(config))

    menuBar = hs.menubar.new()

    menuBar:setClickCallback(function()
        self:_menuBarClicked(menuBar, appName, config)
    end)
    menuBar:setTitle(config.title)

    table.insert(self.menuBars, menuBar)
end

--- MenuBarApps:start()
--- Method
--- Spoon start method for MenuBarApps. Creates all configured menu bars.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function MenuBarApps:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("MenuBarApps")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting MenuBarApps")

    for appName, config in pairs(self.apps) do
        self:_createMenuBar(appName, config)
    end
end

--- MenuBarApps:stop()
--- Method
--- Spoon stop method for MenuBarApps. Deletes all configured menu bars.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function MenuBarApps:stop()
    self.logger.v("Stopping MenuBarApps")

    for i, menuBar in ipairs(self.menuBars) do menuBar:delete() end
end

return MenuBarApps

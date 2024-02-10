--- === MenuBarApps ===
---
--- Control applications from the macOS Menu Bar 
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/MenuBarApps.spoon.zip
--- 
--- README with Example Usage: [README.md](https://github.com/adammillerio/MenuBarApps.spoon/blob/main/README.md)
local MenuBarApps = {}

MenuBarApps.__index = MenuBarApps

-- Metadata
MenuBarApps.name = "MenuBarApps"
MenuBarApps.version = "0.0.2"
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

--- MenuBarApps.menuBarOpenTimer
--- Variable
--- hs.timer for moving an app's first window after being opened via MenuBarApps.
--- This behavior can be disabled by setting disableOpen=true on the app config.
MenuBarApps.menuBarOpenTimer = nil

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

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function MenuBarApps:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Action a menu item's window. This performs whatever action is needed on an
-- app's window after being migrated to the current space.
-- Inputs are the hs.menubar, app config, the hs.application to action on, and
-- the hs.window to action on.
function MenuBarApps:_actionMenuItem(menuBar, config, app, appWindow)
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

    -- Focus the window.
    appWindow:focus()
end

-- Retrieve and move a window from an app to the currently focused space.
-- Invoked after opening the app, this retrieves the cached window for this app
-- and moves it to the currently focused space.
-- Inputs are the hs.menubar, app config, currently focused space ID, the
-- hs.application to action on.
function MenuBarApps:_getAndMoveOpenedAppWindow(menuBar, config,
                                                currentlyFocusedSpace, app)
    if config.spacePrecedence then
        -- Get the latest window specifically for this space.
        spaceID = currentlyFocusedSpace
    else
        -- Otherwise just get the latest in general.
        spaceID = nil
    end

    appWindow = WindowCache:findWindowByApp(config.app, spaceID)
    if not appWindow then
        self.logger.ef("No window for app %s open, cannot continue", config.app)
        return
    end

    self:_moveOpenedAppWindow(menuBar, config, currentlyFocusedSpace, app,
                              appWindow)
end

-- Move an existing opened app window to the currently focused space.
-- Invoked directly from the menu bar handler, this will move the retrieved window
-- for this app to the currently focused space.
-- Inputs are the hs.menubar, app config, currently focused space ID, the
-- hs.application to action on, and the hs.window to action on.
function MenuBarApps:_moveOpenedAppWindow(menuBar, config,
                                          currentlyFocusedSpace, app, appWindow)
    -- Move the window to the currently focused space.
    hs.spaces.moveWindowToSpace(appWindow, currentlyFocusedSpace)

    self:_actionMenuItem(menuBar, config, app, appWindow)
end

-- Open a new window for the running app in the current Space.
-- Invoked from the menu bar handler for applications which have space precedence
-- enabled, this will look at the newWindowConfig for the given app to determine
-- the menu item to select which will open a new window in the current Space. It
-- will then wait for a window from this app to appear in the Space and then action
-- on it.
-- Inputs are the hs.menubar, app config, currently focused space ID, and the
-- hs.application to action on.
function MenuBarApps:_openNewWindowInSpace(menuBar, config,
                                           currentlyFocusedSpace, app)
    newWindowConfig = config.newWindowConfig
    if not newWindowConfig then
        self.logger.ef(
            "No newWindowConfig defined for app %s, cannot open new window in space",
            config.app)
        return
    end

    menuSection = newWindowConfig.menuSection
    menuItem = newWindowConfig.menuItem
    if menuSection and menuItem then
        self.logger.vf("Selecting menu item '%s' in section '%s' in app '%s'",
                       menuItem, menuSection, config.app)
        selected = app:selectMenuItem({menuSection, menuItem})

        if not selected then
            self.logger.wf(
                "Could not find menu item '%s' in section '%s' in app '%s'",
                self.menuItem, self.menuSection, config.app)

            return
        end
    end

    -- Wait for a window from this app to appear in the Space and continue the
    -- action flow.
    self.menuBarOpenTimer = WindowCache:waitForWindowByApp(appName,
                                                           self:_instanceCallback(
                                                               self._getAndMoveOpenedAppWindow,
                                                               menuBar, config,
                                                               currentlyFocusedSpace,
                                                               app), nil,
                                                           currentlyFocusedSpace)
end

-- Handler for a menu bar click.
-- Inputs are the hs.menubar clicked and the configured appName and config.
function MenuBarApps:_menuBarClicked(menuBar, appName, config)
    -- Store the focused space from before we start the action flow. This helps
    -- when apps try to force themselves to open in another space which will change
    -- the focused space during app open.
    currentlyFocusedSpace = hs.spaces.focusedSpace()

    -- Get app hs.window
    self.logger.vf("Finding open window for app %s", appName)

    spaceWindowNeeded = false
    if config.spacePrecedence then
        -- Search the Space-specific window cache for a window from this app.
        appWindow = WindowCache:findWindowByApp(appName, currentlyFocusedSpace)

        if not appWindow then
            -- Search the main cache to find any instance of a window from this
            -- app, so we can use it to open another one.
            appWindow = WindowCache:findWindowByApp(appName)
            if appWindow then
                -- We found an existing window, and need to make a new one for
                -- this space.
                spaceWindowNeeded = true
            end
        end
    else
        -- Otherwise, just search the main cache for whichever window is latest.
        appWindow = WindowCache:findWindowByApp(appName)
    end

    -- If we could not find a cached window for the app of this menu bar.
    if not appWindow then
        if config.disableOpen then
            -- Open is disabled and no window, cannot continue.
            self.logger.wf(
                "%s is not open or hidden and open disabled, cannot continue",
                appName)
            return
        else
            -- Attempt to open app by name.
            self.logger.vf("Opening application %s", appName)
            app = hs.application.open(appName)
            if not app then
                -- No application with this name exists, cannot continue.
                self.logger.ef("No application named %s could be opened",
                               appName)
                return
            end

            -- Indicate the app was opened during this run.
            appOpened = true
        end
    else
        -- If we can, get the window app's application
        app = appWindow:application()
        appOpened = false
    end

    if appOpened then
        -- If this is a "fresh" open, we instead tell WindowCache to only continue
        -- the action flow once it can find a window from the app in it. This is
        -- implicitly Space local, so it does not need to check precedence.
        self.menuBarOpenTimer = WindowCache:waitForWindowByApp(appName,
                                                               self:_instanceCallback(
                                                                   self._getAndMoveOpenedAppWindow,
                                                                   menuBar,
                                                                   config,
                                                                   currentlyFocusedSpace,
                                                                   app))
    elseif config.spacePrecedence and spaceWindowNeeded then
        -- If the app is running but has no window in this Space, and spacePrecedence
        -- is enabled, then open a new window for this app in this Space.
        self:_openNewWindowInSpace(menuBar, config, currentlyFocusedSpace, app)
    elseif hs.window.frontmostWindow():id() ~= appWindow:id() then
        -- If this window already exists but is not the frontmost window, then we
        -- need to act on it, and move the window to the currently focused space.
        self:_moveOpenedAppWindow(menuBar, config, currentlyFocusedSpace, app,
                                  appWindow)
    else
        -- Otherwise just hide the app if it existed and was at the front.
        app:hide()
    end
end

-- Generate a sub menu for a menu bar.
-- Input is the menuConfig.
function MenuBarApps:_createMenu(menuConfig)
    self.logger.vf("Creating menu with config: %s", hs.inspect(menuConfig))
    local menu = {}

    for _, config in ipairs(menuConfig) do
        self.logger.vf("Creating menuItem config: %s", hs.inspect(config))
        local menuItem = {}

        if config.action ~= "menu" then
            self.logger
                .vf("Setting menu item to config: %s", hs.inspect(config))
            menuItem.fn = self:_instanceCallback(self._menuBarClicked, menuBar,
                                                 config.app, config)
        else
            self.logger.vf("Creating new child menu with config: %s",
                           hs.inspect(config.menu))
            menuItem.menu = self:_createMenu(config.menu)
        end

        menuItem.title = config.title

        self.logger.vf("Adding menu item: %s", hs.inspect(menuItem))
        table.insert(menu, menuItem)
    end

    self.logger.vf("Generated menu: %s", hs.inspect(menu))
    return menu
end

-- Utility method for creating a new menu bar and adding it to the table.
-- Input is the menu config.
function MenuBarApps:_createMenuBar(config)
    self.logger.vf("Creating MenuBar with config: %s", hs.inspect(config))

    menuBar = hs.menubar.new()

    if config.action ~= "menu" then
        self.logger.vf("(%s) Not Menu: Setting item click callback",
                       config.title)
        menuBar:setClickCallback(self:_instanceCallback(self._menuBarClicked,
                                                        menuBar, config.app,
                                                        config))
    else
        self.logger.vf("(%s) Menu: Generating main menu", config.title)
        menuBar:setMenu(self:_createMenu(config.menu))
    end

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

    for _, config in ipairs(self.apps) do self:_createMenuBar(config) end
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

    if self.menuBarOpenTimer then self.menuBarOpenTimer:stop() end
end

return MenuBarApps

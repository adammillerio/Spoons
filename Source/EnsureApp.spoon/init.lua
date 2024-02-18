--- === EnsureApp ===
---
--- Utility for providing fast and guaranteed access to app windows during macros.
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/EnsureApp.spoon.zip
--- 
--- README with Example Usage: [README.md](https://github.com/adammillerio/EnsureApp.spoon/blob/main/README.md)
local EnsureApp = {}

EnsureApp.__index = EnsureApp

-- Metadata
EnsureApp.name = "EnsureApp"
EnsureApp.version = "0.0.3"
EnsureApp.author = "Adam Miller <adam@adammiller.io>"
EnsureApp.homepage = "https://github.com/adammillerio/EnsureApp.spoon"
EnsureApp.license = "MIT - https://opensource.org/licenses/MIT"

-- Dependency Spoons
-- WindowCache is used for quick retrieval of windows when showing/hiding.
WindowCache = spoon.WindowCache

--- EnsureApp.action.move
--- Constant
--- Move the window to appear under the provided frame as if it were a menu. This
--- requires the actionConfig `moveMenuBar` to be set to the destination hs.menubar
--- during calls to ensureApp().

--- EnsureApp.action.maximize
--- Constant
--- Maximize the application on the current space if it is not maximized already.

--- EnsureApp.action.none
--- Constant
--- No-op, will do no action other than moving window to the space and focusing
--- it (if enabled).

local actions = {move = "move", maximize = "maximize", none = "none"}

for k in pairs(actions) do EnsureApp[k] = k end -- expose actions

--- EnsureApp.apps
--- Variable
--- Table containing each application's name and it's desired configuration. The
--- key of each entry is just an identifier used during calls to ensureApp, and
--- the value is a configuration table with the following entries:
---  * app - Application name as it appears in the title bar.
---  * action - String with action to take on window when showing. See constants.
---  * spacePrecedence - Open a Space-specific window of this app, requires newWindowConfig.
---  * newWindowConfig - Configuration for opening a new window of the app with values.
---    * menuSection - Menu section in app menu bar to select.
---    * menuItem - Menu item in menu section to select
---  * disableOpen - If true, this will disable auto-opening the app if not open.
EnsureApp.apps = nil

--- EnsureApp.defaultAppConfig
--- Variable
--- Table containing the default configuration to be used for any app that is not
--- configured in self.apps with app-specific config. By default, this will move
--- the most recently accessed window in any space to the current one and focus it.
EnsureApp.defaultAppConfig = {action = "none"}

--- EnsureApp.appNamesSet
--- Variable
--- Table with "Set" of all app names configured for EnsureApp.
EnsureApp.appNamesSet = nil

--- EnsureApp.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log 
--- level for the messages coming from the Spoon.
EnsureApp.logger = nil

--- EnsureApp.logLevel
--- Variable
--- EnsureApp specific log level override, see hs.logger.setLogLevel for options.
EnsureApp.logLevel = nil

--- EnsureApp.windowOpenTimer
--- Variable
--- hs.timer for moving an app's first window after being opened via EnsureApp.
--- This behavior can be disabled by setting disableOpen=true on the app config.
EnsureApp.windowOpenTimer = nil

--- EnsureApp:init()
--- Method
--- Spoon initializer method for EnsureApp.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function EnsureApp:init() self.appNamesSet = {} end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function EnsureApp:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Action a window. This performs whatever action is needed on an app's window 
-- after being migrated to the current space.
-- Inputs are the app config, action specific config, the hs.application to action
-- on, and the hs.window to action on.
function EnsureApp:_actionWindow(config, actionConfig, app, appWindow)
    -- move mode - This moves the application under the supplied moveMenuBar so that
    -- it appears like a menu
    if config.action == actions.move then
        local appMenuBarFrame = nil
        if actionConfig then
            -- Get the hs.menubar to moe the window to from the supplied actionConfig.
            local appMoveMenuBar = actionConfig.moveMenuBar
            if not appMoveMenuBar then
                self.logger.ef(
                    "No moveMenuBar provided for move action for app %s",
                    config.app)
                -- Focus the window anyway just as a fallback.
                appWindow:focus()
                return
            end

            -- Get rect representing the hs.menubar frame.
            appMenuBarFrame = appMoveMenuBar:frame()
        else
            self.logger.ef(
                "No actionConfig provided for move action for app %s",
                config.app)
            -- Focus the window anyway just as a fallback.
            appWindow:focus()
            return
        end

        -- Get rect representing the frame of the app window
        local appWindowFrame = appWindow:frame()

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
        if config.action == actions.none then
            self.logger.vf("None action, executing no actions for app: %s",
                           config.app)
        else
            self.logger.ef("Unknown action %s", action)
            return
        end
    end

    if actionConfig then
        -- Don't focus if the user specified not to for this ensure action.
        if actionConfig.skipFocus then
            self.logger.vf("Skipping app window focus after ensure")
            return
        end
    end

    -- Focus the window.
    appWindow:focus()
end

-- Retrieve and move a window from an app to the currently focused space.
-- Invoked after opening the app, this retrieves the cached window for this app
-- and moves it to the currently focused space.
-- Inputs are the app config, action specific config, currently focused space ID,
-- and the hs.application to action on.
function EnsureApp:_getAndMoveOpenedAppWindow(config, actionConfig,
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

    self:_moveOpenedAppWindow(config, actionConfig, currentlyFocusedSpace, app,
                              appWindow)
end

-- Move an existing opened app window to the currently focused space.
-- Invoked directly on an existing window, this will move the retrieved window
-- for this app to the currently focused space.
-- Inputs are the app config, action specific config, currently focused space
-- ID, the hs.application to action on, and the hs.window to action on.
function EnsureApp:_moveOpenedAppWindow(config, actionConfig,
                                        currentlyFocusedSpace, app, appWindow)
    -- Move the window to the currently focused space.
    hs.spaces.moveWindowToSpace(appWindow, currentlyFocusedSpace)

    self:_actionWindow(config, actionConfig, app, appWindow)
end

-- Open a new window for the running app in the current Space.
-- For applications which have space precedence enabled, this will look at the 
-- newWindowConfig for the given app to determine the menu item to select which
-- will open a new window in the current Space. It will then wait for a window 
-- from this app to appear in the Space and then action on it.
-- Inputs are the app config, action specific config, currently focused space ID,
-- and the hs.application to action on.
function EnsureApp:_openNewWindowInSpace(config, actionConfig,
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
    self.windowOpenTimer = WindowCache:waitForWindowByApp(appName,
                                                          self:_instanceCallback(
                                                              self._getAndMoveOpenedAppWindow,
                                                              config,
                                                              actionConfig,
                                                              currentlyFocusedSpace,
                                                              app), nil,
                                                          currentlyFocusedSpace)
end

--- EnsureApp:ensureAppCallback(appName[, actionConfig])
--- Method
--- (Callback) Ensure the existence of a window from appName in the current Space.
---
--- Parameters:
---  * appName - Name of the application to ensure.
---  * actionConfig - Optional actionConfig table with action-specific information.
---    * moveMenuBar- hs.menubar to move under with `action=move`.
---
--- Returns:
---  * None
---
--- Notes:
---  * This is a utility class for mapping app ensures to things like menu bars.
---  * Refer to EnsureApp.apps for information on how to configure apps.
function EnsureApp:ensureAppCallback(appName, actionConfig)
    return self:_instanceCallback(self.ensureApp, appName, actionConfig)
end

--- EnsureApp:ensureApp(appName[, actionConfig])
--- Method
--- Ensure the existence of a window from appName in the current Space.
---
--- Parameters:
---  * appName - Name of the application to ensure.
---  * actionConfig - Optional actionConfig table with action-specific information.
---    * moveMenuBar- hs.menubar to move under with `action=move`.
---
--- Returns:
---  * None
---
--- Notes:
---  * The application name must be one recognized by macOS. hs.applications.find
---    way to discover this.
---  * The default action is to move the most recently accessed window in any space
---    corresponding to this application to the current space and focus it.
---     * This can be configured with defaultAppConfig.
---  * Refer to EnsureApp.apps for information on how to add additional app-specific
---    configurations like space precedence.
function EnsureApp:ensureApp(appName, actionConfig)
    local config = self.apps[appName]
    if not config then
        self.logger.ef(
            "No EnsureApp configuration for %s, using default config (this is best-effort)",
            appName)
        config = hs.fnutils.copy(self.defaultAppConfig)
        -- Set the app to whatever appName we got.
        config.app = appName
    end

    -- Store the focused space from before we start the action flow. This helps
    -- when apps try to force themselves to open in another space which will change
    -- the focused space during app open.
    currentlyFocusedSpace = hs.spaces.focusedSpace()

    -- Fullscreen/tiled spaces cannot support ensuring apps and will actually
    -- just cause an endless loop of more apps trying to go fullscreen.
    if hs.spaces.spaceType(currentlyFocusedSpace) == "fullscreen" then
        self.logger.v("In fullscreen space, skipping ensure action")
        return
    end

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

    -- If we could not find a cached window for the app.
    local app = nil
    if not appWindow then
        if config.disableOpen or (actionConfig and actionConfig.disableOpen) then
            -- Open is disabled and no window, cannot continue.
            self.logger.wf(
                "%s is not open or hidden and open disabled, cannot continue",
                appName)
            return
        else
            -- Attempt to open app by name.
            self.logger.vf("Opening application %s", config.app)
            app = hs.application.open(config.app)
            if not app then
                -- No application with this name exists, cannot continue.
                self.logger.ef("No application named %s could be opened",
                               config.app)
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
        self.windowOpenTimer = WindowCache:waitForWindowByApp(appName,
                                                              self:_instanceCallback(
                                                                  self._getAndMoveOpenedAppWindow,
                                                                  config,
                                                                  actionConfig,
                                                                  currentlyFocusedSpace,
                                                                  app))
    elseif config.spacePrecedence and spaceWindowNeeded then
        -- If the app is running but has no window in this Space, and spacePrecedence
        -- is enabled, then open a new window for this app in this Space.
        self:_openNewWindowInSpace(config, actionConfig, currentlyFocusedSpace,
                                   app)
    elseif hs.window.frontmostWindow():id() ~= appWindow:id() then
        -- If this window already exists but is not the frontmost window, then we
        -- need to act on it, and move the window to the currently focused space.
        self:_moveOpenedAppWindow(config, actionConfig, currentlyFocusedSpace,
                                  app, appWindow)
    else
        -- Otherwise just hide the app if it existed and was at the front.
        app:hide()
    end
end

--- EnsureApp:getAppNames([spaceID])
--- Method
--- Get a list of all app names currently configured in EnsureApps.
---
--- Parameters:
---  * spaceID - Optional space ID. If provided, WindowCache will be queried to
---     find apps present in the provided space. These will then be placed at the
---     beginning of the list before the rest of the configured apps are filled.
---     This is useful for things like Lightspot.spoon.
---
--- Returns:
---  * A table representing the names of all configured app names, with recent apps
---    in the current space being prioritized if spaceID is provided.
---
--- Notes:
---  * WindowCache window access history does not persist through Hammerspoon reloads.
function EnsureApp:getAppNames(spaceID)
    local orderedAppNames = {}
    local appNamesSet = {}

    if spaceID then
        local recentAppNamesForSpace = self:getAppNamesForSpace(spaceID)
        for _, appName in ipairs(recentAppNamesForSpace) do
            table.insert(orderedAppNames, appName)
            appNamesSet[appName] = true
        end
    end

    for appName, _ in pairs(self.apps) do
        if not appNamesSet[appName] then
            table.insert(orderedAppNames, appName)
        end
    end

    return orderedAppNames
end

--- EnsureApp:getAppNamesForSpace(spaceID)
--- Method
--- Given a spaceID, return the name of all configured apps present in the space.
---
--- Parameters:
---  * spaceID - ID of an hs.space to retrieve ensured app names for.
---
--- Returns:
---  * A table representing the names of all ensured apps currently present in the
---    space, ordered by most recent first.
function EnsureApp:getAppNamesForSpace(spaceID)
    local appNamesForSpace = WindowCache:getAppNamesForSpace(spaceID)

    local ensuredAppNamesForSpace = {}
    for _, appName in ipairs(appNamesForSpace) do
        if self.apps[appName] then
            table.insert(ensuredAppNamesForSpace, appName)
        end
    end

    return ensuredAppNamesForSpace
end

--- EnsureApp:getAppEnsured(app)
--- Method
--- Returns whether or not app name is configured for EnsureApp.
---
--- Parameters:
---  * app - App name to check.
---
--- Returns:
---  * A boolean representing whether or not the app is configured for EnsureApp.
function EnsureApp:getAppEnsured(app)
    if self.appNamesSet[app] then
        return true
    else
        return false
    end
end

--- EnsureApp:start()
--- Method
--- Spoon start method for EnsureApp.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function EnsureApp:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("EnsureApp")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting EnsureApp")

    -- Initialize the app names "set".
    for appName, _ in pairs(self.apps) do self.appNamesSet[appName] = true end
end

--- EnsureApp:stop()
--- Method
--- Spoon stop method for EnsureApp.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function EnsureApp:stop()
    self.logger.v("Stopping EnsureApp")

    if self.windowOpenTimer then self.windowOpenTimer:stop() end
end

return EnsureApp

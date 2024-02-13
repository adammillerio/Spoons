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
MenuBarApps.version = "0.0.4"
MenuBarApps.author = "Adam Miller <adam@adammiller.io>"
MenuBarApps.homepage = "https://github.com/adammillerio/MenuBarApps.spoon"
MenuBarApps.license = "MIT - https://opensource.org/licenses/MIT"

-- EnsureApp is used for handling app movements when showing/hiding.
EnsureApp = spoon.EnsureApp

--- MenuBarApps.apps
--- Variable
--- Table containing each application's name and it's desired configuration. The
--- key of each entry is the name of the App as it appears in the title bar, and
--- the value is a configuration table with the following entries:
---     * title - String with title text to display in the menu bar icon itself
---     * app - Name of the application in EnsureApp config. 
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

-- Generate a sub menu for a menu bar.
-- Input is the menuConfig and EnsureApp action specific config.
function MenuBarApps:_createMenu(menuConfig, actionConfig)
    self.logger.vf("Creating menu with config: %s", hs.inspect(menuConfig))
    local menu = {}

    for _, config in ipairs(menuConfig) do
        self.logger.vf("Creating menuItem config: %s", hs.inspect(config))
        local menuItem = {}

        if not config.menu then
            self.logger
                .vf("Setting menu item to config: %s", hs.inspect(config))
            menuItem.fn = EnsureApp:ensureAppCallback(config.app, actionConfig)
        else
            self.logger.vf("Creating new child menu with config: %s",
                           hs.inspect(config.menu))
            menuItem.menu = self:_createMenu(config.menu, actionConfig)
        end

        menuItem.title = config.title

        self.logger.vf("Adding menu item: %s", hs.inspect(menuItem))
        table.insert(menu, menuItem)
    end

    self.logger.vf("Generated menu: %s", hs.inspect(menu))
    return menu
end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function MenuBarApps:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Special callback for a choice based menu bar item. This behaves like a normal
-- menu bar app for the current choice. If the Alt key is held when clicking, it
-- will rotate the menu bar item one choice forward in the list of choices.
-- Inputs are the entire config (with all choices), action specific configs for
-- EnsureApp, the hs.menubar if an update is needed, and a table representing
-- any modifiers and their state supplied by setClickCallback.
function MenuBarApps:_choiceBasedMenuCallback(config, actionConfig, menuBar,
                                              modifiers)
    if modifiers.alt then
        -- Rotate the menu bar one forward.
        local choice = table.remove(config.choice, 1)
        table.insert(config.choice, choice)

        -- Update the title.
        menuBar:setTitle(config.choice[1].title)
    else
        -- No modifier, ensure the current choice's app as normal.
        EnsureApp:ensureApp(config.choice[1].app, actionConfig)
    end
end

-- Utility method for creating a new menu bar and adding it to the table.
-- Input is the menu config.
function MenuBarApps:_createMenuBar(config)
    self.logger.vf("Creating MenuBar with config: %s", hs.inspect(config))

    -- Create the new menubar item.
    local menuBar = hs.menubar.new()
    menuBar:autosaveName(string.format("MenuBarApps%s", config.title))

    -- Store the menuBar in the actionConfig, to be used with any apps which
    -- have their EnsureApp configuration set to "move" in order to relocate the
    -- window under the menubar.
    local actionConfig = {moveMenuBar = menuBar}

    if config.menu then
        -- Generate the menu that will become the menu bar's main menu.
        self.logger.vf("(%s) Menu: Generating main menu", config.title)
        menuBar:setMenu(self:_createMenu(config.menu, actionConfig))

        menuBar:setTitle(config.title)
    elseif config.choice then
        -- Set the choice based menu callback and set title to first choice.
        local choiceTitle = config.choice[1].title

        self.logger.vf("(%s) Choice: Setting choice callback", choiceTitle)
        menuBar:setClickCallback(self:_instanceCallback(
                                     self._choiceBasedMenuCallback, config,
                                     actionConfig, menuBar))

        menuBar:setTitle(choiceTitle)
    else
        -- Default, set it directly to a callback to ensure the app.
        self.logger.vf("(%s) Not Menu: Setting item click callback",
                       config.title)
        menuBar:setClickCallback(EnsureApp:ensureAppCallback(config.app,
                                                             actionConfig))

        menuBar:setTitle(config.title)
    end

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
end

return MenuBarApps

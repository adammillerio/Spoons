--- === Lightspot ===
---
--- Lightweight, consistent, and fast Spotlight replacement.
---
--- Download: https://github.com/adammillerio/Spoons/raw/main/Spoons/Lightspot.spoon.zip
---
--- README: [README.md](https://github.com/adammillerio/Lightspot.spoon/blob/main/README.md)
local Lightspot = {}

Lightspot.__index = Lightspot

-- Metadata
Lightspot.name = "Lightspot"
Lightspot.version = "0.0.1"
Lightspot.author = "Adam Miller <adam@adammiller.io>"
Lightspot.homepage = "https://github.com/adammillerio/Lightspot.spoon"
Lightspot.license = "MIT - https://opensource.org/licenses/MIT"

-- Dependency Spoons
-- EnsureApp is used for handling app movements when showing.
EnsureApp = spoon.EnsureApp

--- Lightspot.defaultHotkeys
--- Variable
--- Default hotkey to use for the chooser when "hotkeys" = "default".
Lightspot.defaultHotkeys = {chooser = {{"cmd"}, "space"}}

--- Lightspot.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log
--- level for the messages coming from the Spoon.
Lightspot.logger = nil

--- Lightspot.logLevel
--- Variable
--- Lightspot specific log level override, see hs.logger.setLogLevel for options.
Lightspot.logLevel = nil

--- Lightspot.chooser
--- Variable
--- hs.chooser object representing the chooser.
Lightspot.chooser = nil

--- Lightspot:init()
--- Method
--- Spoon initializer method for Lightspot.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Lightspot:init() end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function Lightspot:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Choice generator for Chooser. Gets all ensured app names, with recently opened
-- apps in the currently focused space being placed at the front.
function Lightspot:_chooserChoices()
    local choices = {}

    --  Create a table of all app names.
    for _, app in ipairs(EnsureApp:getAppNames(hs.spaces.focusedSpace())) do
        table.insert(choices, {
            text = app,
            subText = nil,
            image = nil,
            valid = true,
            app = app
        })
    end

    return choices
end

-- Completion function for chooser, which ensures the selected app if it
-- is not already in focus, or does a Spotlight-like fallback, which searches for
-- any matching hs.applications installed on the system that match the provided
-- query, and opening them.
-- Input is the table representing the choice from the Chooser.
function Lightspot:_chooserCompletion(choice)
    print("completing")
    if choice == nil then
        self.logger.vf("No choice made, skipping")
        return
    end

    if choice.app then
        -- Ensure the app.
        EnsureApp:ensureApp(choice.app)
    elseif choice.text then
        -- This is a default invocation and there is no ensured app with this name.

        -- Get the user's input text.
        local appName = choice.text

        self.logger.vf(
            "No EnsureApp config for app %s, falling back to Spotlight-like completion",
            appName)

        -- Search for any applications matching this query.
        -- This works better with the following enabled in your init.lua:
        -- hs.application.enableSpotlightForNameSearches(true)
        local foundApps = {hs.application.find(appName)}
        if foundApps then
            for _, foundApp in ipairs(foundApps) do
                self.logger.vf("Found app for Spotlight-like query: %s",
                               foundApp)

                -- For some reason, I am getting hs.window back in some cases,
                -- so I have to do a "type" check here.
                -- TODO: Investigate and file issue if there is one.
                if getmetatable(foundApp).__name == "hs.window" then
                    self.logger.wf("Found app is actually hs.window, skipping")
                    return
                end

                local foundAppName = foundApp:name()

                EnsureApp:ensureApp(foundAppName)
                return
            end
        else
            -- Nothing to find, give up.
            self.logger.wf("Couldn't find any apps in Spotlight-like query: %s",
                           appName)
        end
    end
end

-- Lightspot chooser.
-- Shows a Spotlight-like completion menu on screen for ensuring an app by it's name.
function Lightspot:_showChooser()
    if not self.chooser:isVisible() then
        -- Update row count, clear previous input, refresh choices, and show chooser.
        self.chooser:query(nil)
        self.chooser:refreshChoicesCallback()
        self.chooser:show()
    else
        -- Hotkey pressed again while chooser is visible, so hide it. Mostly
        -- replicating Spotlight behavior.
        self.chooser:hide()
    end
end

--- Lightspot:start()
--- Method
--- Spoon start method for Lightspot.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Starts the hs.chooser which is then bound to the "chooser" hotkey.
function Lightspot:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("Lightspot")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting Lightspot")

    -- Create chooser.
    self.logger.v("Creating chooser")
    self.chooser = hs.chooser.new(
                       self:_instanceCallback(self._chooserCompletion))
    self.chooser:choices(self:_instanceCallback(self._chooserChoices))
    -- Run callback even if the choice was not "valid", which triggers a
    -- "Spotlight-like" fall through for querying applications.
    self.chooser:enableDefaultForQuery(true)
end

--- Lightspot:stop()
--- Method
--- Spoon stop method for Lightspot.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
---
--- Notes:
---  * Stops the hs.chooser.
function Lightspot:stop() self.logger.v("Stopping Lightspot") end

function Lightspot:bindHotkeys(mapping)
    -- Bind method for showing the chooser.
    hs.spoons.bindHotkeysToSpec({
        chooser = self:_instanceCallback(self._showChooser)
    }, mapping)
end

return Lightspot

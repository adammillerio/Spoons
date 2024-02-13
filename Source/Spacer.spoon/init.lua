--- === Spacer ===
---
--- Name and switch Mission Control spaces in the menu bar, with fullscreen support!
---
--- Download: [Spacer.spoon.zip](https://github.com/adammillerio/Spoons/raw/main/Spoons/Spacer.spoon.zip)
--- 
--- README: [README.md](https://github.com/adammillerio/Spacer.spoon/blob/main/README.md)
---
--- Space names can be changed from the menubar by holding Alt while selecting
--- the desired space to rename. These are persisted between launches via the
--- hs.settings module.
---
--- A GUI based space "chooser" can be opened space_chooser hotkey (default cmd+space)
---
--- Current application can be put in fullscreen to the left of the current space
--- via the toggle_fullscreen_window_to_left hotkey (default cmd+shift+f)
local Spacer = {}
Spacer.__index = Spacer

-- Metadata
Spacer.name = "Spacer"
Spacer.version = "1.0.3"
Spacer.author = "Adam Miller <adam@adammiller.io>"
Spacer.homepage = "https://github.com/adammillerio/Spacer.spoon"
Spacer.license = "MIT - https://opensource.org/licenses/MIT"

--- Spacer.settingsKey
--- Constant
--- Key used for persisting space names between Hammerspoon launches via hs.settings.
Spacer.settingsKey = "SpacerSpaceNames"

--- Spacer.menuBarAutosaveName
--- Constant
--- Autosave name used with macOS to save menu bar item position.
Spacer.menuBarAutosaveName = "SpacerMenuBar"

--- Spacer.defaultHotkeys
--- Variable
--- Default hotkey to use for the space chooser and fullscreen 
--- when "hotkeys" = "default".
Spacer.defaultHotkeys = {
    space_chooser = {{"ctrl"}, "space"},
    toggle_fullscreen_window_to_left = {{"cmd", "shift"}, "f"}
}

--- Spacer.tilingMenuSection
--- Variable
--- Menu "section" which has tiling options. Set this according to your language.
Spacer.tilingMenuSection = "Window"

--- Spacer.tilingMenuItem
--- Variable
--- Menu item for tiling window to the left. Set this according to your language.
Spacer.tilingMenuItem = "Tile Window to Left of Screen"

--- Spacer.exitFullScreenKeystroke
--- Variable
--- Keystroke representing shortcut to exit a full screen application. Defaults to
--- Cmd+Ctrl+F which has worked for all applications so far.
Spacer.exitFullScreenKeystroke = {modifiers = {"cmd", "ctrl"}, character = "f"}

--- Spacer.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log 
--- level for the messages coming from the Spoon.
Spacer.logger = nil

--- Spacer.logLevel
--- Variable
--- Spacer specific log level override, see hs.logger.setLogLevel for options.
Spacer.logLevel = nil

--- Spacer.menuBar
--- Variable
--- hs.menubar representing the menu bar for Spacer.
Spacer.menuBar = nil

--- Spacer.spaceWatcher
--- Variable
--- hs.spaces.watcher instance used for monitoring for space changes.
Spacer.spaceWatcher = nil

--- Spacer.spaceNames
--- Variable
--- Table with key-value mapping of Space ID to it's user set name.
Spacer.spaceNames = nil

--- Spacer.orderedSpaces
--- Variable
--- Table holding an ordered list of space IDs, which is then used to resolve
--- actual space names for IDs from Spacer.spaceNames.
Spacer.orderedSpaces = nil

--- Spacer.orderedSpaceNames
--- Variable
--- Table with an ordered list of the space names, which is used when loading
--- the menubar, as well as persisted to and from hs.settings between loads.
Spacer.orderedSpaceNames = nil

--- Spacer.focusedSpace
--- Variable
--- int with the ID of the currently focused space.
Spacer.focusedSpace = nil

--- Spacer.spaceChooser
--- Variable
--- hs.chooser object representing the Space chooser.
Spacer.spaceChooser = nil

--- Spacer.delayedWindowClickTimer
--- Variable
--- hs.timer used in fullscreenWindowToLeft to perform a delayed left click.
Spacer.delayedWindowClickTimer = nil

-- Set the menu text of the Spacer menu bar item.
function Spacer:_setMenuText()
    self.menuBar:setTitle(self.spaceNames[self.focusedSpace])
end

-- Handler for user clicking one of the Spacer menu bar menu items.
-- Inputs are the space ID, a table of modifiers and their state upon selection,
-- and the menuItem table.
function Spacer:_menuItemClicked(spacePos, spaceID, modifiers, menuItem)
    if modifiers['alt'] then
        -- Alt held, enter user space rename mode.
        _, inputSpaceName = hs.dialog.textPrompt("Input Space Name",
                                                 "Enter New Space Name")

        -- Rename space and update menu text.
        self:_renameSpace(spacePos, spaceID, inputSpaceName)
        self:_setMenuText()
    else
        if spaceID ~= self.focusedSpace then
            -- Go to the selected space if it is not the current one.
            hs.spaces.gotoSpace(spaceID)
        end
    end
end

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function Spacer:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Handler for creating the Spacer menu bar menu.
function Spacer:_menuHandler()
    -- Reload space names, in case user has deleted/moved/created spaces since
    -- last time clicking without actually changing spaces.
    self:_reloadSpaceNames()

    -- Create table of menu items
    menuItems = {}

    -- Iterate through the ordered space IDs from left to right.
    for i, spaceID in ipairs(self.orderedSpaces) do
        menuItem = {}

        -- Set callback to handler for space being clicked.
        menuItem["fn"] = self:_instanceCallback(self._menuItemClicked, i,
                                                spaceID)

        -- Set menu item to either the user name for the space or the default.
        -- Look up the name for this space ID and set it on the menu item.
        menuItem["title"] = self.spaceNames[spaceID]

        table.insert(menuItems, menuItem)
    end

    return menuItems
end

-- Rename a space, updating both the positional and by-ID value, and writing
-- back to hs.settings.
function Spacer:_renameSpace(spacePos, spaceID, name)
    self.orderedSpaceNames[spacePos] = name
    self.spaceNames[spaceID] = name

    self:_writeSpaceNames()
end

-- Persist the current ordered set of space names back to hs.settings.
function Spacer:_writeSpaceNames()
    self.logger.vf("Writing space names to hs.settings at %s: %s",
                   self.settingsKey, hs.inspect(self.orderedSpaceNames))
    hs.settings.set(self.settingsKey, self.orderedSpaceNames)
end

-- Handler for space watcher reporting a space change. Input is the space ID,
-- although in my testing this has always been -1 and the docs say that it was
-- not something to be relied on.
function Spacer:_spaceChanged(spaceID)
    -- Store the focused space ID.
    self.focusedSpace = hs.spaces.focusedSpace()

    -- Reload space names, in case user has created and switched to a new Desktop.
    self:_reloadSpaceNames()

    -- Update menu text to the new space.
    self:_setMenuText()
end

-- Retrieve the "name" of a fullscreen space.
-- This trudges through the internal data_managedDisplaySpaces structure to locate
-- and set the name of a fullscreen space, which is the app name of the first
-- "tile" in a tiled space.
function Spacer:_getFullScreenSpaceName(spaceID)
    spaceData = hs.spaces.data_managedDisplaySpaces()

    screenUUID = hs.screen.mainScreen():getUUID()

    for _, displaySpaces in ipairs(spaceData) do
        -- Find spaces for this screen.
        if displaySpaces["Display Identifier"] == screenUUID then
            for _, space in ipairs(displaySpaces["Spaces"]) do
                -- Find the space with this ID.
                if space["ManagedSpaceID"] == spaceID then
                    -- Retrieve and return tiled app name.
                    return
                        space["TileLayoutManager"]["TileSpaces"][1]["appName"] ..
                            " (F)"
                end
            end
        end
    end

    -- Could not find name.
    return nil
end

-- Load a new space into Spacer, resolving either it's current name if a new but
-- moved space, outside of initial load, it's previous ordinal name at the current
-- position if on initial load, or defaulting to "None".
function Spacer:_loadNewSpace(spacePos, spaceID, initial)
    self.logger.vf("Creating new space at \"Desktop %d\" with ID %d", spacePos,
                   spaceID)

    -- If this is a Fullscreen app space, find and format a name based on the app.
    if hs.spaces.spaceType(spaceID) == "fullscreen" then
        spaceName = self:_getFullScreenSpaceName(spaceID)
    else
        if initial then
            -- See if there was a name for the space in this position last load.
            spaceName = self.orderedSpaceNames[spacePos]
        else
            -- See if there's already a name stored for this space and use if there is.
            spaceName = self.spaceNames[spaceID]
        end
    end

    if spaceName == nil then
        -- No existing name, default space name to "None" and inser it into the table.
        spaceName = "None"
        self.orderedSpaceNames[spacePos] = spaceName
    end

    self.logger.vf("Setting name for \"Desktop %d\" to \"%s\"", spacePos,
                   spaceName)
    -- Map space ID to name
    self.spaceNames[spaceID] = spaceName
    -- Insert the space into the ordered table to record it positionally from
    -- left to right.
    table.insert(self.orderedSpaces, spaceID)
end

-- Reload space names.
-- There are no lifecycle hooks for mission control (at least not exposed in HS)
-- so this method is intended to be called during Spacer related events in order
-- to go through Spacer's collection of space IDs and names and compare it against
-- a retrieved list of all current spaces. It will then make any changes as
-- necessary to reconcile Spacer's state with what is retrieved from mission
-- control.
function Spacer:_reloadSpaceNames()
    self.logger.v("Reloading space names")

    -- Signal boolean for if anything has changed during the reload process.
    changed = false

    -- Get the main screen on the device
    screen = hs.screen.mainScreen()
    -- Get all spaces on this screen
    spaces = hs.spaces.allSpaces()

    -- Get the spaces for this screen.
    screenSpaces = spaces[screen:getUUID()]

    -- Retrieve the number of spaces we had before making any changes
    existingNumSpaces = #self.orderedSpaces
    self.logger.vf("Existing number of spaces is %d", existingNumSpaces)

    -- For every numerical index i and spaceID for spaces on this screen, from left
    -- to right.
    for i, spaceID in ipairs(screenSpaces) do
        -- Retrieve ID of the space that was in this this position last time
        self.logger.vf("Getting existing space ID for Desktop %d", i)
        existingSpaceID = self.orderedSpaces[i]
        self.logger.vf("Existing space ID for Desktop %d: %s", i,
                       existingSpaceID)

        -- If there was no ID in this position, then this is a newly
        --  created space in the rightmost position, so initialize and append it
        --  to the orderedSpaces and continue iteration.
        if existingSpaceID == nil then
            -- New space at end, append.
            self:_loadNewSpace(i, spaceID, false)

            changed = true
            goto continue
        end

        -- Look up the assigned name for this space ID
        self.logger.vf("Getting existing space name for Desktop %d", i)
        existingSpaceName = self.spaceNames[existingSpaceID]
        self.logger.vf("Existing space name for Desktop %d: %s", i,
                       existingSpaceName)

        -- Load the space name for the ID at this index during this run
        spaceName = self.spaceNames[spaceID]
        if spaceName == nil then
            -- New space not at end, append.
            self:_loadNewSpace(i, spaceID, false)

            changed = true
            goto continue
        end

        -- If the resolved name now does not match the resolved name from
        --  last run, then update the ordered left-to-right set of space IDs at
        --  this index to now be the ID of the current space in this position. Also
        --  update the ordered name to the same thing.
        if spaceName ~= existingSpaceName then
            self.logger.vf(
                "Space Name \"%s\" for Desktop %d differs from existing space name",
                spaceName, i)

            self.orderedSpaces[i] = spaceID
            self.orderedSpaceNames[i] = spaceName
            changed = true
        end

        ::continue::
    end

    -- Check if the new number of spaces we have is less than the old
    --  one, if it is, then remove all extra indices in the orderedSpaces table.
    numSpaces = #screenSpaces
    self.logger.vf("New number of spaces is %d", numSpaces)
    if numSpaces < existingNumSpaces then
        for i = numSpaces + 1, existingNumSpaces do
            self.logger.vf("Removing deleted Desktop %d", i)
            table.remove(self.orderedSpaces, i)
            table.remove(self.orderedSpaceNames, i)
        end

        changed = true
    end

    -- If there were changes, write back to hs.settings.
    if changed then self:_writeSpaceNames() end
end

-- Perform an initial load of all space IDs and names. This will retrieve the
-- previously persisted ordinal space names from settings, and then initialize
-- the current set of retrieved space IDs against it before storing it in the
-- orderedSpaces and orderedSpaceNames tables respectively. This is intended to
-- be called once on startup, and then _reloadSpaceNames is used to reconcile
-- the in-memory state during Spacer related events.
function Spacer:_loadSpaceNames()
    self.logger.vf("Loading space names from hs.settings key \"%s\"",
                   self.settingsKey)

    -- Load the persisted space names from the previous session if any.
    settingsSpaceNames = hs.settings.get(self.settingsKey)
    if settingsSpaceNames == nil then
        -- Default to empty table.
        self.logger.v("No saved space names, initializing empty table")
        settingsSpaceNames = {}
    end

    self.orderedSpaceNames = settingsSpaceNames
    self.logger.vf("Loaded existing space names from settings: %s",
                   hs.inspect(self.orderedSpaceNames))

    self.logger.v("Loading space names for main screen")
    -- Get the main screen on the device
    screen = hs.screen.mainScreen()
    -- Get all spaces on this screen
    spaces = hs.spaces.allSpaces()

    -- Get the spaces for this screen.
    screenSpaces = spaces[screen:getUUID()]

    -- Iterate through spaces by index, this gives them to us from left to right.
    for i, spaceID in ipairs(screenSpaces) do
        -- Load new space.
        self:_loadNewSpace(i, spaceID, true)
    end

    self.logger.vf("Loaded space names: %s", hs.inspect(self.orderedSpaceNames))
end

-- Choice generator for Spacer Chooser.
function Spacer:_spaceChooserChoices()
    choices = {}

    --  Create a table of all space names in order from left-to-right.
    for i, spaceID in ipairs(self.orderedSpaces) do
        table.insert(choices, {
            text = self.spaceNames[spaceID],
            subText = nil,
            image = nil,
            valid = true,
            spaceID = spaceID
        })
    end

    return choices;
end

-- Completion function for space chooser, which switches to the selected space
-- unless it is the current one or nil.
-- Input is the table representing the choice from the Chooser.
function Spacer:_spaceChooserCompletion(choice)
    if choice == nil then
        self.logger.vf("No choice made, skipping")
        return
    elseif choice.spaceID == self.focusedSpace then
        self.logger.vf("Choice is currently focused space, skipping")
        return
    end

    -- Go to the selected space.
    hs.spaces.gotoSpace(choice.spaceID)
end

-- Spacer space chooser.
-- Reloads spaces, then shows a Spotlight-like completion menu on screen for
-- selecting a space either by it's position, or by it's name.
function Spacer:_showSpaceChooser()
    if not self.spaceChooser:isVisible() then
        -- Reload, in case user has made a space without changing spaces or clicking
        -- the menu.
        self:_reloadSpaceNames()

        -- Update row count, clear previous input, refresh choices, and show chooser.
        self.spaceChooser:rows(#self.orderedSpaces)
        self.spaceChooser:query(nil)
        self.spaceChooser:refreshChoicesCallback()
        self.spaceChooser:show()
    else
        -- Hotkey pressed again while chooser is visible, so hide it. Mostly
        -- replicating Spotlight behavior.
        self.spaceChooser:hide()
    end
end

--- Spacer:toggleFullscreenWindowToLeft()
--- Method
--- Toggle the fullscreen state of current window to left of space.
---
--- Parameters:
---  * args - Args provided to hs CLI after "--" via _cli.args.
---
--- Returns:
---  * None
---
--- Notes:
---  * This is bound by default to Cmd+Shift+F and will call fullscreenWindowToLeft
---    or exitFullscreen based on the current fullscreen state of the application.
function Spacer:toggleFullscreenWindowToLeft()
    app = hs.application.frontmostApplication()
    if app == nil then
        self.logger.w("No frontmost application, can't fullscreen")
        return
    end

    window = app:focusedWindow()
    if window == nil then
        self.logger.w("Frontmost application has no windows, can't fullscreen")
        return
    end

    if window:isFullScreen() then
        self.logger
            .v("Current window is already fullscreen, exiting fullscreen")
        self:exitFullScreen()
    else
        self.logger.v(
            "Current window not fullscreen, entering fullscreen to left")
        self:fullscreenWindowToLeft(app)
    end
end

--- Spacer:fullscreenWindowToLeft(app)
--- Method
--- Fullscreen app's focused window to the left of current space.
---
--- Parameters:
---  * app - hs.application to fullscreen
---
--- Returns:
---  * None
---
--- Notes:
---  * Attempts to select Window -> Tile Window to Left of Screen in app menu
---    * Manually configurable via tilingMenuSection and tilingMenuItem
---  * If this doesn't work, it will manually macro the OS flow for this
---    * Show the menu for the green resize button in the top left
---    * Press Down, Down, and Return to select Tile Window to Left of Screen
---  * Clicks around the top-left of the current screen to exit tiling and fullscreen
---  * Returns mouse to original position
---  * All credit for this goes to clay_golem on Apple StackExchange
---    * https://apple.stackexchange.com/posts/462160/revisions
function Spacer:fullscreenWindowToLeft(app)
    if not self:_trySelectingTilingMenuItem(app) then
        self:_tileToTheLeft(app)
    end

    self.delayedWindowClickTimer = hs.timer.delayed.new(1,
                                                        self:_instanceCallback(
                                                            self._clickOnLeftScreenSide))
    self.delayedWindowClickTimer:start()
end

--- Spacer:exitFullscreen(window)
--- Method
--- Exit fullscreen on window.
---
--- Parameters:
---  * None
--- Returns:
---  * None
---
--- Notes:
---  * This presses the keystroke cmd+ctrl+f by default, which should work globally
---    * Configurable via exitFullscreenKeystroke
function Spacer:exitFullScreen()
    self.logger.vf("Pressing keystroke to exit fullscreen: %s",
                   hs.inspect(self.exitFullScreenKeystroke))
    hs.eventtap.keyStroke(self.exitFullScreenKeystroke.modifiers,
                          self.exitFullScreenKeystroke.character)
end

-- Click the mouse around the upper left corner of the screen, and return it
-- to the initial position.
function Spacer:_clickOnLeftScreenSide()
    mousePosition = hs.mouse.getRelativePosition()
    currentScreenFrame = hs.mouse.getCurrentScreen():frame()

    clickPosition = {
        x = currentScreenFrame.x + 10,
        y = currentScreenFrame.y + 10
    }

    self.logger.vf("Clicking at position: %s", hs.inspect(clickPosition))

    -- Click for 1ms
    hs.eventtap.leftClick(clickPosition, 1000) -- hold for 1ms

    -- Restore the original mouse position
    self.logger.vf("Restoring mouse position to: %s", mousePosition)
    hs.mouse.setRelativePosition(mousePosition)
end

-- Attempt to select tiling window options via application menu.
function Spacer:_trySelectingTilingMenuItem(app)
    self.logger.vf("Selecting menu item '%s' in section '%s'",
                   self.tilingMenuItem, self.tiling)
    selected = app:selectMenuItem({self.tilingMenuSection, self.tilingMenuItem})

    if not selected then
        self.logger.wf("Could not find menu item '%s' in section '%s'",
                       self.tilingMenuItem, self.tilingMenuSection)
    end

    return selected
end

-- Tile application to the left via the green fullscreen window element in the OS.
function Spacer:_tileToTheLeft(app)
    window = app:focusedWindow()

    if not window then
        self.logger.w("No window found")
        return false
    end

    windowAx = hs.axuielement.windowElement(window)
    windowAx:setTimeout(0.01)
    resizeButtonAx = windowAx:attributeValue("AXFullScreenButton")
    resizeButtonAx:setTimeout(0.01)
    resizeButtonAx:performAction("AXShowMenu")

    hs.eventtap.keyStroke({}, "down", 1000)
    hs.eventtap.keyStroke({}, "down", 1000)
    hs.eventtap.keyStroke({}, "return", 1000)
end

--- Spacer:init()
--- Method
--- Spoon initializer method for Spacer.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Spacer:init()
    self.spaceNames = {}
    self.orderedSpaces = {}
end

--- Spacer:start()
--- Method
--- Spoon start method for Spacer. Creates/starts menu bar item and space watcher.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Spacer:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("Spacer")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting Spacer")

    -- Set focused space.
    self.focusedSpace = hs.spaces.focusedSpace()

    -- Load initial space names from settings or initialize new set.
    self:_loadSpaceNames()

    self.logger.v("Creating menubar item")
    self.menuBar = hs.menubar.new()
    self.menuBar:autosaveName(self.menuBarAutosaveName)
    self.menuBar:setMenu(self:_instanceCallback(self._menuHandler))

    -- Set space watcher to call handler on space change.
    self.logger.v("Creating and starting space watcher")
    self.spaceWatcher = hs.spaces.watcher.new(
                            self:_instanceCallback(self._spaceChanged))

    self.spaceWatcher:start()

    -- Create space chooser.
    self.logger.v("Creating space chooser")
    self.spaceChooser = hs.chooser.new(self:_instanceCallback(
                                           self._spaceChooserCompletion))
    self.spaceChooser:choices(self:_instanceCallback(self._spaceChooserChoices))

    -- Perform an initial text set for the current space.
    self:_setMenuText()
end

--- Spacer:stop()
--- Method
--- Spoon stop method for Spacer. Deletes menu bar item and stops space watcher.
---
--- Parameters:
---  * None
---
--- Returns:
---  * None
function Spacer:stop()
    self.logger.v("Deleting menubar item")
    self.menuBar:delete()

    self.logger.v("Stopping space watcher")
    self.spaceWatcher:stop()

    self.logger.v("Deleting space chooser")
    self.spaceChooser:delete()

    -- Write space names back to settings.
    self._writeSpaceNames()
end

function Spacer:bindHotkeys(mapping)
    -- Bind method for showing the space chooser and fullscreen to the desired hotkey.
    hs.spoons.bindHotkeysToSpec({
        space_chooser = self:_instanceCallback(self._showSpaceChooser),
        toggle_fullscreen_window_to_left = self:_instanceCallback(
            self.toggleFullscreenWindowToLeft)
    }, mapping)
end

return Spacer

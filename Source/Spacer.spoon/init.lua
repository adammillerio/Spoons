--- === Spacer ===
---
--- Name and switch Mission Control spaces in the menu bar
---
--- Download: [Spacer.spoon.zip](https://github.com/adammillerio/Spoons/raw/main/Spoons/Spacer.spoon.zip)
--- 
--- README: [README.md](https://github.com/adammillerio/Spacer.spoon/blob/main/README.md)
---
--- Space names can be changed from the menubar by holding Alt while selecting
--- the desired space to rename. These are persisted between launches via the
--- hs.settings module.
local Spacer = {}
Spacer.__index = Spacer

-- Metadata
Spacer.name = "Spacer"
Spacer.version = "1.0.0"
Spacer.author = "Adam Miller <adam@adammiller.io>"
Spacer.homepage = "https://github.com/adammillerio/Spacer.spoon"
Spacer.license = "MIT - https://opensource.org/licenses/MIT"

--- Spacer.settingsKey
--- Constant
--- Key used for persisting space names between Hammerspoon launches via hs.settings.
Spacer.settingsKey = "SpacerSpaceNames"

--- Spacer.defaultHotkeys
--- Variable
--- Default hotkey to use for the space chooser when "hotkeys" = 
Spacer.defaultHotkeys = {space_chooser = {{"ctrl"}, "space"}}

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

-- Load a new space into Spacer, resolving either it's current name if a new but
-- moved space, outside of initial load, it's previous ordinal name at the current
-- position if on initial load, or defaulting to "None".
function Spacer:_loadNewSpace(spacePos, spaceID, initial)
    self.logger.vf("Creating new space at \"Desktop %d\" with ID %d", spacePos,
                   spaceID)

    if initial then
        -- See if there was a name for the space in this position last load.
        spaceName = self.orderedSpaceNames[spacePos]
        if spaceName == nil then
            -- No previous name in position, default space name to "None" and insert
            -- it into the table.
            spaceName = "None"
            self.orderedSpaceNames[spacePos] = spaceName
        end
    else
        -- See if there's already a name stored for this space and use if there is.
        spaceName = self.spaceNames[spaceID]
        if spaceName == nil then
            -- No previous name in position, default space name to "None" and insert
            -- it into the table.
            spaceName = "None"
            self.orderedSpaceNames[spacePos] = spaceName
        end
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

        -- Update row count, clear previous input, and show chooser.
        self.spaceChooser:rows(#self.orderedSpaces)
        self.spaceChooser:query(nil)
        self.spaceChooser:show()
    else
        -- Hotkey pressed again while chooser is visible, so hide it. Mostly
        -- replicating Spotlight behavior.
        self.spaceChooser:hide()
    end
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
    -- Bind method for showing the space chooser to the desired hotkey.
    hs.spoons.bindHotkeysToSpec({
        space_chooser = self:_instanceCallback(self._showSpaceChooser)
    }, mapping)
end

return Spacer

--- === SiriSays ===
---
--- Use "Type to Siri" through Hammerspoon
---
--- Download: [SiriSays.spoon.zip](https://github.com/adammillerio/Spoons/raw/main/Spoons/SiriSays.spoon.zip)
--- 
--- README: [README.md](https://github.com/adammillerio/SiriSays.spoon/blob/main/README.md)
local SiriSays = {}
SiriSays.__index = Spacer

-- Metadata
SiriSays.name = "SiriSays"
SiriSays.version = "0.0.1"
SiriSays.author = "Adam Miller <adam@adammiller.io>"
SiriSays.homepage = "https://github.com/adammillerio/SiriSays.spoon"
SiriSays.license = "MIT - https://opensource.org/licenses/MIT"

--- SiriSays.notificationCenterBundleID
--- Constant
--- Bundle ID of Apple Notification Center, used to detect when "Type to Siri"
--- prompt is up.
SiriSays.notificationCenterBundleID = "com.apple.notificationcenterui"

--- SiriSays.logger
--- Variable
--- Logger object used within the Spoon. Can be accessed to set the default log 
--- level for the messages coming from the Spoon.
SiriSays.logger = nil

--- SiriSays.logLevel
--- Variable
--- Spacer specific log level override, see hs.logger.setLogLevel for options.
SiriSays.logLevel = nil

--- SiriSays.typeToSiriCloseDelay
--- Variable
--- int representing the time in seconds to wait before "auto closing"
--- the Type-to-Siri prompt.
SiriSays.typeToSiriCloseDelay = 5

--- SiriSays.previouslyFocusedWindow
--- Variable
--- The previously focused window stored prior to starting the macro, used for
--- auto closing the TTS prompt.
SiriSays.previouslyFocusedWindow = nil

--- SiriSays.typeToSiriOpenTimer
--- Variable
--- hs.timer that waits unto the TTS prompt is open.
SiriSays.typeToSiriOpenTimer = nil

--- SiriSays.typeToSiriCloseTimer
--- Variable
--- hs.timer that waits typeToSiriCloseDelay seconds before auto closing the TTS
--- prompt.
SiriSays.typeToSiriCloseTimer = nil

-- Utility method for having instance specific callbacks.
-- Inputs are the callback fn and any arguments to be applied after the instance
-- reference.
function SiriSays:_instanceCallback(callback, ...)
    return hs.fnutils.partial(callback, self, ...)
end

-- Return whether or not the currently focused window's application's Bundle ID
-- is Notification Center, which is where the Type to Siri prompt resides.
function SiriSays:_waitForTypeToSiri()
    self.logger.vf("Waiting for TTS Application BundleID %s to focus",
                   self.notificationCenterBundleID)
    return hs.window.focusedWindow():application():bundleID() ==
               self.notificationCenterBundleID
end

-- Auto-close the Type-to-Siri prompt. If the Notification Center is still focused,
-- it will "auto-close" it by focusing the previously focused window stored and
-- clicking in the middle of it. Ideally in the future I can find a better way
-- to truly close the TTS prompt than clicking out of it, but so far I have not
-- been able to. Alt-Tab, typing, and hiding Notification Center have not worked.
function SiriSays:_closeTypeToSiri()
    if self:_waitForTypeToSiri() then
        self.logger.vf("Refocusing window: %s", self.previouslyFocusedWindow)
        self.previouslyFocusedWindow:focus()

        frame = self.previouslyFocusedWindow:frame()

        -- Compute the X/Y coord of the center of the previously focused window.
        windowMidPoint = {
            x = (frame.x + (frame.w / 2)),
            y = (frame.y + (frame.h / 2))
        }

        self.logger.vf("Clicking at %s", hs.inspect(windowMidPoint))

        hs.eventtap.leftClick(windowMidPoint)
    end
end

-- Send a prompt to Type-to-Siri.
-- After typeToSiriTimer detects that the TTS prompt is up, this sends the
-- provided prompt, presses return to submit it, and then initiates a second
-- timer to wait typeToSiriCloseDelay seconds before auto closing if needed.
function SiriSays:_typeToSiri(prompt)
    self.logger.vf("Sending prompt '%s' to TTS", prompt)
    hs.eventtap.keyStrokes(prompt)
    self.logger.vf("Pressing enter to submit to TTS")
    hs.eventtap.keyStroke({}, "return")

    self.logger.vf("Waiting %d seconds to auto-close TTS",
                   self.typeToSiriCloseDelay)
    self.typeToSiriCloseTimer = hs.timer.doAfter(self.typeToSiriCloseDelay,
                                                 self:_instanceCallback(
                                                     self._closeTypeToSiri))
end

--- SiriSays:siri(prompt)
--- Method
--- Initiate a macro for sending text to Siri.
---
--- Parameters:
---  * prompt - string prompt to send to Siri
---
--- Returns:
---  * None
---
--- Notes:
---  * This "function" is really a multi-step macro that does the following
---    * Presses Fn+Space to open the TTS prompt
---    * Waits until "Notification Center" is the focused application (TTS prompt)
---    * Sends the provided prompt as keystrokes
---    * Presses return to submit prompt
---    * Waits typeToSiriCloseDelay seconds before "auto closing" the prompt
---    * Auto close focuses the window from before TTS prompt then clicks the center
---      * Will not occur if prompt is already unfocused
---  * This requires the following settings to be enabled
---    * Accessibility
---      * Type to Siri
---        * On
---    * Siri & Spotlight
---      * Siri Responses
---        * Voice Feedback
---          * Off
---        * Always show Siri captions
---          * On
---        * Keyboard Shortcut
---          * Press Fn (Globe) Space
function SiriSays:siri(prompt)
    self.logger.vf("Sending Siri prompt: %s", prompt)

    self.previouslyFocusedWindow = hs.window.focusedWindow()
    self.logger.vf("Stored previously focused window: %s",
                   self.previouslyFocusedWindow)

    self.typeToSiriOpenTimer = hs.timer.waitUntil(
                                   self:_instanceCallback(
                                       self._waitForTypeToSiri),
                                   self:_instanceCallback(self._typeToSiri,
                                                          prompt))

    self.logger.v("Pressing Fn+Space to start Type-To-Siri (TTS)")
    hs.eventtap.keyStroke({"fn"}, "space")

    self.typeToSiriOpenTimer:start()
end

--- SiriSays:siri_cli(args)
--- Method
--- Initiate a siri prompt from the Hammerspoon CLI.
---
--- Parameters:
---  * args - Args provided to hs CLI after "--" via _cli.args.
---
--- Returns:
---  * None
---
--- Notes:
---  * This is intended to be invoked via the Hammerspoon CLI with the prompt after --
---  * ie `alias siri='hs -c "spoon.SiriSays:siri_cli(_cli.args)" --'`
function SiriSays:siri_cli(args)
    self.logger.v("Starting SiriSays CLI invocation")

    if args[1] ~= "--" then
        -- CLI was not invoked with -- at the end.
        self.logger.e("SiriSays:siri_cli must be invoked via hs CLI with --")
        return
    end

    -- Remove first -- argument
    table.remove(args, 1)

    -- Join all arguments after -- and send them as a prompt to siri.
    self:siri(table.concat(args, " "))
end

function SiriSays:start()
    -- Start logger, this has to be done in start because it relies on config.
    self.logger = hs.logger.new("SiriSays")

    if self.logLevel ~= nil then self.logger.setLogLevel(self.logLevel) end

    self.logger.v("Starting SiriSays")
end

function SiriSays:stop()
    self.logger.v("Stopping SiriSays")
    if self.typeToSiriOpenTimer ~= nil then self.typeToSiriOpenTimer:stop() end
    if self.typeToSiriCloseTimer ~= nil then self.typeToSiriCloseTimer:stop() end
end

return SiriSays

-- Pauseable timers and transitions with speed adjustment
-- Author: Lerg
-- Release date: 2012-04-14
-- Version: 1.2
-- License: MIT
-- Web: http://developer.anscamobile.com/code/pausable-timers-and-transitions-speed-adjustment
--
-- USAGE:
--  Import this module with a desired name, for example:
--      tnt = require('tnt')
--  Then you create timers and transitions with the same logic as before:
--      timer1 = tnt:newTimer(1000, function () print('tick') end, 1, {name = 'Tick Timer', userData = 'User data', onEnd = function (event) print(event.name .. ' has completed') end})
--      trans1 = tnt:newTransition(object, {time = 1000, x = 480, name = 'Slide Transition', userData = 'User data', cycle = 10, backAndForth = true, onEnd = function (object, event) print(event.name .. ' has completed') end})
--  Name and userData arguments are optional. userData can be anything.
--  onEnd callback (or object listener) is fired once timer or transition has finished its job completely, after all ticks or transition cycles, calling either the callback method or the appropriate method of the object listener: timerEnd or transitionEnd.
--  With cycle param you can tell transition to loop. 0 - infinite times. You can also set backAndForth param.
--  Every instance has pause(), resume() and cancel() methods.
--  You can manage all timers and transitions with function like tnt:pauseAllTimers(), tnt:resumeAllTransitions() etc.
--  For speed adjustment first pause all timers and transitions, then modify tnt.speed to say 0.5, which means 2 times faster.
--  and lastly resume all paused instances.
--
-- LIMITATIONS:
--  Doesn't work with delta transitions. Easings will start over after each pausing, it can be fixed, but I don't need it at the moment,
--  so didn't implemented. Fix would be to set up custom easings and pass elapsed time to each easing function.
--
-- CONTRIBUTORS:
--  CluelessIdeas (www.cluelessideas.com), TMApps (www.timemachineapps.com/blog)
--
-- CHANGELIST:
-- 1.2:
--  [Feature] Added cycling support for transitions. Both repeating and "back and forth" loops. Infinite and finite.
--  [Feature] Added onEnd listener support - callback to be called when timer or transition elapsed completely (repeative timers and transitions)
--  [Feature] Added table listeners support. Events are timer, timerEnd, transition, transitionEnd
--  [Feature] Added speed constants tnt.NORMAL, tnt.FAST and tnt.SLOW - feel free to use them or add your own.
-- 1.1.2:
--  [Bug] Transitions are wrongfully decided to be already ended.
--  [Feature] Added name and userData params for transtitions just like for timers.
--  [Feature] Added LuaDoc.
--  [Feature] Added default value for the count argument.
-- 1.1.1:
--  [Bug] Quick bugfix on remainingTime calculations.
-- 1.1:
--  [Bug] onComplete function is not getting called for transitions when pausing right before the event.
--  [Bug] Timers are not counting resting time from resuming till next pausing (before next tick).
--  [Feature] Added userData and name to actual timers instances, they are accessible through event callback function argument, like event.userData and event.name.
--  [Feature] Added cleanTimersAndTransitions() function which frees the memory on demand (you can call it every couple of seconds)
--
-- I can be found on the corona IRC channel.
 
-- Module table
local _M = {}
 
-- Game speed: 1 - normal, 0.5 - fast, 2 - slow
_M.speed = 1
 
_M.NORMAL = 1
_M.FAST = 0.5
_M.SLOW = 2
 
-- Every instance is hold here
local allTimers = {}
local allTransitions = {}
 
-- Cache
local tInsert = table.insert
local tRemove = table.remove
 
-- Pausable timers
-- @param duration number Transition duration.
-- @param callback function Function to be called on the each tick.
-- @param count number How many times to tick, 0 - unlimited. Default is 1.
-- @param params table Extra parameters. Optional.
--          name string The name for the timer. Available in the callback.
--          userData table Any user data. Available in the callback.
--          onEnd function A callback to call when timer is elapsed completely (count wise).
function _M:newTimer (duration, callback, count, params)
    -- Timer handler
    local tH = {}
    tH.speed = self.speed
    tH.start = system.getTimer()
    tH.duration = duration
    tH.callback = callback
    tH.count = count or 1
    tH.counter = 0
    tH.isInfinite = (count == 0)
    if params then
        tH.name = params.name
        tH.userData = params.userData
        tH.onEnd = params.onEnd
    end
    tH.shouldRemove = false
    tH.paused = false
    tH.intervalStartTime = tH.start
    tH.remainingTime = duration
 
    -- Internal function which fires up the actual callback function
    -- @param event Corona's timer event
    local function callbackWrapper (event)
        local tH_callback = tH.callback
        if tH_callback then
            event.userData = tH.userData
            event.name = tH.name
            if type(tH_callback) == 'function' then
                tH_callback(event)
            elseif type(tH_callback) == 'table' and type(tH_callback.timerEnd) == 'function' then
                tH_callback:timerEnd(event)
            end
            if not tH.isInfinite then
                tH.counter = tH.counter + 1
                if tH.counter >= tH.count then
                    tH:cancel()
                    local onEnd = tH.onEnd
                    if type(onEnd) == 'function' then
                        onEnd(event)
                    elseif type(onEnd) == 'table' and type(onEnd.timerEnd) == 'function' then
                        onEnd:timerEnd(event)
                    end
                end
            end
            tH.remainingTime = tH.duration
            tH.intervalStartTime = system.getTimer()
        else
            tH:cancel()
        end
    end
 
    tH.t = timer.performWithDelay(tH.duration * self.speed, callbackWrapper, tH.count)
 
    -- Cancels running timer and prepares for the resuming
    function tH:pause ()
        if self.t then
            timer.cancel(self.t)
        end
        if not self.paused then
            self.paused = true
            self.pausingTime = system.getTimer()
            self.remainingTime = self.remainingTime - ((self.pausingTime - self.intervalStartTime) / _M.speed)
            if self.remainingTime < 0 then
                self.remainingTime = 0
            end
        end
    end
 
    -- Initiates a fresh timer if paused
    function tH:resume ()
        if self.paused then
            self.paused = false
            if not self.isInfinite then
                -- Timer elapsed
                if self.counter >= self.count then
                    self:cancel()
                else
                    local function callbackDoubleWrapper (event)
                        callbackWrapper(event)
                        local ticksRemains = self.count - self.counter
                        if ticksRemains > 0 then
                            self.t = timer.performWithDelay(self.duration * _M.speed, callbackWrapper, ticksRemains)
                            self.speed = _M.speed
                        else
                            self:cancel()
                        end
                    end
                    self.intervalStartTime = system.getTimer()
                    self.t = timer.performWithDelay(self.remainingTime * _M.speed, callbackDoubleWrapper, 1)
                    self.speed = _M.speed
                end
            else
                local function callbackDoubleWrapper (event)
                    callbackWrapper(event)
                    self.t = timer.performWithDelay(self.duration * _M.speed, callbackWrapper, 0)
                end
                self.intervalStartTime = system.getTimer()
                self.t = timer.performWithDelay(self.remainingTime * _M.speed, callbackDoubleWrapper, 1)
                self.speed = _M.speed
            end
        end
    end
 
    -- Cancels actual timer instance and marks this handler to be removed
    function tH:cancel ()
        if self.t then
            timer.cancel(self.t)
        end
        self.shouldRemove = true
        self.callback = nil
    end
 
    tInsert(allTimers, tH)
    return tH
end
 
-- Pauses everything in the allTimers table
function _M:pauseAllTimers()
    local i
    local allTimersCount = #allTimers
    if allTimersCount > 0 then
        for i = allTimersCount, 1, -1 do
            local child = allTimers[i]
            if child.shouldRemove then
                tRemove(allTimers, i)
            else
                child:pause()
            end
        end
    end
end
 
-- Resumes everything in the allTimers table
function _M:resumeAllTimers()
    local i
    local allTimersCount = #allTimers
    if allTimersCount > 0 then
        for i = allTimersCount, 1, -1 do
            local child = allTimers[i]
            if child.shouldRemove then
                tRemove(allTimers, i)
            else
                child:resume()
            end
        end
    end
end
 
-- Cancels everything in the allTimers table
function _M:cancelAllTimers()
    local i
    local allTimersCount = #allTimers
    if allTimersCount > 0 then
        for i = allTimersCount, 1, -1 do
            local child = allTimers[i]
            child:cancel()
            tRemove(allTimers, i)
        end
    end
end
 
-- Pausable transitions
-- @param object table An object for which transition is applied.
-- @param params table Transition parameters.
--        name string The name for the transition. Available in the onComplete function. Optional.
--        userData table Any user data. Available in the onComplete function. Optional.
--        cycle number How many times to repeat transition. 0 - infinite. Optional.
--        backAndForth boolean Should it be back and forth cycling? Optional.
--        onEnd function A callback to call when transition is completed completely (count wise). Optional.
function _M:newTransition(object, params)
    -- Transition handler
    local tH = {name = params.name, userData = params.userData, originalTime = params.time, cycleCount = 0}
    local elapsed, elapsedCount, currentCountRemains
    local onComplete = params.onComplete
    local onEnd = params.onEnd
    local cycleTransition = params.cycle or 1
    local backAndForthCycling = params.backAndForth or false
    local initialValues = {}
    for k, v in pairs(params) do
        if k ~= 'onComplete' and k ~= 'onEnd' and k ~= 'time' and k ~= 'transition' and k ~= 'delta' and k ~= 'name' and k ~= 'userData' and k ~= 'cycle' and k ~= 'backAndForth' then
            initialValues[k] = object[k]
        end
    end
 
    -- This function is called for each completed transition to mark its handler for removal
    local function callbackWrapper ()
        if type(onComplete) == 'function' then
            onComplete(object, {userData = tH.userData, name = tH.name})
        elseif type(onComplete) == 'table' and type(onComplete.transition) == 'function' then
            onComplete:transition(object, {userData = tH.userData, name = tH.name})
        end
        local doRepeat = false
        if cycleTransition > 0 then
            tH.cycleCount = tH.cycleCount + 1
            if tH.cycleCount >= cycleTransition then
                tH:cancel()
                if type(onEnd) == 'function' then
                    onEnd(object, {userData = tH.userData, name = tH.name})
                elseif type(onEnd) == 'table' and type(onEnd.transitionEnd) == 'function' then
                    onEnd:transitionEnd(object, {userData = tH.userData, name = tH.name})
                end
            else
                doRepeat = true
            end
        elseif cycleTransition == 0 then
            doRepeat = true
        end
        if doRepeat then
            transition.cancel(tH.t)
            tH.params.time = tH.originalTime
            tH.start = system.getTimer()
            tH.elapsed = nil
            for k, v in pairs(initialValues) do
                if not backAndForthCycling then
                    object[k] = v
                else
                    tH.params[k] = v
                    initialValues[k] = object[k]
                end
            end
            tH.t = transition.to(object, tH.params)
        end
    end
 
    tH.params = {}
    -- Make a shallow copy of the user's params so they are not messed up in the user's space
    for k, v in pairs(params) do tH.params[k] = v end
    tH.params.onComplete = callbackWrapper
    tH.params.time = tH.originalTime * self.speed
    tH.t = transition.to(object, tH.params)
    tH.start = system.getTimer()
    tH.speed = self.speed
 
    --  Stops current transiton and prepares for the resuming
    function tH:pause()
        if self.t then
            self.elapsed = (system.getTimer() - self.start) / self.speed
            transition.cancel(self.t)
        else
            self:cancel()
        end
    end
    -- Initiates a fresh transition if paused
    function tH:resume()
        if self.elapsed and not self.shouldRemove then
            -- Current speed
            local s = _M.speed
            self.params.time = (self.originalTime - self.elapsed) * s
            self.t = transition.to(object, self.params)
            self.start = system.getTimer() - self.elapsed * s
            self.speed = s
            self.elapsed = nil
        end
    end
    -- Cancels actual transition instance and marks this handler to be removed
    function tH:cancel()
        if self.t then
            transition.cancel(self.t)
        end
        self.shouldRemove = true
    end
 
    tInsert(allTransitions, tH)
    return tH
end
 
-- Pauses everything in the allTransitions table
function _M:pauseAllTransitions()
    local i
    local allTransitionsCount = #allTransitions
    if allTransitionsCount > 0 then
        for i = allTransitionsCount, 1, -1 do
            local child = allTransitions[i]
            if child.shouldRemove then
                tRemove(allTransitions, i)
            else
                child:pause()
            end
        end
    end
end
 
-- Resumes everything in the allTransitions table
function _M:resumeAllTransitions()
    local i
    local allTransitionsCount = #allTransitions
    if allTransitionsCount > 0 then
        for i = allTransitionsCount, 1, -1 do
            local child = allTransitions[i]
            if child.shouldRemove then
                tRemove(allTransitions, i)
            else
                child:resume()
            end
        end
    end
end
 
-- Cancels everything in the allTransitions table
function _M:cancelAllTransitions()
    local i
    local allTransitionsCount = #allTransitions
    if allTransitionsCount > 0 then
        for i = allTransitionsCount, 1, -1 do
            local child = allTransitions[i]
            child:cancel()
            tRemove(allTransitions, i)
        end
    end
end
 
-- Deletes unused instances (frees memory)
function _M:cleanTimersAndTransitions()
    local i
    local allTimersCount = #allTimers
    if allTimersCount > 0 then
        for i = allTimersCount, 1, -1 do
            local child = allTimers[i]
            if child.shouldRemove then
                tRemove(allTimers, i)
            end
        end
    end
    local allTransitionsCount = #allTransitions
    if allTransitionsCount > 0 then
        for i = allTransitionsCount, 1, -1 do
            local child = allTransitions[i]
            if child.shouldRemove then
                tRemove(allTransitions, i)
            end
        end
    end
end
 
return _M

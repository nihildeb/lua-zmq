-- Copyright (c) 2011 by Robert G. Jakabosky <bobby@sharedrealm.com>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

--
-- zmq.poller wraps the low-level zmq.ZMQ_Poller object.
--
-- This wrapper simplifies the event polling loop.
--

local zmq = require"zmq"

local setmetatable = setmetatable
local tonumber = tonumber
local assert = assert

local poller_mt = {}
poller_mt.__index = poller_mt

function poller_mt:add(sock, events, cb)
	local id = self.poller:add(sock, events)
	self.callbacks[id] = function(revents) return cb(sock, revents) end
end

function poller_mt:modify(sock, events, cb)
	local id
	if events ~= 0 and cb then
		id = self.poller:modify(sock, events)
		self.callbacks[id] = function(revents) return cb(sock, revents) end
	else
		id = self:remove(sock)
		self.callbacks[id] = nil
	end
end

function poller_mt:remove(sock)
	local id = self.poller:remove(sock)
	self.callbacks[id] = nil
end

function poller_mt:poll(timeout)
	local poller = self.poller
	local count, err = poller:poll(timeout)
	if not count then
		return nil, err
	end
	local callbacks = self.callbacks
	for i=1,count do
		local id, revents = poller:next_revents_idx()
		callbacks[id](revents)
	end
	return count
end

function poller_mt:start()
	self.is_running = true
	while self.is_running do
		status, err = self:poll(-1)
		if not status then
			return false, err
		end
	end
	return true
end

function poller_mt:stop()
	self.is_running = false
end

local M = {}

function M.new(pre_alloc)
	return setmetatable({
		poller = zmq.ZMQ_Poller(pre_alloc),
		callbacks = {},
	}, poller_mt)
end

zmq.poller = M
return setmetatable(M, {__call = function(tab, ...) return M.new(...) end})


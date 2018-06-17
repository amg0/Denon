-- // This program is free software: you can redistribute it and/or modify
-- // it under the condition that it is for private or home useage and
-- // this whole comment is reproduced in the source code file.
-- // Commercial utilisation is not authorized without the appropriate
-- // written agreement from amg0 / alexis . mermet @ gmail . com
-- // This program is distributed in the hope that it will be useful,
-- // but WITHOUT ANY WARRANTY; without even the implied warranty of
-- // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE .
local MSG_CLASS		= "DENON"
local DENON_SERVICE	= "urn:upnp-org:serviceId:altdenon1"
local devicetype	= "urn:schemas-upnp-org:device:altdenon:1"
-- local this_device	= nil
local DEBUG_MODE	= false -- controlled by UPNP action
local version		= "v0.1"
local JSON_FILE = "D_DENON.json"
local UI7_JSON_FILE = "D_DENON_UI7.json"

local json = require("dkjson")
-- local mime = require('mime')
local socket = require("socket")
-- local http = require("socket.http")
-- local https = require ("ssl.https")
-- local ltn12 = require("ltn12")
-- local modurl = require ("socket.url")

local targets = {}
local this_device = nil

------------------------------------------------
-- Debug --
------------------------------------------------
function log(text, level)
  luup.log(string.format("%s: %s", MSG_CLASS, text), (level or 50))
end

function debug(text)
  if (DEBUG_MODE) then
	log("debug: " .. text)
  end
end

function warning(stuff)
  log("warning: " .. stuff, 2)
end

function error(stuff)
  log("error: " .. stuff, 1)
end

local function isempty(s)
  return s == nil or s == ""
end

------------------------------------------------
-- VERA Device Utils
------------------------------------------------
local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getAltID(lul_device)
  return luup.devices[lul_device].id
end

-----------------------------------
-- from a altid, find a child device
-- returns 2 values
-- a) the index === the device ID
-- b) the device itself luup.devices[id]
-----------------------------------
local function findChild( lul_parent, altid )
  -- debug(string.format("findChild(%s,%s)",lul_parent,altid))
  for k,v in pairs(luup.devices) do
	if( getParent(k)==lul_parent) then
	  if( v.id==altid) then
		return k,v
	  end
	end
  end
  return nil,nil
end

local function getParent(lul_device)
  return luup.devices[lul_device].device_num_parent
end

local function getRoot(lul_device)
  while( getParent(lul_device)>0 ) do
	lul_device = getParent(lul_device)
  end
  return lul_device
end

------------------------------------------------
-- Device Properties Utils
------------------------------------------------
local function getSetVariable(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

local function getSetVariableIfEmpty(serviceId, name, deviceId, default)
  local curValue = luup.variable_get(serviceId, name, deviceId)
  if (curValue == nil) or (curValue:trim() == "") then
	curValue = default
	luup.variable_set(serviceId, name, curValue, deviceId)
  end
  return curValue
end

local function setVariableIfChanged(serviceId, name, value, deviceId)
  debug(string.format("setVariableIfChanged(%s,%s,%s,%s)",serviceId, name, value or 'nil', deviceId))
  local curValue = luup.variable_get(serviceId, name, tonumber(deviceId)) or ""
  value = value or ""
  if (tostring(curValue)~=tostring(value)) then
	luup.variable_set(serviceId, name, value or '', tonumber(deviceId))
  end
end

local function setAttrIfChanged(name, value, deviceId)
  debug(string.format("setAttrIfChanged(%s,%s,%s)",name, value or 'nil', deviceId))
  local curValue = luup.attr_get(name, deviceId)
  if ((value ~= curValue) or (curValue == nil)) then
	luup.attr_set(name, value or '', deviceId)
	return true
  end
  return value
end

------------------------------------------------
-- Tasks
------------------------------------------------
local taskHandle = -1
local TASK_ERROR = 2
local TASK_ERROR_PERM = -2
local TASK_SUCCESS = 4
local TASK_BUSY = 1

--
-- Has to be "non-local" in order for MiOS to call it :(
--
local function task(text, mode)
  if (mode == TASK_ERROR_PERM)
  then
	error(text)
  elseif (mode ~= TASK_SUCCESS)
  then
	warning(text)
  else
	log(text)
  end
  
  if (mode == TASK_ERROR_PERM)
  then
	taskHandle = luup.task(text, TASK_ERROR, MSG_CLASS, taskHandle)
  else
	taskHandle = luup.task(text, mode, MSG_CLASS, taskHandle)

	-- Clear the previous error, since they're all transient
	if (mode ~= TASK_SUCCESS)
	then
	  luup.call_delay("clearTask", 15, "", false)
	end
  end
end

function clearTask()
  task("Clearing...", TASK_SUCCESS)
end

local function UserMessage(text, mode)
  mode = (mode or TASK_ERROR)
  task(text,mode)
end

------------------------------------------------
-- Generic Queue
------------------------------------------------
function tablelength(T)
  local count = 0
  if (T~=nil) then
	for _ in pairs(T) do count = count + 1 end
  end
  return count
end
Queue = {
	new = function(self,o)
		o = o or {}	  -- create object if user does not provide one
		setmetatable(o, self)
		self.__index = self
		return o
	end,
	size = function(self)
		return tablelength(self)
	end,
	push = function(self,e)
		return table.insert(self,1,e)
	end,
	pull = function(self)
	    local elem = self[1]
		table.remove(self,1)
		return elem
	end,
	add = function(self,e)
		return table.insert(self,e)
	end,
	removeItem = function(self, idx)
		table.remove(self,idx)
	end,
	getHead = function(self)
		local elem = self[1]
		return elem
	end,
	list = function(self)
		local i = 0
		return function()
			if (i<#self) then
				i=i+1
				return i,self[i]
			end
		end
	end,
	listReverse = function(self)
		local i = #self
		return function()
			if (i>0) then
				local j = i
				i = i-1
				return j,self[j]
			end
		end
	end,
}
------------------------------------------------
-- DENON plugin methods
------------------------------------------------
Denon = {
	new = function(self,ipaddr)
	  debug(string.format("Denon:new(%s)",ipaddr))
		o = {
			ipaddr = ipaddr,
			port = 23,
			socket = nil,
			queue = Queue:new()
		}
		setmetatable(o, self)
		self.__index = self
		return o
	end,
	connect = function(self)
		debug(string.format("Denon:connect()"))
		local result, err = nil, ''
		if ( self.socket == nil ) then
			self.socket, err = socket.tcp()
			if (self.socket~=nil) then
				self.socket:settimeout(5)
				result, err = self.socket:connect(self.ipaddr, self.port)
				if (result==nil) then
					self.socket:close()
					self.socket = nil
				end
			end
		end
		return result,err
	end,
	_receiveFrame = function(self)
		debug(string.format("Denon:_receiveFrame()"))
		local str=''
		local err=''
		if (self.socket ~= nil) then
			local result = 1
			while (result~='\r') do
				result,err = self.socket:receive("1")
				if (result==nil) then
					error(string.format("receive err:%s",err))
					break
				end
				str = str..result
			end
			debug(string.format("received:%s",str))
		else
			error(string.format("socket not connected"))
		end
		return str,err
	end,
	_sendFrame = function(self,frame)
		debug(string.format("Denon:_sendFrame(%s)",frame))
		local result,err = nil, ''
		if (self.socket ~= nil) then
			result,err = self.socket:send( frame .. "\r" )	-- effectively the total number of bytes sent
			debug(string.format("send returned %s",result or 'nil'))
			if (result ~= nil) then
				luup.sleep(100)
				local received =''
				received,err = self:_receiveFrame()
			else
				error(string.format("send failed, err:%s",err))
			end
		end
		return result,err
	end,
	disconnect = function(self)
		debug(string.format("Denon:disconnect()"))
		if (self.socket ~= nil) then
			self.socket:shutdown('both')
			self.socket:close()
			self.socket = nil
		end
		return nil
	end,
	_engine = function(self)
		debug(string.format("Denon:_engine()"))
		local size = self.queue:size()
		debug(string.format("queue size = %d",size))
		if (size > 0) then
			local result=''
			repeat
				local cmd = self.queue:pull()
				local result,err = self:_sendFrame(cmd.frame)
				size = self.queue:size()
				debug(string.format("queue size = %d",size))
			until ((size==0))  --or (result==nil) 
			
			-- size is 0 now, we can disconnect
			self:disconnect()
		end
	end,
	send = function(self,frame)
		debug(string.format("Denon:send(%s)",frame))
		self.queue:add({frame=frame})
		local result,err = 1,''
		local size = self.queue:size()
		debug(string.format("queue size = %d",size))
		if (size==1) then
			result,err = self:connect()
			if (result~=nil) then
				luup.call_delay("SendEngine", 1, self.ipaddr)
			else
				error(string.format("connect to %s failed with err %s. engine will stop. reload luup",self.ipaddr,err))
			end
		end
		return result,err
	end,
}

function SendEngine(ipaddr)
	debug(string.format("SendEngine(%s)",ipaddr))
	local obj = targets[ipaddr]
	if (obj~=nil) then
		obj:_engine()
	else
		warning(string.format("address %s is unknown in targets",ipaddr))
	end
end

------------------------------------------------
-- UPNP Actions Sequence
------------------------------------------------
local function setDebugMode(lul_device,newDebugMode)
  lul_device = tonumber(lul_device)
  newDebugMode = tonumber(newDebugMode) or 0
  debug(string.format("setDebugMode(%d,%d)",lul_device,newDebugMode))
  luup.variable_set(DENON_SERVICE, "Debug", newDebugMode, lul_device)
  if (newDebugMode==1) then
	DEBUG_MODE=true
  else
	DEBUG_MODE=false
  end
end

------------------------------------------------
-- UPNP actions Sequence
------------------------------------------------

local function startEngine(lul_device)
	debug(string.format("startEngine(%s)",lul_device))
	local success =  false
	local res,msg = nil,''
	lul_device = tonumber(lul_device)

	local ipaddr = luup.attr_get ('ip', lul_device )	
	if (isempty(ipaddr) == false) then
		targets[ipaddr] = Denon:new(ipaddr)
		res,msg = targets[ipaddr]:send("PW?")
		if (res~=nil) then
			res,msg = targets[ipaddr]:send("SI?")
		end
	else
		UserMessage("please add ip address in the ip attribute and reload "..lul_device,TASK_ERROR_PERM)
	end
	
	return (res~=nil)
end

function startupDeferred(lul_device)
	lul_device = tonumber(lul_device)
	log("startupDeferred, called on behalf of device:"..lul_device)
	local iconCode = getSetVariable(DENON_SERVICE,"IconCode", lul_device, "0")

	local debugmode = getSetVariable(DENON_SERVICE, "Debug", lul_device, "0")	
	if (debugmode=="1") then
		DEBUG_MODE = true
		UserMessage("Enabling debug mode for device:"..lul_device,TASK_BUSY)
	end

	local major,minor = 0,0
	if (oldversion~=nil) then
		if (oldversion ~= "") then
		  major,minor = string.match(oldversion,"v(%d+)%.(%d+)")
		  major,minor = tonumber(major),tonumber(minor)
		  debug ("Plugin version: "..version.." Device's Version is major:"..major.." minor:"..minor)

		  newmajor,newminor = string.match(version,"v(%d+)%.(%d+)")
		  newmajor,newminor = tonumber(newmajor),tonumber(newminor)
		  debug ("Device's New Version is major:"..newmajor.." minor:"..newminor)

		  -- force the default in case of upgrade
		  if ( (newmajor>major) or ( (newmajor==major) and (newminor>minor) ) ) then
			-- log ("Version upgrade => Reseting Plugin config to default")
		  end
		else
		  log ("New installation")
		end
		luup.variable_set(DENON_SERVICE, "Version", version, lul_device)
	end

	local success = startEngine(lul_device)
	setVariableIfChanged(DENON_SERVICE, "IconCode", success and "100" or "0", lul_device)
	
	-- report success or failure
	if( luup.version_branch == 1 and luup.version_major == 7) then
		if (success == true) then
			luup.set_failure(0,lul_device)  -- should be 0 in UI7
		else
			luup.set_failure(1,lul_device)  -- should be 0 in UI7
		end
	else
		luup.set_failure(false,lul_device)	-- should be 0 in UI7
	end

	log("startup completed")
end

------------------------------------------------
-- Check UI7
------------------------------------------------
local function checkVersion(lul_device)
  local ui7Check = luup.variable_get(DENON_SERVICE, "UI7Check", lul_device) or ""
  if ui7Check == "" then
	luup.variable_set(DENON_SERVICE, "UI7Check", "false", lul_device)
	ui7Check = "false"
  end
  if( luup.version_branch == 1 and luup.version_major == 7) then
	if (ui7Check == "false") then
		-- first & only time we do this
		luup.variable_set(DENON_SERVICE, "UI7Check", "true", lul_device)
		luup.attr_set("device_json", UI7_JSON_FILE, lul_device)
		luup.reload()
	end
  else
	-- UI5 specific
  end
end

function initstatus(lul_device)
  lul_device = tonumber(lul_device)
  this_device = lul_device
  -- this_device = lul_device
  log("initstatus("..lul_device..") starting version: "..version)
  checkVersion(lul_device)
  -- hostname = getIP()
  local delay = 1	-- delaying first refresh by x seconds
  debug("initstatus("..lul_device..") startup for Root device, delay:"..delay)
  luup.call_delay("startupDeferred", delay, tostring(lul_device))
end

-- do not delete, last line must be a CR according to MCV wiki page

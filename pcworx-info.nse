local bin = require "bin"
local nmap = require "nmap"
local shortport = require "shortport"
local stdnse = require "stdnse"
local table = require "table"

description = [[
This NSE script will query and parse pcworx protocol to a remote PLC. 
The script will send a initial request packets and once a response is received,
it validates that it was a proper response to the command that was sent, and then 
will parse out the data. PCWorx is a protocol and Program by Phoenix Contact. 


http://digitalbond.com

]]
---
-- @usage
-- nmap --script pcworx-info -sU  -p 1962 <host>
--
--
-- @output
--| pcworx-info: 
--1962/tcp open  pcworx
--| pcworx-info:
--|   PLC Type: ILC 330 ETH
--|   Model Number: 2737193
--|   Firmware Version: 3.95T
--|   Firmware Date: Mar  2 2012
--|_  Firmware Time: 09:39:02
 
--
--
-- @xmloutput
--<elem key="PLC Type">ILC 330 ETH</elem>
--<elem key="Model Number">2737193</elem>
--<elem key="Firmware Version">3.95T</elem>
--<elem key="Firmware Date">Mar  2 2012</elem>
--<elem key="Firmware Time">09:39:02</elem>
author = "Stephen Hilt (Digital Bond)"
license = "Same as Nmap--See http://nmap.org/book/man-legal.html"
categories = {"discovery", "version"}

--
-- Function to define the portrule as per nmap standards
--
--
portrule = shortport.portnumber(1962, "tcp")

---
--  Function to set the nmap output for the host, if a valid pcworx Protocol packet
--  is received then the output will show that the port is open instead of
--
-- @param host Host that was passed in via nmap
-- @param port port that pcworx Protocol is running on (Default TCP/1962)
function set_nmap(host, port)

  --set port Open
  port.state = "open"
  -- set version name to pcworx Protocol
  port.version.name = "pcworx"
  nmap.set_port_version(host, port)
  nmap.set_port_state(host, port, "open")

end

---
--  Action Function that is used to run the NSE. This function will send the initial query to the
--  host and port that were passed in via nmap. The initial response is parsed to determine if host
--  is a pcworx Protocol device. If it is then more actions are taken to gather extra information.
--
-- @param host Host that was scanned via nmap
-- @param port port that was scanned via nmap
action = function(host,port)
  local init_comms = bin.pack("H","0101001a0000000078800003000c494245544830314e305f4d00")
  
  -- create table for output
  local output = stdnse.output_table()
  -- create local vars for socket handling
  local socket, try, catch
  -- create new socket
  socket = nmap.new_socket()
  -- define the catch of the try statement
  catch = function()
    socket:close()
  end
  -- create new try
  try = nmap.new_try(catch)
  try(socket:connect(host, port))
  try(socket:send(init_comms))
  -- receive response
  local rcvstatus, response = socket:receive()
  if(rcvstatus == false) then
    return false, response
  end
  -- pcworx has a session ID that is generated by the PLC
  -- This will pull the SID so we can communicate further to the PLC
  local pos, sid = bin.unpack("C", response, 18)
  local init_comms2 = bin.pack("HCH","0105001600010000788000", sid, "00000006000402950000")  
  try(socket:send(init_comms2))
  -- receive response
  local rcvstatus, response = socket:receive()
  if(rcvstatus == false) then
    return false, response
  end
  -- this is the request that will pull all the information from the PLC
  local req_info = bin.pack("HCH","0106000e00020000000000",sid,"0400")
  try(socket:send(req_info))
  -- receive response
  local rcvstatus, response = socket:receive()
  if(rcvstatus == false) then
    return false, response
  end
  local pos, check1 = bin.unpack("C",response,1)
  -- if the response starts with 0x81 then we will continue
  if(check1 == 0x81) then
	-- set the port information via nmap output
    set_nmap(host, port)
    -- create output table with proper data
    pos, output["PLC Type"] = bin.unpack("z",response,31)
	pos, output["Model Number"] = bin.unpack("z", response, 153)
	pos, output["Firmware Version"] = bin.unpack("z",response, 67)
	pos, output["Firmware Date"] = bin.unpack("z", response, 80)
	pos, output["Firmware Time"] = bin.unpack("z", response, 92)
	
	-- close socket and return output table
	socket:close()
	return output
  end
  -- close socket
  socket:close()
  -- return nil
  return nil
end	
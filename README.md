# Implementation of a JSON-RPC 2.0 client for MATLAB
 
## Syntax
`PROXY = jsonrpc(URL, ...)`

## Description
`PROXY = jsonrpc(URL, ...)` initializes a proxy object that manages 
the communication with a JSON-RPC 2.0 server. The URL argument is
the server URL, e.g. `http://localhost:1080`.
The URL argument may be followed by name/value pairs that are
passed to WEBOPTIONS. This is useful e.g. to increase the connection
timeout for RPC commands that require a long time to complete.
Note that the `MediaType` weboption is always `application/json`
and cannot be changed.

RPC methods of the server are invoked as if they were methods of
the proxy object itself.

Note that all request objects sent by jsonrpc include an id member;
notifications are not supported.

## Example
```matlab
% Initialize a proxy object with a connection timeout of 10
% seconds and list the methods supported by the JSON-RPC server.
% This assumes that the server supports introspection.
proxy = jsonrpc('http://localhost:1080', 'Timeout', 10)
proxy.system.listMethods()
```
jsonrpc uses WEBWRITE for the actual communication with the server.

See also weboptions, webwrite, [https://www.jsonrpc.org](https://www.jsonrpc.org)

Copyright (c) 2022 Plexim GmbH
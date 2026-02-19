classdef jsonrpc < handle
    % Jsonrpc Implementation of a JSON-RPC 2.0 client
    %
    %   Syntax
    %   ------
    %   PROXY = JSONRPC(URL, ...)
    %
    %   Description
    %   -----------
    %   PROXY = JSONRPC(URL, ...) initializes a proxy object that manages
    %   the communication with a JSON-RPC 2.0 server. The URL argument is
    %   the server URL, e.g. 'http://localhost:1080'.
    %   The URL argument may be followed by name/value pairs that are
    %   passed to WEBOPTIONS. This is useful e.g. to increase the connection
    %   timeout for RPC commands that require a long time to complete.
    %   Note that the 'MediaType' weboption is 'application/json' for MATLAB
    %   and 'application/x-www-form-urlencoded' for Octave and cannot be changed.
    %
    %   RPC methods of the server are invoked as if they were methods of
    %   the proxy object itself. Method parameters are transparently
    %   converted from MATLAB to JSON, and results are transparently
    %   converted from JSON to MATLAB.
    %
    %   Note that all request objects sent to the servcer include an id
    %   member; notifications are not supported.
    %
    %   Example
    %   -------
    %   % Initialize a proxy object with a connection timeout of 10
    %   % seconds and list the methods supported by the JSON-RPC server.
    %   % This assumes that the server supports introspection.
    %   proxy = jsonrpc('http://localhost:1080', 'Timeout', 10)
    %   proxy.system.listMethods()
    %
    %   JSONRPC uses WEBWRITE for the actual communication with the server.
    %
    %   See also WEBOPTIONS, WEBWRITE, https://www.jsonrpc.org
    %
    %   MIT License
    %   Copyright (c) 2022 Plexim GmbH

    % Permission is hereby granted, free of charge, to any person obtaining a copy
    % of this software and associated documentation files (the "Software"), to deal
    % in the Software without restriction, including without limitation the rights
    % to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    % copies of the Software, and to permit persons to whom the Software is
    % furnished to do so, subject to the following conditions:
    %
    % The above copyright notice and this permission notice shall be included in all
    % copies or substantial portions of the Software.
    %
    % THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    % IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    % FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    % AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    % LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    % OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    % SOFTWARE.

    properties
        Url = []
        Options = []
        Id = []
        IsOctave = []
    end
    methods
        function obj = jsonrpc(url, varargin)
            obj.Url = url;
            obj.Id = 0;

            % Detect if running in Octave or MATLAB
            obj.IsOctave = exist('OCTAVE_VERSION', 'builtin') ~= 0;

            % Set MediaType based on environment
            if obj.IsOctave
                mediaType = 'application/x-www-form-urlencoded';
            else
                mediaType = 'application/json';
            end

            options = weboptions(varargin{:});
            if ~strcmp(options.MediaType, mediaType) && any(strcmp(varargin, 'MediaType'))
                warning('JSONRPC:SetOptions:MediaType', 'overriding option ''MediaType'' with ''%s''', mediaType);
            end
            options.MediaType = mediaType;
            obj.Options = options;
        end

        function set.Options(obj, options)
            if ~isa(options, 'weboptions')
                error('JSONRPC:SetOptions', 'argument must be a WEBOPTIONS object')
            end

            % Set MediaType based on environment
            if obj.IsOctave
                mediaType = 'application/x-www-form-urlencoded';
            else
                mediaType = 'application/json';
            end

            if ~strcmp(options.MediaType, mediaType)
                warning('JSONRPC:SetOptions:MediaType', 'overriding option ''MediaType'' with ''%s''', mediaType);
            end
            options.MediaType = mediaType;
            obj.Options = options;
        end

        function result = subsref(obj, s)
            % implement getter for properties
            if numel(s) == 1 && strcmp(s.type, '.')
                result = obj.(s.subs);
                return
            end

            % check call syntax: obj.cmd1.cmd2.cmd3(varargin)
            if ~all(strcmp({s(1:end-1).type}, '.')) || ~strcmp(s(end).type, '()')
                error('JSONRPC:Invoke', 'syntax error')
            end

            % prepare request
            % Use strjoin for Octave, join for MATLAB
            if obj.IsOctave
                method = char(strjoin({s(1:end-1).subs}, '.'));
            else
                method = char(join({s(1:end-1).subs}, '.'));
            end

            params = s(end).subs;
            obj.Id = obj.Id + 1;
            request = struct(...
                'jsonrpc', '2.0', ...
                'method', method, ...
                'params', {params}, ...
                'id', obj.Id);

            % send request (different approach for Octave vs MATLAB)
            if obj.IsOctave
                response = webwrite(obj.Url, 'data', jsonencode(request), obj.Options);
                % convert to struct if needed
                if ischar(response)
                    response = jsondecode(response);
                end
            else
                response = webwrite(obj.Url, request, obj.Options);
            end

            % sanity check
            if ~isstruct(response)
                response = char(response);
                if length(response) > 100
                    response = [response(1:97) '...'];
                end
                error('JSONRPC:Invoke', 'server did not send a JSON response but this instead:\n%s', ...
                    response)
            end

            % check response id
            if response.id ~= obj.Id
                error('JSONRPC:Invoke', 'server response id (%i) does not match request id (%i)', ...
                    response.id, obj.Id)
            end

            % evaluate response
            if isfield(response, 'result')
                result = response.result;
            elseif isfield(response, 'error')
                error('JSONRPC:Invoke', 'server responded with error %i when invoking ''%s'': %s', ...
                    response.error.code, ...
                    method, ...
                    response.error.message);
            else
                error('unknown error');
            end
        end
    end
end

function value = imosQCFlag( qc_class, qc_set, field )
%IMOSQCFLAG Returns an appropriate QC flag value (String), description, color 
% speck, or set description for the given qc_class (String), using the given 
% qc_set (integer).

% The QC sets definitions, descriptions, and valid flag values for each, are 
% maintained in the file  'imosQCSets.txt' which is stored  in the same 
% directory as this m-file.
%
% The value returned by this function is one of:
%   - the appropriate QC flag value to use for flagging data when using the 
%     given QC set. 
%   - a human readable description of the flag meaning.
%   - a ColorSpec which should be used when displaying the flag
%   - a human readable description of the qc set.
%
% Inputs:
%
%   qc_class - must be one of the (case insensitive) strings listed in the 
%              imosQCSets.txt file. If it is not equal to one of these strings, 
%              the flag and desc return values will be empty.
%
%   qc_set   - must be an integer identifier to one of the supported QC sets. 
%              If it does not map to a supported QC set, it is assumed to be 
%              the first qc set defined in the imosQCSets.txt file.
%
%   field    - String which defines what the return value is. Must be one
%              of 'flag', 'desc', 'set_desc' or 'color'.
%
% Outputs:
%   value    - One of the flag value, flag description, or set description.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%

error(nargchk(3, 3, nargin));
if ~ischar(qc_class),  error('qc_class must be a string'); end
if ~isnumeric(qc_set), error('qc_set must be numeric');    end
if ~ischar(field),     error('field must be a string');    end

value = '';

% open the IMOSQCSets file - it should be 
% in the same directory as this m-file
path = fileparts(which(mfilename));

fid = -1;
flags = [];
sets = [];
try
  fid = fopen([path filesep 'imosQCSets.txt']);
  if fid == -1, return; end

  % read in the QC sets and flag values for each set
  sets  = textscan(fid, '%f%s',       'delimiter', ',', 'commentStyle', '%');
  flags = textscan(fid, '%f%s%s%s%s', 'delimiter', ',', 'commentStyle', '%');
  fclose(fid);

catch e
  if fid ~= -1, fclose(fid); end
  rethrow(e);
end

% no set definitions in file
if isempty(sets{1}), return; end

% no flag definitions in file
if isempty(flags{1}), return; end

% get the qc set description (or reset the qc set to 1)
qc_set_idx = find(sets{1} == qc_set);
if isempty(qc_set_idx), qc_set_idx = 1; end;

set_desc = sets{2}(qc_set_idx);
set_desc = set_desc{1};

flag  = '';
color = '';
desc  = '';

% find a flag entry with matching qc_set and qc_class values
lines = find(flags{1} == qc_set);
for k=1:length(lines)
  
  classes = flags{5}{lines(k)};
  
  % dirty hack to get around matlab's lack of support for word boundaries
  classes = [' ' classes ' '];
  
  % if this flag matches the class, we've found the flag value to return
  if ~isempty(regexpi(classes, ['\s' qc_class '\s'], 'match'))
    
    flag  = flags{2}{lines(k)};
    desc  = flags{3}{lines(k)};
    color = flags{4}{lines(k)};
    
    % if color was specified numerically, convert it from a string
    temp = str2num(color);
    if ~isempty(temp), color = temp; end
    
    break;
    
  end
end

switch field
  case 'flag',     value = flag;
  case 'desc',     value = desc;
  case 'color',    value = color;
  case 'set_desc', value = set_desc;
end

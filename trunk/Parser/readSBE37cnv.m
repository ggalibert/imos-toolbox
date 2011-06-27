function data = readSBE37cnv( dataLines, instHeader, procHeader )
%READSBE37CNV Processes data from a Seabird .cnv file.
%
% This function is able to process data retrieved from a converted (.cnv) 
% data file generated by the Seabird SBE Data Processing program. This
% function is called from SBE37SMParse.
%
% Inputs:
%   dataLines  - Cell array of strings, the data lines in the original file.
%   instHeader - Struct containing instrument header.
%   procHeader - Struct containing processed header.
%
% Outputs:
%   data       - Struct containing data.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
% Modified by: Brad Morris <b.morris@unsw.edu.au>

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
  error(nargchk(3,3,nargin));
  
  data = struct;
  
  format = '';
  
  columns = procHeader.columns;
  for k = 1:length(columns), format = [format '%n']; end
  
  dataLines = [dataLines{:}];
  dataLines = textscan(dataLines, format);
  
  for k = 1:length(columns)
    
    d = dataLines{k};
    d(d == procHeader.badFlag) = nan;
    
%     [n, d] = convertData(genvarname(columns{k}), d, instHeader);
    [n, d] = convertData(genvarname(columns{k}), d, procHeader);
    
    if isempty(n) || isempty(d), continue; end
    
    % if the same parameter appears multiple times, 
    % don't overwrite it in the data struct - append
    % a number to the end of the variable name, as 
    % per the IMOS convention
    count = 0;
    nn = n;
    while isfield(data, nn)
      
      count = count + 1;
      nn = [n '_' num2str(count)];
    end
    
    data.(nn) = d; 
  end
end

function [name, data] = convertData(name, data, procHeader)
%CONVERTDATA The .cnv file provides data in a bunch of different units of
% measurement. This function is just a big switch statement which takes
% SBE17SM data as input, and attempts to convert it to IMOS compliant name and
% unit of measurement. Returns empty string/vector if the parameter is not
% supported.
%
%BDM (18/02/2011) - Modified to suit SBE37SM - i.e. ORS065

%This is not used for SBE37SM
% the cast date, if present, is used for time field offset
castDate = 0;
% if isfield(instHeader, 'castDate'), castDate = instHeader.castDate; end

%sort out start year for conversion of Julian days
startYear=2010;%This is clumsy - may need fixing!!
if isfield(procHeader,'startTime'),startYear=str2num(datestr(procHeader.startTime,'yyyy')); end

switch name
    
    % elapsed time (seconds since start)
    case 'timeS'
        name = 'TIME';
        data = data / 86400 + castDate;
        
        % elapsed time (minutes since start)
    case 'timeM'
        name = 'TIME';
        data = data / 1440 + castDate;
        
        % elapsed time (hours since start)
    case 'timeH'
        name = 'TIME';
        data = data / 24  + castDate;
        
        % elapsed time (days since start of year)
    case 'timeJ'
        name = 'TIME';
        %data = rem(data, floor(data)) + floor(castDate);
        data = data + datenum(startYear-1,12,31);
        
        % strain gauge pressure (dbar)
        %case 'prdM'
    case 'prM'
        name = 'PRES';
        
        % temperature (deg C)
        %case 'tv290C'
    case 't090C'
        name = 'TEMP';
        
        % conductivity (S/m)
    case 'c0S0x2Fm'
        name = 'CNDC';
        
        % conductivity (mS/cm)
        % mS/cm -> S/m
    case 'c0ms0x2Fcm'
        name = 'CNDC';
        data = data ./ 10;
        
        % conductivity (uS/cm)
    case 'c0us0x2Fcm'
        name = 'CNDC';
        data = data ./ 100000;
        
        % fluorescence (ug/L)
        % ug/L == mg/m^-3
    case 'flC'
        name = 'FLU2';
        
        % fluorescence (mg/m^3)
    case 'flECO0x2DAFL'
        name = 'FLU2';
        
        % oxygen (mg/L)
        % mg/L == kg/m^3
    case 'oxsolMg0x2FL'
        name = 'DOXY';
        
        % oxygen (umol/Kg)
        % umol/Kg -> mol/Kg
    case 'oxsolMm0x2FKg'
        name = 'DOX2';
        data = data ./ 1000000;
        
        % oxygen (mg/L)
        % mg/L == kg/m^3
    case 'oxsatMg0x2FL'
        name = 'DOXY';
        
        % oxygen (umol/Kg)
        % umol/Kg -> mol/Kg
    case 'oxsatMm0x2FKg'
        name = 'DOX2';
        data = data ./ 1000000;
        
        % oxygen (mg/L)
        % mg/L == kg/m^3
    case 'sbeox0Mg0x2FL'
        name = 'DOXY';
        
        % oxygen (umol/Kg)
        % umol/Kg -> mol/Kg
    case 'sbeox0Mm0x2FKg'
        name = 'DOX2';
        data = data ./ 1000000;
        
        % salinity (PSU)
    case 'sal00'
        name = 'PSAL';
        
        % turbidity (NTU)
    case 'obs'
        name = 'TURB';
        
        % turbidity (NTU)
    case 'upoly0'
        name = 'TURB';
        
        % depth (m)
    case 'depSM'
        name = 'DEPTH';
        
        % depth (m)
    case 'depFM'
        name = 'DEPTH';
                      
    otherwise
        name = '';
        data = [];
end
end

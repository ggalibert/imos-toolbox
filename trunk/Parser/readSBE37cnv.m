function [data, comment] = readSBE37cnv( dataLines, instHeader, procHeader )
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
%   data       - Struct containing variable data.
%   comment    - Struct containing variable comment.
%
% Author: 		Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor: 	Brad Morris <b.morris@unsw.edu.au>
% 				Guillaume Galibert <guillaume.galibert@utas.edu.au>

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
  comment = struct;
  
  columns = procHeader.columns;
  
  format = '%n';
  format = repmat(format, 1, length(columns));
  
  dataLines = [dataLines{:}];
  dataLines = textscan(dataLines, format);
  
  for k = 1:length(columns)
    
    d = dataLines{k};
    d(d == procHeader.badFlag) = nan;
    
%     [n, d] = convertData(genvarname(columns{k}), d, instHeader);
    [n, d, c] = convertData(genvarname(columns{k}), d, procHeader);
    
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
    comment.(nn) = c;
  end
  
  % Let's add a new parameter if DOX1, PSAL/CNDC, TEMP and PRES are present and
  % not DOX2
  if isfield(data, 'DOX1') && ~isfield(data, 'DOX2')
      
      % umol/l -> umol/kg
      %
      % to perform this conversion, we need to calculate the
      % density of sea water; for this, we need temperature,
      % salinity, and pressure data to be present
      temp = isfield(data, 'TEMP');
      pres = isfield(data, 'PRES_REL');
      psal = isfield(data, 'PSAL');
      cndc = isfield(data, 'CNDC');
      
      % if any of this data isn't present,
      % we can't perform the conversion to umol/kg
      if temp && pres && (psal || cndc)
          temp = data.TEMP;
          pres = data.PRES_REL;
          if psal
              psal = data.PSAL;
          else
              cndc = data.CNDC;
              % conductivity is in S/m and gsw_C3515 in mS/cm
              crat = 10*cndc ./ gsw_C3515;
              
              psal = gsw_SP_from_R(crat, temp, pres);
          end
          
          % calculate density from salinity, temperature and pressure
          dens = sw_dens(psal, temp, pres); % cannot use the GSW SeaWater library TEOS-10 as we don't know yet the position
          
          % umol/l -> umol/kg (dens in kg/m3 and 1 m3 = 1000 l)
          data.DOX2 = data.DOX1 .* 1000.0 ./ dens;
          comment.DOX2 = ['Originally expressed in mg/l, assuming O2 density = 1.429kg/m3, 1ml/l = 44.660umol/l '...
          'and using density computed from Temperature, Salinity and Pressure '...
          'with the CSIRO SeaWater library (EOS-80) v1.1.'];
      end
  end
end

function [name, data, comment] = convertData(name, data, procHeader)
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
if isfield(procHeader, 'startTime')
    castDate = procHeader.startTime;
end

%sort out start year for conversion of Julian days
startYear=2010;%This is clumsy - may need fixing!!
if isfield(procHeader,'startTime')
    startYear=str2double(datestr(procHeader.startTime,'yyyy')); 
end

switch name
    
        % elapsed time (seconds since start)
    case 'timeS'
        name = 'TIME';
        data = data / 86400 + castDate;
        comment = '';
        
        % elapsed time (seconds since 01-Jan-2000)
    case 'timeK'
        name = 'TIME';
        data = data / 86400 + datenum(2000,1,1);
        comment = '';
        
        % elapsed time (minutes since start)
    case 'timeM'
        name = 'TIME';
        data = data / 1440 + castDate;
        comment = '';
        
        % elapsed time (hours since start)
    case 'timeH'
        name = 'TIME';
        data = data / 24  + castDate;
        comment = '';
        
        % elapsed time (days since start of year)
    case 'timeJ'
        name = 'TIME';
        %data = rem(data, floor(data)) + floor(castDate);
        data = data + datenum(startYear-1,12,31);
        comment = '';
        
        % strain gauge pressure (dbar)
        %case 'prdM'
    case {'pr', 'prM', 'prdM'}
        name = 'PRES_REL';
        comment = '';
        
        % strain gauge pressure (psi)
        % 1 psi = 0.68948 dBar
        % 1 dbar = 1.45038 psi
    case 'prdE'
        name = 'PRES_REL';
        data = data .* 0.68948;
        comment = '';
        
        % temperature (deg C)
        %case 'tv290C'
    case {'t090C', 'tv290C', 't090'}
        name = 'TEMP';
        comment = '';
        
        % conductivity (S/m)
    case {'c0S0x2Fm', 'cond0S0x2Fm'}
        name = 'CNDC';
        comment = '';
        
        % conductivity (mS/cm)
        % mS/cm -> S/m
    case {'c0ms0x2Fcm', 'cond0ms0x2Fcm', 'c0mS0x2Fcm', 'cond0mS0x2Fcm'}
        name = 'CNDC';
        data = data ./ 10;
        comment = '';
        
        % conductivity (uS/cm)
    case {'c0us0x2Fcm', 'cond0us0x2Fcm', 'c0uS0x2Fcm', 'cond0uS0x2Fcm'}
        name = 'CNDC';
        data = data ./ 10000;
        comment = '';
        
        % fluorescence (counts)
    case 'flC'
        name = 'FLU2';
        comment = '';
        
        % artificial chlorophyll from fluorescence (mg/m3)
    case 'flECO0x2DAFL'
        name = 'CHLF';
        comment = 'Artificial chlorophyll data computed from bio-optical sensor raw counts measurements using factory calibration coefficient.';
        
        % oxygen (mg/l)
        % mg/l => umol/l
    case {'oxsolMg0x2FL', 'oxsatMg0x2FL', 'sbeox0Mg0x2FL'}
        name = 'DOX1';
        data = data .* 44.660/1.429; % O2 density = 1.429kg/m3
        comment = 'Originally expressed in mg/l, O2 density = 1.429kg/m3 and 1ml/l = 44.660umol/l were assumed.';
        
        % oxygen (umol/Kg)
        % umol/Kg
    case {'oxsolMm0x2FKg', 'oxsatMm0x2FKg', 'sbeox0Mm0x2FKg'}
        name = 'DOX2';
        comment = '';
        
        % salinity (PSU)
    case 'sal00'
        name = 'PSAL';
        comment = '';
        
        % turbidity (NTU)
    case {'obs', 'upoly0'}
        name = 'TURB';
        comment = '';
        
        % depth (m)
    case {'depSM', 'depFM'}
        name = 'DEPTH';
        comment = '';
                      
    otherwise
        name = '';
        data = [];
        comment = '';
end
end

function sample_data=adcpWorkhorseRDIensembleAveragingPP(sample_data, qcLevel, ~)
% function sample_data_averaged=adcpWorkhorseRDIensembleAveragingPP(sample_data, qcLevel, ~)
% Uses a moving average to smooth the data, then interpolates to new time
% grid
% Required inputs:
%	sample_data: structure of data for all instruments
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
% Outputs:
%	sample_data_averaged: structure with ensemble averaged data
% Author:      Rebecca Cowley <rebecca.cowley@csiro.au>
%

%
% Copyright (C) 2021, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
%% Improvements & Limitations
%		Not all datafields will be supported, it's a work in progress
% 		Could output a structure with all the structures, but given the shear volume of data, I prefer saving as we go so that I can restart a given Navg
%	Should remove fields not used in adcp, to make it smaller/faster fpr the code to handle
%   Moved to a PP routine after review of single-ping processing
narginchk(2, 3);
if ~iscell(sample_data), error('sample_data must be a cell array'); end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

% read in filter parameters
propFile = fullfile('Preprocessing', 'adcpWorkhorseRDIensembleAveragingPP.txt');
binInt     = str2double(readProperty('binIntPP',   propFile));

% read dataset QC parameters if exist and override previous 
% parameters file
currentQCtest = mfilename;

%get our new structure ready:
sample_data_averaged = sample_data;

for k = 1:length(sample_data)
    % do not process if not RDI nor Nortek
    isRDI = false;
    if strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), isRDI = true; end
    if ~isRDI, continue; end 

    binInt = readDatasetParameter(sample_data{k}.toolbox_input_file, currentQCtest, 'binIntPP', binInt);
    %set up the time range
    time = sample_data{k}.dimensions{1}.data;
    sampInt = sample_data{k}.instrument_sample_interval; % mean samping interval in seconds
    N = binInt/sampInt;
    new_datestamp = time(1)+(N*sampInt/2)/(3600*24):binInt/(3600*24):time(end); % the datestmp mid-way through the interval, str date
    
    %PRESSURE-averaging.  If pressure recorded every ping, it
    %is noisy, this needs to be cleaned up first
    ind = IMOS.find(sample_data{k}.variables,{'DEPTH'});
    if ~isempty(ind)
        disp('Warning, DEPTHPP routine should be run after bin averaging. Not completing bin averaging.');
        return
    end
    ind = IMOS.find(sample_data{k}.variables,{'PRES_REL'});
    if ~isempty(ind)
        sample_data{k}.variables{ind}.data = g_boxcar_smoothNONAN(sample_data{k}.variables{ind}.data',N)';
    end
    
    %start bin averaging
    isBinAverageApplied = false;
    % now we operate on anything with TIME as a dimension.
    fldnms = IMOS.get(sample_data{k}.variables,'name');
    for j=1:length(fldnms)
        if ~IMOS.var_contains_dim(sample_data{k}, fldnms{j}, 'TIME')
            continue
        end
        isBinAverageApplied = true;
        % bin average the data:
        if binInt<sampInt
            warning('You''ve specified an averaging period smaller than sampling interval, aborted.');
            continue
        end
        %remove flagged data before continuing:
        singlePing = sample_data{k}.variables{j}.data;
        try
            flags = sample_data{k}.variables{j}.flags;
        catch
            flags = zeros(size(singlePing));
        end
        if isreal(singlePing)
            singlePing(flags > 2) = NaN;
        else
            singlePing(flags > 2) = NaN + NaN*i;
        end
        
        inan = isnan(singlePing);
        if ~isreal(singlePing)
            avDat1 = g_boxcar_smoothNONAN(imag(singlePing)',N)';
            avDat2 = g_boxcar_smoothNONAN(real(singlePing)',N)';
            avDat = complex(avDat2,avDat1);
        else
            avDat = g_boxcar_smoothNONAN(singlePing',N)';
        end
        if isreal(avDat)
            avDat(inan) = NaN;
        else
            avDat(inan) = NaN + NaN*i;
        end
        
        %now interpolate
        averagedData = interp1(time,avDat,new_datestamp');
        if isBinAverageApplied
            % we re-assign the data
            sample_data_averaged{k}.variables{j}.data = averagedData;
            
            %reset flags to zero for upcoming QC
            sample_data_averaged{k}.variables{j}.flags = zeros(size(averagedData));
        end
    end
    if isBinAverageApplied
        sample_data_averaged{k}.dimensions{1}.data = new_datestamp';
        sample_data_averaged{k}.dimensions{1}.flags = zeros(size(new_datestamp'));
        sample_data_averaged{k}.time_coverage_start = new_datestamp(1);
        sample_data_averaged{k}.time_coverage_end = new_datestamp(end);
        sample_data_averaged{k}.instrument_average_interval = binInt;
        sample_data_averaged{k}.meta.instrument_average_interval = binInt;

        %update the time dimension comment:
        sample_data_averaged{k}.dimensions{1}.comment = ...
            ['Time stamp corresponds to the middle of the measurement which lasts ' num2str(binInt) ' seconds.'];
        sample_data_averaged{k}.dimensions{1}.history = [sample_data_averaged{k}.dimensions{1}.history ...
            'Time has been bin averaged from single ping data, original seconds_to_middle_of_measurement = ' ...
            num2str(sample_data_averaged{k}.dimensions{1}.seconds_to_middle_of_measurement)];
        sample_data_averaged{k}.dimensions{1}.seconds_to_middle_of_measurement = 0;
    end
    
    %assign sample_data_averaged back to sample_data
    sample_data{k} = sample_data_averaged{k};
    
    % write/update dataset QC parameters
    writeDatasetParameter(sample_data{k}.toolbox_input_file, currentQCtest, 'binIntPP', binInt);
    binavecomment = ['adcpWorkhorseRDIbinAveragingPP.m: Ensemble averaging to ' num2str(binInt) 'seconds preprocessing applied.'];
    

    if isfield(sample_data{k}, 'history') && ~isempty(sample_data{k}.history)
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binavecomment);
    else
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binavecomment);
    end
end



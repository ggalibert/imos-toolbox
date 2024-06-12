function sample_data = signatureParse( filename, tMode )
%SIGNATUREPARSE Parses ADCP data from a raw Nortek Signature 
% binary (.ad2cp) file or a .mat that has extracted from the 
% Nortek instrument software(faster).
%
%
% Inputs:
%   filename    - Cell array containing the name of the raw signature
%                 file to parse (either .ad2cp or .mat).
%   tMode       - Toolbox data type mode.
% 
% Outputs:
%   sample_data - Struct containing sample data.
%
% Example:
%
% % for tests, see tests/Parser/testSignature.m
%
% author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
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
narginchk(1,2);

if ~iscellstr(filename), error('filename must be a cell array of strings'); end

% only one file supported
filename = filename{1};
[~, ~, ext] = fileparts(filename);

isMagBias = false;
magDec = 0;

switch lower(ext)
    case '.ad2cp'
        % read in all of the structures in the raw file
        structures = readAD2CPBinary(filename);
        
        acquisitionMode = fieldnames(structures);
        instrumentModel = '';
        % look for the string data record A0
        iA0 = contains(acquisitionMode,'IdA0');

        if any(iA0)
            % this is a string data record
            if structures.(acquisitionMode{iA0}).Data.Id == 16 || structures.(acquisitionMode{iA0}).Data.Id == 18
                iA0_Header = structures.(acquisitionMode{iA0}).Data.String;
                instrumentModel = Nortek.read_nortek_header_key(iA0_Header,'ID','STR','string');
                magDec = Nortek.read_nortek_header_key(iA0_Header,'GETUSER','DECL','float');
                Beam2xyz = Nortek.transfer_matrix(iA0_Header);
                structures = rmfield(structures, acquisitionMode{iA0});
                acquisitionMode(iA0) = [];
            end
        end

        i1A = contains(acquisitionMode,'Id1A');
        if any(i1A) %ignore extra information and avoid warnings below
            structures = rmfield(structures,acquisitionMode{i1A});
            acquisitionMode(i1A) = [];
        end
        
        % look for burst/average data record version 3
        i15 = contains(acquisitionMode,'Id15_Version3');
        i16 = contains(acquisitionMode,'Id16_Version3');
        is_version3 = i15 | i16;
        not_supported = {acquisitionMode{~is_version3}}';
        acquisitionMode = {acquisitionMode{is_version3}}';
        for k = 1:length(not_supported)
            dataRecordNamesNotSupported = not_supported{k};
            structures = rmfield(structures, dataRecordNamesNotSupported);
            warning('data record %s is not supported.',dataRecordNamesNotSupported);
        end

        if ~any(is_version3)
            error('Not a single burst/average data record version 3 format found (only format supported).');
        else
            serialNumber = num2str(structures.(acquisitionMode{1}).Data(1).SerialNumber);
        end
        
        data = struct;
        nDataset = length(acquisitionMode);
        for i=1:nDataset
            data.(acquisitionMode{i}).nSamples  = length(structures.(acquisitionMode{i}).Header);
            data.(acquisitionMode{i}).nCells    = unique(vertcat(structures.(acquisitionMode{i}).Data.nCells));
            data.(acquisitionMode{i}).nBeams    = unique(vertcat(structures.(acquisitionMode{i}).Data.nBeams));
            data.(acquisitionMode{i}).coordSys  = unique(vertcat(structures.(acquisitionMode{i}).Data.coordSys));
            data.(acquisitionMode{i}).cellSize  = unique(vertcat(structures.(acquisitionMode{i}).Data.CellSize))*0.001; % m
            data.(acquisitionMode{i}).blankDist = unique(vertcat(structures.(acquisitionMode{i}).Data.Blanking))*0.001; % m
            
            if length(data.(acquisitionMode{i}).nCells)    > 1, error('Multiple nCells values not supported'); end
            if length(data.(acquisitionMode{i}).nBeams)    > 1, error('Multiple nBeams values not supported'); end
            if length(data.(acquisitionMode{i}).coordSys)  > 1, error('Multiple coordSys values not supported'); end
            if length(data.(acquisitionMode{i}).cellSize)  > 1, error('Multiple cellSize values not supported'); end
            if length(data.(acquisitionMode{i}).blankDist) > 1, error('Multiple blankDist values not supported'); end
        
            % retrieve sample data
            data.(acquisitionMode{i}).Time               = vertcat(structures.(acquisitionMode{i}).Data.Time);
            data.(acquisitionMode{i}).speedOfSound       = vertcat(structures.(acquisitionMode{i}).Data.SpeedOfSound)*0.1; % m/s
            data.(acquisitionMode{i}).Temperature        = vertcat(structures.(acquisitionMode{i}).Data.Temperature)*0.01; % degree Celsius
            data.(acquisitionMode{i}).Pressure           = vertcat(structures.(acquisitionMode{i}).Data.Pressure)*0.001; % dBar
            data.(acquisitionMode{i}).Heading            = vertcat(structures.(acquisitionMode{i}).Data.Heading)*0.01; % deg
            data.(acquisitionMode{i}).Pitch              = vertcat(structures.(acquisitionMode{i}).Data.Pitch)*0.01; % deg
            data.(acquisitionMode{i}).Roll               = vertcat(structures.(acquisitionMode{i}).Data.Roll)*0.01; % deg
            data.(acquisitionMode{i}).Battery            = vertcat(structures.(acquisitionMode{i}).Data.BatteryVoltage)*0.1; % Volt
            data.(acquisitionMode{i}).Status             = vertcat(structures.(acquisitionMode{i}).Data.Status);
            data.(acquisitionMode{i}).Error              = vertcat(structures.(acquisitionMode{i}).Data.Error); % error codes for each cell of a velocity profile inferred from the beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
            data.(acquisitionMode{i}).AmbiguityVel       = vertcat(structures.(acquisitionMode{i}).Data.AmbiguityVel);
            data.(acquisitionMode{i}).TransmitEnergy     = vertcat(structures.(acquisitionMode{i}).Data.TransmitEnergy);
            data.(acquisitionMode{i}).NominalCorrelation = vertcat(structures.(acquisitionMode{i}).Data.NominalCorrelation);
            % support velocity data in ENU or beam coordinates
            data.(acquisitionMode{i}).isVelocityData = false;
            if isfield(structures.(acquisitionMode{i}).Data, 'VelocityData')
                switch data.(acquisitionMode{i}).coordSys
                    case 0 % 0 is ENU, 1 is XYZ and 2 is BEAM
                        velocity        = cat(3, structures.(acquisitionMode{i}).Data.VelocityData);
                        velocityScaling = repmat(10.^vertcat(structures.(acquisitionMode{i}).Data.VelocityScaling), 1, data.(acquisitionMode{i}).nCells);
                        data.(acquisitionMode{i}).Velocity_E      = squeeze(velocity(1,:,:))'.*velocityScaling; % m/s
                        data.(acquisitionMode{i}).Velocity_N      = squeeze(velocity(2,:,:))'.*velocityScaling;
                        data.(acquisitionMode{i}).Velocity_U      = squeeze(velocity(3,:,:))'.*velocityScaling;
                        if data.(acquisitionMode{i}).nBeams == 4
                            data.(acquisitionMode{i}).Velocity_U2     = squeeze(velocity(4,:,:))'.*velocityScaling;
                        end
                        clear velocity velocityScaling;
                        
                        data.(acquisitionMode{i}).isVelocityData = true;
                        data.(acquisitionMode{i}).coordSys = 'ENU';
                        
                    case 2
                        velocity        = cat(3, structures.(acquisitionMode{i}).Data.VelocityData);
                        velocityScaling = repmat(10.^vertcat(structures.(acquisitionMode{i}).Data.VelocityScaling), 1, data.(acquisitionMode{i}).nCells);
                        data.(acquisitionMode{i}).Velocity_1      = squeeze(velocity(1,:,:))'.*velocityScaling; % m/s
                        data.(acquisitionMode{i}).Velocity_2      = squeeze(velocity(2,:,:))'.*velocityScaling;
                        data.(acquisitionMode{i}).Velocity_3      = squeeze(velocity(3,:,:))'.*velocityScaling;
                        data.(acquisitionMode{i}).Velocity_4      = squeeze(velocity(4,:,:))'.*velocityScaling;
                        clear velocity velocityScaling;
                        
                        data.(acquisitionMode{i}).isVelocityData = true;
                        data.(acquisitionMode{i}).coordSys = 'BEAM';
                        
                end
            end
            
            if data.(acquisitionMode{i}).isVelocityData
                amplitude       = cat(3, structures.(acquisitionMode{i}).Data.AmplitudeData);
                data.(acquisitionMode{i}).Backscatter1    = squeeze(amplitude(1,:,:))'; % count
                data.(acquisitionMode{i}).Backscatter2    = squeeze(amplitude(2,:,:))';
                data.(acquisitionMode{i}).Backscatter3    = squeeze(amplitude(3,:,:))';
                if data.(acquisitionMode{i}).nBeams == 4
                    data.(acquisitionMode{i}).Backscatter4    = squeeze(amplitude(4,:,:))';
                end
                clear amplitude;
                
                correlation     = cat(3, structures.(acquisitionMode{i}).Data.CorrelationData);
                data.(acquisitionMode{i}).Correlation1    = squeeze(correlation(1,:,:))'; % percent [0 - 100]
                data.(acquisitionMode{i}).Correlation2    = squeeze(correlation(2,:,:))';
                data.(acquisitionMode{i}).Correlation3    = squeeze(correlation(3,:,:))';
                if data.(acquisitionMode{i}).nBeams == 4
                   data.(acquisitionMode{i}).Correlation4    = squeeze(correlation(4,:,:))';
                end
                clear correlation;
            end
            
            data.(acquisitionMode{i}).isAltimeterData = false;
            if isfield(structures.(acquisitionMode{i}).Data, 'AltimeterDistance')
                data.(acquisitionMode{i}).AltimeterDistanceLE    = vertcat(structures.(acquisitionMode{i}).Data.AltimeterDistance);
                data.(acquisitionMode{i}).AltimeterQualityLE     = vertcat(structures.(acquisitionMode{i}).Data.AltimeterQuality);
%                 data.(acquisitionMode{i}).AltimeterStatus        = vertcat(structures.(acquisitionMode{i}).Data.AltimeterStatus); % flags for when pitch or roll is > 5 or > 10. We already have pitch and roll data...
                
                data.(acquisitionMode{i}).isAltimeterData = true;
            end
            
            data.(acquisitionMode{i}).isASTData = false;
            if isfield(structures.(acquisitionMode{i}).Data, 'ASTDistance')
                data.(acquisitionMode{i}).AltimeterDistanceAST   = vertcat(structures.(acquisitionMode{i}).Data.ASTDistance);
                data.(acquisitionMode{i}).AltimeterQualityAST    = vertcat(structures.(acquisitionMode{i}).Data.ASTQuality);
                data.(acquisitionMode{i}).AltimeterTimeOffsetAST = vertcat(structures.(acquisitionMode{i}).Data.ASTOffset100uSec);
                data.(acquisitionMode{i}).AltimeterPressure      = vertcat(structures.(acquisitionMode{i}).Data.ASTPressure);
                
                data.(acquisitionMode{i}).isASTData = true;
            end
        end
        clear structures;
        
    case '.mat'
        [~, ~, cpuEndianness] = computer;
        
        % read in all of the structures in the file
        structures = load(filename);
        dataFields = fieldnames(structures.Data);
        
        % look for potentially more data in other .mat files
        [path, name, ext] = fileparts(filename);
        
        isAvgd = false;
        if any(strfind(name, '_avgd'))
            isAvgd = true;
        end
        
        if strcmpi(name(end-1:end), '_1')
            % we assume the first file is name_1.mat so the next one would
            % be name_2.mat
            name(end-1:end) = [];
            iMatFile = 2;
        else
            % we assume the first file is name.mat so the next one would be
            % name_1.mat
            iMatFile = 1;
        end
        nextFilename = fullfile(path, [name '_' num2str(iMatFile) ext]);
        
        while exist(nextFilename, 'file')
            nextStructures = load(nextFilename);
            % for each field of the structure we append new data to the
            % existing ones
            for i=1:length(dataFields)
                if isfield(nextStructures.Data, dataFields{i})
                    structures.Data.(dataFields{i}) = [structures.Data.(dataFields{i}); nextStructures.Data.(dataFields{i})];
                end
            end
            
            iMatFile = iMatFile + 1;
            nextFilename = fullfile(path, [name '_' num2str(iMatFile) ext]);
            clear nextStructures;
        end
        
        serialNumber = num2str(structures.Config.SerialNo);
        instrumentModel = structures.Config.InstrumentName;

        % check for magnetic declination
        magDec = structures.Config.Declination;
        
        % investigate which mode(s) has been set for acquisition
        acquisitionMode = {};
        configFields = fieldnames(structures.Config);
        if strcmpi(structures.Config.Plan_BurstEnabled, 'True') && ~isAvgd
            acquisitionMode{end+1} = 'Burst_';
        end
        if strcmpi(structures.Config.Plan_AverageEnabled, 'True')
            acquisitionMode{end+1} = 'Average_';
        end
        if isfield(structures.Config, 'Alt_Plan_BurstEnabled')
            if strcmpi(structures.Config.Alt_Plan_BurstEnabled, 'True') && ~isAvgd
                % we need to compare structures.Config.Plan_xxx VS structures.Config.Alt_Plan_xxx
                % to see if we can put together the two datasets
                configPlanFields    = configFields(strncmpi('Plan_', configFields, 5) & ~strncmpi('Plan_Average', configFields, 12));
                configAltPlanFields = configFields(strncmpi('Alt_Plan_', configFields, 9) & ~strncmpi('Alt_Plan_Average', configFields, 16));
                
                nPlanFields = length(configPlanFields);
                samePlan = false(nPlanFields, 1);
                for i=1:nPlanFields
                    if ischar(structures.Config.(configPlanFields{i}))
                        samePlan(i) = strcmp(structures.Config.(configPlanFields{i}), structures.Config.(configAltPlanFields{i}));
                    else
                        samePlan(i) = structures.Config.(configPlanFields{i}) == structures.Config.(configAltPlanFields{i});
                    end
                end
                
                configBurstFields    = configFields(strncmpi('Burst_', configFields, 6));
                configAltBurstFields = configFields(strncmpi('Alt_Burst_', configFields, 10));
                
                nBurstFields = length(configBurstFields);
                sameBurst = false(nBurstFields, 1);
                for i=1:nBurstFields
                    if ischar(structures.Config.(configBurstFields{i}))
                        sameBurst(i) = strcmp(structures.Config.(configBurstFields{i}), structures.Config.(configAltBurstFields{i}));
                    else
                        sameBurst(i) = all(all(structures.Config.(configBurstFields{i}) == structures.Config.(configAltBurstFields{i})));
                    end
                end
                
                if all(samePlan) && all(sameBurst)
                    % can be added to former dataset
                    [~, iBurst] = find(strcmp(acquisitionMode, 'Burst_'));
                    acquisitionMode{end+1, iBurst} = 'Alt_Burst_';
                else
                    % distinct dataset
                    acquisitionMode{1, end+1} = 'Alt_Burst_';
                end
            end
        end
        if isfield(structures.Config, 'Alt_Plan_AverageEnabled')
            if strcmpi(structures.Config.Alt_Plan_AverageEnabled, 'True')
                % we need to compare structures.Config.Plan_xxx VS structures.Config.Alt_Plan_xxx
                % to see if we can put together the two datasets
                configPlanFields    = configFields(strncmpi('Plan_', configFields, 5) & ~strncmpi('Plan_Burst', configFields, 10));
                configAltPlanFields = configFields(strncmpi('Alt_Plan_', configFields, 9) & ~strncmpi('Alt_Plan_Burst', configFields, 14));
                
                nPlanFields = length(configPlanFields);
                samePlan = false(nPlanFields, 1);
                for i=1:nPlanFields
                    if ischar(structures.Config.(configPlanFields{i}))
                        samePlan(i) = strcmp(structures.Config.(configPlanFields{i}), structures.Config.(configAltPlanFields{i}));
                    else
                        samePlan(i) = structures.Config.(configPlanFields{i}) == structures.Config.(configAltPlanFields{i});
                    end
                end
                
                configAvgFields    = configFields(strncmpi('Average_', configFields, 8));
                configAltAvgFields = configFields(strncmpi('Alt_Average_', configFields, 12));
                
                nAvgFields = length(configAvgFields);
                sameAvg = false(nAvgFields, 1);
                for i=1:nAvgFields
                    if ischar(structures.Config.(configAvgFields{i}))
                        sameAvg(i) = strcmp(structures.Config.(configAvgFields{i}), structures.Config.(configAltAvgFields{i}));
                    else
                        sameAvg(i) = all(all(structures.Config.(configAvgFields{i}) == structures.Config.(configAltAvgFields{i})));
                    end
                end
                
                if all(samePlan) && all(sameAvg)
                    % can be added to former dataset
                    [~, iAverage] = find(strcmp(acquisitionMode, 'Average_'));
                    acquisitionMode{end+1, iAverage} = 'Alt_Average_';
                else
                    % distinct dataset
                    acquisitionMode{1, end+1} = 'Alt_Average_';
                end
            end
        end
%         if strcmpi(structures.Config.Burst_Altimeter, 'True')
%             acquisitionMode{end+1} = 'BurstRawAltimeter_';
%         end
%         if strcmpi(structures.Config.Alt_Burst_Altimeter, 'True')
%             acquisitionMode{end+1} = 'Alt_BurstRawAltimeter_';
%         end
        
        data = struct;
        nDataset = size(acquisitionMode, 2);
        nBeams = 4; % default -- WHY IS THIS NEEDED - I don't think it is needed due to l.354 nBeams = blah
        for i=1:nDataset
            data.(acquisitionMode{1, i}).Time = structures.Data.([acquisitionMode{1, i} 'Time']);
            
            data.(acquisitionMode{1, i}).instrument_sample_interval = 1;
            
            data.(acquisitionMode{1, i}).nSamples    = length(data.(acquisitionMode{1, i}).Time);
            data.(acquisitionMode{1, i}).nCells      = double(structures.Config.([acquisitionMode{1, i} 'NCells']));
            data.(acquisitionMode{1, i}).nBeams      = double(structures.Config.([acquisitionMode{1, i} 'NBeams']));
            nBeams = data.(acquisitionMode{1, i}).nBeams;
            
            data.(acquisitionMode{1, i}).cellSize    = structures.Config.([acquisitionMode{1, i} 'CellSize']);
            data.(acquisitionMode{1, i}).blankDist   = structures.Config.([acquisitionMode{1, i} 'BlankingDistance']);
            
            data.(acquisitionMode{1, i}).Status         = dec2bin(bytecast(structures.Data.([acquisitionMode{1, i} 'Status']), 'L', 'uint32', cpuEndianness), 32);
            data.(acquisitionMode{1, i}).Error          = structures.Data.([acquisitionMode{1, i} 'Error']); % error codes for each cell of a velocity profile inferred from the beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
            data.(acquisitionMode{1, i}).AmbiguityVel   = structures.Data.([acquisitionMode{1, i} 'AmbiguityVel']);
            data.(acquisitionMode{1, i}).TransmitEnergy = structures.Data.([acquisitionMode{1, i} 'TransmitEnergy']);
            data.(acquisitionMode{1, i}).NominalCorrelation = structures.Data.([acquisitionMode{1, i} 'NominalCorrelation']);
            
            % support velocity data in ENU or beam coordinates
            data.(acquisitionMode{1, i}).isVelocityData = false;
            if isfield(structures.Data, [acquisitionMode{1, i} 'Velocity_ENU'])
                data.(acquisitionMode{1, i}).Velocity_E  = squeeze(structures.Data.([acquisitionMode{1, i} 'Velocity_ENU'])(:, 1, :));
                data.(acquisitionMode{1, i}).Velocity_N  = squeeze(structures.Data.([acquisitionMode{1, i} 'Velocity_ENU'])(:, 2, :));
                data.(acquisitionMode{1, i}).Velocity_U  = squeeze(structures.Data.([acquisitionMode{1, i} 'Velocity_ENU'])(:, 3, :));
                if( nBeams == 4 )
                    data.(acquisitionMode{1, i}).Velocity_U2 = squeeze(structures.Data.([acquisitionMode{1, i} 'Velocity_ENU'])(:, 4, :));
                end
                
                data.(acquisitionMode{1, i}).isVelocityData = true;
                data.(acquisitionMode{1, i}).coordSys = 'ENU';
            elseif isfield(structures.Data, [acquisitionMode{1, i} 'VelEast'])
                data.(acquisitionMode{1, i}).Velocity_E     = structures.Data.([acquisitionMode{1, i} 'VelEast']);
                data.(acquisitionMode{1, i}).Velocity_N     = structures.Data.([acquisitionMode{1, i} 'VelNorth']);
                if isfield(structures.Data, [acquisitionMode{1, i} 'VelUp'])
                    data.(acquisitionMode{1, i}).Velocity_U = structures.Data.([acquisitionMode{1, i} 'VelUp']);
                else
                    data.(acquisitionMode{1, i}).Velocity_U = structures.Data.([acquisitionMode{1, i} 'VelUp1']);
                end
                if( nBeams == 4 )
                    data.(acquisitionMode{1, i}).Velocity_U2    = structures.Data.([acquisitionMode{1, i} 'VelUp2']);
                end
                
                data.(acquisitionMode{1, i}).isVelocityData = true;
                data.(acquisitionMode{1, i}).coordSys = 'ENU';
            elseif isfield(structures.Data, [acquisitionMode{1, i} 'VelBeam1'])
                data.(acquisitionMode{1, i}).Velocity_1     = structures.Data.([acquisitionMode{1, i} 'VelBeam1']);
                data.(acquisitionMode{1, i}).Velocity_2     = structures.Data.([acquisitionMode{1, i} 'VelBeam2']);
                data.(acquisitionMode{1, i}).Velocity_3     = structures.Data.([acquisitionMode{1, i} 'VelBeam3']);
                data.(acquisitionMode{1, i}).Velocity_4     = structures.Data.([acquisitionMode{1, i} 'VelBeam4']);
                
                data.(acquisitionMode{1, i}).isVelocityData = true;
                data.(acquisitionMode{1, i}).coordSys = 'BEAM';
            end
            if data.(acquisitionMode{1, i}).isVelocityData
                data.(acquisitionMode{1, i}).Beam2xyz = structures.Config.([acquisitionMode{1, i} 'Beam2xyz']);
                if isfield(structures.Data, [acquisitionMode{1, i} 'Amplitude_Beam'])
                    data.(acquisitionMode{1, i}).Backscatter1 = squeeze(structures.Data.([acquisitionMode{1, i} 'Amplitude_Beam'])(:, 1, :))*2; % looks like the .mat format is giving dB by default with dB = raw counts * 0.5
                    data.(acquisitionMode{1, i}).Backscatter2 = squeeze(structures.Data.([acquisitionMode{1, i} 'Amplitude_Beam'])(:, 2, :))*2;
                    data.(acquisitionMode{1, i}).Backscatter3 = squeeze(structures.Data.([acquisitionMode{1, i} 'Amplitude_Beam'])(:, 3, :))*2;
                    if( nBeams == 4 )
                        data.(acquisitionMode{1, i}).Backscatter4 = squeeze(structures.Data.([acquisitionMode{1, i} 'Amplitude_Beam'])(:, 4, :))*2;
                    end
                elseif isfield(structures.Data, [acquisitionMode{1, i} 'AmpBeam1'])
                    data.(acquisitionMode{1, i}).Backscatter1 = structures.Data.([acquisitionMode{1, i} 'AmpBeam1'])*2;
                    data.(acquisitionMode{1, i}).Backscatter2 = structures.Data.([acquisitionMode{1, i} 'AmpBeam2'])*2;
                    data.(acquisitionMode{1, i}).Backscatter3 = structures.Data.([acquisitionMode{1, i} 'AmpBeam3'])*2;
                    if( nBeams == 4 )
                        data.(acquisitionMode{1, i}).Backscatter4 = structures.Data.([acquisitionMode{1, i} 'AmpBeam4'])*2;
                    end
                end
                if isfield(structures.Data, [acquisitionMode{1, i} 'Correlation_Beam'])
                    data.(acquisitionMode{1, i}).Correlation1 = squeeze(structures.Data.([acquisitionMode{1, i} 'Correlation_Beam'])(:, 1, :));
                    data.(acquisitionMode{1, i}).Correlation2 = squeeze(structures.Data.([acquisitionMode{1, i} 'Correlation_Beam'])(:, 2, :));
                    data.(acquisitionMode{1, i}).Correlation3 = squeeze(structures.Data.([acquisitionMode{1, i} 'Correlation_Beam'])(:, 3, :));
                    if( nBeams == 4 )
                        data.(acquisitionMode{1, i}).Correlation4 = squeeze(structures.Data.([acquisitionMode{1, i} 'Correlation_Beam'])(:, 4, :));
                    end
                elseif isfield(structures.Data, [acquisitionMode{1, i} 'CorBeam1'])
                    data.(acquisitionMode{1, i}).Correlation1 = structures.Data.([acquisitionMode{1, i} 'CorBeam1']);
                    data.(acquisitionMode{1, i}).Correlation2 = structures.Data.([acquisitionMode{1, i} 'CorBeam2']);
                    data.(acquisitionMode{1, i}).Correlation3 = structures.Data.([acquisitionMode{1, i} 'CorBeam3']);
                    if( nBeams == 4 )
                        data.(acquisitionMode{1, i}).Correlation4 = structures.Data.([acquisitionMode{1, i} 'CorBeam4']);
                    end
                end
            end
            
            data.(acquisitionMode{1, i}).isAltimeterData = false;
            if isfield(structures.Data, [acquisitionMode{1, i} 'AltimeterDistanceLE'])
                data.(acquisitionMode{1, i}).AltimeterDistanceLE    = structures.Data.([acquisitionMode{1, i} 'AltimeterDistanceLE']);
                data.(acquisitionMode{1, i}).AltimeterQualityLE     = structures.Data.([acquisitionMode{1, i} 'AltimeterQualityLE']);
%                 data.(acquisitionMode{1, i}).AltimeterStatus        = structures.Data.([acquisitionMode{1, i} 'AltimeterStatus']); % flags for when pitch or roll is > 5 or > 10. We already have pitch and roll data...
                
                data.(acquisitionMode{1, i}).isAltimeterData = true;
            end
            
            data.(acquisitionMode{1, i}).isASTData = false;
            if isfield(structures.Data, [acquisitionMode{1, i} 'AltimeterDistanceAST'])
                data.(acquisitionMode{1, i}).AltimeterDistanceAST   = structures.Data.([acquisitionMode{1, i} 'AltimeterDistanceAST']);
                data.(acquisitionMode{1, i}).AltimeterQualityAST    = structures.Data.([acquisitionMode{1, i} 'AltimeterQualityAST']);
                data.(acquisitionMode{1, i}).AltimeterTimeOffsetAST = structures.Data.([acquisitionMode{1, i} 'AltimeterTimeOffsetAST']);
                data.(acquisitionMode{1, i}).AltimeterPressure      = structures.Data.([acquisitionMode{1, i} 'AltimeterPressure']);
                
                data.(acquisitionMode{1, i}).isASTData = true;
            end
            
            data.(acquisitionMode{1, i}).Battery      = structures.Data.([acquisitionMode{1, i} 'Battery']);
            data.(acquisitionMode{1, i}).Heading      = structures.Data.([acquisitionMode{1, i} 'Heading']);
            data.(acquisitionMode{1, i}).Pitch        = structures.Data.([acquisitionMode{1, i} 'Pitch']);
            data.(acquisitionMode{1, i}).Roll         = structures.Data.([acquisitionMode{1, i} 'Roll']);
            data.(acquisitionMode{1, i}).Temperature  = structures.Data.([acquisitionMode{1, i} 'Temperature']);
            data.(acquisitionMode{1, i}).speedOfSound = structures.Data.([acquisitionMode{1, i} 'Soundspeed']);
            data.(acquisitionMode{1, i}).Pressure     = structures.Data.([acquisitionMode{1, i} 'Pressure']);
            
            if size(acquisitionMode, 1) == 2
                if ~isempty(acquisitionMode{2, i})
                    % we're adding the similar dataset to the existing one
                    data.(acquisitionMode{1, i}).Time = [data.(acquisitionMode{1, i}).Time; ...
                        structures.Data.([acquisitionMode{2, i} 'Time'])];
                    
                    data.(acquisitionMode{1, i}).nSamples    = length(data.(acquisitionMode{1, i}).Time);
                    
                    data.(acquisitionMode{1, i}).Status         = [data.(acquisitionMode{1, i}).Status; ...
                        dec2bin(bytecast(structures.Data.([acquisitionMode{2, i} 'Status']), 'L', 'uint32', cpuEndianness), 32)];
                    data.(acquisitionMode{1, i}).Error          = [data.(acquisitionMode{1, i}).Error; ...
                        structures.Data.([acquisitionMode{2, i} 'Error'])]; % error codes for each cell of a velocity profile inferred from the beams. 0=good; otherwise error. See http://www.nortek-as.com/en/knowledge-center/forum/waves/20001875?b_start=0#769595815
                    data.(acquisitionMode{1, i}).AmbiguityVel   = [data.(acquisitionMode{1, i}).AmbiguityVel; ...
                        structures.Data.([acquisitionMode{2, i} 'AmbiguityVel'])];
                    data.(acquisitionMode{1, i}).TransmitEnergy = [data.(acquisitionMode{1, i}).TransmitEnergy; ...
                        structures.Data.([acquisitionMode{2, i} 'TransmitEnergy'])];
                    data.(acquisitionMode{1, i}).NominalCorrelation = [data.(acquisitionMode{1, i}).NominalCorrelation; ...
                        structures.Data.([acquisitionMode{2, i} 'NominalCorrelation'])];
                    
                    % only support velocity data in ENU coordinates
                    if isfield(structures.Data, [acquisitionMode{2, i} 'Velocity_ENU'])
                        data.(acquisitionMode{1, i}).Velocity_E  = [data.(acquisitionMode{1, i}).Velocity_E; ...
                            squeeze(structures.Data.([acquisitionMode{2, i} 'Velocity_ENU'])(:, 1, :))];
                        data.(acquisitionMode{1, i}).Velocity_N  = [data.(acquisitionMode{1, i}).Velocity_N; ...
                            squeeze(structures.Data.([acquisitionMode{2, i} 'Velocity_ENU'])(:, 2, :))];
                        data.(acquisitionMode{1, i}).Velocity_U  = [data.(acquisitionMode{1, i}).Velocity_U; ...
                            squeeze(structures.Data.([acquisitionMode{2, i} 'Velocity_ENU'])(:, 3, :))];
                        data.(acquisitionMode{1, i}).Velocity_U2 = [data.(acquisitionMode{1, i}).Velocity_U2; ...
                            squeeze(structures.Data.([acquisitionMode{2, i} 'Velocity_ENU'])(:, 4, :))];
                        
                    elseif isfield(structures.Data, [acquisitionMode{2, i} 'VelEast'])
                        data.(acquisitionMode{1, i}).Velocity_E     = [data.(acquisitionMode{1, i}).Velocity_E; ...
                            structures.Data.([acquisitionMode{2, i} 'VelEast'])];
                        data.(acquisitionMode{1, i}).Velocity_N     = [data.(acquisitionMode{1, i}).Velocity_N; ...
                            structures.Data.([acquisitionMode{2, i} 'VelNorth'])];
                        if isfield(structures.Data, [acquisitionMode{2, i} 'VelUp'])
                            data.(acquisitionMode{1, i}).Velocity_U = [data.(acquisitionMode{1, i}).Velocity_U; ...
                                structures.Data.([acquisitionMode{2, i} 'VelUp'])];
                        else
                            data.(acquisitionMode{1, i}).Velocity_U = [data.(acquisitionMode{1, i}).Velocity_U; ...
                                structures.Data.([acquisitionMode{2, i} 'VelUp1'])];
                        end
                        data.(acquisitionMode{1, i}).Velocity_U2    = [data.(acquisitionMode{1, i}).Velocity_U2; ...
                            structures.Data.([acquisitionMode{2, i} 'VelUp2'])];
                        
                    elseif isfield(structures.Data, [acquisitionMode{1, i} 'VelBeam1'])
                        data.(acquisitionMode{1, i}).Velocity_1     = [data.(acquisitionMode{1, i}).Velocity_1; ...
                            structures.Data.([acquisitionMode{2, i} 'VelBeam1'])];
                        data.(acquisitionMode{1, i}).Velocity_2     = [data.(acquisitionMode{1, i}).Velocity_2; ...
                            structures.Data.([acquisitionMode{2, i} 'VelBeam2'])];
                        data.(acquisitionMode{1, i}).Velocity_3     = [data.(acquisitionMode{1, i}).Velocity_3; ...
                            structures.Data.([acquisitionMode{2, i} 'VelBeam3'])];
                        data.(acquisitionMode{1, i}).Velocity_4     = [data.(acquisitionMode{1, i}).Velocity_4; ...
                            structures.Data.([acquisitionMode{2, i} 'VelBeam4'])];
                        
                    end
                    if data.(acquisitionMode{1, i}).isVelocityData
                        if isfield(structures.Data, [acquisitionMode{2, i} 'Amplitude_Beam'])
                            data.(acquisitionMode{1, i}).Backscatter1 = [data.(acquisitionMode{1, i}).Backscatter1; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Amplitude_Beam'])(:, 1, :))*2]; % looks like the .mat format is giving dB by default with dB = raw counts * 0.5
                            data.(acquisitionMode{1, i}).Backscatter2 = [data.(acquisitionMode{1, i}).Backscatter2; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Amplitude_Beam'])(:, 2, :))*2];
                            data.(acquisitionMode{1, i}).Backscatter3 = [data.(acquisitionMode{1, i}).Backscatter3; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Amplitude_Beam'])(:, 3, :))*2];
                            data.(acquisitionMode{1, i}).Backscatter4 = [data.(acquisitionMode{1, i}).Backscatter4; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Amplitude_Beam'])(:, 4, :))*2];
                        elseif isfield(structures.Data, [acquisitionMode{2, i} 'AmpBeam1'])
                            data.(acquisitionMode{1, i}).Backscatter1 = [data.(acquisitionMode{1, i}).Backscatter1; ...
                                structures.Data.([acquisitionMode{2, i} 'AmpBeam1'])*2];
                            data.(acquisitionMode{1, i}).Backscatter2 = [data.(acquisitionMode{1, i}).Backscatter2; ...
                                structures.Data.([acquisitionMode{2, i} 'AmpBeam2'])*2];
                            data.(acquisitionMode{1, i}).Backscatter3 = [data.(acquisitionMode{1, i}).Backscatter3; ...
                                structures.Data.([acquisitionMode{2, i} 'AmpBeam3'])*2];
                            data.(acquisitionMode{1, i}).Backscatter4 = [data.(acquisitionMode{1, i}).Backscatter4; ...
                                structures.Data.([acquisitionMode{2, i} 'AmpBeam4'])*2];
                        end
                        if isfield(structures.Data, [acquisitionMode{2, i} 'Correlation_Beam'])
                            data.(acquisitionMode{1, i}).Correlation1 = [data.(acquisitionMode{1, i}).Correlation1; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Correlation_Beam'])(:, 1, :))];
                            data.(acquisitionMode{1, i}).Correlation2 = [data.(acquisitionMode{1, i}).Correlation2; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Correlation_Beam'])(:, 2, :))];
                            data.(acquisitionMode{1, i}).Correlation3 = [data.(acquisitionMode{1, i}).Correlation3; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Correlation_Beam'])(:, 3, :))];
                            data.(acquisitionMode{1, i}).Correlation4 = [data.(acquisitionMode{1, i}).Correlation4; ...
                                squeeze(structures.Data.([acquisitionMode{2, i} 'Correlation_Beam'])(:, 4, :))];
                        elseif isfield(structures.Data, [acquisitionMode{2, i} 'CorBeam1'])
                            data.(acquisitionMode{1, i}).Correlation1 = [data.(acquisitionMode{1, i}).Correlation1; ...
                                structures.Data.([acquisitionMode{2, i} 'CorBeam1'])];
                            data.(acquisitionMode{1, i}).Correlation2 = [data.(acquisitionMode{1, i}).Correlation2; ...
                                structures.Data.([acquisitionMode{2, i} 'CorBeam2'])];
                            data.(acquisitionMode{1, i}).Correlation3 = [data.(acquisitionMode{1, i}).Correlation3; ...
                                structures.Data.([acquisitionMode{2, i} 'CorBeam3'])];
                            data.(acquisitionMode{1, i}).Correlation4 = [data.(acquisitionMode{1, i}).Correlation4; ...
                                structures.Data.([acquisitionMode{2, i} 'CorBeam4'])];
                        end
                    end
                    
                    if isfield(structures.Data, [acquisitionMode{2, i} 'AltimeterDistanceLE'])
                        data.(acquisitionMode{1, i}).AltimeterDistanceLE    = [data.(acquisitionMode{1, i}).AltimeterDistanceLE; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterDistanceLE'])];
                        data.(acquisitionMode{1, i}).AltimeterQualityLE     = [data.(acquisitionMode{1, i}).AltimeterQualityLE; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterQualityLE'])];
                        %                     data.(acquisitionMode{i}).AltimeterStatus        = [data.(acquisitionMode{1, i}).AltimeterStatus; ...
                        %                         structures.Data.([acquisitionMode{2, i} 'AltimeterStatus'])]; % flags for when pitch or roll is > 5 or > 10. We already have pitch and roll data...
                    end
                    
                    if isfield(structures.Data, [acquisitionMode{2, i} 'AltimeterDistanceAST'])
                        data.(acquisitionMode{1, i}).AltimeterDistanceAST   = [data.(acquisitionMode{1, i}).AltimeterDistanceAST; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterDistanceAST'])];
                        data.(acquisitionMode{1, i}).AltimeterQualityAST    = [data.(acquisitionMode{1, i}).AltimeterQualityAST; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterQualityAST'])];
                        data.(acquisitionMode{1, i}).AltimeterTimeOffsetAST = [data.(acquisitionMode{1, i}).AltimeterTimeOffsetAST; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterTimeOffsetAST'])];
                        data.(acquisitionMode{1, i}).AltimeterPressure      = [data.(acquisitionMode{1, i}).AltimeterPressure; ...
                            structures.Data.([acquisitionMode{2, i} 'AltimeterPressure'])];
                    end
                    
                    data.(acquisitionMode{1, i}).Battery      = [data.(acquisitionMode{1, i}).Battery; ...
                        structures.Data.([acquisitionMode{2, i} 'Battery'])];
                    data.(acquisitionMode{1, i}).Heading      = [data.(acquisitionMode{1, i}).Heading; ...
                        structures.Data.([acquisitionMode{2, i} 'Heading'])];
                    data.(acquisitionMode{1, i}).Pitch        = [data.(acquisitionMode{1, i}).Pitch; ...
                        structures.Data.([acquisitionMode{2, i} 'Pitch'])];
                    data.(acquisitionMode{1, i}).Roll         = [data.(acquisitionMode{1, i}).Roll; ...
                        structures.Data.([acquisitionMode{2, i} 'Roll'])];
                    data.(acquisitionMode{1, i}).Temperature  = [data.(acquisitionMode{1, i}).Temperature; ...
                        structures.Data.([acquisitionMode{2, i} 'Temperature'])];
                    data.(acquisitionMode{1, i}).speedOfSound = [data.(acquisitionMode{1, i}).speedOfSound; ...
                        structures.Data.([acquisitionMode{2, i} 'Soundspeed'])];
                    data.(acquisitionMode{1, i}).Pressure     = [data.(acquisitionMode{1, i}).Pressure; ...
                        structures.Data.([acquisitionMode{2, i} 'Pressure'])];
                    
                    % we now need to sort the data chronologically
                    [~, iSort] = sort(data.(acquisitionMode{1, i}).Time);
                    nSample = length(data.(acquisitionMode{1, i}).Time);
                    dataFields = fieldnames(data.(acquisitionMode{1, i}));
                    for j=1:length(dataFields)
                        if size(data.(acquisitionMode{1, i}).(dataFields{j}), 1) == nSample
                            data.(acquisitionMode{1, i}).(dataFields{j}) = data.(acquisitionMode{1, i}).(dataFields{j})(iSort, :);
                        end
                    end
                end
            end
        end
        clear structures;
        
        acquisitionMode = acquisitionMode(1, :);

    otherwise
        error('Data format not supported');
        
end

if magDec ~= 0
    isMagBias = true;
    magBiasComment = ['A compass correction of ' num2str(magDec) ...
        'degrees has been applied to the data by a technician using Nortek''s software ' ...
        '(usually to account for magnetic declination).'];
end

sample_data = cell(1, nDataset);
for i=1:nDataset
    sample_data{i}.toolbox_input_file              = filename;
    sample_data{i}.meta.featureType                = ''; % strictly this dataset cannot be described as timeSeriesProfile since it also includes timeSeries data like TEMP
    sample_data{i}.meta.binSize                    = data.(acquisitionMode{i}).cellSize;
    sample_data{i}.meta.nBeams                     = data.(acquisitionMode{i}).nBeams;
    sample_data{i}.meta.instrument_make            = 'Nortek';
    if isempty(instrumentModel)
        sample_data{i}.meta.instrument_model       = 'Signature';
    else
        sample_data{i}.meta.instrument_model       = instrumentModel;
    end
    sample_data{i}.meta.instrument_serial_no       = serialNumber;
    
    diffTimeInSec = diff(data.(acquisitionMode{i}).Time*24*3600);
    
    % look for most frequents modes
    Ms = unique(round(diffTimeInSec*100)/100); % unique() sorts in order of most frequent
    
    % we look for the second burst (less likely to be chopped) 
    % and we hope it is valid
    dt = [0; diffTimeInSec];
    if length(Ms) > 1
        iBurst = find(dt >= Ms(2) - 1/100, 2, 'first');
        sample_data{i}.meta.instrument_sample_interval = Ms(1);
        sample_data{i}.meta.instrument_burst_interval = round((data.(acquisitionMode{i}).Time(iBurst(2)) - ...
            data.(acquisitionMode{i}).Time(iBurst(1)))*24*3600 * 100)/100;
        sample_data{i}.meta.instrument_burst_duration = round((data.(acquisitionMode{i}).Time(iBurst(2)-1) - ...
            data.(acquisitionMode{i}).Time(iBurst(1)))*24*3600 * 100)/100;
    else % use the header information
        sample_data{i}.meta.instrument_sample_interval = Ms;
        sample_data{i}.meta.instrument_burst_interval = 0; %or miAvgInterval
        sample_data{i}.meta.instrument_burst_duration = 0;

    end

    ok_sampling = sample_data{i}.meta.instrument_sample_interval <= sample_data{i}.meta.instrument_burst_duration <= sample_data{i}.meta.instrument_burst_interval;
    if ~ok_sampling
        warning("Instrument sampling metadata is inconsistent for file %s",filename);
    end

    switch sample_data{i}.meta.instrument_model
        case 'Signature250'
            sample_data{i}.meta.beam_angle         = 20;
        case 'Signature55'
            sample_data{i}.meta.beam_angle         = 20;
        case 'Signature100'
            sample_data{i}.meta.beam_angle         = 20;
        case 'Signature500'
            sample_data{i}.meta.beam_angle         = 25;
        case 'Signature1000'
            sample_data{i}.meta.beam_angle         = 25;
        otherwise % send error message 
            error('Signature not supported');
    end
     if data.(acquisitionMode{i}).isVelocityData
         switch lower(ext)
             case '.mat'
                sample_data{i}.meta.beam_to_xyz_transform  = data.(acquisitionMode{i}).Beam2xyz; 
             case '.ad2cp'
                 sample_data{i}.meta.beam_to_xyz_transform  = Beam2xyz;
         end
     end

    % generate distance values
    distance = nan(data.(acquisitionMode{i}).nCells, 1);
    distance(:) = (data.(acquisitionMode{i}).blankDist):  ...
        (data.(acquisitionMode{i}).cellSize): ...
        (data.(acquisitionMode{i}).blankDist + (data.(acquisitionMode{i}).nCells-1) * data.(acquisitionMode{i}).cellSize);
 
    % distance between the ADCP's transducers and the middle of each cell
    % See http://www.nortek-bv.nl/en/knowledge-center/forum/current-profilers-and-current-meters/579860330
    distance = (distance + data.(acquisitionMode{i}).cellSize);    
    
    % add dimensions with their data mapped
    iStartOrientation = 26;
    iEndOrientation = 28;
    adcpOrientations = bin2dec(data.(acquisitionMode{i}).Status(:, end-iEndOrientation+1:end-iStartOrientation+1));
    adcpOrientation = mode(adcpOrientations); % hopefully the most frequent value reflects the orientation when deployed
    % we assume adcpOrientation == 4 by default "ZUP"
    if adcpOrientation == 5
        % case of a downward looking ADCP -> negative values
        distance = -distance;
    end
    
    dims = {'TIME', data.(acquisitionMode{i}).Time, ''};
    
    if data.(acquisitionMode{i}).isVelocityData
         % we'll only keep velocity data collected when ADCP is oriented as expected
        iBadOriented = any(adcpOrientations ~= repmat(adcpOrientation, data.(acquisitionMode{i}).nSamples, 1), 2);
        
        switch data.(acquisitionMode{i}).coordSys
            case 'ENU'
                data.(acquisitionMode{i}).Velocity_N  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_E  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_U  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_U2 (iBadOriented, :) = NaN;
        
            case 'BEAM'
                data.(acquisitionMode{i}).Velocity_1  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_2  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_3  (iBadOriented, :) = NaN;
                data.(acquisitionMode{i}).Velocity_4  (iBadOriented, :) = NaN;
                
        end
        data.(acquisitionMode{i}).Backscatter1(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Backscatter2(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Backscatter3(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Backscatter4(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Correlation1(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Correlation2(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Correlation3(iBadOriented, :) = NaN;
        data.(acquisitionMode{i}).Correlation4(iBadOriented, :) = NaN;
        
        dims = [dims; ...
            {'DIST_ALONG_BEAMS', distance, ['Values correspond to the distance between the instrument''s transducers and the centre of each cells. ' ...
            'Nortek instrument data is not vertically bin-mapped (no tilt correction applied). Cells are lying parallel to the beams, ' ...
            'at heights above sensor that vary with tilt.']}];
    end
    
    nDims = size(dims, 1);
    sample_data{i}.dimensions = cell(nDims, 1);
    for j=1:nDims
        sample_data{i}.dimensions{j}.name         = dims{j, 1};
        sample_data{i}.dimensions{j}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(dims{j, 1}, 'type')));
        sample_data{i}.dimensions{j}.data         = sample_data{i}.dimensions{j}.typeCastFunc(dims{j, 2});
        sample_data{i}.dimensions{j}.comment      = dims{j, 3};
    end
    clear dims;
    
    % add variables with their dimensions and data mapped.
    % we assume no correction for magnetic declination has been applied
    if isMagBias
        magExt = '';
    else
        magExt = '_MAG';
    end
    iDimVel = nDims;
    iDimDiag = nDims;
    vars = {
        'TIMESERIES',       [],             1;...
        'LATITUDE',         [],             NaN; ...
        'LONGITUDE',        [],             NaN; ...
        'NOMINAL_DEPTH',    [],             NaN
        };
    
    if data.(acquisitionMode{i}).isVelocityData
        switch data.(acquisitionMode{i}).coordSys
            case 'ENU'
                if data.(acquisitionMode{i}).nBeams == 4
                    vars = [vars; {
                        ['VCUR' magExt],    [1 iDimVel],    data.(acquisitionMode{i}).Velocity_N; ... % V
                        ['UCUR' magExt],    [1 iDimVel],    data.(acquisitionMode{i}).Velocity_E; ... % U
                        'WCUR',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_U; ...
                        'WCUR_2',           [1 iDimVel],    data.(acquisitionMode{i}).Velocity_U2
                        }];
                else
                    vars = [vars; {
                        ['VCUR' magExt],    [1 iDimVel],    data.(acquisitionMode{i}).Velocity_N; ... % V
                        ['UCUR' magExt],    [1 iDimVel],    data.(acquisitionMode{i}).Velocity_E; ... % U
                        'WCUR',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_U
                         }];
                end
        
            case 'BEAM'
                vars = [vars; {
                    'VEL1',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_1; ...
                    'VEL2',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_2; ...
                    'VEL3',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_3; ...
                    'VEL4',             [1 iDimVel],    data.(acquisitionMode{i}).Velocity_4
                    }];
                
        end
        
        if data.(acquisitionMode{i}).nBeams == 4
        vars = [vars; {
            'ABSIC1',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter1; ...
            'ABSIC2',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter2; ...
            'ABSIC3',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter3; ...
            'ABSIC4',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter4; ...
            'ABSI1',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter1*0.5; ... % 1 count = 0.5 dB according to manual
            'ABSI2',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter2*0.5; ...
            'ABSI3',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter3*0.5; ...
            'ABSI4',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter4*0.5; ...
            'CMAG1',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation1; ...
            'CMAG2',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation2; ...
            'CMAG3',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation3; ...
            'CMAG4',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation4
            }];
        else
        vars = [vars; {
            'ABSIC1',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter1; ...
            'ABSIC2',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter2; ...
            'ABSIC3',           [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter3; ...
            'ABSI1',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter1*0.5; ... % 1 count = 0.5 dB according to manual
            'ABSI2',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter2*0.5; ...
            'ABSI3',            [1 iDimDiag],   data.(acquisitionMode{i}).Backscatter3*0.5; ...
            'CMAG1',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation1; ...
            'CMAG2',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation2; ...
            'CMAG3',            [1 iDimDiag],   data.(acquisitionMode{i}).Correlation3; ...
            }];
        end
    end
    
    if data.(acquisitionMode{i}).isAltimeterData
        vars = [vars; {
            'LE_DIST',          1,   data.(acquisitionMode{i}).AltimeterDistanceLE; ...
            'LE_QUALITY',       1,   data.(acquisitionMode{i}).AltimeterQualityLE
            }];
    end
       
    if data.(acquisitionMode{i}).isASTData
        vars = [vars; {
            'AST_DIST',         1,   data.(acquisitionMode{i}).AltimeterDistanceAST; ...
            'AST_QUALITY',      1,   data.(acquisitionMode{i}).AltimeterQualityAST; ... % Dimensionless indication of signal's surface return strength. Is reported the lowest quality for the pair of AST measurements. Useful for data clean up when there is poor surface returns. The values range from 0 to 256 and "good" data is often found above 100.
            'AST_TIME_OFFSET',  1,   data.(acquisitionMode{i}).AltimeterTimeOffsetAST; ...
            'ALTIMETER_PRES',   1,   data.(acquisitionMode{i}).AltimeterPressure
            }];
    end
    
    vars = [vars; {
        'TEMP',             1,              data.(acquisitionMode{i}).Temperature; ...
        'PRES_REL',         1,              data.(acquisitionMode{i}).Pressure; ...
        'SSPD',             1,              data.(acquisitionMode{i}).speedOfSound; ...
        'BAT_VOLT',         1,              data.(acquisitionMode{i}).Battery; ...
        'PITCH',            1,              data.(acquisitionMode{i}).Pitch; ...
        'ROLL',             1,              data.(acquisitionMode{i}).Roll; ...
        ['HEADING' magExt], 1,              data.(acquisitionMode{i}).Heading; ...
        'ERROR',            1,              data.(acquisitionMode{i}).Error; ...
        'AMBIG_VEL',        1,              data.(acquisitionMode{i}).AmbiguityVel; ...
        'TRANSMIT_E',       1,              data.(acquisitionMode{i}).TransmitEnergy; ...
        'NOMINAL_CORR',     1,              data.(acquisitionMode{i}).NominalCorrelation
        }];
    
    nVars = size(vars, 1);
    sample_data{i}.variables = cell(nVars, 1);
    for k=1:nVars
        sample_data{i}.variables{k}.name         = vars{k, 1};
        sample_data{i}.variables{k}.typeCastFunc = str2func(netcdf3ToMatlabType(imosParameters(vars{k, 1}, 'type')));
        sample_data{i}.variables{k}.dimensions   = vars{k, 2};
        if ~isempty(vars{k, 2}) % we don't want this for scalar variables
            if length(sample_data{i}.variables{k}.dimensions) == 2
                sample_data{i}.variables{k}.coordinates = ['TIME LATITUDE LONGITUDE ' sample_data{i}.dimensions{sample_data{i}.variables{k}.dimensions(2)}.name];
            else
                sample_data{i}.variables{k}.coordinates = 'TIME LATITUDE LONGITUDE NOMINAL_DEPTH';
            end
        end
        sample_data{i}.variables{k}.data         = sample_data{i}.variables{k}.typeCastFunc(vars{k, 3});
        
        if any(strcmpi(vars{k, 1}, {'VCUR', 'UCUR', 'HEADING'}))
            sample_data{i}.variables{k}.compass_correction_applied = magDec;
            sample_data{i}.variables{k}.comment = magBiasComment;
        end
    end
    clear vars;
end

end



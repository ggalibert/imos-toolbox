function sample_data = adcpWorkhorseVelocityBeam2EnuPP(sample_data, qcLevel, ~)
%function sample_data = adcpWorkhorseVelocityBeam2EnuPP( sample_data, qcLevel, ~ )
%
% Convert Workhorse acoustic beam velocity to East Northing Up
% (ENU or earth) coordinates.
%
% This function only applies to FV01 datasets and is bounded to Teledyne
% instruments containing Beam Velocity variables and all attitude
% required variables (heading,pitch,roll).
%
%
%
% Inputs:
%   sample_data - cell array of data sets.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%
% Outputs:
%   sample_data - the same data sets, with updated velocity variables in ENU coordinates.
%
%
% author: hugo.oliveira@utas.edu.au [based on several draft and BecCowley 675 branch]
%
narginchk(2, 3)

if ~iscell(sample_data)
    errormsg('sample_data must be a cell array')
end

if isempty(sample_data) || strcmpi(qcLevel, 'raw')
    return
end
qcSet           = str2double(readProperty('toolbox.qc_set'));
badFlag         = imosQCFlag('bad',             qcSet, 'flag');
goodFlag        = imosQCFlag('good',            qcSet, 'flag');
rawFlag         = imosQCFlag('raw',             qcSet, 'flag');

sind = TeledyneADCP.find_teledyne_beam_datasets(sample_data,'HEIGHT_ABOVE_SENSOR');
dind = TeledyneADCP.find_teledyne_beam_datasets(sample_data,'DIST_ALONG_BEAMS');
if ~isempty(dind)
    for k=1:length(dind)
        dataset = sample_data{dind(k)};
        warn_vars = IMOS.adcp.beam_vars(dataset);
        for l=1:length(warn_vars)
            vname = warn_vars{l};
            dispmsg('Performing beam2earth converison without bin-mapping/tilt correction for variable %s in dataset %s',vname,dataset.toolbox_input_file);
        end
    end
    sind = union(sind, dind);
end

for k = 1:numel(sind)
    ind = sind(k);
    not_workhorse = ~contains(sample_data{ind}.meta.instrument_model, 'workhorse', 'IgnoreCase', true);
    if not_workhorse
        continue
    end

    compass_correction = sample_data{ind}.meta.compass_correction_applied;

    if compass_correction
        heading_vname = 'HEADING';
        vel_vars = {'UCUR','VCUR','WCUR','ECUR'};
    else
        heading_vname = 'HEADING_MAG';
        vel_vars = {'UCUR_MAG','VCUR_MAG','WCUR','ECUR'}; %compat: old code did not use MAG for WCUR and ECUR, even though it should.
    end

    info = sample_data{ind}.meta.adcp_info;

    if info.coords.used_binmapping
        %compat: The toolbox is silent about this.
        %dispmsg('Instrument frame of reference is beam but bin_mapping was selected at instrument settings. Performing rotation to earth coordinates anyway...')
        % Even if the EX bit is set for bin mapping,
        % if the data is collected in beam coordinates,
        % bin mapping does not occur on board.
    end

    pitch_bit = info.sensors_settings.Pitch;
    beam_face_config = info.beam_face_config;
    beam_angle = info.beam_angle;

    head_ind = IMOS.find(sample_data{ind}.variables,heading_vname);
    pitch_ind = IMOS.find(sample_data{ind}.variables,'PITCH');
    roll_ind = IMOS.find(sample_data{ind}.variables,'ROLL');
    vel1_ind = IMOS.find(sample_data{ind}.variables,'VEL1');
    vel2_ind = IMOS.find(sample_data{ind}.variables,'VEL2');
    vel3_ind = IMOS.find(sample_data{ind}.variables,'VEL3');
    vel4_ind = IMOS.find(sample_data{ind}.variables,'VEL4');

    I = TeledyneADCP.workhorse_beam2inst(beam_angle);
    %here we need to check for 3-beam solutions if screening has happened
    %TODO: get a test in place for 3-beam solutions. Currently, all data is
    %converted (4-beam solutions)
    %first apply the flags to NaN out bad data:
    v1 = sample_data{ind}.variables{vel1_ind}.data;
    v2 = sample_data{ind}.variables{vel2_ind}.data;
    v3 = sample_data{ind}.variables{vel3_ind}.data;
    v4 = sample_data{ind}.variables{vel4_ind}.data;
    v1(sample_data{ind}.variables{vel1_ind}.flags > 2) = NaN;
    v2(sample_data{ind}.variables{vel2_ind}.flags > 2) = NaN;
    v3(sample_data{ind}.variables{vel3_ind}.flags > 2) = NaN;
    v4(sample_data{ind}.variables{vel4_ind}.flags > 2) = NaN;
    
    [v1, v2, v3, v4] = TeledyneADCP.workhorse_beam2earth(pitch_bit, ...
        beam_face_config, ...
        sample_data{ind}.variables{head_ind}.data,...
        sample_data{ind}.variables{pitch_ind}.data, ...
        sample_data{ind}.variables{roll_ind}.data,...
        I, v1, v2, v3, v4);

    Beam2EnuComment = ['adcpWorkhorseVelocityBeam2EnuPP.m: velocity data in Easting Northing Up (ENU) coordinates has been calculated from velocity data in Beams coordinates ' ...
        'using heading and tilt information, 3-beam solutions and instrument coordinate transform matrix.'];

    %change in place.
    sample_data{ind}.variables{vel1_ind}.name = vel_vars{1};
    sample_data{ind}.variables{vel1_ind}.data = v1;

    sample_data{ind}.variables{vel2_ind}.name = vel_vars{2};
    sample_data{ind}.variables{vel2_ind}.data = v2;

    sample_data{ind}.variables{vel3_ind}.name = vel_vars{3};
    sample_data{ind}.variables{vel3_ind}.data = v3;

    sample_data{ind}.variables{vel4_ind}.name = vel_vars{4};
    sample_data{ind}.variables{vel4_ind}.data = v4;

    vel_indexes = [vel1_ind,vel2_ind,vel3_ind,vel4_ind];
    for j=1:4
        vind = vel_indexes(j);
        if isfield(sample_data{ind}.variables{vind},'comment')
            sample_data{ind}.variables{vind}.comment = [ sample_data{ind}.variables{vind}.comment Beam2EnuComment ];
        else
            sample_data{ind}.variables{vind}.comment = Beam2EnuComment;
        end
    end

    %reset flags as any present would have been from screening tests and
    %apply to beam velocities and would have been used in 3-beam solutions
    [sample_data{ind}.variables{vel1_ind}.flags, ...
        sample_data{ind}.variables{vel1_ind}.flags, ...
        sample_data{ind}.variables{vel1_ind}.flags, ...
        sample_data{ind}.variables{vel1_ind}.flags] = deal(repmat(rawFlag,size(v1)));
        
    no_toolbox_tilt_correction = isfield(sample_data{ind}, 'history') && ~contains(sample_data{ind}.history, 'adcpBinMappingPP');
    if no_toolbox_tilt_correction
        %TODO: using warnmsg here would be too verbose - we probably need another function with the scope report level as argument.
        dispmsg('WARNING: Bin-Mapping not applied for %s. Data is converted to ENU coordinates without tilt corrections.',sample_data{ind}.toolbox_input_file)
        % compat: Change dimensions to HEIGHT_ABOVE_SENSOR, since this would be done at adcpBinMappingPP.
        %
        % height_above_sensor_ind = IMOS.find(sample_data{ind}.dimensions,'HEIGHT_ABOVE_SENSOR');
        % for k=1:numel(vel_indexes)
        %     vind = vel_indexes(k);
        %     sample_data{ind}.variables{vind}.coordinates(end) = height_above_sensor_ind;
        %     sample_data{ind}.variables{vind}.coords = 'TIME LATITUDE LONGITUDE HEIGHT_ABOVE_SENSOR';
        % end
    end

    if isfield(sample_data{ind}, 'history')
        sample_data{ind}.history = sprintf('%s\n%s - %s', sample_data{ind}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    else
        sample_data{ind}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), Beam2EnuComment);
    end
end

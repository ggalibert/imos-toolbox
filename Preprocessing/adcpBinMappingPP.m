function sample_data = adcpBinMappingPP(sample_data, qcLevel, ~)
%ADCPBINMAPPINGPP bin-maps any RDI or Nortek adcp variable expressed in beams coordinates
%and which is function of DIST_ALONG_BEAMS into a HEIGHT_ABOVE_SENSOR dimension
%if the velocity data found in this dataset is already a function of
%HEIGHT_ABOVE_SENSOR.
%
% For every beam, each bin has its vertical height above sensor inferred from
% the tilt information. Data values are then interpolated at the nominal
% vertical bin heights (when tilt is 0).
%
% Inputs:
%   sample_data - cell array of data sets, ideally with DIST_ALONG_BEAMS dimension.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%
% Outputs:
%   sample_data - the same data sets, with relevant processed variable originally function
%                 of DIST_ALONG_BEAMS now function of HEIGHT_ABOVE_SENSOR.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               hugo.oliveira@utas.edu.au
%

narginchk(2, 3);

if ~iscell(sample_data), error('sample_data must be a cell array'); end
if isempty(sample_data), return; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

for k = 1:length(sample_data)
    %TODO: rafactor this whole block as a funciton
    % do not process if not RDI nor Nortek
    isRDI = false;
    isNortek = false;
    if strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), isRDI = true; end
    if strcmpi(sample_data{k}.meta.instrument_make, 'Nortek'), isNortek = true; end
    if ~isRDI && ~isNortek, continue; end

    % do not process if Nortek with more than 3 beams
    absic4Idx = getVar(sample_data{k}.variables, 'ABSIC4');
    if absic4Idx && isNortek, continue; end

    % do not process if dist_along_beams, pitch or roll are missing from dataset
    distAlongBeamsIdx = getVar(sample_data{k}.dimensions, 'DIST_ALONG_BEAMS');
    pitchIdx = getVar(sample_data{k}.variables, 'PITCH');
    rollIdx = getVar(sample_data{k}.variables, 'ROLL');
    if ~distAlongBeamsIdx || ~pitchIdx || ~rollIdx, continue; end

    % do not process if ENU velocity data not vertically bin-mapped and there
    % is no beam velocity data (ENU velocity is not going to be bin-mapped later so useless)
    heightAboveSensorIdx = getVar(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
    ucurIdx = getVar(sample_data{k}.variables, 'UCUR');
    if ~ucurIdx, ucurIdx = getVar(sample_data{k}.variables, 'UCUR_MAG'); end
    vel1Idx = getVar(sample_data{k}.variables, 'VEL1');

    if ucurIdx% in the case of datasets originally collected in beam coordinates there is no UCUR

        if ~any(sample_data{k}.variables{ucurIdx}.dimensions == heightAboveSensorIdx) && ~vel1Idx
            continue;
        end

    end

    % We apply tilt corrections to project DIST_ALONG_BEAMS onto the vertical
    % axis HEIGHT_ABOVE_SENSOR.
    %
    % RDI 4 beams ADCPs:
    % It is assumed that the beams are in a convex configuration such as beam 1
    % and 2 (respectively 3 and 4) are aligned on the pitch (respectively roll)
    % axis. For an upward looking ADCP, when pitch is positive beam 3 is closer 
    % to the surface while beam 4 gets further away. When roll is positive beam 
    % 2 is closer to the surface while beam 1 gets further away.
    %
    % Nortek 3 beams ADCPs:
    % It is assumed that the beams are in a convex configuration such as beam 1
    % and the centre of the ADCP are aligned on the roll axis. Beams 2 and 3
    % are symetrical against the roll axis. Each beam is 120deg apart from
    % each other. When pitch is positive beam 1 is closer to the surface
    % while beams 2 and 3 get further away. When roll is positive beam 3 is
    % closer to the surface while beam 2 gets further away.
    %

    % Set pitch sign to deal with downward facing ADCPs
    pitchSign = 1;

    distAlongBeams = sample_data{k}.dimensions{distAlongBeamsIdx}.data';
    if all(diff(distAlongBeams)<0)
        %invert distAlongBeams so we have increasing values
        % this is required for the interpolation function.
        distAlongBeams = distAlongBeams*-1;
        pitchSign = -1;
    end
    pitch = sample_data{k}.variables{pitchIdx}.data * pi / 180;
    roll = sample_data{k}.variables{rollIdx}.data * pi / 180;
    beamAngle = sample_data{k}.meta.beam_angle * pi / 180;

    %adjust pitch
    info = sample_data{k}.meta.adcp_info;
    pitch_bit = info.sensors_settings.Pitch;
    pitch = TeledyneADCP.gimbal_pitch(pitch,roll, pitch_bit);

    %TODO: the adjusted distances should be exported
    % as variables to enable further diagnostic plots and debugging.
    if isRDI && absic4Idx ~= 0 % RDI 4 beams
        number_of_beams = 4;

        nonMappedHeightAboveSensorBeam = TeledyneADCP.adcp_adjusted_distances_rdi4beam(roll, pitch, pitchSign, distAlongBeams, beamAngle, number_of_beams);        

    elseif isNortek && absic4Idx == 0 % Nortek 3 beams
        number_of_beams = 3;

        nonMappedHeightAboveSensorBeam = NortekADCP.adcp_adjusted_distances_nortek3beam(roll, pitch, distAlongBeams, beamAngle, number_of_beams);

    end

    nSamples = length(pitch);
    %TODO: deep refactor required for speed: The interpolation step can
    % be done to all variables at once per time step.
    %TODO: remove nested logics to outer loop, by pre-computing the vars/
    % interpolation conditions. This would allow a progress bar here.

    for n = 1:number_of_beams
        beam_vars = IMOS.adcp.beam_vars(sample_data{k}, n);
        [all_beam_vars] = IMOS.concatenate_variables(sample_data{k}.variables, beam_vars);

        switch n
            case 1
                dvar = nonMappedHeightAboveSensorBeam(:,:,n);
            case 2
                dvar = nonMappedHeightAboveSensorBeam(:,:,n);
            case 3
                dvar = nonMappedHeightAboveSensorBeam(:,:,n);
            case 4
                dvar = nonMappedHeightAboveSensorBeam(:,:,n);
            otherwise
                errormsg('Beam number %s not supported', num2str(n))
        end

        arrtype = class(all_beam_vars); % compat.
        castfun = str2func(arrtype);
        nvar = length(beam_vars);
        Ndim = castfun(1:nvar);
        new_pos = {castfun(distAlongBeams), Ndim};
        interpFunction = griddedInterpolant([0 1], [0 0],'linear','none');
        mapped_beam_data = NaN(size(all_beam_vars),arrtype);

        for i = 1:nSamples
            interpFunction.GridVectors = {dvar(i, :), Ndim};
            interpFunction.Values = squeeze(all_beam_vars(i, :, :));
            mapped_beam_data(i, :, :) = interpFunction(new_pos);
        end
        %compat: follow previous hack/"RDI hack",
        %where first bin value is restore to the original bin value.
        %TODO: I don't think this is really necessary as is,
        % only actually required if nan after interp.
        mapped_beam_data(:, 1, :) = all_beam_vars(:, 1, :);

        need_new_dimension = isempty(IMOS.find(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR'));
        if need_new_dimension
            %need a full struct, not basic one.
            dims = IMOS.as_named_struct(sample_data{k}.dimensions);
            hinfo = IMOS.varparams().HEIGHT_ABOVE_SENSOR;
            % compat. TODO: long_name is not consistent with imos parameters
            % compat. TODO: the dimensions information should have a reference table too.
            hdim = struct('name', 'HEIGHT_ABOVE_SENSOR', ...
                'typeCastFunc', dims.DIST_ALONG_BEAMS.typeCastFunc, ...
                'data', dims.DIST_ALONG_BEAMS.data, ...
                'long_name', 'height_above_sensor', ...
                'standard_name', hinfo.standard_name, ...
                'axis', 'Z', ...
                'positive', hinfo.direction_positive, ...
                'comment', ['Values correspond to the distance between the instrument''s transducers and the centre of each cells. ' ...
                    'Data has been vertically bin-mapped using tilt information so that the cells ' ...
                    'have consistant heights above sensor in time.']);
            sample_data{k}.dimensions{end+1} = hdim;
        end

        hdim_index = IMOS.find(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');

        binMappingComment = ['adcpBinMappingPP.m: data in beam coordinates originally referenced to DIST_ALONG_BEAMS ' ...
                            'has been vertically bin-mapped to HEIGHT_ABOVE_SENSOR using tilt information.'];

        for j = 1:length(beam_vars)
            bvar_name = beam_vars{j};
            bvar_ind = IMOS.find(sample_data{k}.variables,bvar_name);
            sample_data{k}.variables{bvar_ind}.dimensions(distAlongBeamsIdx) = hdim_index;
            sample_data{k}.variables{bvar_ind}.coordinates = 'TIME LATITUDE LONGITUDE HEIGHT_ABOVE_SENSOR';
            sample_data{k}.variables{bvar_ind}.data = mapped_beam_data(:, :, j); % j since concatenated in order of beam_vars.

            update_comment = isfield(sample_data{k}.variables{bvar_ind}, 'comment') && ~isempty(sample_data{k}.variables{bvar_ind}.comment);
            if update_comment
                sample_data{k}.variables{bvar_ind}.comment = [sample_data{k}.variables{bvar_ind}.comment ' ' binMappingComment];
            else
                sample_data{k}.variables{bvar_ind}.comment = binMappingComment;
            end

        end

    end

    %remove DIST_ALONG_BEAMS dimension, if dangling.
    detect_dab = @(x)(isinside(x, distAlongBeamsIdx));
    dab_vars = cellfun(detect_dab, IMOS.get(sample_data{k}.variables, 'dimensions'));
    remove_dab_dim = ~any(dab_vars);

    if remove_dab_dim
        old_hdim_index = IMOS.find(sample_data{k}.dimensions,'HEIGHT_ABOVE_SENSOR');
        sample_data{k}.dimensions(distAlongBeamsIdx) = []; %pop
        %now fix inconsistency created by the above removal.
        new_hdim_index = IMOS.find(sample_data{k}.dimensions, 'HEIGHT_ABOVE_SENSOR');
        for v=1:length(sample_data{k}.variables)
            vdim = sample_data{k}.variables{v}.dimensions;
            ind_to_update = union(find(vdim == distAlongBeamsIdx),find(vdim == old_hdim_index));
            if ind_to_update
                sample_data{k}.variables{v}.dimensions(ind_to_update) = new_hdim_index;
            end
        end
        binMappingComment = [binMappingComment ' DIST_ALONG_BEAMS is not used by any variable left and has been removed.'];
    end

    if isfield(sample_data{k}, 'history') && ~isempty(sample_data{k}.history)
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
    else
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), binMappingComment);
    end

end

end

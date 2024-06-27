function [sample_data,df] = adcpWorkhorseEchoRangePP( sample_data, qcLevel, ~ )
% adcpWorkhorseEchoRangePP Quality control procedure for Teledyne Workhorse (and similar)
% ADCP instrument data, using the echo intensity diagnostic variable.
%
% Echo Range test :
% The Echo Range test is also known as the 'Fish Detection Test' and is
% designed as a screening check for the single ping data. The equivalent is
% performed on board the RDI if the WA command is enabled. Only use this
% test if the WA command has not been enabled in the RDI data you have
% collected.
% The test is probably only useful for single ping data, prior to ensemble
% averaging.
%
% This test checks the difference between the highest and lowest values in the 4 beams
% in each bin (echo intensity range, EIR) at each time stamp. If the threshold
% is exceeded, the beam with the lowest echo intensity is flagged.
% Then checks the difference in the second lowest value from the highest
% value. If greater than threshold, entire 4 beams of the bin are flagged
% bad.
% Once this information is collected, three beam solutions can be applied
% to calculate velocity from raw beam data where one bin is flagged as bad.
% The echo intensity data should ideally be bin-mapped first using
% adcpBinMappingPP.m routine.
% If the difference exceeds a threshold, the entire bin is flagged as bad
%
% Inputs:
%   sample_data - struct containing the entire data set and dimension data.
%   qcLevel     - string, 'raw' or 'qc'. Some pp not applied when 'raw'.
%
% Outputs:
%   sample_data - same as input, with QC flags added for variable/dimension
%                 data.
%
% Author:       Guillaume Galibert <guillaume.galibert@utas.edu.au>
%               Rebecca Cowley <rebecca.cowley@csiro.au>
%
narginchk(2,3);
if ~iscell(sample_data), error('sample_data must be a cell array'); end

% auto logical in input to enable running under batch processing
if nargin<2, auto=false; end

% no modification of data is performed on the raw FV00 dataset except
% local time to UTC conversion
if strcmpi(qcLevel, 'raw'), return; end

paramsLog  = [];

for k = 1:length(sample_data)
    %TODO: rafactor this whole block as a funciton
    % do not process if not RDI nor Nortek
    isRDI = false;
    if strcmpi(sample_data{k}.meta.instrument_make, 'Teledyne RDI'), isRDI = true; end
    if ~isRDI, continue; end
    % get all necessary dimensions and variables id in sample_data struct
    idVel1 = 0;
    idVel2 = 0;
    idVel3 = 0;
    idVel4 = 0;
    idABSIC = cell(4, 1);
    for j=1:4
        idABSIC{j}  = 0;
    end
    lenVar = length(sample_data{k}.variables);
    for i=1:lenVar
        paramName = sample_data{k}.variables{i}.name;
        
        if strncmpi(paramName, 'VEL1', 4),  idVel1 = i; end
        if strncmpi(paramName, 'VEL2', 4),  idVel2 = i; end
        if strncmpi(paramName, 'VEL3', 4),  idVel3 = i; end
        if strncmpi(paramName, 'VEL4', 4),  idVel4 = i; end
        for j=1:4
            cc = int2str(j);
            if strcmpi(paramName, ['ABSIC' cc]), idABSIC{j} = i; end
        end
    end
    
    % check if the data is compatible with the QC algorithm
    idMandatory = (idVel1 | idVel2 | idVel3 | idVel4 );
    for j=1:4
        idMandatory = idMandatory & idABSIC{j};
    end
    if ~idMandatory, return; end
    
    % let's get the associated vertical dimension
    idVertDim = sample_data{k}.variables{idABSIC{1}}.dimensions(2);
    if strcmpi(sample_data{k}.dimensions{idVertDim}.name, 'DIST_ALONG_BEAMS')
        disp(['Warning : adcpWorkhorseEchoRangePP applied with a non tilt-corrected ABSICn (no bin mapping) on dataset ' sample_data{k}.toolbox_input_file]);
    end
    
    qcSet           = str2double(readProperty('toolbox.qc_set'));
    badFlag         = imosQCFlag('bad',             qcSet, 'flag');
    goodFlag        = imosQCFlag('good',            qcSet, 'flag');
    rawFlag         = imosQCFlag('raw',             qcSet, 'flag');
    
    %Pull out echo intensity
    sizeData = size(sample_data{k}.variables{idABSIC{1}}.data);
    ea = nan(4, sizeData(1), sizeData(2));
    for j=1:4
        ea(j, :, :) = sample_data{k}.variables{idABSIC{j}}.data;
    end
    
    % read in filter parameters
    propFile  = fullfile('Preprocessing', 'adcpWorkhorseEchoRangePP.txt');
    ea_fishthresh = str2double(readProperty('ea_fishthresh',   propFile));
    
    % read dataset QC parameters if exist and override previous
    % parameters file
    currentQCtest = mfilename;
    ea_fishthresh = readDatasetParameter(sample_data{k}.toolbox_input_file, currentQCtest, 'ea_fishthresh', ea_fishthresh);
    
    paramsLog = ['ea_fishthresh=' num2str(ea_fishthresh)];
    
    try
        frame_of_reference = sample_data{k}.meta.adcp_info.coords.frame_of_reference;
        is_beam = strcmpi(frame_of_reference,'beam');
    catch
        try
            is_beam = unique(sample_data{k}.meta.fixedLeader.coordinateTransform) ~=7;
        catch
            is_beam = false;
        end
    end
    
    %TODO: refactor from below
    % Run QC
    % Following code is adapted from the UWA 'adcpfishdetection.m' code
    
    [n, t, m]=size(ea); % m depth cells, n (4) beams, t timesteps
    % same flags are given to any variable
    bad_ea = ones(n,t,m,'int8')*rawFlag;
    
    % matrix operation of the UW original code which loops over each timestep
    [B, Ix]=sort(ea,1,'descend'); %sort echo from highest to lowest along each bin
    %step one - really only useful for data in beam coordinates. If one
    %beam fails, then can do 3-beam solutions
    if is_beam
        %step 1: Find the beams with the highest and two lowest echo levels
        df = squeeze(B(1,:,:)-B(4,:,:)); %get the difference from highest value to lowest
        ind=find(df>ea_fishthresh); % problematic depth cells
        bad_ea(4,ind) = true; %flag these as bad (individual cells, of the lowest echo value)
    end
    %step 2: Flags entire bin of velocity data as more than one cell is >
    %threshold, which means three beam solution can't be calculated.
    % Is this test really useful for data that has already been converted to
    % ENU? No, it should not be run as the thresholds used flag out the data
    % for identification of 3-beam solutions
    df = squeeze(B(1,:,:)-B(3,:,:)); %get the difference from highest value to second lowest
    ind=df>ea_fishthresh; % problematic depth cells
    bad_ea(:,ind) = true; %flag the entire bin (all beams) as bad
    
    % % need to re-sort the bad_ea matrix back to match beam order:
    [~,be_sorted] = sort3d(bad_ea,1,Ix);
    
    
    % % %very slow option
    % be = bad_ea;
    % for a = 1:t
    %     for b = 1:m
    %         [~,ixx] = sort(Ix(:,a,b));
    %         bad_ea(:,a,b) = bad_ea(ixx,a,b);
    %     end
    % end
    
    % Keep the flags for each velocity parameter (beam)
    flags = be_sorted;
    flags(flags == 1) = badFlag;
    flags(flags == 0) = goodFlag;
    
    sample_data{k}.variables{idVel1}.flags = squeeze(flags(1,:,:));
    sample_data{k}.variables{idVel2}.flags = squeeze(flags(2,:,:));
    sample_data{k}.variables{idVel3}.flags = squeeze(flags(3,:,:));
    sample_data{k}.variables{idVel4}.flags = squeeze(flags(4,:,:));
    % write/update dataset QC parameters
    writeDatasetParameter(sample_data{k}.toolbox_input_file, currentQCtest, 'ea_fishthresh', ea_fishthresh);
    echorangecomment = ['adcpWorkhorseEchoRangePP.m: Echo Range preprocessing screening applied to beam velocities. Threshold = ' num2str(ea_fishthresh)];
    

    if isfield(sample_data{k}, 'history') && ~isempty(sample_data{k}.history)
        sample_data{k}.history = sprintf('%s\n%s - %s', sample_data{k}.history, datestr(now_utc, readProperty('exportNetCDF.dateFormat')), echorangecomment);
    else
        sample_data{k}.history = sprintf('%s - %s', datestr(now_utc, readProperty('exportNetCDF.dateFormat')), echorangecomment);
    end
end

end

function [sA,B] = sort3d(sA,dim,idx)
    [~,idxx] = sort(idx,dim);
    gridargs = arrayfun(@(s) 1:s, size(sA), 'UniformOutput',false);
    [gridargs{:}]=ndgrid(gridargs{:});
    gridargs{dim} = idxx;
    B = sA(sub2ind(size(sA), gridargs{:}));
end

function [sample_data, varChecked, paramsLog] = imosRingingBinSetQC(sample_data, ~)
%function [sample_data, varChecked, paramsLog] = imosRingingBinSetQC(sample_data, ~)
%
% A ringing bin removal for ADCPs.
%
% The user enters the bin number(s) to be flagged bad in
% imosRingingBinSetQC.txt.
%
% Every datapoint in the bin(s) is marked as bad.
%
% See imosRingingBinSetQC.txt to enter bins for flagging.
%
%
%
% author: Rebecca.Cowley@csiro.au
%
%
narginchk(1, 2);
varChecked = {};
paramsLog = [];
currentQCtest = mfilename;
if ~isstruct(sample_data), error('sample_data must be a struct'); end

%get the bins to be flagged
options = IMOS.resolve.function_parameters();
%probably a better way to do this.
bins = options('bin');
if ischar(bins)
    bins = str2num(bins);
end

nt = numel(IMOS.get_data(sample_data.dimensions, 'TIME'));
if IMOS.adcp.is_along_beam(sample_data)
    bin_dist = IMOS.get_data(sample_data.dimensions, 'DIST_ALONG_BEAMS');
else
    bin_dist = IMOS.get_data(sample_data.dimensions, 'HEIGHT_ABOVE_SENSOR');
end


flag_vars = IMOS.adcp.current_variables(sample_data);
qcSet = str2double(readProperty('toolbox.qc_set'));
badFlag = imosQCFlag('bad', qcSet, 'flag');
goodFlag = imosQCFlag('good', qcSet, 'flag');

flags = ones(nt,length(bin_dist), 'int8') * goodFlag;
flags(:,bins) = badFlag;
flag_vars_inds = IMOS.find(sample_data.variables, flag_vars);
for k = 1:numel(flag_vars_inds)
    vind = flag_vars_inds(k);
    sample_data.variables{vind}.flags = flags;
end

varChecked = flag_vars;

paramsLog = ['ringing_bin_removed=' num2str(bins)];
writeDatasetParameter(sample_data.toolbox_input_file, currentQCtest, 'ringing_bin_removed', bins);
end

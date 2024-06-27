function [b1,b2,b3,b4] = workhorse_3beamsolution(T, beamdat)
%function btim = workhorse_3beamsolution(T, beamdat)
%
% Return the 3 beam solutions for instrument coordinate data with screened
% data indicating one bad beam
%
% 
% Reference: page 14-15 of ADCP Coordinate Transformation,
% Formulas and Calculations, Teledyne RD Instruments.
% P/N 951-6079-00 (January 2008).
%
%
% Inputs:
%
%   T=transformation matrix from beam to instrument axis as obtained from
%   workhorse_beam2inst
%   beamdat: mx4 matrix with m depth cells, and 4 beams (one profile)
%
% Outputs:
%
% btim [double] - A 4x4 beam data matrix with 3-beam solutions included.
%
%
% author: rebecca.cowley@csiro.au
%
%
narginchk(2, 2)

if nargin < 2
    errormsg('Not enough arguments to continue')
end

%code snippet from any3beam.m from UWA code set.
three_beam = find(isfinite(beamdat)*ones(4, 1) == 3);
btim=beamdat;
%disp(length(three_beam))
if any(three_beam)
	data = beamdat(three_beam, :); % CB selecting depth cells  with exactly 3 "good" beams 
	mask = isnan(data); % CB finding which of the 4 beam is bad
	data(mask) = 0; %CB forcing "bad beam"  to zero instead of NaN. Now the error vel is 0.
	tran = ones(length(three_beam), 1) * T(4, :); % CB matrix with rows representing the depth cells with 3 beams, each row represents the error vel transformation
	err = (data .* tran) * ones(4, 1);% mult the data with the error vel trans matrix
 	errmat = -err ./tran;
    	data(mask) = errmat(mask); % CB Assigning the bad beam to its value dependent on other 3 beams
	btim(three_beam, :) = data;
end
b1 = btim(:,1)';
b2 = btim(:,2)';
b3 = btim(:,3)';
b4 = btim(:,4)';
end

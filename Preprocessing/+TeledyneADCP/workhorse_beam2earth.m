function [v1, v2, v3, v4] = workhorse_beam2earth(pitch_bit, beam_face_config, h, p, r, I, b1, b2, b3, b4)
%function [v1, v2, v3, v4] = workhorse_beam2earth(pitch_bit, beam_face_config, h, p, r, I, b1, b2, b3, b4)
%
% Transform Workhorse velocity beam coordinates to Earth coordinates, 
% based on ADCP configuration and sensors.
%
% The function computes the rotation matrix equation:
%
% VEL_ENU(T,N) = H(T) * GP(T) * AR(T) * I * BEAM_VEL(T,N), ∀ T & N.
%
% Where: H,GP,AR are the Heading, Gimbal Pitch and Adjusted Roll 
% matrices transformations for each measured timestep (T).
% The I matrix is the time invariant 4x4 rotation matrix 
% from beam to instrument coordinates.
% BEAM_VAR is a 4xN matrix of all beam variable 
% components (in order) for all bins (N).
%
% The pitch_bit and beam_face_config are also
% adcp deployment or instrument invariant configs
% for the Gimbal Pitch and Adjusted Roll matrices.
%
% Reference: ADCP Coordinate Transformation, Formulas and Calculations,
%            Teledyne RD Instruments. P/N 951-6079-00 (January 2008).
%
%
% Inputs:
%
% pitch_config 1x1 [logical] - The Pitch sensor bit switch [True | False].
% beam_face_config [str] - The ADCP beam face config ['up' | 'down'].
% h [double] Tx1 - Heading vector in degrees.
% p [double] Tx1 - Pitch vector in degrees.
% r [double] Tx1 - Roll vector in degrees.
% I [double] 4x4 - The beam to instrument rotation matrix.
% b1 [double] TxN - The beam1 array.
% b2 [double] TxN - ditto, but for beam2.
% b3 [double] TxN - 
% b4 [double] TxN - 
%
% Outputs:
%
% v1 [double] TxN - Value at eastern direction.
% v2 [double] TxN - Value at the northern direction.
% v3 [double] TxN - Value at the vertical direction.
% v4 [double] TxN - Value at the Neutral direction.
%
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(10, 10)

if ~strcmpi(beam_face_config, 'up') && ~strcmpi(beam_face_config, 'down')
    errormsg('Beam face config %s not supported', beam_face_config)
elseif ~iscolumn(h)
    errormsg('Heading angle is nota column vector')
elseif ~iscolumn(p)
    errormsg('Pitch angle is nota column vector')
elseif ~iscolumn(r)
    errormsg('Roll angle is nota column vector')
elseif size(h, 1) ~= size(p, 1) || size(h, 1) ~= size(r, 1) || size(p, 1) ~= size(r, 1)
    errormsg('Size mismatch for one of the heading,pitch, and/or roll arguments.')
elseif ~isequal(size(I), [4, 4])
    errormsg('Instrument Matrix argument is not a 4x4 matrix.');
end

Tlen = size(h, 1);
Nbins = size(b1, 2);
esize = [Tlen, Nbins];
mismatch_vel_size = ~isequal(size(b1), esize) || ~isequal(size(b2), esize) || ~isequal(size(b3), esize) || ~isequal(size(b4), esize);

if mismatch_vel_size
    errormsg('Velocity arrays are not of TxN size.')
end

otype = class(b1);
[v1, v2, v3, v4] = deal(NaN(esize, otype));

gpitch = deg2rad(TeledyneADCP.gimbal_pitch(p,r, pitch_bit));
heading = deg2rad(h);
switch beam_face_config
    case 'up'
        adjusted_roll = deg2rad(r + 180);
    case 'down'
        adjusted_roll = deg2rad(r);
end

for t = 1:size(v1, 1)
    %get values for 3-beam solutions
    [b1(t, :), b2(t, :), b3(t, :), b4(t, :)] = TeledyneADCP.workhorse_3beamsolution(I, [b1(t, :); b2(t, :); b3(t, :); b4(t, :)]');
    
    h_t = heading(t);
    p_t = gpitch(t);
    r_t = adjusted_roll(t);

    H = [cos(h_t) sin(h_t) 0 0; ...
            -sin(h_t) cos(h_t) 0 0; ...
            0 0 1 0; ...
            0 0 0 1];

    GP = [1 0 0 0; ...
            0 cos(p_t) -sin(p_t) 0; ...
            0 sin(p_t) cos(p_t) 0; ...
            0 0 0 1];

    AR = [cos(r_t) 0 sin(r_t) 0; ...
            0 1 0 0; ...
            -sin(r_t) 0 cos(r_t) 0; ...
            0 0 0 1];

    v_t = (H * GP) * (AR * I) * cat(1, b1(t, :), b2(t, :), b3(t, :), b4(t, :));
    v1(t, :) = v_t(1, :);
    v2(t, :) = v_t(2, :);
    v3(t, :) = v_t(3, :);
    v4(t, :) = v_t(4, :);
end

end

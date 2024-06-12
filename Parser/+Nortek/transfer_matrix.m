function [Beam2xyz] = transfer_matrix(iA0_Header)
% function [Beam2xyz] = transfer_matrix(iA0_Header)
%
% get transfer function from adcp config command GETXFAVG
%
% Input:
%    iA0_Header - the header string
%
% Output:
%    Beam2xyz - transfer matrix to use to convert between ENU and beam
%
% Example
%
%
%

narginchk(1,1)

r = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','ROWS','int');
Beam2xyz = zeros(r,r);

Beam2xyz(1,1) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M11','float');
Beam2xyz(1,2) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M12','float');
Beam2xyz(1,3) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M13','float');
Beam2xyz(2,1) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M21','float');
Beam2xyz(2,2) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M22','float');
Beam2xyz(2,3) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M23','float');
Beam2xyz(3,1) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M31','float');
Beam2xyz(3,2) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M32','float');
Beam2xyz(3,3) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M33','float');

if r==4
    Beam2xyz(1,4) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M14','float');
    Beam2xyz(2,4) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M24','float');
    Beam2xyz(3,4) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M34','float');
    Beam2xyz(4,1) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M41','float');
    Beam2xyz(4,2) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M42','float');
    Beam2xyz(4,3) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M43','float');
    Beam2xyz(4,4) = Nortek.read_nortek_header_key(iA0_Header,'GETXFAVG','M44','float');
end

end


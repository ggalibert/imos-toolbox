function [cvars] = current_variables(sample_data)
% function [bool] = echo_intensity_variables(sample_data)
%
% Return variables names associated with currents.
% Purpose primarily for use in ringing bin removal 
%
% Inputs:
%
% sample_data [struct] - a toolbox dataset.
%
% Outputs:
%
% cvars [cell] - A cell with variable names.
%
% Example:
%
% %basic usage
% x.variables{1}.name = 'VEL1';
% x.variables{2}.name = 'X';
% assert(inCell(IMOS.adcp.echo_intensity_variables(x),'VEL1'))
% assert(~inCell(IMOS.adcp.echo_intensity_variables(x),'X'))
%
% y.variables{1}.name = 'UCUR';
% y.variables{2}.name = 'DEPTH';
% assert(inCell(IMOS.adcp.echo_intensity_variables(y),'UCUR'))
% assert(~inCell(IMOS.adcp.echo_intensity_variables(y),'DEPTH'))
%
% author: hugo.oliveira@utas.edu.au
% edited:rebecca.cowley@csiro.au

narginchk(1, 1)

var_pool = {
            'VEL1', ...
            'UCUR', ...
            'UCUR_MAG', ...
            'VEL2', ...
            'VCUR', ...
            'VCUR_MAG', ...
            'VEL3', ...
            'WCUR', ...
            'VEL4', ...
            'CSPD', ...
            'CDIR'
        };
cvars = intersect(var_pool, IMOS.get(sample_data.variables, 'name'));
end

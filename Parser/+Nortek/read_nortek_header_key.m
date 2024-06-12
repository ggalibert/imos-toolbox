function [value] = read_nortek_header_key(hstr,mode,key,vtype)
% function value = read_nortek_header_key(hstr,mode,key,vtype)
%
% Read a nortek value from a `key` name
% within a `mode` line from the header string `hstr`.
% The type of the variable is defined by `vtype`.
% See example.
%
% Inputs:
% 
% hstr - the header string
% mode- the name of the mode or the first string in the line
% key - the name of the key
% vtype - the textscan type of the value [Optional]
%      - default: 'float'
%
%
% Outputs:
% 
% value - a single value
%
% Example:
%
% hstr = 'GETAVG1,ABC="CBA",MIAVG=600,ERR=0.00e-10';
% [value] = read_nortek_header_key(hstr,'GETAVG1','MIAVG','int');
% assert(value==600)
% [value] = read_nortek_header_key(hstr,'GETAVG1','ABC','str');
% assert(value=='CBA')
% [value] = read_nortek_header_key(hstr,'GETAVG1','ERR','float');
% assert(value==0.00e-10)
%
% author: hugo.oliveira@utas.edu.au
%
narginchk(4,4)

if strcmpi(vtype,'float')
    mtype = '-?[\d.]+(?:[eE][-?+?\d+]\d+)?';
    mfun = @str2double;
elseif strcmpi(vtype,'integer') || strcmpi(vtype,'int')
    mtype = '\d+';
    mfun = @str2double;
else
    mtype = '".*?"';
    mfun = @(x) strrep(x,'"','');
end

%header lines always start with command,key0=value0,key1=value1,...
re_match = ['(?<mode>(' mode  '))' '(.*?)' key '={1}' '(?<value>(' mtype '))'];
data = regexpi(hstr,re_match,'names');

if ~isempty(data)
    value = mfun(data.value);
else
    error('Could not find key %s with type %s',key,vtype);
end

end


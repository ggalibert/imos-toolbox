function [fieldTrip dataDir] = startDialog()
%STARTDIALOG Displays a dialog prompting the user to select a Field Trip 
% and a directory which contains raw data files.
%
% The user is able to choose from a list of field trip IDs, limited by a 
% date range; the field trips are retrieved from the deployment database. 
% When the user confirms the dialog, the selected field trip and data 
% directory are returned. If the user cancels the dialog, both the 
% fieldTrip and dataDir return values will be empty matrices.
%
% Outputs:
%
%   fieldTrip - struct containing information about the field trip selected
%               by the user.
%
%   dataDir   - a string containing the location of the directory selected
%               by the user.
%
% Author: Paul McCarthy <paul.mccarthy@csiro.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
  error(nargchk(0,2,nargin));
  
  dataDir     = pwd;
  fieldTripId = 1;
  lowDate     = 0;
  highDate    = now;
  dateFmt     = readToolboxProperty('toolbox.dateFormat');
    
  % if default values exist for data dir and field trip, use them
  try 
    dataDir     =            readToolboxProperty('startDialog.dataDir'); 
    fieldTripId = str2double(readToolboxProperty('startDialog.fieldTrip'));
    lowDate     = str2double(readToolboxProperty('startDialog.lowDate'));
    highDate    = str2double(readToolboxProperty('startDialog.highDate'));
  catch
  end

  if isnan(lowDate), lowDate  = 0;   end
  if isnan(highDate, highDate = now; end

  % retrieve all field trip IDs; they are displayed as a drop down menu
  fieldTrips = executeDDBQuery('FieldTrip', [], []);
  
  if isempty(fieldTrips), error('No field trip entries in DDB'); end
  
  % generate field trip descriptions - we don't want to do it every time
  % the field trip list is regenerated, as it results in poor performance
  % (a bit of a lag when the user changes the date range). Instead, we
  % generate the descriptions now, and maintain a list of descriptions in
  % parallel with the list of field trips (and filtered field trips)
  fieldTripDescs = genFieldTripDescs(fieldTrips, dateFmt);
  
  % generate initial field trip list; after the first 
  % time, this is handled by the dateStartCallback and
  % dateEndCallback functions
  [filteredFieldTrips filteredFieldTripDescs] = ...
    filterFieldTrips(fieldTrips, fieldTripDescs, lowDate, highDate);
  
  
  % currently selected field trip
  fieldTripIdx = 1;
  
  % find the default field trip
  fieldTrip = filteredFieldTrips(1);
  
  if fieldTripId ~= -99999
    for k = 1:length(filteredFieldTrips)

      f = filteredFieldTrips(k);

      % save default field trip selection
      if f.FieldTripID == fieldTripId
        fieldTripIdx = k; 
        fieldTrip    = f;
        break;
      end
    end  
  end
  
  %% Dialog creation
  %

  % dialog figure
  f = figure('Name',        'Select Field Trip', ...
             'Visible',     'off',...
             'MenuBar',     'none',...
             'Resize',      'off',...
             'WindowStyle', 'Modal',...
             'NumberTitle', 'off');

  % create the widgets
  dateStartButton = uicontrol('Style',  'pushbutton', ...
                              'String', ...
                              ['Field trip start: ' datestr(lowDate, dateFmt)]);
  dateEndButton   = uicontrol('Style', 'pushbutton', 'String', ...
                              ['Field trip end: ' datestr(highDate, dateFmt)]);
  
  fidLabel      = uicontrol('Style',  'text',...
                            'String', 'Field Trip ID');
  fidMenu       = uicontrol('Style',  'popupmenu', ...
                            'String', filteredFieldTripDescs,...
                            'Value',  fieldTripIdx);

  dirLabel      = uicontrol('Style', 'text',       'String', 'Data Directory');
  dirText       = uicontrol('Style', 'edit',       'String',  dataDir);
  dirButton     = uicontrol('Style', 'pushbutton', 'String', 'Browse');

  cancelButton  = uicontrol('Style', 'pushbutton', 'String', 'Cancel');
  confirmButton = uicontrol('Style', 'pushbutton', 'String', 'Ok');

  % labels and text are aligned to the left
  set([fidLabel, dirLabel, dirText], 'HorizontalAlignment', 'Left');

  % use normalised coordinates
  set(f,                                'Units', 'normalized');
  set([fidLabel,fidMenu],               'Units', 'normalized');
  set([dirLabel, dirText, dirButton],   'Units', 'normalized');
  set([cancelButton, confirmButton],    'Units', 'normalized');
  set([dateStartButton, dateEndButton], 'Units', 'normalized');

  % position the widgets
  set(f,               'Position', [0.2,  0.4,  0.6,   0.2]);

  set(cancelButton,    'Position', [0.0,  0.0,  0.5,   0.25]);
  set(confirmButton,   'Position', [0.5,  0.0,  0.5,   0.25]);

  set(dirLabel,        'Position', [0.0,  0.25, 0.199, 0.25]);
  set(dirText,         'Position', [0.2,  0.25, 0.65,  0.25]);
  set(dirButton,       'Position', [0.85, 0.25, 0.15,  0.25]);

  set(fidLabel,        'Position', [0.0,  0.50, 0.199, 0.25]);
  set(fidMenu,         'Position', [0.2,  0.50, 0.8,   0.25]);
  
  set(dateStartButton, 'Position', [0.0,  0.75, 0.50,  0.25]);
  set(dateEndButton,   'Position', [0.5,  0.75, 0.50,  0.25]);
  
  % reset back to pixels
  set(f,                                'Units', 'pixels');
  set([fidLabel,fidMenu],               'Units', 'pixels');
  set([dirLabel, dirText, dirButton],   'Units', 'pixels');
  set([cancelButton, confirmButton],    'Units', 'pixels');
  set([dateStartButton, dateEndButton], 'Units', 'pixels');
  
  % set widget callbacks
  set(f,               'CloseRequestFcn', @cancelCallback);
  set(dateStartButton, 'Callback',        @dateStartCallback);
  set(dateEndButton,   'Callback',        @dateEndCallback);
  set(fidMenu,         'Callback',        @fidMenuCallback);
  set(dirText,         'Callback',        @dirTextCallback);
  set(dirButton,       'Callback',        @dirButtonCallback);
  set(cancelButton,    'Callback',        @cancelCallback);
  set(confirmButton,   'Callback',        @confirmCallback);
  
  % user can hit escape to quit dialog
  set(f, 'WindowKeyPressFcn', @keyPressCallback);

  % display the dialog and wait for user input
  set(f, 'Visible', 'on');
  uiwait(f);
  
  %% Callback functions
  %
  
  function keyPressCallback(source,ev)
  %KEYPRESSCALLBACK If the user pushes escape/return while the dialog has 
  % focus, the dialog is cancelled/confirmed. This is done by delegating 
  % to the cancelCallback/confirmCallback functions.
  %
    if     strcmp(ev.Key, 'escape'), cancelCallback( source,ev); 
    elseif strcmp(ev.Key, 'return'), confirmCallback(source,ev); 
    end
  end

  function dateStartCallback(source,ev)
  %DATESTARTCALLBACK Called when the date end button is pushed. Prompts the
  % user to enter a date, then updates the field trip list so that it only
  % displays field trips with a start date after the entered date. 
  % 
    [y m d] = datevec(lowDate);
    [y m d] = datePromptDialog(y,m,d);
    newLowDate = datenum(y,m,d);
    
    if newLowDate == lowDate, return; end
    
    lowDate = newLowDate;
    
    % update button display
    set(dateStartButton, 'String', datestr(lowDate, dateFmt));
    
    % update field trip list
    [filteredFieldTrips filteredFieldTripDescs] = ...
      filterFieldTrips(fieldTrips, fieldTripDescs, lowDate, highDate);
    set(fidMenu, 'Value', 1);
    set(fidMenu, 'String', filteredFieldTripDescs);
    
    % update field trip menu
    fidMenuCallback(source,ev);
  
  end

  function dateEndCallback(source,ev)
  %DATEENDCALLBACK Called when the date end button is pushed. Prompts the
  % user to enter a date, then updates the field trip list so that it only
  % displays field trips with an end date before the entered date. 
  % 
    [y m d] = datevec(highDate);
    [y m d] = datePromptDialog(y,m,d);
    newHighDate = datenum(y,m,d);
    
    if newHighDate == highDate, return; end
    
    highDate = newHighDate;
    
    % update button display
    set(dateEndButton, 'String', datestr(highDate, dateFmt));
    
    % update field trip list
    [filteredFieldTrips filteredFieldTripDescs] = ...
      filterFieldTrips(fieldTrips, fieldTripDescs, lowDate, highDate);
    set(fidMenu, 'Value', 1);
    set(fidMenu, 'String', filteredFieldTripDescs);
    
    % update field trip menu
    fidMenuCallback(source,ev);
    
  end
  
  function fidMenuCallback(source,ev)
  % FIDMENUCALLBACK Field Trip ID popup menu callback. Saves the currently 
  % selected field trip.
  %
    fieldTripIdx = get(fidMenu, 'Value');
    fieldTrip    = filteredFieldTrips(fieldTripIdx);
  end

  function dirTextCallback(source,ev)
  %DIRTEXTCALLBACK Directory text field callback. If the text entered in
  % the dirText field is a valid directory, saves it. Otherwise the dirText
  % field is reset.
  %
    newDir = get(source, 'String');
    
    % ignore invalid input
    if ~isdir(newDir), set(source, 'String', dataDir); return; end
    
    dataDir = newDir;
  end

  function dirButtonCallback(source,ev)
  %DIRBUTTONCALLBACK Directory browse button callback. Opens a file browser, 
  % prompting the user to select a directory. Saves the selected directory, 
  % and updates the contents of the dirText field.
  %
    newDir = '';
    
    while ~isdir(newDir)
      newDir = uigetdir(dataDir, 'Select Data Directory');
    
      % user cancelled dialog 
      if newDir == 0, return; end
    end
    
    % save new dir, update dirText text field
    dataDir = newDir;
    set(dirText, 'String', dataDir);
  end

  function cancelCallback(source,ev)
  %CANCELCALLBACK Cancel button callback. Discards user input and closes the 
  % dialog .
  %
    dataDir   = [];
    fieldTrip = [];
    delete(f);
  end

  function confirmCallback(source,ev)
  % CONFIRMCALLBACK. Confirm button callback. Closes the dialog.
  %
    delete(f);
  end


  %% Input processing
  %
  
  % if user cancelled, return empty matrices
  if isempty(dataDir) || isempty(fieldTrip), return; end
  
  % persist the user's directory and field trip selection
  writeToolboxProperty('startDialog.dataDir',   dataDir);
  writeToolboxProperty('startDialog.fieldTrip', num2str(fieldTrip.FieldTripID));
  writeToolboxProperty('startDialog.lowDate',   num2str(lowDate));
  writeToolboxProperty('startDialog.highDate',  num2str(highDate));
  
end

function [fieldTrips fieldTripDescs] = ...
  filterFieldTrips(fieldTrips, fieldTripDescs, lowDate, highDate)
%FILTERFIELDTRIPS Filters the given field trip structs. returning those
% which have an end date after the given low date, or which have a start
% date before the given high date.
%

  % some of the DateStart/DateEnd fields may not have been set, 
  % so we can't process them in a nice array type manner. Field 
  % trips which do not have a start/end date automatically pass 
  % through the filter
  
  startDates = {fieldTrips.DateStart};
  endDates   = {fieldTrips.DateEnd};
  
  toRemove = [];
  
  for k = 1:length(fieldTrips)
    
    startDate = startDates{k};
    endDate   = endDates{k};
    
    % pass incomplete entries
    if isempty(startDate) && isempty(endDate), continue; end
    
    % check that field trip start is before high limit
    if ~isempty(startDate)
      if startDate > highDate, toRemove(end+1) = k; continue; end
    end
    
    % check that field trip end is after low limit
    if ~isempty(endDate)
      if endDate < lowDate, toRemove(end+1) = k; continue; end
    end
  end
  
  % return the filtered list
  fieldTrips(    toRemove) = [];
  fieldTripDescs(toRemove) = [];
end

function descs = genFieldTripDescs(fieldTrips, dateFmt)
%GENFIELDTRIPDESCS Generate descriptions of the given field trips for use
%in the dialog's field trip menu.
%
  descs = {};
  
  for k = 1:length(fieldTrips)
    
    f = fieldTrips(k);
    if isempty(f.DateStart), startDate = '';
    else startDate = datestr(f.DateStart, dateFmt);
    end
    
    if isempty(f.DateEnd),   endDate = '';
    else endDate   = datestr(f.DateEnd, dateFmt);
    end
    
    dateRange = [startDate  ' - ' endDate];
    
    desc = [num2str(f.FieldTripID) ' (' dateRange ') ' f.FieldDescription];
    
    descs{end+1} = desc;
  end
end


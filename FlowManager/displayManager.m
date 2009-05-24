function displayManager( fieldTrip, sample_data,...
                         metadataUpdateCallback,...
                         rawDataRequestCallback,...
                         autoQCRequestCallback,...
                         manualQCRequestCallback,...
                         exportRequestCallback)
%DISPLAYMANGER Manages the display of data.
%
% The display manager handles the interaction between the main window and
% the rest of the toolbox. It defines what is displayed in the main window,
% and how the system reacts when the user interacts with the main window.
%
% Inputs:
%   fieldTrip               - struct containing field trip information.
%   sample_data             - Cell array of sample_data structs, one for
%                             each instrument.
%   metadataUpdateCallback  - Callback function which is called when a data
%                             set's metadata is modified.
%   rawDataRequestCallback  - Callback function which is called to retrieve
%                             the raw data set.
%   autoQCRequestCallback   - Callback function called when the user attempts 
%                             to execute an automatic QC routine.
%   manualQCRequestCallback - Callback function called when the user attempts 
%                             to execute a manual QC routine.
%   exportRequestCallback   - Callback function called when the user attempts 
%                             to export data.
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
  error(nargchk(7,7,nargin));

  if ~isstruct(fieldTrip), error('fieldTrip must be a struct');       end
  if ~iscell(sample_data), error('sample_data must be a cell array'); end
  if isempty(sample_data), error('sample_data is empty');             end

  if ~isa(metadataUpdateCallback,  'function_handle')
    error('metadataUpdateCallback must be a function handle'); 
  end
  if ~isa(rawDataRequestCallback,  'function_handle')
    error('rawDataRequestCallback must be a function handle'); 
  end
  if ~isa(autoQCRequestCallback,   'function_handle')
    error('autoQCRequestCallback must be a function handle'); 
  end
  if ~isa(manualQCRequestCallback, 'function_handle')
    error('manualQCRequestCallback must be a function handle'); 
  end
  if ~isa(exportRequestCallback,   'function_handle')
    error('exportRequestCallback must be a function handle'); 
  end
  
  % define the user options, and create the main window
  states = {'Metadata', 'Raw data', 'Quality Control', 'Export'};
  mainWindow(fieldTrip, sample_data, states, 2, @stateSelectCallback);
  
  function stateSelectCallback(...
    panel, updateCallback, state, sample_data, graphType, set, vars, dim)
  %STATESELECTCALLBACK Called when the user pushes one of the 'state' buttons 
  % on the main window. Populates the given panel as appropriate.
  %
  % Inputs:
  %   panel          - uipanel on which things can be drawn.
  %   updateCallback - function to be called when data is modified.
  %   state          - selected state (string).
  %   sample_data    - Cell array of sample_data structs
  %   graphType      - currently selected graph type (string).
  %   set            - currently selected sample_data struct (index)
  %   vars           - currently selected variables (indices).
  %   dim            - currently selected dimension (index).
  %
  
    % clear any figure level mouse callbacks that may have been 
    % added (this is mostly to remove the selectData callbacks)
    set(f, 'WindowButtonDownFcn',   []);
    set(f, 'WindowButtonMotionFcn', []);
    set(f, 'WindowButtonUpFcn',     []);
  
    switch(state)

      case 'Metadata'
        
        % display metadata viewer, allowing user to modify metadata
        viewMetadata(...
          panel, fieldTrip, sample_data{set}, @metadataUpdateWrapperCallback);
        
      case 'Raw data' 
        
        % request a copy of raw data
        raw = rawDataRequestCallback();
        
        % update GUI with raw data set
        for k = 1:length(raw), updateCallback(raw{k}); end
        
        % display selected raw data
        graphFunc = str2func(graphType);
        graphFunc(panel, raw{set}, vars, dim, false);
        
      case 'Quality Control'
      
        % run the QC chain
        autoQC = autoQCRequestCallback();
        
        % update GUI with QC'd data set
        for k = 1:length(autoQC), updateCallback(autoQC{k}); end
        
        % redisplay the data
        graphFunc = str2func(graphType);
        [graphs lines flags] = ...
          graphFunc(panel, autoQC{set}, vars, dim, true);
        
        % add data selection functionality
        selectData(@dataSelectCallback);
    end
    
    function metadataUpdateWrapperCallback(sam)
    %METADATAUPDATEWRAPPERCALLBACK Called by the viewMetadata display when
    % metadata is updated. Calls the two subsequent metadata callback
    % functions (mainWindow and flowManager).
    
      % notify of change to metadata
      metadataUpdateCallback(sam);
      
      % update GUI with modified data set
      updateCallback(sam);
    end
  end

  function dataSelectCallback(ax, type, range)
    
    switch(type)
      case 'normal', disp(['data range: ' num2str(range)]);
      case 'alt',    disp(['flag range: ' num2str(range)]);
    end
    
  end
end

function mainWindow(windowTitle, sample_data, states, startState, selectionCallback)
%MAINWINDOW Displays a window which allows the user to view data.
%
% The mainWindow is the main toolbox window. It provides menus allowing the
% user to select the data set to use and the graph type to display (if a
% graph is being displayed), and enable/disable variables.
%
% The central area of the mainWindow is left empty, it is up to the
% calling function (the displayManager) to populate this window. It is also
% up to the calling function to define the buttons which will appear down
% the left of the window; these are referred to as states.
%
% Whenever the user changes the state (via a state button) or any of the
% options, the provided selectionCallback function is called with the new
% selection.
%
% The main window never modifies data, but must be kept informed of changes
% to the data set. This is achieved by the updateCallback function handle
% which is passed to the selectionCallback function. Whenever data is
% changed, this function must be called in order to keep the main window
% display consistent.
%
% Inputs:
%   windowTitle       - String to be used as the window title.
%   sample_data       - Cell array of structs of sample data.
%   states            - Cell array of strings containing state names.
%   startState        - Index into states array, specifying initial state.
%   selectionCallback - A function which is called when the user pushes a
%                       state button. The function must take the following
%                       input arguments:
%                         event          - String describing what triggered
%                                          the callback. One of 'state',
%                                          'set', 'graph', or 'var'.
%                         panel          - A uipanel on which things can be
%                                          drawn.
%                         updateCallback - Function to be called when data
%                                          is updated. The function is of
%                                          the form:
%                                            function updateCallback(...
%                                              sample_data)
%                         state          - Currently selected state (String)
%                         sample_data    - Cell array of sample_data
%                                          structs
%                         graphType      - Currently selected graph type
%                                          (String)
%                         set            - Currently selected sample_data
%                                          struct
%                         vars           - Currently selected variables
%                       The function must also provide one output argument:
%                         state          - the new state, if it changed.
%
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:  Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (C) 2017, Australian Ocean Data Network (AODN) and Integrated 
% Marine Observing System (IMOS).
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation version 3 of the License.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
% GNU General Public License for more details.

% You should have received a copy of the GNU General Public License
% along with this program.
% If not, see <https://www.gnu.org/licenses/gpl-3.0.en.html>.
%
narginchk(5,5);

if ~ischar(windowTitle),                            error('windowTitle must be a string');         end
if ~iscell(sample_data) || isempty(sample_data),    error('sample_data must be a cell array');     end
if ~iscellstr(states),                              error('states must be a cell array');          end
if ~isnumeric(startState),                          error('initialState must be a numeric');       end
if ~isa(selectionCallback, 'function_handle'),      error('selectionCallback must be a function'); end

currentState = states{startState};

% sample menu entries (1-1 mapping to sample_data structs)
lenSam = length(sample_data);
sampleDataDescs = cell(lenSam, 1);
for k = 1:lenSam
    sampleDataDescs{k} = genSampleDataDesc(sample_data{k});
end

backgroundPlotColor = [1 1 1]; % white

% window figure
fig = figure(...
    'Name',        windowTitle, ...
    'Visible',     'off',...
    'MenuBar',     'none',...
    'ToolBar',     'figure',...
    'Resize',      'on',...
    'WindowStyle', 'Normal',...
    'NumberTitle', 'off',...
    'Tag',         'mainWindow');

% sample data selection menu
sampleMenu = uicontrol(...
    'Style',  'popupmenu',...
    'String', sampleDataDescs,...
    'Value',  1,...
    'Tag',    'samplePopUpMenu');

% get the toolbox execution mode
mode = readProperty('toolbox.mode');

switch mode
    case 'profile'
        graphMenuValue = 2;
    case 'timeSeries'
        graphMenuValue = 1;
end

% graph type selection menu
graphMenu = uicontrol(...
    'Style',    'popupmenu',...
    'String',   listGraphs(),...
    'Value',    graphMenuValue);

% extra instrument check box
extraSampleCb = uicontrol(...
    'Style',    'checkbox',...
    'String',   'Graph extra instrument good data only (black)',...
    'Value',    0,...
    'Tag',      'extraSampleCheckBox');

% extra sample data selection menu
extraSampleMenu = uicontrol(...
    'Style',  'popupmenu',...
    'String', sampleDataDescs,...
    'Value',  1,...
    'Enable', 'off',...
    'Tag',    'extraSamplePopUpMenu');

% flag visibility check box
visiFlagCb = uicontrol(...
    'Style',    'checkbox',...
    'String',   'Show data flag if any',...
    'Value',    1,...
    'Tag',      'visiFlagCheckBox');

% bad data visibility check box
visiBadCb = uicontrol(...
    'Style',    'checkbox',...
    'String',   'Hide bad data',...
    'Value',    0,...
    'Tag',      'visiBadCheckBox');

% side panel
sidePanel = uipanel(...
    'Parent',     fig,...
    'BorderType', 'none');

% buttons panel
butPanel = uipanel(...
    'Parent',     sidePanel,...
    'BorderType', 'none');

% state buttons
lenStates = length(states);
stateButtons = nan(lenStates, 1);
for k = 1:lenStates
    stateButtons(k) = uicontrol(...
        'Parent', butPanel,...
        'Style',  'pushbutton',...
        'String', states{k});
end

% variable selection panel - created in createVarPanel
varPanel = uipanel(...
    'Parent',     sidePanel,...
    'BorderType', 'none');

% main display
mainPanel = uipanel(...
    'BackgroundColor',  backgroundPlotColor,...
    'BorderType',       'none',...
    'Parent',           fig,...
    'Tag',              'mainPanel');

% use normalized units
set(fig,              'Units', 'normalized');
set(sidePanel,        'Units', 'normalized');
set(mainPanel,        'Units', 'normalized');
set(butPanel,         'Units', 'normalized');
set(varPanel,         'Units', 'normalized');
set(sampleMenu,       'Units', 'normalized');
set(graphMenu,        'Units', 'normalized');
set(extraSampleCb,    'Units', 'normalized');
set(extraSampleMenu,  'Units', 'normalized');
set(visiFlagCb,       'Units', 'normalized');
set(visiBadCb,        'Units', 'normalized');
set(stateButtons,     'Units', 'normalized');

% set window position
set(fig, 'Position', [0.1,  0.15, 0.8,  0.7]);

% restrict window to primary screen
set(fig, 'Units', 'pixels');
pos       = get(fig,  'OuterPosition');
monitors  = get(0,    'MonitorPositions');
if pos(3) > monitors(1,3)
    pos(1) = 1;
    pos(3) = monitors(1,3);
    set(fig, 'OuterPosition', pos);
end
set(fig, 'Units', 'normalized');

% set widget positions
set(sidePanel,          'Position', posUi2(fig, 100, 100, 16:100,  1:10,  0));
set(mainPanel,          'Position', posUi2(fig, 100, 100, 16:100, 11:100, 0));
set(sampleMenu,         'Position', posUi2(fig, 100, 100,  1:5,    1:75,  0));
set(graphMenu,          'Position', posUi2(fig, 100, 100,  1:5,   76:100, 0));
set(extraSampleMenu,    'Position', posUi2(fig, 100, 100,  6:10,   1:75,  0));
set(extraSampleCb,      'Position', posUi2(fig, 100, 100,  6:10,  76:100, 0));
set(visiFlagCb,         'Position', posUi2(fig, 100, 100, 11:15,  76:100, 0));
set(visiBadCb,          'Position', posUi2(fig, 100, 100, 11:15,  51:75,  0));

% varPanel and butPanel are positioned relative to sidePanel
set(butPanel, 'Position', posUi2(sidePanel, 10, 1, 1:5,  1, 0));
set(varPanel, 'Position', posUi2(sidePanel, 10, 1, 6:10, 1, 0));

% set state buttons position relative to butPanel
n = length(stateButtons);
for k = 1:n
    set(stateButtons(k), 'Position', posUi2(butPanel, n, 1, k, 1, 0));
end

% set callbacks - variable panel widget
% callbacks are set in createParamPanel
set(sampleMenu,         'Callback', @sampleMenuCallback);
set(graphMenu,          'Callback', @graphMenuCallback);
set(extraSampleCb,      'Callback', @sampleMenuCallback);
set(extraSampleMenu,    'Callback', @sampleMenuCallback);
set(visiFlagCb,         'Callback', @sampleMenuCallback);
set(visiBadCb,          'Callback', @sampleMenuCallback);
set(stateButtons,       'Callback', @stateButtonCallback);

set(fig, 'Visible', 'on');
createVarPanel(sample_data{1}, []);
selectionChange('state');

tb      = findall(fig, 'Type', 'uitoolbar');
buttons = findall(tb);

savefigb    = findobj(buttons, 'TooltipString', 'Save Figure');
zoominb     = findobj(buttons, 'TooltipString', 'Zoom In');
zoomoutb    = findobj(buttons, 'TooltipString', 'Zoom Out');
panb        = findobj(buttons, 'TooltipString', 'Pan');
datacursorb = findobj(buttons, 'TooltipString', 'Data Cursor');

buttons(buttons == tb)            = [];
buttons(buttons == savefigb)      = [];
if verLessThan('matlab', '9.5')
    buttons(buttons == zoominb)       = [];
    buttons(buttons == zoomoutb)      = [];
    buttons(buttons == panb)          = [];
    buttons(buttons == datacursorb)   = [];
end

delete(buttons);

% reset save figure callback with the FileSaveAs one instead of FileSave
set(savefigb, 'ClickedCallback', 'filemenufcn(gcbf,''FileSaveAs'')');

%set zoom/pan post-callback
%zoom v6 off; % undocumented Matlab to make sure zoom function prior to R14 is not used. Seems to not be supported from R2015a.
hZoom = zoom(fig);
hPan  = pan(fig);
set(hZoom, 'ActionPostCallback', @zoomPostCallback);
set(hPan,  'ActionPostCallback', @zoomPostCallback);

% update zoom in and pan's tooltips to display hot keys
if verLessThan('matlab', '9.5')
    set(zoominb, 'TooltipString', 'Zoom In (Ctrl+z)');
    set(panb,    'TooltipString', 'Pan (Ctrl+a)');
else
    zoominb = uitoggletool(tb, ...
        'TooltipString', 'Zoom In (Ctrl+z)',...
        'HandleVisibility', 'off', ...
        'OnCallback', @onZoomIn, ...
        'OffCallback', 'zoom(''off'')');
    [img,map,alpha] = imread(fullfile(matlabroot,'toolbox','matlab','icons','tool_zoom_in.png'));
    img = double(img)/double(intmax(class(img)));
    img(repmat(alpha==0,[1 1 3])) = NaN;
    zoominb.CData = img;

    zoomoutb = uitoggletool(tb, ...
        'TooltipString', 'Zoom Out',...
        'HandleVisibility', 'off', ...
        'OnCallback', @onZoomOut, ...
        'OffCallback', 'zoom(''off'')');
    [img,map,alpha] = imread(fullfile(matlabroot,'toolbox','matlab','icons','tool_zoom_out.png'));
    img = double(img)/double(intmax(class(img)));
    img(repmat(alpha==0,[1 1 3])) = NaN;
    zoomoutb.CData = img;
    
    hPan = uitoggletool(tb, ...
        'TooltipString',  'Pan (Ctrl+a)',...
        'HandleVisibility', 'off', ...
        'OnCallback', 'pan(''on'')', ...
        'OffCallback', 'pan(''off'')');
    [img,map,alpha] = imread(fullfile(matlabroot,'toolbox','matlab','icons','tool_hand.png'));
    img = double(img)/double(intmax(class(img)));
    img(repmat(alpha==0,[1 1 3])) = NaN;
    hPan.CData = img;
end

%set uimenu
hToolsMenu                                  = uimenu(fig,                         'label', 'Tools');
switch mode
    case 'timeSeries'
        hToolsCheckPlannedDepths            = uimenu(hToolsMenu,                    'label', 'Check DEPTH against NOMINAL_DEPTH');
        hToolsCheckPlannedDepthsNonQC       = uimenu(hToolsCheckPlannedDepths,      'label', 'all data');
        hToolsCheckPlannedDepthsQC          = uimenu(hToolsCheckPlannedDepths,      'label', 'only good and non QC''d data');
        hToolsCheckPressDiffs               = uimenu(hToolsMenu,                    'label', 'Check pressure differences between selected instrument and nearest neighbours');
        hToolsCheckPressDiffsNonQC          = uimenu(hToolsCheckPressDiffs,         'label', 'all data');
        hToolsCheckPressDiffsQC             = uimenu(hToolsCheckPressDiffs,         'label', 'only good and non QC''d data');
        hToolsLineDepth                     = uimenu(hToolsMenu,                    'label', 'DEPTH timeseries line plot across mooring');
        hToolsLineDepthNonQC                = uimenu(hToolsLineDepth,               'label', 'all data');
        hToolsLineDepthQC                   = uimenu(hToolsLineDepth,               'label', 'only good and non QC''d data');
        hToolsLineCommonVar                 = uimenu(hToolsMenu,                    'label', '1D variable timeseries line plot across mooring');
        hToolsLineCommonVarNonQC            = uimenu(hToolsLineCommonVar,           'label', 'all data');
        hToolsLineCommonVarQC               = uimenu(hToolsLineCommonVar,           'label', 'only good and non QC''d data');
        hToolsScatterCommonVar              = uimenu(hToolsMenu,                    'label', '1D variable vs DEPTH timeseries scatter plot across mooring');
        hToolsScatterCommonVarNonQC         = uimenu(hToolsScatterCommonVar,        'label', 'all data');
        hToolsScatterCommonVarQC            = uimenu(hToolsScatterCommonVar,        'label', 'only good and non QC''d data');
        hToolsScatter2DCommonVar            = uimenu(hToolsMenu,                    'label', '2D variable vs DEPTH timeseries scatter plot across mooring');
        hToolsScatter2DCommonVarNonQC       = uimenu(hToolsScatter2DCommonVar,      'label', 'all data');
        hToolsScatter2DCommonVarQC          = uimenu(hToolsScatter2DCommonVar,      'label', 'only good and non QC''d data');
        hToolsDiagramCommonVarDepth         = uimenu(hToolsMenu,                    'label', '1D variable vs DEPTH diagram plot across mooring');
        hToolsDiagramCommonVarDepthNonQC    = uimenu(hToolsDiagramCommonVarDepth,   'label', 'all data');
        hToolsDiagramCommonVarDepthQC       = uimenu(hToolsDiagramCommonVarDepth,   'label', 'only good and non QC''d data');
        hToolsDiagram2DCommonVarDepth       = uimenu(hToolsMenu,                    'label', '2D variable vs DEPTH diagram plot across mooring');
        hToolsDiagram2DCommonVarDepthNonQC  = uimenu(hToolsDiagram2DCommonVarDepth, 'label', 'all data');
        hToolsDiagram2DCommonVarDepthQC     = uimenu(hToolsDiagram2DCommonVarDepth, 'label', 'only good and non QC''d data');
        
        %set menu callbacks
        set(hToolsCheckPlannedDepthsNonQC,      'callBack', {@displayCheckPlannedDepths,   false});
        set(hToolsCheckPlannedDepthsQC,         'callBack', {@displayCheckPlannedDepths,   true});
        set(hToolsCheckPressDiffsNonQC,         'callBack', {@displayCheckPressDiffs,      false});
        set(hToolsCheckPressDiffsQC,            'callBack', {@displayCheckPressDiffs,      true});
        set(hToolsLineDepthNonQC,               'callBack', {@displayLineMooringDepth,     false});
        set(hToolsLineDepthQC,                  'callBack', {@displayLineMooringDepth,     true});
        set(hToolsLineCommonVarNonQC,           'callBack', {@displayLineMooringVar,       false});
        set(hToolsLineCommonVarQC,              'callBack', {@displayLineMooringVar,       true});
        set(hToolsScatterCommonVarNonQC,        'callBack', {@displayScatterMooringVar,    false,  true});
        set(hToolsScatterCommonVarQC,           'callBack', {@displayScatterMooringVar,    true,   true});
        set(hToolsScatter2DCommonVarNonQC,      'callBack', {@displayScatterMooringVar,    false,  false});
        set(hToolsScatter2DCommonVarQC,         'callBack', {@displayScatterMooringVar,    true,   false});
        set(hToolsDiagramCommonVarDepthNonQC,   'callBack', {@displayDiagramMooringVar,    false,  true,  'DEPTH'});
        set(hToolsDiagramCommonVarDepthQC,      'callBack', {@displayDiagramMooringVar,    true,   true,  'DEPTH'});
        set(hToolsDiagram2DCommonVarDepthNonQC, 'callBack', {@displayDiagramMooringVar,    false,  false, 'DEPTH'});
        set(hToolsDiagram2DCommonVarDepthQC,    'callBack', {@displayDiagramMooringVar,    true,   false, 'DEPTH'});
    case 'profile'
        hToolsLineCastVar             = uimenu(hToolsMenu,        'label', '1D variable vs DEPTH selected profile line plot');
        hToolsLineCastVarNonQC        = uimenu(hToolsLineCastVar, 'label', 'all data');
        hToolsLineCastVarQC           = uimenu(hToolsLineCastVar, 'label', 'only good and non QC''d data');
        
        %set menu callbacks
        set(hToolsLineCastVarNonQC,       'callBack', {@displayLineCastVar, false});
        set(hToolsLineCastVarQC,          'callBack', {@displayLineCastVar, true});
end
hHotKeyMenu = uimenu(fig, 'label', 'Hot Keys');
uimenu(hHotKeyMenu, 'Label', 'Enable zoom',       'Accelerator', 'z', 'Callback', @(src,evt)zoom(fig, 'on'));
uimenu(hHotKeyMenu, 'Label', 'Enable pan',        'Accelerator', 'a', 'Callback', @(src,evt)pan( fig, 'on'));
uimenu(hHotKeyMenu, 'Label', 'Disable zoom/pan',  'Accelerator', 'q', 'Callback', @disableZoomAndPan);

hHelpMenu = uimenu(fig,       'label', 'Help');
hHelpWiki = uimenu(hHelpMenu, 'label', 'IMOS Toolbox Wiki');

%set menu callbacks
set(hHelpWiki, 'callBack', @openWikiPage);

%% Widget Callbacks

    function selectionChange(event)
        %Retrieves the current selection, clears the main panel, and calls
        % selectionCallback.
        %
        state = currentState;
        sam   = getSelectedData();
        vars  = getSelectedVars();
        graph = getSelectedGraphType();
        
        if get(extraSampleCb, 'value')
            extraSam = getExtraSelectedData();
        else
            extraSam.meta.index = 0;
        end
        
        isFlagVisible = get(visiFlagCb, 'value');
        
        % clear main panel
        children = get(mainPanel, 'Children');
        delete(children);
        
        % delete any mouse listeners that may have been added
        zoom off;
        pan off;
        set(fig, 'WindowButtonDownFcn',   []);
        set(fig, 'WindowButtonMotionFcn', []);
        set(fig, 'WindowButtonUpFcn',     []);
        
        currentState = selectionCallback(...
            event,...               % string describing what triggered the callback.
            mainPanel, ...          % uipanel on which things can be drawn.
            @updateCallback, ...    % function to be called when data is modified.
            state, ...              % selected state (string).
            sample_data, ...        % cell array of sample_data structs
            graph, ...              % currently selected graph type (string).
            sam.meta.index, ...     % currently selected sample_data struct (index)
            vars, ...               % currently selected variables (indices).
            extraSam.meta.index, ...% currently selected extra sample_data struct (index)
            isFlagVisible);         % currently selected visibility of flags (boolean)
        
        % set data cursor mode custom display
        dcm_obj = datacursormode(fig);
        set(dcm_obj, 'UpdateFcn', {@customDcm, sam, vars, graph, mode});
    end

    function sampleMenuCallback(source, ev)
        %SAMPLEMENUCALLBACK Called when a dataset is selected from the sample
        % menu. Updates the variables panel, then delegates to selectionChange.
        %
        sam = getSelectedData();
        if get(extraSampleCb, 'value')
            set(extraSampleMenu, 'Enable', 'on');
        else
            set(extraSampleMenu, 'Enable', 'off');
        end
        
        % keep track of previously selected variables
        iTickBox = getSelectedVars();
        nTickBoxed = length(iTickBox);
        selectedVarNames = cell(1, nTickBoxed);
        tickBoxes = get(varPanel, 'UserData');
        for i=1:nTickBoxed
            selectedVarNames{i} = get(tickBoxes(iTickBox(i)), 'String');
        end
        
        % reset the varPanel
        newVars = [];
        createVarPanel(sam, []);
        
        % we want to be able to keep the selected variables from one dataset to another if possible
        newTickBoxes = get(varPanel, 'UserData');
        for j=1:length(newTickBoxes)
            varName = get(newTickBoxes(j), 'String');
            if any(strcmp(varName, selectedVarNames))
                newVars = [newVars j];
            end
        end
        
        if ~isempty(newVars), createVarPanel(sam, newVars); end
        selectionChange('set');
    end

    function graphMenuCallback(source, ev)
        %GRAPHMENUCALLBACK Called when the user changes the graph type via the
        % graph selection menu. Delegates to selectionChange.
        %
        selectionChange('graph');
    end

    function stateButtonCallback(source, ev)
        %STATEBUTTONCALLBACK Called when the user pushes a state button. Updates
        % the current state, then delegates to selectionChange.
        %
        currentState = get(source, 'String');
        selectionChange('state');
        
        % reset varPanel
        sam = getSelectedData();
        vars = getSelectedVars();
        createVarPanel(sam, vars);
    end

    function varPanelCallback(source, ev)
        %PARAMPANELCALLBACK Called when the variable or dimension selection
        % changes. Delegates to selectionChange.
        %
        selectionChange('var');
    end

    function zoomPostCallback(source, ev)
        %ZOOMPOSTCALLBACK Called when the zoom function is called. Redraws axis ticks.
        %
        graphs1D = findobj('Tag', 'axis1D');
        graphs2D = findobj('Tag', 'axis2D');
        
        isCurAx1D = false;
        iGraph1D = (gca == graphs1D);
        if any(iGraph1D)
            isCurAx1D = true;
            graphs1D(iGraph1D) = [];
        else
            graphs2D(gca == graphs2D) = [];
        end
        
        graphs = [graphs1D; graphs2D];
        
        % reset current axis yTicks
        yLimits = get(gca, 'YLim');
        yStep   = (yLimits(2) - yLimits(1)) / 5;
        yTicks  = yLimits(1):yStep:yLimits(2);
        set(gca, 'YTick', yTicks);
        
        % sync all other 2D Y axis if needed
        if ~isCurAx1D && ~isempty(graphs2D)
            set(graphs2D, 'YLim', yLimits);
            set(graphs2D, 'YTick', yTicks);
        end
        
        % reset current axis xTicks
        xLimits = get(gca, 'XLim');
        xStep   = (xLimits(2) - xLimits(1)) / 5;
        xTicks  = xLimits(1):xStep:xLimits(2);
        set(gca, 'XTick', xTicks);
        
        graphName = get(graphMenu, 'String');
        graphName = graphName{get(graphMenu, 'Value')};
        if strcmpi(graphName, 'TimeSeries')
            % sync all other X axis
            set(graphs, 'XLim', xLimits);
            set(graphs, 'XTick', xTicks);
            
            % update other 1D axis yLim / yTick to reflect the
            % change in the Y range of displayed data
            if ~isempty(graphs1D)
                sam = getSelectedData();
                extraSam = getExtraSelectedData();
                
                hTickBoxes = get(varPanel, 'UserData');
                
                qcSet     = str2double(readProperty('toolbox.qc_set'));
                rawFlag   = imosQCFlag('raw',          qcSet, 'flag');
                goodFlag  = imosQCFlag('good',         qcSet, 'flag');
                pGoodFlag = imosQCFlag('probablyGood', qcSet, 'flag');
                okFlags = [rawFlag goodFlag pGoodFlag];
                
                for i=1:length(graphs1D)
                    userData = get(graphs1D(i), 'UserData');
                    
                    hData = userData{1};
                    xData = get(hData(1), 'XData');
                    yData = get(hData(1), 'YData');
                    
                    iTickBox = userData{2}; % index into currently ticked boxes
                    iAllTickedBox = find(cell2mat(get(hTickBoxes, 'Value')) == 1);
                    
                    varName = get(hTickBoxes(iAllTickedBox(iTickBox)), 'String');
                    iVar = getVar(sam.variables, varName);
                    flags = sam.variables{iVar}.flags;
                    if get(extraSampleCb, 'value')
                        iExtraVar = getVar(extraSam.variables, varName);
                        if iExtraVar
                            flags = [flags; extraSam.variables{iExtraVar}.flags];
                            xData = [xData, get(hData(2), 'XData')];
                            yData = [yData, get(hData(2), 'YData')];
                        end
                    end
                    iGood = ismember(flags, okFlags);
                    
                    xData(~iGood) = [];
                    yData(~iGood) = [];
                    
                    iDataIn = xData >= xLimits(1) & xData <= xLimits(2);
                    yLimits = [min(yData(iDataIn)), max(yData(iDataIn))];
                    set(graphs1D(i), 'YLim', yLimits);
                    
                    yStep   = (yLimits(2) - yLimits(1)) / 5;
                    yTicks  = yLimits(1):yStep:yLimits(2);
                    
                    set(graphs1D(i), 'YTick', yTicks);
                end
            end
            
            % tranformation of datenum xticks in datestr
            datetick(gca, 'x', 'dd-mm-yy HH:MM', 'keepticks');
            xTickLabel = get(gca, 'XTickLabel');
            for i=1:length(graphs)
                set(graphs(i), 'XTickLabel', xTickLabel); % this is to avoid too many calls to datetick()
            end
            
        elseif strcmpi(graphName, 'DepthProfile')
            % sync all other Y axis
            set(graphs, 'YLim', yLimits);
            set(graphs, 'YTick', yTicks);
        end
    end

%% Menu callback
    function displayCheckPressDiffs(source, ev, isQC)
        %DISPLAYLINEPRESSDIFFS opens a new window where all the PRES/PRES_REL
        %values for instruments adjacent to the current instrument are
        %displayed with the differences between these instrument pressures
        %
        %check for pressure
        iSampleMenu = get(sampleMenu, 'Value');
        iPRES_REL = getVar(sample_data{iSampleMenu}.variables, 'PRES_REL');
        iPRES = getVar(sample_data{iSampleMenu}.variables, 'PRES');
        if iPRES_REL == 0 && iPRES == 0
            sampleMenuStrings = get(sampleMenu, 'String');
            disp(['No pressure data for ' sampleMenuStrings{iSampleMenu}])
            return
        end
        
        checkMooringPresDiffs(sample_data, iSampleMenu, isQC, false, '');
    end

    function displayCheckPlannedDepths(source, ev, isQC)
        %DISPLAYCHECKPLANNEDDEPTHS Opens a new window where the actual
        %depths recorded are compared to the planned depths.
        %
        checkMooringPlannedDepths(sample_data, isQC, false, '');
    end

    function displayLineMooringDepth(source, ev, isQC)
        %DISPLAYLINEMOORINGDEPTH Opens a new window where all the nominal depths and
        %actual/computed depths from intruments on the mooring are line-plotted in a timeseries plot.
        %
        lineMooring1DVar(sample_data, 'DEPTH', isQC, false, '');
        
    end

    function displayLineMooringVar(source, ev, isQC)
        %DISPLAYLINEMOORINGVAR Opens a new window where all the previously selected
        % variables collected by intruments on the mooring are line-plotted in a timeseries plot.
        %
        stringQC = 'non QC';
        if isQC, stringQC = 'QC'; end
        
        lenSampleData = length(sample_data);
        paramsName = {};
        paramsCount = [];
        paramsName{1} = 'diff(TIME)';
        paramsCount(1) = lenSampleData;
        % get all params that are in common in at least two datasets
        for i=1:lenSampleData
            lenParamsSample = length(sample_data{i}.variables);
            for j=1:lenParamsSample
                sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
                if ~any(sameParam)
                    paramsName{end+1} = sample_data{i}.variables{j}.name;
                    paramsCount(end+1) = 1;
                else
                    paramsCount(sameParam) = paramsCount(sameParam)+1;
                end
            end
        end
        
        iParamsToGetRid = (paramsCount == 1);
        paramsName(iParamsToGetRid) = [];
        
        % we get rid of DEPTH parameter, if necessary user should use the
        % Depth specific plot
        iDEPTH = strcmpi(paramsName, 'DEPTH');
        paramsName(iDEPTH) = [];
        
        % we get rid of TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE and NOMINAL_DEPTH parameters
        iParam = strcmpi(paramsName, 'TIMESERIES');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'PROFILE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'TRAJECTORY');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'LATITUDE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'LONGITUDE');
        paramsName(iParam) = [];
        iParam = strcmpi(paramsName, 'NOMINAL_DEPTH');
        paramsName(iParam) = [];
        
        % by default diff(TIME) is selected
        iDiffTIME = find(strcmpi(paramsName, 'diff(TIME)'));
        
        [iSelection, ok] = listdlg(...
            'ListString', paramsName, ...
            'SelectionMode', 'single', ...
            'ListSize', [150 150], ...
            'InitialValue', iDiffTIME, ...
            'Name', ['Timeserie plot a ' stringQC '''d variable accross all instruments in the mooring'], ...
            'PromptString', 'Select a variable :');
        
        if ok==0
            return;
        else
            varName = paramsName{iSelection};
        end
        
        lineMooring1DVar(sample_data, varName, isQC, false, '');
        
    end

    function disableZoomAndPan(source, ev)
        pan( fig, 'off');
        zoom(fig, 'off');
    end

    function displayLineCastVar(source, ev, isQC)
        %DISPLAYLINECASTVAR Opens a new window where all the
        % variables collected by the currently selected CTD cast are line-plotted in a profile plot.
        %
        
        % only currently selected profile for better readability
        iSampleMenu = get(sampleMenu, 'Value');
        sam = sample_data(iSampleMenu);
        
        % get all params names
        lenSampleData = length(sam);
        paramsName = {};
        for i=1:lenSampleData
            lenParamsSample = length(sam{i}.variables);
            for j=1:lenParamsSample
                isParamQC = any(sam{i}.variables{j}.flags == 1) || any(sam{i}.variables{j}.flags == 2);
                if i==1 && j==1
                    paramsName{1} = sam{1}.variables{1}.name;
                else
                    sameParam = strcmpi(paramsName, sam{i}.variables{j}.name);
                    if ~any(sameParam)
                        paramsName{end+1} = sam{i}.variables{j}.name;
                    end
                end
                % get rid of non QC'd params if only interested in QC
                if isQC && ~isParamQC; paramsName(end) = []; end
            end
        end
        lineCastVar(sam, paramsName, isQC, false, '');
    end

    function displayScatterMooringVar(source, ev, isQC, is1D)
        %DISPLAYSCATTERMOORINGVAR Opens a new window where all the previously selected
        % variables collected by intruments on the mooring are scatter-plotted in a timeseries plot.
        %
        stringQC = 'non QC';
        if isQC, stringQC = 'QC'; end
        
        % go through all datasets, list parameters and count them
        [paramsName, paramsCount, params2D] = countParams();
        
        if is1D
            % get rid of unwanted parameters
            iParamsToBeRemoved = removeUnwantedParamsFor1DvarVsDepth(paramsName, params2D);
            paramsName(iParamsToBeRemoved) = [];
            paramsCount(iParamsToBeRemoved) = [];
            
            % get rid of params that are not found in at least two datasets
            iParamsNotInCommon = (paramsCount == 1);
            paramsName(iParamsNotInCommon) = [];
            
            % by default TEMP is selected
            iDefault = find(strcmpi(paramsName, 'TEMP'));
        else
            % get rid of unwanted parameters
            iParamsToBeRemoved = removeUnwantedParamsFor2DvarVsDepth(paramsName, params2D);
            paramsName(iParamsToBeRemoved) = [];
            
            % by default CDIR is selected
            iDefault = find(strcmpi(paramsName, 'CDIR'));
        end
        
        if isempty(iDefault), iDefault = 1; end
        
        [iSelection, ok] = listdlg(...
            'ListString',       paramsName, ...
            'SelectionMode',    'single', ...
            'ListSize',         [150 150], ...
            'InitialValue',     iDefault, ...
            'Name',             ['Timeserie plot a ' stringQC '''d variable vs DEPTH accross all instruments in the mooring'], ...
            'PromptString',     'Select a variable :');
        
        if ok==0
            return;
        else
            varName = paramsName{iSelection};
        end
        
        if is1D
            scatterMooring1DVarAgainstDepth(sample_data, varName, isQC, false, '');
        else
            scatterMooring2DVarAgainstDepth(sample_data, varName, isQC, false, '');
        end
        
    end

    function displayDiagramMooringVar(source, ev, isQC, is1D, yAxisVarName)
        %DISPLAYDIAGRAMMOORINGVAR Opens a new window where all the previously selected
        % variables collected by intruments on the mooring are scatter-plotted in a diagram plot.
        %
        stringQC = 'non QC';
        if isQC, stringQC = 'QC'; end
        
        % go through all datasets and list parameters
        [paramsName, ~, params2D] = countParams();
        
        if is1D
            % get rid of unwanted parameters
            iParamsToBeRemoved = removeUnwantedParamsFor1DvarVsDepth(paramsName, params2D);
            paramsName(iParamsToBeRemoved) = [];
            
            % we get rid of yAxisVarName
            iYAxisVarName = strcmpi(yAxisVarName, paramsName);
            paramsName(iYAxisVarName) = [];
            
            % by default TEMP is selected
            iDefault = find(strcmpi(paramsName, 'TEMP'));
        else
            % get rid of unwanted parameters
            iParamsToBeRemoved = removeUnwantedParamsFor2DvarVsDepth(paramsName, params2D);
            paramsName(iParamsToBeRemoved) = [];
            
            % we get rid of yAxisVarName
            iYAxisVarName = strcmpi(yAxisVarName, paramsName);
            paramsName(iYAxisVarName) = [];
            
            % by default CDIR is selected
            iDefault = find(strcmpi(paramsName, 'CDIR'));
        end
        
        if isempty(iDefault), iDefault = 1; end
        
        [iSelection, ok] = listdlg(...
            'ListString',       paramsName, ...
            'SelectionMode',    'single', ...
            'ListSize',         [150 150], ...
            'InitialValue',     iDefault, ...
            'Name',             ['Diagram plot a ' stringQC '''d variable vs ' yAxisVarName ' accross all instruments in the mooring'], ...
            'PromptString',     'Select a variable :');
        
        if ok==0
            return;
        else
            varName = paramsName{iSelection};
        end
        
        if is1D
            diagramMooring1DVarAgainstOther(sample_data, varName, yAxisVarName, isQC, false, '');
        else
            diagramMooring2DVarAgainstOther(sample_data, varName, yAxisVarName, isQC, false, '');
        end
        
    end

    function [paramsName, paramsCount, params2D] = countParams()
        %COUNTPARAMS goes through all datasets and parameters and count them
        lenSampleData = length(sample_data);
        paramsName = {};
        paramsCount = [];
        params2D = logical([]);
        for i=1:lenSampleData
            lenParamsSample = length(sample_data{i}.variables);
            for j=1:lenParamsSample
                sameParam = strcmpi(paramsName, sample_data{i}.variables{j}.name);
                if ~any(sameParam)
                    paramsName{end+1} = sample_data{i}.variables{j}.name;
                    paramsCount(end+1) = 1;
                    if length(sample_data{i}.variables{j}.dimensions) == 2 && ... % TIME, HEIGHT_ABOVE_SENSOR
                            size(sample_data{i}.variables{j}.data, 2) > 1 && ...
                            size(sample_data{i}.variables{j}.data, 3) == 1 % we're only plotting ADCP 2D variables with DEPTH variable.
                        params2D(end+1) = true;
                    else
                        params2D(end+1) = false;
                    end
                else
                    paramsCount(sameParam) = paramsCount(sameParam)+1;
                end
            end
        end
    end

    function iParamsToBeRemoved = removeUnwantedParamsFor1DvarVsDepth(paramsName, params2D)
        %REMOVEUNWANTEDPARAMSFOR1DVARVSDEPTH gets rid of unwanted parameters
        
        iParamsToBeRemoved = false(size(paramsName));
        
        % get only params that are 1D
        iParamsToBeRemoved(params2D) = true;
        
        % we get rid of DEPTH, PRES and PRES_REL parameters
        iDEPTH = strcmpi('DEPTH', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        iDEPTH = strcmpi('PRES', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        iDEPTH = strcmpi('PRES_REL', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        
        % we get rid of TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE and NOMINAL_DEPTH parameters
        iParam = strcmpi(paramsName, 'TIMESERIES');
        iParamsToBeRemoved(iParam) = true;
        iParam = strcmpi(paramsName, 'PROFILE');
        iParamsToBeRemoved(iParam) = true;
        iParam = strcmpi(paramsName, 'TRAJECTORY');
        iParamsToBeRemoved(iParam) = true;
        iParam = strcmpi(paramsName, 'LATITUDE');
        iParamsToBeRemoved(iParam) = true;
        iParam = strcmpi(paramsName, 'LONGITUDE');
        iParamsToBeRemoved(iParam) = true;
        iParam = strcmpi(paramsName, 'NOMINAL_DEPTH');
        iParamsToBeRemoved(iParam) = true;
    end

    function iParamsToBeRemoved = removeUnwantedParamsFor2DvarVsDepth(paramsName, params2D)
        %REMOVEUNWANTEDPARAMSFOR2DVARVSDEPTH gets rid of unwanted parameters
        
        iParamsToBeRemoved = false(size(paramsName));
        
        % get only params that are 2D
        iParamsToBeRemoved(~params2D) = true;
        
        % we get rid of DEPTH, PRES and PRES_REL parameters
        iDEPTH = strcmpi('DEPTH', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        iDEPTH = strcmpi('PRES', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        iDEPTH = strcmpi('PRES_REL', paramsName);
        iParamsToBeRemoved(iDEPTH) = true;
        
        % we get rid of HEIGHT parameter
        iHEIGHT = strcmpi('HEIGHT', paramsName);
        iParamsToBeRemoved(iHEIGHT) = true;
        
        % we get rid of ADCP diagnostic parameters
        for i=1:4
            iStr = num2str(i);
            iABSI = strcmpi(['ABSI' iStr], paramsName);
            iParamsToBeRemoved(iABSI) = true;
            iABSIC = strcmpi(['ABSIC' iStr], paramsName);
            iParamsToBeRemoved(iABSIC) = true;
            iCORR = strcmpi(['CMAG' iStr], paramsName);
            iParamsToBeRemoved(iCORR) = true;
            iPERG = strcmpi(['PERG' iStr], paramsName);
            iParamsToBeRemoved(iPERG) = true;
        end
    end

    function openWikiPage(source, ev)
        %OPENWIKIPAGE opens a new tab in your web-browser to access the
        %IMOS-Toolbox wiki
        %
        url = 'https://github.com/aodn/imos-toolbox/wiki';
        stat = web(url, '-browser');
        if stat == 1
            fprintf('%s\n', 'Warning : Browser was not found.');
        elseif stat == 2
            fprintf('%s\n', 'Warning : Browser was found but could not be launched.');
        end
    end

%% Data update callback

    function updateCallback(sam)
        %UPDATECALLBACK Called when a data set has been modified. Saves the new
        % copy of the data set.
        %
        narginchk(1,1);
        if ~isstruct(sam),              error('sam must be a struct');         end
        if ~isfield(sam.meta, 'index'), error('sam must have an index field'); end
        
        % synchronise current data sets and sample_data
        sample_data{sam.meta.index} = sam;
        lenSam = length(sample_data);
        
        % regenerate descriptions
        sampleDataDescs = cell(lenSam, 1);
        for i = 1:lenSam
            sampleDataDescs{i} = genSampleDataDesc(sample_data{i});
        end
        
        set(sampleMenu,         'String', sampleDataDescs);
        set(extraSampleMenu,    'String', sampleDataDescs);
        
    end

%% Retrieving current selection

    function sam = getSelectedData()
        %GETSELECTEDDATA Returns the currently selected sample_data.
        %
        idx = get(sampleMenu, 'Value');
        
        sam = sample_data{idx};
    end

    function sam = getExtraSelectedData()
        %GETEXTRASELECTEDDATA Returns the currently selected extra sample_data.
        %
        idx = get(extraSampleMenu, 'Value');
        
        sam = sample_data{idx};
    end

    function graphType = getSelectedGraphType()
        %GETSELECTEDGRAPHTYPE Returns the currently selected graph type.
        %
        idx   = get(graphMenu, 'Value');
        types = get(graphMenu, 'String');
        
        graphType = types{idx};
        
    end

    function vars = getSelectedVars()
        %GETSELECTEDVARS Returns a vector containing the indices of the
        % variables which are selected.
        %
        
        % menu and checkboxes are stored in user data
        checkboxes = get(varPanel, 'UserData');
        
        vars = [];
        
        for m = 1:length(checkboxes)
            if get(checkboxes(m), 'Value'), vars(end+1) = m; end
        end
    end

%% Miscellaneous

    function createVarPanel(sam, vars)
        %CREATEVARPANEL Creates the variable selection panel. Called when the
        % selected dataset changes. The panel allows users to select which
        % variables should be displayed.
        %
        % delete checkboxes and dim menu from previous data set
        checkboxes = get(varPanel, 'Children');
        for m = 1:length(checkboxes), delete(checkboxes(m)); end
        
        switch mode
            case 'profile'
                % we don't want to plot TIME, PROFILE, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
                p = getVar(sam.variables, 'BOT_DEPTH');
                
                % we don't want to plot DEPTH if it's a variable
                iDepth = getVar(sam.variables, 'DEPTH');
                if iDepth ~= 0
                    sam.variables(iDepth) = [];
                end
            case 'timeSeries'
                % we don't want to plot TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, NOMINAL_DEPTH
                p = getVar(sam.variables, 'NOMINAL_DEPTH');
        end
        
        % create checkboxes for new data set. The order in which the checkboxes
        % are created is the same as the order of the variables - this is
        % important, as the getSelectedParams function assumes that the indices
        % line up.
        checkboxes(:) = [];
        n = length(sam.variables);
        for m = 1+p:n
            if isempty(vars)
                % enable at most 3 variables initially,
                % otherwise the graph will be cluttered
                val = 1;
                if m-p > 3, val = 0; end
            else
                if any(m-p == vars)
                    val = 1;
                else
                    val = 0;
                end
            end
            
            checkboxes(m-p) = uicontrol(...
                'Parent',           varPanel,...
                'Style',            'checkbox',...
                'String',           sam.variables{m}.name,...
                'TooltipString',    sprintf('%s\n(%s)', sam.variables{m}.long_name, sam.variables{m}.units),...
                'Value',            val,...
                'Callback',         @varPanelCallback,...
                'Units',            'normalized',...
                'Position',         posUi2(varPanel, n-p, 1, m-p, 1, 0),...
                'Tag',              ['checkbox' sam.variables{m}.name]);
        end
        
        % the checkboxes are saved in UserData field to make them
        % easy to retrieve in the getSelectedVars function
        set(varPanel, 'UserData', checkboxes);
    end

    function txt = customDcm(~, event_obj, sam, vars, graph, mode)
        % Customizes text of data tips
        switch mode
            case 'profile'
                % we don't want to plot TIME, PROFILE, DIRECTION, LATITUDE, LONGITUDE, BOT_DEPTH
                varOffset = getVar(sam.variables, 'BOT_DEPTH');
                dimLabel  = 'DEPTH';
                dimUnit   = ' m';
                dimFun    = @num2str;
                
            case 'timeSeries'
                % we don't want to plot TIMESERIES, PROFILE, TRAJECTORY, LATITUDE, LONGITUDE, NOMINAL_DEPTH
                varOffset = getVar(sam.variables, 'NOMINAL_DEPTH');
                dimLabel  = 'TIME';
                dimUnit   = ' UTC';
                dimFun    = @datestr;
        end
        
        % retrieve x/y click positions
        posClic = get(event_obj, 'Position');
        
        iDim = getVar(sam.dimensions, dimLabel);
        nRecord = length(sam.dimensions{iDim}.data);
        
        xLabel = get(get(gca, 'XLabel'), 'String');
        
        nVar = length(vars);
        switch graph
            case 'DepthProfile'
                txt = cell(1, nVar+1);
                % impossible to retrieve an exact TIME value, unfortunately
                % DataIndex doesn't make sense
                txt{1} = ['DEPTH: ' num2str(posClic(2)) ' m'];
                
                for iVar=1:nVar
                    iVarCorr  = vars(iVar)+varOffset;
                    varLabel  = sam.variables{iVarCorr}.name;
                    varUnit   = [' ' sam.variables{iVarCorr}.units];
                    
                    varData   = num2str(posClic(1));
                    
                    if ~isempty(strfind(xLabel, varLabel))
                        txt{iVar+1} = [varLabel ': ' varData varUnit];
                    end
                end
                
            case 'TimeSeries'
                txt = cell(1, nVar+1);
                txt{1} = [dimLabel ': ' dimFun(posClic(1)) dimUnit];
                
                for iVar=1:nVar
                    iVarCorr  = vars(iVar)+varOffset;
                    varLabel  = sam.variables{iVarCorr}.name;
                    varUnit   = [' ' sam.variables{iVarCorr}.units];
                    
                    nSample   = numel(sam.variables{iVarCorr}.data);
                    zInfo = '';
                    if strcmpi(get(gca, 'Tag'), 'axis1D') && nSample > nRecord
                        % we've clicked on a 1D plot and are dealing with 2D information
                        % we don't want to display
                        txt{iVar+1} = [];
                        continue;
                    else
                        nDim = length(sam.variables{iVarCorr}.dimensions);
                        if nDim == 1
                            % we've clicked on a 1D plot and are dealing with a 1D info
                            iSample = sam.dimensions{iDim}.data == posClic(1);
                        else
                            % we've clicked on a 2D plot and are dealing with a 2D info
                            iZ = sam.variables{iVarCorr}.dimensions(2);
                            nZ = length(sam.dimensions{iZ}.data);
                            iSample = repmat(sam.dimensions{iDim}.data == posClic(1), 1, nZ) & repmat((sam.dimensions{iZ}.data == posClic(2))', nRecord, 1);
                            
                            zLabel = sam.dimensions{iZ}.name;
                            zUnit  = [' ' sam.dimensions{iZ}.units];
                            zData  = num2str(posClic(2));
                            zInfo  = [' @' zLabel ': ' zData zUnit];
                        end
                    end
                    varData   = num2str(sam.variables{iVarCorr}.data(iSample));
                    
                    txt{iVar+1} = [varLabel ': ' varData varUnit zInfo];
                end
        end
        
        % clean up empty cells
        txt(cellfun(@isempty, txt)) = [];
    end

%%
    function onZoomIn(source, ev)
            z = zoom;
            z.Enable = 'on';
            z.Direction = 'in';
    end

    function onZoomOut(source, ev)
            z = zoom;
            z.Enable = 'on';
            z.Direction = 'out';
    end

end

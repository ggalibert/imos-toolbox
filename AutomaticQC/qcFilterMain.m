function sam = qcFilterMain(sam, filterName, auto, rawFlag, goodFlag, probGoodFlag, probBadFlag, badFlag, cancel)
%QCFILTERMAIN Runs the given data set through the given automatic QC filter and
% updates flags on sample_data structure.
%
% Inputs:
%   sam         - Cell array of sample data structs, containing the data
%                 over which the qc routines are to be executed.
%   filterName  - String name of the QC test to be applied.
%   auto        - Optional boolean argument. If true, the automatic QC
%                 process is executed automatically (interesting, that),
%                 i.e. with no user interaction.
%   rawFlag     - flag for non QC'd status.
%   goodFlag    - flag for good QC test status.
%   probGoodFlag- flag for probably good QC test status.
%   probBadFlag - flag for probably bad QC test status.
%   badFlag     - flag for bad QC test status.
%   cancel      - cancel QC app process integer code.
%
% Outputs:
%   sam         - Same as input, after QC routines have been run over it.
%                 Will be empty if the user cancelled/interrupted the QC
%                 process.
%
% Author:       Paul McCarthy <paul.mccarthy@csiro.au>
% Contributor:	Brad Morris <b.morris@unsw.edu.au>
%           	Guillaume Galibert <guillaume.galibert@utas.edu.au>
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
  % turn routine name into a function
  filter = str2func(filterName);
  
  % if this filter is a Set QC filter, we pass the entire data set
  if ~isempty(regexp(filterName, 'SetQC$', 'start'))
    
    [fsam, fvar, flog] = filter(sam, auto);
    if isempty(fvar), return; end
    
    % Currently only flags are copied across; other changes to the data set
    % are discarded. Flags are overwritten - if a later routine flags 
    % the same value as a previous routine with a higher flag, the previous
    % flag is overwritten by the latter.
    type{1} = 'dimensions';
    type{2} = 'variables';
    for m = 1:length(type)
        for k = 1:length(sam.(type{m}))
            
            if all(~strcmpi(sam.(type{m}){k}.name, fvar)), continue; end
            
            initFlags = sam.(type{m}){k}.flags;
            
            % Look for the current test flags provided
            goodIdx     = fsam.(type{m}){k}.flags == goodFlag;
            probGoodIdx = fsam.(type{m}){k}.flags == probGoodFlag;
            probBadIdx  = fsam.(type{m}){k}.flags == probBadFlag;
            badIdx      = fsam.(type{m}){k}.flags == badFlag;
            
            if ~strcmpi(func2str(filter), 'imosHistoricalManualSetQC') % imosHistoricalManualSetQC can downgrade flags
                % otherwise we can only upgrade flags
                % set current flag areas
                canBeFlagGoodIdx     =                        sam.(type{m}){k}.flags == rawFlag;
                canBeFlagProbGoodIdx = canBeFlagGoodIdx     | sam.(type{m}){k}.flags == goodFlag;
                canBeFlagProbBadIdx  = canBeFlagProbGoodIdx | sam.(type{m}){k}.flags == probGoodFlag;
                canBeFlagBadIdx      = canBeFlagProbBadIdx  | sam.(type{m}){k}.flags == probBadFlag;
            
                % update new flags in current variable
                goodIdx     = canBeFlagGoodIdx & goodIdx;
                probGoodIdx = canBeFlagProbGoodIdx & probGoodIdx;
                probBadIdx  = canBeFlagProbBadIdx & probBadIdx;
                badIdx      = canBeFlagBadIdx & badIdx;        
            end
            
            % call the sub fuction to add the results of the failed tests
            % into a new variable
            addFailedTestsFlags()     
            
            sam.(type{m}){k}.flags(goodIdx)     = fsam.(type{m}){k}.flags(goodIdx);
            sam.(type{m}){k}.flags(probGoodIdx) = fsam.(type{m}){k}.flags(probGoodIdx);
            sam.(type{m}){k}.flags(probBadIdx)  = fsam.(type{m}){k}.flags(probBadIdx);
            sam.(type{m}){k}.flags(badIdx)      = fsam.(type{m}){k}.flags(badIdx);
            
            % update ancillary variable attribute comment
            if isfield(fsam.(type{m}){k}, 'ancillary_comment')
                sam.(type{m}){k}.ancillary_comment = fsam.(type{m}){k}.ancillary_comment;
            end
            
            % add a log entry
            qcSet    = str2double(readProperty('toolbox.qc_set'));
                
            uFlags = unique(fsam.(type{m}){k}.flags);
            % we're just keeping trace of flags given other than 0 or 1
            % (has failed the test)
            uFlags(uFlags == rawFlag) = [];
            uFlags(uFlags == goodFlag) = [];
            
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).procDetails = flog;
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).nFlag = 0;
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).codeFlag = [];
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).stringFlag = [];
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).HEXcolor = reshape(dec2hex(round(255*imosQCFlag(imosQCFlag('good',  qcSet, 'flag'),  qcSet, 'color')))', 1, 6);
                
            if isempty(uFlags) && ~strcmpi(filterName, 'imosHistoricalManualSetQC') % we don't want manual QC to log when no fail
                sam.meta.log{end+1} = [filterName '(' flog ')' ...
                        ' did not fail on any ' ...
                        sam.(type{m}){k}.name ' sample.'];
            else
                for i=1:length(uFlags)
                    flagString = imosQCFlag(uFlags(i),  qcSet, 'desc');
                    
                    flagIdxI = fsam.(type{m}){k}.flags == uFlags(i);
                    canBeFlagIdx = initFlags < uFlags(i);
                    flagIdxI = canBeFlagIdx & flagIdxI;
                    nFlag = sum(sum(flagIdxI));
                
                    if nFlag == 0
                        if ~strcmpi(filterName, 'imosHistoricalManualSetQC') % we don't want manual QC to log when no fail
                            sam.meta.log{end+1} = [filterName '(' flog ')' ...
                                ' did not fail on any ' ...
                                sam.(type{m}){k}.name ' sample.'];
                        end
                    else
                        if strcmpi(filterName, 'imosHistoricalManualSetQC')
                            tmpFilterName = 'Author manually';
                        else
                            tmpFilterName = [filterName '(' flog ')'];
                        end
                        sam.meta.log{end+1} = [tmpFilterName ...
                            ' flagged ' num2str(nFlag) ' ' ...
                            sam.(type{m}){k}.name ' samples with flag ' flagString '.'];
                        
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).nFlag = nFlag;
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).codeFlag = uFlags(i);
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).stringFlag = flagString;
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).HEXcolor = reshape(dec2hex(round(255*imosQCFlag(uFlags(i),  qcSet, 'color')))', 1, 6);
                    end
                end
            end
%             disp(sam.meta.log{end});
        end
    end
  
  % otherwise we pass dimensions/variables one at a time
  else
    % check dimensions first, then variables
    type{1} = 'dimensions';
    type{2} = 'variables';
    for m = 1:length(type)
        for k = 1:length(sam.(type{m}))
            
            data  = sam.(type{m}){k}.data;
            if ~isfield(sam.(type{m}){k}, 'flags'), continue; end
            flags = sam.(type{m}){k}.flags;
            initFlags = flags;
            
            % user cancelled
            if ~isempty(cancel) && getappdata(cancel, 'cancel'), return; end
           
            if contains(filterName,'TimeSeriesSpikeQC')
              varname = sam.(type{m}){k}.name;
              if ~exist('varflags','var')
                [varflags, varlogs] = filter(sam, auto);
              end
              processed_vars = fieldnames(varflags);
              if inCell(processed_vars,varname)
                f = varflags.(varname);
                l = varlogs.(varname);
              else
                continue;
              end
            else
              % log entries and any data changes that the routine generates
              % are currently discarded; only the flags are retained.
              [~, f, l] = filter(sam, data, k, type{m}, auto);
            end
            
            if isempty(f), continue; end
            
            % Flags are overwritten
            % Set current flag areas
            canBeFlagGoodIdx      = flags == rawFlag;
            
            canBeFlagProbGoodIdx  = canBeFlagGoodIdx | ...
                flags == goodFlag;
            
            canBeFlagProbBadIdx   = canBeFlagProbGoodIdx | ...
                flags == probGoodFlag;
            
            canBeFlagBadIdx       = canBeFlagProbBadIdx | ...
                flags == probBadFlag;
            
            % Look for the current test flags provided
            goodIdx     = f == goodFlag;
            probGoodIdx = f == probGoodFlag;
            probBadIdx  = f == probBadFlag;
            badIdx      = f == badFlag;
            
            % call the sub fuction to add the results of the failed tests
            % into a new variable
            addFailedTestsFlags() 
            
            % update new flags in current variable
            goodIdx     = canBeFlagGoodIdx & goodIdx;
            probGoodIdx = canBeFlagProbGoodIdx & probGoodIdx;
            probBadIdx  = canBeFlagProbBadIdx & probBadIdx;
            badIdx      = canBeFlagBadIdx & badIdx;
            clear canBeFlagGoodIdx canBeFlagProbGoodIdx canBeFlagProbBadIdx canBeFlagBadIdx
            
            flags(goodIdx)     = f(goodIdx);
            flags(probGoodIdx) = f(probGoodIdx);
            flags(probBadIdx)  = f(probBadIdx);
            flags(badIdx)      = f(badIdx);
            clear goodIdx probGoodIdx probBadIdx badIdx
            
            sam.(type{m}){k}.flags = flags;
            clear flags
            
            % add a log entry
            qcSet    = str2double(readProperty('toolbox.qc_set'));
            % update count (for log entry)
            uFlags = unique(f)+1; % +1 because uFlags can be 0 and will then be used as an index
            % we're just keeping trace of flags given other than 0 or 1
            uFlags(uFlags-1 == rawFlag) = [];
            uFlags(uFlags-1 == goodFlag) = [];
            
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).procDetails = l;
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).nFlag = 0;
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).codeFlag = [];
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).stringFlag = [];
            sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).HEXcolor = reshape(dec2hex(round(255*imosQCFlag(imosQCFlag('good',  qcSet, 'flag'),  qcSet, 'color')))', 1, 6);
            
            if isempty(uFlags)
                sam.meta.log{end+1} = [filterName '(' l ')' ...
                        ' did not fail on any ' ...
                        sam.(type{m}){k}.name ' sample.'];
            else
                for i=1:length(uFlags)
                    flagString = imosQCFlag(uFlags(i)-1,  qcSet, 'desc');
                    uFlagIdx = f == uFlags(i)-1;
                    canBeFlagIdx = initFlags < uFlags(i)-1;
                    uFlagIdx = canBeFlagIdx & uFlagIdx;
                    nFlag = sum(sum(sum(uFlagIdx)));
                    
                    if nFlag == 0
                        sam.meta.log{end+1} = [filterName '(' l ')' ...
                            ' did not fail on any ' ...
                            sam.(type{m}){k}.name ' sample.'];
                    else
                        sam.meta.log{end+1} = [filterName '(' l ')' ...
                            ' flagged ' num2str(nFlag) ' ' ...
                            sam.(type{m}){k}.name ' samples with flag ' flagString '.'];
                        
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).nFlag = nFlag;
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).codeFlag = uFlags(i)-1;
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).stringFlag = flagString;
                        sam.meta.QCres.(filterName).(sam.(type{m}){k}.name).HEXcolor = reshape(dec2hex(round(255*imosQCFlag(uFlags(i)-1,  qcSet, 'color')))', 1, 6);
                    end
                end
            end
%             disp(sam.meta.log{end});
        end
    end
  end
  
    function addFailedTestsFlags()
        % addFailedTestsFlags inherits all the variable available in the
        % workspace. 
        %
        % we now have for the test filterName the result (good, probgood, probBad, bad) value for each variable and each datapoint.
        % For most QC routines, a failed test is where data is not flagged
        % as good.
        % However, more information is available on
        % https://github.com/aodn/imos-toolbox/wiki/QCProcedures 
        %
        % This function aims to store, in a new variable named "failed_tests"
        % the result of why a data point wasn't flagged as good, i.e. which 
        % QC routine was responsible for "rejecting" a data point.
        %
        % To do so, each failed QC routine is linked to the power of 2 of
        % an integer. 
        % For example: 
        % manualQC is linked to 2^1
        % imosCorrMagVelocitySetQC is linked to 2^2
        % ...
        % Any integer can be written as the sum of disting powers of 2
        % numbers (see various proofs online
        % https://math.stackexchange.com/questions/176678/strong-induction-proof-every-natural-number-sum-of-distinct-powers-of-2)
        %
        %
        % Note that QC tests can be rerun by the user multiple times. This
        % however should be dealt in the FlowManager/displayManager.m
        % function
        %
        %
        % the failed tests depends on the test. It is not always the same
        % for all. See table for each individual test at
        % https://github.com/aodn/imos-toolbox/wiki/QCProcedures
        if strcmp(filterName, 'imosTiltVelocitySetQC')  % see https://github.com/aodn/imos-toolbox/wiki/QCProcedures#adcp-tilt-test---imostiltvelocitysetqc---compulsory
            % For the imosTiltVelocitySetQC, users would like to know if the
            % failed test is because the data was flagged as bad or as probably
            % good
            % this test (imosTiltVelocitySetQC)
            % there is a two level flag for failed tests. We're taking this
            % into account below
            failedTestsIdx_probGood = probGoodIdx;
            failedTestsIdx_bad = badIdx;
        elseif strcmp(filterName, 'imosErrorVelocitySetQC') % see https://github.com/aodn/imos-toolbox/wiki/QCProcedures#adcp-error-velocity-test---imoserrorvelocitysetqc---optional
            % for this specific QC routine, a test is considerer to be pass 
            % if the data is flagged good or probably good if ECUR is NaN
            
            % find variable index for ECUR
            notdone = true;
            while notdone
                for kk = 1:length(sam.(type{m}))
                    if strcmp(sam.(type{m}){kk}.name, 'ECUR')
                        notdone = false;
                        break                        
                    end
                end
            end
            
            if not(notdone)
                if all(isnan(sam.(type{m}){kk}.data(:)))
                    failedTestsIdx = badIdx | probBadIdx;
                else
                    failedTestsIdx = badIdx | probBadIdx | probGoodIdx ;
                end
            end                            
            
        else
            failedTestsIdx = probGoodIdx | probBadIdx | badIdx; % result matrice for all variables
        end
        
        
        if strcmp(filterName, 'imosTiltVelocitySetQC')
            failedTests_probGood = zeros(size(failedTestsIdx_probGood));
            failedTests_probGood(logical(failedTestsIdx_probGood)) = imosQCTest(strcat(filterName, '_probably_good'));
            failedTests_probGood = int32(failedTests_probGood);
            
            failedTests_bad = zeros(size(failedTestsIdx_bad));
            failedTests_bad(logical(failedTestsIdx_bad)) = imosQCTest(strcat(filterName, '_bad'));
            failedTests_bad = int32(failedTests_bad);
            
            if ~isfield(sam.(type{m}){k}, 'failed_tests')  % if the flat_tests field does not exist yet
                                                sam.(type{m}){k}.failed_tests = failedTests_bad + failedTests_probGood;
                                
            else                
                sam.(type{m}){k}.failed_tests = sam.(type{m}){k}.failed_tests + failedTests_bad + failedTests_probGood;
            end
        else

            failedTests = zeros(size(failedTestsIdx));
            if strcmp(filterName, 'imosHistoricalManualSetQC')
                failedTests(logical(failedTestsIdx)) = imosQCTest('userManualQC');  % we replace imosHistoricalManualSetQC with userManualQC so that we only have 1 flag_value/flag_meaning combo in the NetCDF for something very similar in the end
            else                
                failedTests(logical(failedTestsIdx)) = imosQCTest(filterName);
            end
            failedTests = int32(failedTests);
            
            if ~isfield(sam.(type{m}){k},'failed_tests')  % if the flat_tests field does not exist yet
                sam.(type{m}){k}.failed_tests = failedTests;
            else 
                % if it already exists, we sum the previous array with the new one                
                sam.(type{m}){k}.failed_tests = sam.(type{m}){k}.failed_tests + failedTests;

             
            end
        end
    end
end
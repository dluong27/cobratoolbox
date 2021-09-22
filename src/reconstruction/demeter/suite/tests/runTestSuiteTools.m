function [testResultsFolder,curationReport] = runTestSuiteTools(refinedFolder, infoFilePath, inputDataFolder, reconVersion, varargin)
% This function initialzes the test suite on all reconstructions in
% that should be refined through DEMETER.
%
% USAGE:
%
%    testResultsFolder = runTestSuiteTools(refinedFolder, infoFilePath, inputDataFolder, reconVersion, varargin)
%
%
% REQUIRED INPUTS
% refinedFolder             Folder with refined COBRA models generated by the
%                           refinement pipeline
% infoFilePath              File with information on reconstructions to refine
% inputDataFolder           Folder with experimental data and database files to
% reconVersion              Name of the refined reconstruction resource
%
% OPTIONAL INPUTS
% testResultsFolder         Folder where the test results are saved
% numWorkers                Number of workers in parallel pool (default: 2)
% createReports             Boolean defining if a report for each
%                           reconstruction should be created (default: false).
% reportsFolder             Folder where reports should be saved
% translatedDraftsFolder    Folder with  translated draft COBRA models generated by KBase
%                           pipeline to analyze (will only be analyzed if
%                           folder is provided)
% OUTPUTS
% testResultsFolder         Folder where the test results are saved
% curationReport            Summary of results of QA/QC tests
%
% .. Authors:
%       - Almut Heinken, 09/2020

% Define default input parameters if not specified
parser = inputParser();
parser.addRequired('refinedFolder', @ischar);
parser.addRequired('infoFilePath', @ischar);
parser.addRequired('inputDataFolder', @ischar);
parser.addRequired('reconVersion', @ischar);
parser.addParameter('testResultsFolder', [pwd filesep 'TestResults'], @ischar);
parser.addParameter('numWorkers', 2, @isnumeric);
parser.addParameter('createReports', false, @islogical);
parser.addParameter('reportsFolder', '', @ischar);
parser.addParameter('translatedDraftsFolder', '', @ischar);

parser.parse(refinedFolder, infoFilePath, inputDataFolder, reconVersion, varargin{:});

refinedFolder = parser.Results.refinedFolder;
testResultsFolder = parser.Results.testResultsFolder;
infoFilePath = parser.Results.infoFilePath;
inputDataFolder = parser.Results.inputDataFolder;
numWorkers = parser.Results.numWorkers;
reconVersion = parser.Results.reconVersion;
createReports = parser.Results.createReports;
reportsFolder = parser.Results.reportsFolder;
translatedDraftsFolder = parser.Results.translatedDraftsFolder;

currentDir=pwd;
mkdir(testResultsFolder)

%% run test suite
if ~isempty(translatedDraftsFolder)
    % plot growth for both draft and refined
    notGrowing = plotBiomassTestResults(refinedFolder,reconVersion,'translatedDraftsFolder',translatedDraftsFolder,'testResultsFolder',testResultsFolder, 'numWorkers', numWorkers);

    % plot ATP production for both draft and refined
    tooHighATP = plotATPTestResults(refinedFolder,reconVersion,'translatedDraftsFolder',translatedDraftsFolder,'testResultsFolder',testResultsFolder, 'numWorkers', numWorkers);

    % Draft reconstructions
    mkdir([testResultsFolder filesep reconVersion '_draft'])
    batchTestAllReconstructionFunctions(translatedDraftsFolder,[testResultsFolder filesep reconVersion '_draft'],inputDataFolder,reconVersion,numWorkers);   plotTestSuiteResults([testResultsFolder filesep reconVersion '_draft'],reconVersion);
else
      % plot growth only for refined
    notGrowing = plotBiomassTestResults(refinedFolder,reconVersion,'testResultsFolder',testResultsFolder, 'numWorkers', numWorkers);

    % plot ATP production only for refined
    tooHighATP = plotATPTestResults(refinedFolder,reconVersion,'testResultsFolder',testResultsFolder, 'numWorkers', numWorkers);
end

% Refined reconstructions
mkdir([testResultsFolder filesep reconVersion '_refined'])
batchTestAllReconstructionFunctions(refinedFolder,[testResultsFolder filesep reconVersion '_refined'],inputDataFolder,reconVersion,numWorkers);
plotTestSuiteResults([testResultsFolder filesep reconVersion '_refined'],reconVersion);

%% prepare a report of the QA/QC status of the models

curationReport = printRefinementReport(testResultsFolder,reconVersion);

%% Give an individual report of each reconstruction if desired.
% Note: this is time-consuming.
% Requires LaTeX and pdflatex installation (e.g., MiKTex package)

% automatically create reports if there are less than ten organisms
dInfo = dir(refinedFolder);
modelList={dInfo.name};
modelList=modelList';
modelList(~contains(modelList(:,1),'.mat'),:)=[];

if size(modelList) < 10
    createReports=true;
end

if createReports
    
    if isempty(reportsFolder)
        mkdir('modelReports')
        reportsFolder=[pwd filesep 'modelReports' filesep];
    end
    
    cd(reportsFolder)
    if ~isempty(infoFilePath)
        infoFile = readtable(infoFilePath, 'ReadVariableNames', false, 'Delimiter', 'tab');
        infoFile = table2cell(infoFile);
        
        dInfo = dir(refinedFolder);
        modelList={dInfo.name};
        modelList=modelList';
        modelList(~contains(modelList(:,1),'.mat'),:)=[];
        
        ncbiCol=find(strcmp(infoFile(1,:),'NCBI Taxonomy ID'));
        if isempty(ncbiCol)
            warning('No NCBI Taxonomy IDs provided. This section in the report will be skipped.')
        end
        
        for i = 1:length(modelList)
            model=readCbModel([refinedFolder filesep modelList{i}]);
            biomassReaction = model.rxns{strncmp('bio', model.rxns, 3)};
            if ~isempty(ncbiCol)
                ncbiID = infoFile(find(strcmp(infoFile(:,1),strrep(modelList{i},'.mat',''))),ncbiCol);
            else
                ncbiID='';
            end
            [outputFile] = reportPDF(model, strrep(modelList{i},'.mat',''), biomassReaction, inputDataFolder, reportsFolder, ncbiID);
        end
    else
        warning('No organism information provided. Report generation skipped.')
    end
end

cd(currentDir)

end

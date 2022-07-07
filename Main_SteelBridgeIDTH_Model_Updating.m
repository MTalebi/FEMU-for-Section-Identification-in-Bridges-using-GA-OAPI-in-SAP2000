%% clean-up the workspace & command window
clear all;clc;close all;
% Author:
% Mohammad Talebi Kalaleh
% talebika@ualberta.ca
%% inputs
[ModelName,ModelDirectory,~] = uigetfile({'*.sdb'},'Select a <.sdb> SAP 23 File in folder for Updating'); 
[~,MeasuredDirectory,~] = uigetfile({'*.txt'},'Select a <.txt> File in folder for Measured Acc'); %time_col acc_point1_col acc_point2_col , ...
ProgramPath = "C:\Program Files\Computers and Structures\SAP2000 23\SAP2000.exe";
APIDLLPath = "C:\Program Files\Computers and Structures\SAP2000 23\SAP2000v1.dll";

Output_Sensor_Joints='Sensor_Points';

TH_LoadCase_Name='RHA Moveing Load';
UseAllDimsInAutoListMembers='Yes';%'Yes' or 'No'
InitialDimsChangeRangeLB=-1; %with respect to Initial Sections
InitialDimsChangeRangeUB=+1; %with respect to Initial Sections


%Notes Format in Model For BEAMs
% FlangeWidth=[25,30,35]
% FlangeThickness=[1,1.5,2,2.5]
% WebHeight=[85,90,95,100]
% WebThickness=[0.6,0.8,1]
%% create API helper object, attach to a running instance of SAP & create SapModel object
a = NET.addAssembly(APIDLLPath);
helper = SAP2000v1.Helper;
helper = NET.explicitCast(helper,'SAP2000v1.cHelper');

SapObject = helper.GetObject('CSI.SAP2000.API.SapObject');
SapObject = NET.explicitCast(SapObject,'SAP2000v1.cOAPI');

helper = 0;
SapModel = NET.explicitCast(SapObject.SapModel,'SAP2000v1.cSapModel');

%% sap_etabs function generation for all interfaces
File = NET.explicitCast(SapModel.File,'SAP2000v1.cFile'); %Methods: OpenFile, Save  
LoadPatterns = NET.explicitCast(SapModel.LoadPatterns,'SAP2000v1.cLoadPatterns'); %Methods: Add, GetNameList, GetLoadType, GetAutoSeismicCode

Analyze=NET.explicitCast(SapModel.Analyze,'SAP2000v1.cAnalyze'); %Methods: RunAnalysis, SetRunCaseFlag, GetCaseStatus, GetRunCaseFlag
FrameObj=NET.explicitCast(SapModel.FrameObj,'SAP2000v1.cFrameObj'); %Methods: Count, GetLabelNameList, SetSection, GetSection, GetLabelFromName, GetNameListOnStory, GetDesignProcedure, GetPoints

PointObj=NET.explicitCast(SapModel.PointObj,'SAP2000v1.cPointObj'); %Methods: GetCoordCartesian, GetConnectivity
LoadCases=NET.explicitCast(SapModel.LoadCases,'SAP2000v1.cLoadCases'); %Methods: GetNameList, GetTypeOAPI_1, 
PropArea=NET.explicitCast(SapModel.PropArea,'SAP2000v1.cPropArea'); %Methods: Count, GetWall, GetNameList, SetWall, 
PropFrame=NET.explicitCast(SapModel.PropFrame,'SAP2000v1.cPropFrame'); %Methods: Count, GetAllFrameProperties, GetNameList, GetRebarColumn, SetISection, SetPipe, SetRectangle, SetRebarColumn, SetRebarBeam, SetTube, 
Group=NET.explicitCast(SapModel.GroupDef,'SAP2000v1.cGroup'); %Methods: GetNameList, GetAssignments, GetGroup 

AnalysisResults=NET.explicitCast(SapModel.Results,'SAP2000v1.cAnalysisResults'); %Methods: BaseReact, BaseReactWithCentroid, GeneralizedDispl, JointDrifts, ModalParticipatingMassRatios, ModalPeriod, StoryDrifts
AnalysisResultsSetup=NET.explicitCast(AnalysisResults.Setup,'SAP2000v1.cAnalysisResultsSetup'); %Methods: GetComboSelectedForOutput, SetCaseSelectedForOutput, SetComboSelectedForOutput, SetOptionModeShape
AreaObj=NET.explicitCast(SapModel.AreaObj,'SAP2000v1.cAreaObj'); %Methods: Count, GetLabelNameList, GetNameFromLabel, GetNameListOnStory, GetPier, GetRebarDataPier, GetRebarDataSpandrel, SetDiaphragm, SetLoadUniformToFrame, SetLoadUniform, SetModifiers, 
DirHistLinear=NET.explicitCast(LoadCases.DirHistLinear,'SAP2000v1.cCaseDirectHistoryLinear');
ModHistLinear=NET.explicitCast(LoadCases.ModHistLinear,'SAP2000v1.cCaseModalHistoryLinear');

ModalEigen = NET.explicitCast(LoadCases.ModalEigen,'SAP2000v1.cCaseModalEigen');
Select=NET.explicitCast(SapModel.SelectObj,'SAP2000v1.cSelect'); %Methods: All, Group, PreviousSelection, ClearSelection
%% Save As Model for Identification
ModelSaveAsPath = strcat(ModelDirectory,'Identified_', ModelName);
File.Save(ModelSaveAsPath);
SapModel.SetModelIsLocked(false);
SapModel.SetPresentUnits(SAP2000v1.eUnits.kgf_cm_C);

%% get frame names from model for each group of design
%get all beams tobe designed
[~,~,a]=FrameObj.GetNameList(0,cellstr(''));
Element_Name_GroupName(:,1)=cell(a)';
clear a

%% set groups of design
%assined autoselect for each frame
for i=1:size(Element_Name_GroupName,1)
    [~,a]=FrameObj.GetSection(cell2mat(Element_Name_GroupName(i,1)),'',''); %all elements must be assigned to autoselect
    Element_Name_GroupName(i,2)=cellstr(char(a));
    
end
Element_Name_GroupName=sortrows(Element_Name_GroupName,2);

%Number of all autoselect names assigned to frames
Count_Optimization_Groups=1;
Autoselect_List_Names(1,1)=Element_Name_GroupName(1,2);

for i=2:size(Element_Name_GroupName,1)
    if ~strcmp(Element_Name_GroupName(i,2),Autoselect_List_Names(Count_Optimization_Groups,1))
        Count_Optimization_Groups=Count_Optimization_Groups+1;
        Autoselect_List_Names(Count_Optimization_Groups,1)=Element_Name_GroupName(i,2);

    end
end


%% assign to be optimized frames to a group 

for i=1:Count_Optimization_Groups
    
    Group.SetGroup(Autoselect_List_Names{i,1});
    Frames_In_Group_Index=find(strcmp(Element_Name_GroupName(:,2),Autoselect_List_Names(i,1)));
    for j=1:size(Frames_In_Group_Index,1)
        FrameObj.SetGroupAssign(Element_Name_GroupName{Frames_In_Group_Index(j,1),1},Autoselect_List_Names{i,1});

    end
end

%% get frame section groups from auto select lists and Initial Section assigend to The Frames for starting optimization (X0)
Autoselect_Name_Sections=struct;
for i=1:size(Autoselect_List_Names,1)
    [~,~,MatPropSTL,hw,bf,tf,tw,~,~,~,Notes] = PropFrame.GetISection(Autoselect_List_Names{i,1},'','',0,0,0,0,0,0,0,'','');
    MatPropSTL=char(MatPropSTL);Notes=char(Notes);
    Notes=splitlines(Notes); 
    eval([Notes{1,1},';']); eval([Notes{2,1},';']); eval([Notes{3,1},';']); eval([Notes{4,1},';']);
    
    Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).FlangeWidth=FlangeWidth;
    Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).FlangeThickness=FlangeThickness;
    Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).WebHeight=WebHeight;
    Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).WebThickness=WebThickness;
    Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).MatPropSTL=MatPropSTL;
    
    Group_UperBand(1,4*i-3:4*i)=[size(FlangeWidth,2),size(FlangeThickness,2),size(WebHeight,2),size(WebThickness,2)];

    Group_Initial_Section_Number(1,4*i-3:4*i)=[find(FlangeWidth==bf),find(FlangeThickness==tf),find(WebHeight==hw),find(WebThickness==tw)];

end


%% Nvariables lowerband and upperband and initial x
nvars=Count_Optimization_Groups*4;

x0=Group_Initial_Section_Number;

if strcmp(UseAllDimsInAutoListMembers,'Yes')
    lb=ones(1,nvars);
    ub=Group_UperBand;
    
else
    lb=x0+InitialDimsChangeRangeLB;
    lb(lb<=0)=1;
    
    ub=x0+InitialDimsChangeRangeUB;  
    
    for i=1:nvars
        if ub(1,i)>Group_UperBand(1,i)
            ub(1,i)=Group_UperBand(1,i);
        end
    end
end

IntCon=1:nvars;% all variables are integer

%% load case for analysis and result
AnalysisResultsSetup.DeselectAllCasesAndCombosForOutput;
AnalysisResultsSetup.SetCaseSelectedForOutput(TH_LoadCase_Name);
AnalysisResultsSetup.SetOptionDirectHist(2);
AnalysisResultsSetup.SetOptionModalHist(2);

[~,~,Load_Case_Names]=LoadCases.GetNameList_1(0,cellstr(''));
Load_Case_Names=cell(Load_Case_Names)';
for i=1:size(Load_Case_Names,1)
    Analyze.SetRunCaseFlag(Load_Case_Names{i,1},false);
end
Analyze.SetRunCaseFlag(TH_LoadCase_Name,true);
Analyze.SetRunCaseFlag('MODAL',true);

%% Measured Accs for Sensor Points?
%sensor points in Sap2000 model must be assigned to group Output_Sensor_Joints
[~,~,~,Sensor_Points]=Group.GetAssignments(Output_Sensor_Joints,0,1,cellstr(''));
Sensor_Points=cell(Sensor_Points)';
for i=1:size(Sensor_Points,1)
    acc=dlmread([MeasuredDirectory,'Point',char(Sensor_Points(i,1)),'.txt']);
    Acc_Measured_Time.(['Point',char(Sensor_Points(i,1))])=acc;

end

%% optimization
tic
% GA

fun=@(x) Objective_Fun(x,Autoselect_Name_Sections,Autoselect_List_Names,Output_Sensor_Joints,Sensor_Points,Acc_Measured_Time,PropFrame,Analyze,AnalysisResults,SapModel);
options=optimoptions('ga','InitialPopulationMatrix',x0,'MaxGenerations',10,'PopulationSize',10,'ConstraintTolerance',1e-6,'PlotFcn', @gaplotbestf,'Display','iter');
x_min=ga(fun,nvars,[],[],[],[],lb,ub,[],IntCon,options);
%xmin=[2 3 2 2]
ResponseEstimationError=fun(x_min)
RunTime=toc

%% Compare Results plot
[~,~,~,Point_Names,~,~,Time_Result,~,~,ACC_Z,~,~,~]=AnalysisResults.JointAcc(Output_Sensor_Joints,SAP2000v1.eItemTypeElm.GroupElm,0,cellstr(''),cellstr(''),cellstr(''),cellstr(''),0,0,0,0,0,0,0);
Point_Names=cell(Point_Names)'; Time_Result=double(Time_Result)';ACC_Z=double(ACC_Z)';
for i=1:size(Sensor_Points,1)
    indix_Result_Point=find(strcmp(Point_Names(:,1),Sensor_Points(i,1)));
    Acc_Model_Time.(['Point',char(Sensor_Points(i,1))])=[Time_Result(indix_Result_Point,1),ACC_Z(indix_Result_Point,1)];
end
 
for i=1:size(Sensor_Points,1)
    acc_model=Acc_Model_Time.(['Point',char(Sensor_Points(i,1))]);
    acc_measured=Acc_Measured_Time.(['Point',char(Sensor_Points(i,1))]);

    figure;
    plot(acc_measured(:,1),acc_measured(:,2),'-','color','r','DisplayName','Measured');hold on; grid on;
    plot(acc_model(:,1),acc_model(:,2),'--','color','b','DisplayName','SAPEstimated'); hold off;
    title(['Z Acc for Sensor Point Number ',Sensor_Points{i,1}]);
    legend; xlabel('Time (sec)'); ylabel('Acc (cm/s^2)')

end


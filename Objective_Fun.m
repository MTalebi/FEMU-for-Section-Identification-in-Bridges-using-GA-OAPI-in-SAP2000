function [Cost]=Objective_Fun(x,Autoselect_Name_Sections,Autoselect_List_Names,Output_Sensor_Joints,Sensor_Points,Acc_Measured_Time,PropFrame,Analyze,AnalysisResults,SapModel)
    SapModel.SetModelIsLocked(false);
    
    for i=1:size(x,2)/4
        bf=Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).FlangeWidth(1,x(4*i-3));
        tf=Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).FlangeThickness(1,x(4*i-2));
        hw=Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).WebHeight(1,x(4*i-1));
        tw=Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).WebThickness(1,x(4*i));
        
        MatPropSTL=Autoselect_Name_Sections.(Autoselect_List_Names{i,1}).MatPropSTL;
        PropFrame.SetISection(Autoselect_List_Names{i,1},MatPropSTL,hw,bf,tf,tw,bf,tf,-1,'','');

    end


    Analyze.RunAnalysis;
    
    [~,~,~,Point_Names,~,~,Time_Result,~,~,ACC_Z,~,~,~]=AnalysisResults.JointAcc(Output_Sensor_Joints,SAP2000v1.eItemTypeElm.GroupElm,0,cellstr(''),cellstr(''),cellstr(''),cellstr(''),0,0,0,0,0,0,0);
    Point_Names=cell(Point_Names)'; Time_Result=double(Time_Result)';ACC_Z=double(ACC_Z)';
    for i=1:size(Sensor_Points,1)
        indix_Result_Point=find(strcmp(Point_Names(:,1),Sensor_Points(i,1)));
        Acc_Model_Time.(['Point',char(Sensor_Points(i,1))])=[Time_Result(indix_Result_Point,1),ACC_Z(indix_Result_Point,1)];
    end
    %cost calc
    Cost=0;
    for i=1:size(Sensor_Points,1)
        acc_model=Acc_Model_Time.(['Point',char(Sensor_Points(i,1))]);
        acc_measured=Acc_Measured_Time.(['Point',char(Sensor_Points(i,1))]);
        
        acc_measured_downsampled=interp1(acc_measured(:,1),acc_measured(:,2),acc_model(:,1)); %Analysis time steps could be arbitrary
        Cost=Cost+norm(acc_measured_downsampled-acc_model(:,2));
        
        
    end
    Cost=Cost/size(Sensor_Points,1)/size(acc_measured_downsampled,1)*100;
    
end
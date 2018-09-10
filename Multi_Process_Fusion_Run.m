function [precision,recall,truePositive,falsePositive,worstIDCounter] = Multi_Process_Fusion_Run(varargin)

%Single CNN-D observation (using distance between max activations)
%--------------------------------------------------
%---    This code performs place recognition,   ---
%---    not SLAM - an initial traverse of the   ---
%---    dataset is performed before place       ---
%---    recognition is performed.               ---
%--------------------------------------------------

%Define global variables
global totalImagesR
global totalImagesQ
global Template_count
global Template_plot
% global imcounter_R
% global Imcounter_Q
% global Imstart_R
% global Imstart_Q
% global finalIndex_R         %Nordland only
% global finalIndex_Q         %Nordland only

%Process function inputs
if nargin == 22   
    Video_option = varargin{1};
    Ref_folder = varargin{2};
    Ref_file_type = varargin{3};
    Query_folder = varargin{4};
    Query_file_type = varargin{5};
    Imstart_Q = varargin{6};
    Imstart_R = varargin{7};
    Frame_skip = varargin{8};
    net = varargin{9};
    actLayer = varargin{10};
    SAD_resolution = varargin{11};
    SAD_patchSize = varargin{12};
    HOG_resolution = varargin{13};
    HOG_cellSize = varargin{14};
    Initial_crop = varargin{15};
    Normalise = varargin{16};
    Template_array1 = varargin{17};
    Template_array2 = varargin{18};
    Template_array3 = varargin{19};
    Template_array4 = varargin{20};
    GT_file = varargin{21};
    algSettings = varargin{22};
else
    error('Incorrect number of inputs to function');
end

%Zeroing Variables
recall_count = zeros(1,length(algSettings.thresh));
error_count = zeros(1,length(algSettings.thresh));
false_negative_count = zeros(1,length(algSettings.thresh));
recall_count2 = 0;
error_count2 = 0;
truePositive = [0 0]; 
falsePositive = [0 0];
Template_count_for_plot = 0;
plot_skip = 0;

O1 = zeros(totalImagesR,1);
O2 = zeros(totalImagesR,1);
O3 = zeros(totalImagesR,1);
O4 = zeros(totalImagesR,1);
T = zeros(totalImagesR);
worstIDArray = zeros(1,totalImagesR);

figure 
hold on
    
%Recall route--------------------------------------------------------------
if Video_option == 1
%Nordland------------------------------------------------------------------
    while Imcounter_Q < finalIndex_Q
        if ((Imcounter_Q > 1290) && (Imcounter_Q < 2040)) 
            Imcounter_Q = Imcounter_Q + 1;
        elseif ((Imcounter_Q > 2210) && (Imcounter_Q < 2355)) 
            Imcounter_Q = Imcounter_Q + 1;
        elseif ((Imcounter_Q > 2500) && (Imcounter_Q < 2660)) 
            Imcounter_Q = Imcounter_Q + 1;
        elseif ((Imcounter_Q > 3400) && (Imcounter_Q < 3670)) 
            Imcounter_Q = Imcounter_Q + 1;
        elseif ((Imcounter_Q > 5050) && (Imcounter_Q < 5460))
            Imcounter_Q = Imcounter_Q + 1;
        elseif ((Imcounter_Q > 6060) && (Imcounter_Q < 6220))
            Imcounter_Q = Imcounter_Q + 1;
        else
            Nord_Q.CurrentTime = Imcounter_Q;
            totalImagesQ = totalImagesQ + 1;
            Im = readFrame(Nord_Q);
            if totalImagesQ == 1
                %Some pre-allocations:
                diffVector1 = zeros(1,Template_count);
                diffVector2 = zeros(1,Template_count);
                diffVector3 = zeros(1,Template_count);
                diffVector4 = zeros(1,Template_count);
                Template_count_for_plot = Template_count;
                %Transition matrix:
                for j = 1:totalImagesR
                    for k = 1:Template_count
                        if ((k-j) >= minVelocity) && ((k-j) <= maxVelocity) 
                            T(j,k) = 1; %most likely the robot will stay in place or move forward.
                        else
                            T(j,k) = 0.001; %what is the probability that the robot will take a different route?
                        end
                    end
                end
            end
            
            if Plot == 1
                %display the images in a "movie" figure to check if "real" data:
                subplot(2,2,1,'replace');
                image(Im);
                title('Current View');  
            end
            
            %for HybridNet:
            Im1 = imresize(Im,[227 227],'lanczos3');
            Im2 = rgb2gray(Im);
            Im3 = imresize(Im2,[320 640],'lanczos3'); %downsize for HOG
            Im2 = imresize(Im2,[32 64],'lanczos3'); %downsize for SAD
            
            sum_array1 = CNN_Create_Template_Dist(net,Im1,actLayer);
            sum_array4 = CNN_Create_Template(net,Im1,actLayer);
            
            sum_array2 = zeros(1,size(Im2,1)*size(Im2,2),'int8');
            Im2P = patchNormalizeHMM(Im2,8,0,0);
            sum_array2(1,:) = Im2P(:);
            
            sum_array3 = extractHOGFeatures(Im3,'CellSize',[32 32]);
            
            sArray_sz1 = size(sum_array1);
            sArray_sz4 = size(sum_array4);
            
            if Normalise == 1
                sumArrayStore(totalImagesQ,:) = sum_array4;
                
                Q_fAv = mean(sumArrayStore,1);
                
                if totalImagesQ == 1
                    Q_fSt = ones(1,sArray_sz4(2));
                else
                    Q_fSt = std(sumArrayStore,1);
                end
                
                %Now normalise all the features in the current scene:
                for j = 1:sArray_sz4(2)
                    if Q_fSt(j) == 0
                        sum_array4(j) = 0;
                    else
                        sum_array4(j) = (sum_array4(j) - Q_fAv(j))/Q_fSt(j);
                    end
                end
            end
            
            for k = 1:Template_count
                distV = zeros(1,sArray_sz1(2));
                %for sumArray1
                for j = 1:sArray_sz1(2)
                    distV(j) = ( ( Template_array1(1,j,k) - sum_array1(1,j) ).^2 ) +...
                    ( Template_array1(2,j,k) - sum_array1(2,j) ).^2;
                end   
                dist = sqrt(distV);
                diffVector1(k) = sum(dist)/sArray_sz1(2);
            end
            
            D = abs(Template_array2 - sum_array2);
            diffVector2 = sum(D,2);
            diffVector2 = diffVector2';
            
            G_sumArray3 = gpuArray(sum_array3);
            G_sumArray4 = gpuArray(sum_array4);
            
            G_templateArray3 = gpuArray(Template_array3);
            G_templateArray4 = gpuArray(Template_array4);
            
            G_diffVector3 = gpuArray(zeros(1,Template_count));
            G_diffVector4 = gpuArray(zeros(1,Template_count));
            
            G_diffVector3 = pdist2(G_sumArray3,G_templateArray3,'cosine');
            G_diffVector4 = pdist2(G_sumArray4,G_templateArray4,'cosine');
            
            diffVector3 = gather(G_diffVector3);
            diffVector4 = gather(G_diffVector4);
%--------------------------------------------------------------------------            
            mx1 = max(diffVector1); mx2 = max(diffVector2); mx3 = max(diffVector3); mx4 = max(diffVector4);
            df1 = mx1 - min(diffVector1); df2 = mx2 - min(diffVector2); df3 = mx3 - min(diffVector3); df4 = mx4 - min(diffVector4);
            
            for k = 1:Template_count
                O_diff = ((mx1 - diffVector1(k))/df1)-0.001;
                O_diff2 = ((mx2 - diffVector2(k))/df2)-0.001;
                O_diff3 = ((mx3 - diffVector3(k))/df3)-0.001;
                O_diff4 = ((mx4 - diffVector4(k))/df4)-0.001;
                if O_diff < obsThresh
                    O1(totalImagesQ,k) = 0.001;
                else
                    O1(totalImagesQ,k) = O_diff;
                end
                if O_diff2 < obsThresh
                    O2(totalImagesQ,k) = 0.001; 
                else
                    O2(totalImagesQ,k) = O_diff2;
                end            
                if O_diff3 < obsThresh
                    O3(totalImagesQ,k) = 0.001; 
                else
                    O3(totalImagesQ,k) = O_diff3;
                end  
                if O_diff4 < obsThresh
                    O4(totalImagesQ,k) = 0.001;
                else
                    O4(totalImagesQ,k) = O_diff4;
                end
            end
            
            %Find the worst observations for the current image
            [worstID,worstIDStorage(totalImagesQ,:)] = findWorstID(O1,O2,O3,O4,totalImagesQ,Rwindow);
            worstIDCounter(worstID) = worstIDCounter(worstID) + 1;
            worstIDArray(totalImagesQ) = worstID;
            
%--------------------------------------------------------------------------            
            %Use the Viterbi algorithm to find the optimal path through the matrix of recent difference vectors.
            if totalImagesQ > algSettings.maxSeqLength
                S = (totalImagesQ - algSettings.maxSeqLength + 1):totalImagesQ;
                
                [seq,quality,newSeqLength] = viterbi_Smart_Dynamic_Features(S,T,O1,O2,O3,O4,algSettings.minSeqLength,algSettings.Rwindow,worstIDArray);
            
                quality = quality/newSeqLength;
                
                id = seq(newSeqLength);
%--------------------------------------------------------------------------                
                %loop through every threshold to generate PR curve.
                for thresh_counter = 1:length(thresh)
                    if quality > thresh(thresh_counter)
                        %no 'new scenes' should be found in Nordland
                        false_negative_count(thresh_counter) = false_negative_count(thresh_counter) + 1;
                    else
                        if (totalImagesQ > (id-11)) && (totalImagesQ < (id+11))  %up to 10 frames out in either direction
                            recall_count(thresh_counter) = recall_count(thresh_counter) + 1;
                        else
                            error_count(thresh_counter) = error_count(thresh_counter) + 1;
                        end
                    end
                end
%--------------------------------------------------------------------------          
                    %Now run second set of GT code, to generate template plot
                    plot_thresh = 0.5; %threshold for generating the template graph
                    BadSeq_flag = 0;
                    for k = 1:(newSeqLength-1)
                        if (seq(k+1) - seq(k)) < 0 
                            BadSeq_flag = 1;
                            break
                        end
                    end
                    if quality > plot_thresh    
                        BadSeq_flag = 1;
                    end        
                    if (BadSeq_flag == 1)
                        Template_count_for_plot = Template_count_for_plot + 1;
                        Template_plot(Template_count_for_plot,1) = totalImagesR + totalImagesQ;
                        Template_plot(Template_count_for_plot,2) = Template_count_for_plot;     
                    else                         
                        if (totalImagesQ > (id-11)) && (totalImagesQ < (id+11))   %up to 10 frames out in either direction
                            recall_count2 = recall_count2 + 1;
                            truePositive(recall_count2,1) = totalImagesR + totalImagesQ;
                            truePositive(recall_count2,2) = id;
                        else
                            error_count2 = error_count2 + 1;
                            falsePositive(error_count2,1) = totalImagesR + totalImagesQ;
                            falsePositive(error_count2,2) = id;
                        end
                    end 
%--------------------------------------------------------------------------                
                if Plot == 1                    
                    Nord_R.CurrentTime = id2Vid(id);
                    Im_compare = readFrame(Nord_R);
                    subplot(2,2,3,'replace');
                    image(Im_compare);
                    title('Matched Scene');
                    
                    if totalImagesQ == 1091 || totalImagesQ == 1497
                        stop_point = 1;
                    end

                    plot_skip = plot_skip + 1;  %prevents compuational slow down
                    if plot_skip > 9
                        plot_skip = 0;
                        subplot(2,2,2);
                        title('Template Graph');
                        xlabel('Frame Number');
                        ylabel('Template Number');
                        hold on 
                        if ~exist('truePositive','var')

                        else
                            plot(truePositive(:,1),truePositive(:,2),'sg');
                            hold on
                        end
                        if ~exist('falsePositive','var')

                        else
                            plot(falsePositive(:,1),falsePositive(:,2),'sr');
                            hold on    
                        end
                        plot(Template_plot(:,1),Template_plot(:,2),'sr');
                    end   
                    drawnow;     
                end
%--------------------------------------------------------------------------                
            end
            Imcounter_Q = Imcounter_Q + 1;
        end
    end
%--------------------------------------------------------------------------
else        %Not Nordland    
%--------------------------------------------------------------------------

Query_file_type = strcat('*',Query_file_type);
fQ = dir(fullfile(Query_folder,Query_file_type));

Imcounter_Q = Imstart_Q;
fQ2 = struct2cell(fQ);
filesQ = sort_nat(fQ2(1,:));
i = 1;

while((Imcounter_Q+1) <= length(filesQ))
    filenamesQ{i} = filesQ(Imcounter_Q+1);
    Imcounter_Q = Imcounter_Q + Frame_skip;
    i=i+1;
end

totalImagesQ = length(filenamesQ);

Ref_file_type = strcat('*',Ref_file_type);
fR = dir(fullfile(Ref_folder,Ref_file_type));

Imcounter_R = Imstart_R;
fR2 = struct2cell(fR);
filesR = sort_nat(fR2(1,:));
i = 1;

while((Imcounter_R+1) <= length(filesR))
    filenamesR{i} = filesR(Imcounter_R+1);
    Imcounter_R = Imcounter_R + Frame_skip;
    i=i+1;
end
    
for ii = 1:totalImagesQ
    if ii == 1  %first time in recall route initialise the transition matrix.
        %Some pre-allocations:
        diffVector1 = zeros(1,Template_count);
        diffVector2 = zeros(1,Template_count);
        diffVector3 = zeros(1,Template_count);
        diffVector4 = zeros(1,Template_count);
        Template_count_for_plot = Template_count;
        %Transition matrix:
        for j = 1:totalImagesR %these might as well both be Template_count
            for k = 1:Template_count
                if ((k-j) >= algSettings.minVelocity) && ((k-j) <= algSettings.maxVelocity) 
                    T(j,k) = 1; %most likely the robot will stay in place or move forward.
                else
                    T(j,k) = 0.001; %what is the probability that the robot will take a different route?
                end
            end
        end
    end
    
    Im = imread(char(fullfile(fQ(1).folder,filenamesQ{ii})));
    
    subplot(2,2,1,'replace');
    image(Im);
    title('Current View');
    
    sz = size(Im);
    Im = Im(Initial_crop(1):(sz(1)-Initial_crop(2)),Initial_crop(3):(sz(2)-Initial_crop(4)),:);

    Im1 = imresize(Im,[227 227],'lanczos3');    %for CNN
    Im2 = rgb2gray(Im);
    Im3 = imresize(Im2,[HOG_resolution(2) HOG_resolution(1)],'lanczos3');     %downsize for HOG
    Im4 = imresize(Im2,[SAD_resolution(2) SAD_resolution(1)],'lanczos3');     %downsize for SAD
    
    sum_array1 = CNN_Create_Template(net,Im1,actLayer);         %CNN
    sum_array2 = CNN_Create_Template_Dist(net,Im1,actLayer);    %CNN-Dist
    
    sum_array3 = extractHOGFeatures(Im3,'CellSize',[HOG_cellSize(1) HOG_cellSize(2)]);  %HOG
    
    sum_array4 = zeros(1,size(Im4,1)*size(Im4,2),'int8'); %SAD
    Im4P = patchNormalizeHMM(Im4,SAD_patchSize,0,0);
    sum_array4(1,:) = Im4P(:);
    
    sArray_sz1 = size(sum_array1);
    sArray_sz2 = size(sum_array2);
    
    if Normalise == 1
        sumArrayStore(ii,:) = sum_array1;
        
        Q_fAv = mean(sumArrayStore,1);
        
        if ii == 1
            Q_fSt = ones(1,sArray_sz1(2));
        else
            Q_fSt = std(sumArrayStore,1);
        end
        
        %Now normalise all the features in the current scene:
        for j = 1:sArray_sz1(2)
            if Q_fSt(j) == 0
                sum_array1(j) = 0;
            else
                sum_array1(j) = (sum_array1(j) - Q_fAv(j))/Q_fSt(j);
            end
        end
    end
            
    for k = 1:Template_count  %For CNN-Dist
        distV = zeros(1,sArray_sz2(2));
        %for sumArray2
        for j = 1:sArray_sz2(2)
            distV(j) = ( ( Template_array2(1,j,k) - sum_array2(1,j) ).^2 ) +...
            ( Template_array2(2,j,k) - sum_array2(2,j) ).^2;
        end   
        dist = sqrt(distV);
        diffVector2(k) = sum(dist)/sArray_sz2(2);
    end
    
    D = abs(Template_array4 - sum_array4);
    diffVector4 = sum(D,2);
    diffVector4 = diffVector4';
    
    G_sumArray1 = gpuArray(sum_array1); %CNN
    G_sumArray3 = gpuArray(sum_array3); %HOG
    
    G_templateArray1 = gpuArray(Template_array1);
    G_templateArray3 = gpuArray(Template_array3);
    
    G_diffVector1 = gpuArray(zeros(1,Template_count));
    G_diffVector3 = gpuArray(zeros(1,Template_count));
    
    G_diffVector1 = pdist2(G_sumArray1,G_templateArray1,'cosine');
    G_diffVector3 = pdist2(G_sumArray3,G_templateArray3,'cosine');
    
    diffVector1 = gather(G_diffVector1);
    diffVector3 = gather(G_diffVector3);
%--------------------------------------------------------------------------
%Compute the observation matricies using the cosine distance scores
%This normalisation calc is prone to issues if significant outliers are
%present in the reference traverse.
    mx1 = max(diffVector1); mx2 = max(diffVector2); mx3 = max(diffVector3); mx4 = max(diffVector4);
    df1 = mx1 - min(diffVector1); df2 = mx2 - min(diffVector2); df3 = mx3 - min(diffVector3); df4 = mx4 - min(diffVector4);
    
    for k = 1:Template_count
        O_diff = ((mx1 - diffVector1(k))/df1)-algSettings.epsilon;  %normalise to range 0.001 to 0.999    
        O_diff2 = ((mx2 - diffVector2(k))/df2)-algSettings.epsilon;
        O_diff3 = ((mx3 - diffVector3(k))/df3)-algSettings.epsilon;
        O_diff4 = ((mx4 - diffVector4(k))/df4)-algSettings.epsilon;
        if O_diff < algSettings.obsThresh 
            O1(ii,k) = algSettings.epsilon; 
        else
            O1(ii,k) = O_diff;
        end 
        if O_diff2 < algSettings.obsThresh
            O2(ii,k) = algSettings.epsilon; 
        else
            O2(ii,k) = O_diff2;
        end            
        if O_diff3 < algSettings.obsThresh
            O3(ii,k) = algSettings.epsilon; 
        else
            O3(ii,k) = O_diff3;
        end         
        if O_diff4 < algSettings.obsThresh
            O4(ii,k) = algSettings.epsilon;
        else
            O4(ii,k) = O_diff4;
        end
    end
    %Find the worst observations for the current image
    [worstID] = findWorstID(O1,O2,O3,O4,ii,algSettings.Rwindow);
    worstIDCounter(worstID) = worstIDCounter(worstID) + 1;
    worstIDArray(ii) = worstID;
    
%--------------------------------------------------------------------------
%Use the Viterbi algorithm to find the optimal path through the matrix of recent difference vectors.                
    if ii > algSettings.maxSeqLength

        S = (ii-algSettings.maxSeqLength+1):ii;  %length(S) should be equal to maxSeqLength.

        [seq,quality,newSeqLength] = viterbi_Smart_Dynamic_Features(S,T,O1,O2,O3,O4,algSettings.minSeqLength,algSettings.Rwindow,worstIDArray);        
        
        quality = quality/newSeqLength;
            
        id = seq(newSeqLength);     
%--------------------------------------------------------------------------
        %loop through every threshold to generate the PR curve.
        for thresh_counter = 1:length(algSettings.thresh)
            if quality > algSettings.thresh(thresh_counter)
                if sum(GT_file(Imstart_Q+ii,:))==0
                    %true negative
                else
                    %false negative
                    false_negative_count(thresh_counter) = false_negative_count(thresh_counter) + 1;
                end
            else
                if (GT_file(Imstart_Q+ii,Imstart_R+id)==1)
                    %true positive
                    recall_count(thresh_counter) = recall_count(thresh_counter) + 1;
                else  %false positive
                    error_count(thresh_counter) = error_count(thresh_counter) + 1;
                end
            end
        end        
%--------------------------------------------------------------------------        
            %Now run second set of GT code, to generate template plot
            plot_thresh = 0.3; %threshold for generating the template graph
            if quality > plot_thresh    
                Template_count_for_plot = Template_count_for_plot + 1;
                Template_plot(Template_count_for_plot,1) = totalImagesR + ii;
                Template_plot(Template_count_for_plot,2) = Template_count_for_plot;     
            else    
                if (ground_truth(Imstart_Q+ii,Imstart_R+id)==1)
                    recall_count2 = recall_count2 + 1;
                    truePositive(recall_count2,1) = Imstart_Q + ii;
                    truePositive(recall_count2,2) = Imstart_R + id;
                else
                    error_count2 = error_count2 + 1;
                    falsePositive(error_count2,1) = Imstart_Q + ii;
                    falsePositive(error_count2,2) = Imstart_R + id;
                end
            end 
%--------------------------------------------------------------------------            
        if Plot == 1          
            subplot(2,2,3,'replace');
            Im_compare = imread(char(fullfile(fR(1).folder,filenamesR{id})));
            image(Im_compare);
            title('Matched Scene');
                       
            plot_skip = plot_skip+1;
            if plot_skip > 9
                plot_skip = 0;
                subplot(2,2,2);
                title('Template Graph');
                xlabel('Frame Number');
                ylabel('Template Number');
                hold on 
                if ~exist('truePositive','var')

                else
                    plot(truePositive(:,1),truePositive(:,2),'sg');
                    hold on
                end
                if ~exist('falsePositive','var')

                else
                    plot(falsePositive(:,1),falsePositive(:,2),'sr');
                    hold on    
                end
                plot(Template_plot(:,1),Template_plot(:,2),'sr');
            end   
            drawnow;     
        end         
%--------------------------------------------------------------------------       
    end
end
end
%--------------------------------------------------------------------------
for thresh_counter = 1:length(thresh)
    %Recall = true positives / (true positives + false negatives)
    recall(thresh_counter) = recall_count(thresh_counter)/(recall_count(thresh_counter) + false_negative_count(thresh_counter));
    %Precision = true positives / (true positives + false positives)
    precision(thresh_counter) = recall_count(thresh_counter)/(recall_count(thresh_counter) + error_count(thresh_counter));
end
%plot the precision-recall curve:
figure
plot(recall,precision,'-r');
title('Precision Recall Curve');
xlabel('Recall');
ylabel('Precision');
xlim([0 1]);
ylim([0 1]);
grid on
      
end    
        
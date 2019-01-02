clc;
fprintf("Start \t Initialization \n");

videoSource = 'Video 3.0 #1_STAB.mp4';
%videoSource = 'autobahn_qf.mp4';
%read Video
video = VideoReader(videoSource);

%tolerance threshold for background
tolerance = 25;

%boxes having that distance will be joined
bboxDistTolerance = 15;



fprintf('End \t Initialization \n');
fprintf('Start \t Background Filtering \n');

%get FrameSize
frame1 = read(video, 1);
pictureSize = size(frame1);

%get Background
%take 50 frames and get mode from every pixel
countMatrix = zeros(pictureSize(1), pictureSize(2), 50);
for i = 1:50
    countMatrix(1:end, 1:end, i) = rgb2gray(read(video, i*20)); 
    
    percent = i/(pictureSize(1)+50);  
    perc = sprintf('\t\t %.2f %% \n', percent * 100);
    if(i ~= 1)
        fprintf(repmat('\b', 1, persSize));
    end
    persSize = size(perc, 2);
    fprintf('%s', perc);
end
background = zeros(pictureSize(1), pictureSize(2));
for i = 1:pictureSize(1)
    for j = 1:pictureSize(2)
        background(i,j) = mode(squeeze(countMatrix(i,j,1:50)));
    end
            
    percent = (50+i)/(pictureSize(1)+50);  
    perc = sprintf('\t\t %.2f %% \n', percent * 100);
    fprintf(repmat('\b', 1, persSize));
    persSize = size(perc, 2);
    fprintf('%s', perc);
end
fprintf(repmat('\b', 1, persSize));

%imshow(background, [0 255]);



fprintf('End \t Background Filtering \n');
fprintf('Start \t Road Markings Analysis \n');


%get detection lines
lines = background >= 250;
lines = bwmorph(lines, 'skel', 6);
lines = imopen(lines, strel('line', 5, 90));
%figure, imshow(lines, [0 1]);
line1begin=0;
line2begin=0;
schwarz1 = 0;
weiss1 = 0;
schwarz2 = 0;
for i = 1:pictureSize(1)-1
    if (schwarz1 == 0) 
        for j = 256:pictureSize(2)-256
            if (lines(pictureSize(1)-i, j) ~= 0)
                schwarz1 = 1;
            end
        end
    end
    if schwarz1 == 1
        if(weiss1==0)
            if(~(lines(pictureSize(1)-i,256:end-256) ~= 0))
                weiss1 = 1;
                line1begin=pictureSize(1)-i;
            end
        end
    end
    if weiss1 == 1
        if(schwarz2==0)
            for j = 256:pictureSize(2)-256
                if (lines(pictureSize(1)-i, j) ~= 0)
                    schwarz2 = 1;
                    line2begin = pictureSize(1)-i;
                end
            end
        end 
    end
    
    percent = i/(pictureSize(1)-1);  
    perc = sprintf('\t\t %.2f %% \n', percent * 100);
    if(i ~= 1)
        fprintf(repmat('\b', 1, persSize));
    end
    persSize = size(perc, 2);
    fprintf('%s', perc);
end
fprintf(repmat('\b', 1, persSize));



fprintf('End \t Road Markings Analysis \n');
fprintf('Start \t Car Detection \n');


videoReader = vision.VideoFileReader(videoSource);
videoPlayer = vision.VideoPlayer('Name', 'Detected Cars');

blobAnalysis = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
    'AreaOutputPort', false, 'CentroidOutputPort', false, ...
    'MinimumBlobArea', 150);
videoPlayer = vision.VideoPlayer('Name', 'Detected Cars');
videoPlayer.Position(3:4) = [650,400];  % window size: [width, height]
se = strel('square', 3); % morphological filter for noise removal
i=0;
background = uint8(background);

nframes = video.NumberOfFrames;
fps = video.FrameRate;
taggedCars = zeros([pictureSize(1) pictureSize(2) pictureSize(3) nframes], 'single');
%class(read(video, 1)));

mcnt = [];
bboxCnt = 0;
bboxCntPre = 0;
cnt2 = [0];

while ~isDone(videoReader)
    i=i+1;
    frame = step(videoReader); % read the next video frame
    result = frame;
    frameGray = (rgb2gray(frame)*255);
    backgroundSingle = single(background);
    pixeldifference = frameGray(pictureSize(1), pictureSize(2))-backgroundSingle(pictureSize(1), pictureSize(2));
    % Detect the foreground in the current video frame
    fgFrame = read(video, i);
    fgFrame = rgb2gray(fgFrame);
    fgFrame = uint8(fgFrame);
    if (pixeldifference ~= 0)
        tempbackground = backgroundSingle+pixeldifference;
    else
        tempbackground=backgroundSingle;
    end
    fg = uint8(tempbackground) - fgFrame;
    fg = (fg >= tolerance) | (fg <= -tolerance);
    % Use morphological opening to remove noise in the foreground
    filteredForeground = fg;
    filteredForeground = imerode(fg, se);
    filteredForeground = imopen(filteredForeground, se);

    % Detect the connected components with the specified minimum area, and
    % compute their bounding boxes
    bbox = step(blobAnalysis, filteredForeground);
    

    
    

    
    %union overlapping boxes
    modified = true;
    while (modified)
        modified = false;
    if(bbox ~= 0)
        for k = 1:size(bbox,1)
            for j = k:size(bbox,1)
                if (j<=size(bbox,1) && k<=size(bbox,1))
                if j ~= k
                    dist = distance(bbox(k,1), bbox(k,2), bbox(k,3), bbox(k,4),bbox(j,1), bbox(j,2), bbox(j,3), bbox(j,4));
                    %overlap = bboxOverlapRatio(bbox(k,:), bbox(j,:));
                    %if (overlap ~= 0)
                    if (dist <= bboxDistTolerance)
                        x = min(bbox(k,1), bbox(j,1));
                        y = min(bbox(k,2), bbox(j,2));
                        width = max(bbox(k,1)+bbox(k,3), bbox(j,1)+bbox(j,3));
                        width = width - x;
                        height = max(bbox(k,2)+bbox(k,4), bbox(j,2)+bbox(j,4));
                        height = height - y;
                        bbox(j,:)=[]; %delete box
                        bbox(k,:)=[x y width height]; %update other box
                        j=j-1;
                        modified = true;
                    end
                    
                end
                end
            end
        end
    end
    end
        
    % sort bbox by Y-Coordinate
    [temp, order] = sort(bbox(:,2));
    bbox = bbox(order, :);
    bbox2 = repmat(pictureSize(2)+1, 1, 4);
    
    
    
    bboxCnt = size(bbox, 1);
    lines = [0 line2begin pictureSize(2) line2begin; 0 line1begin pictureSize(2) line1begin];
    color = {'yellow', 'white'};
    cbbox = {};
    txtPos = [];
    txtStr = [];    
    cnt = [];
    vel = [];
    
    
    if(bboxCnt > 2)
        lol = 1;
    end
    
    
    if(bbox ~= 0)
        vel = zeros(1, size(bbox, 1)); 
        cnt = zeros(1, size(bbox, 1));
        o = 0;
        
        for k = 1:size(bbox, 1)
            lines = [lines ; 0 bbox(k, 2)+bbox(k, 4) pictureSize(2) bbox(k, 2)+bbox(k, 4)];          
            cbbox{1, k} = 'yellow';   
            
            if(size(bbox,1) > size(bbox2,1))
                bbox2 = [bbox2; repmat(pictureSize(2)+1, size(bbox, 1)-size(bbox2, 1), 4)];
            elseif(size(bbox,1) < size(bbox2,1))
                %bbox2 = ;
            end 

%             if(bbox(k, 2)+bbox(k, 4) <= line1begin && bbox(k, 2)+bbox(k, 4) >= line2begin)
%                 if(bbox(k, 2) < bbox2(k, 2))
%                     cnt(1,k) = cnt(1,k) + 1;                
%                 end
%             end
            
        if(size(cnt,2) > size(cnt2,2))
            cnt2 = [cnt2 0];
        elseif(size(cnt,2) < size(cnt2,2))
            cnt2 = cnt2(1, 2:end);
        end 

            % car is in speed measuring area 
            if( (bbox(k, 2)+bbox(k, 4) < line1begin) && ... 
                    (bbox(k, 2)+bbox(k, 4) > line2begin)) && ...
                    (bbox(k, 2) < bbox2(k, 2))
                color{1, 2+k} = 'red';
                cnt(1, k) = cnt2(1, k)+1;
            % car is in speed projection area 
            elseif (bbox(k, 2)+bbox(k, 4) > line2begin)
                color{1, 2+k} = 'blue';
            else                
                color{1, 2+k} = 'magenta';  
                cnt(1, k) = cnt2(1, k);
                
                if(cnt(1, k) == 0)
                    vel(1, k) = 0;
                else
                    vel(1, k) = round(3.6 * 12 * fps / cnt(1, k), 0);
                    if(vel(1, k) > 200)
                        %vel(1, k) = 9999;
                        cbbox{1, k} = 'cyan';
                    elseif(vel(1, k) > 130)
                        cbbox{1, k} = 'red';
                    else
                        cbbox{1, k} = 'green'; 
                    end
                end
            end
                        
            %mcnt = cnt;
            txtPos = [txtPos; bbox(k, 1) bbox(k, 2)];            
            txtStr = [txtStr; vel(1,k)];
        end
       
        % Display the number of cars found in the video frame
        result = insertText(result, txtPos, txtStr, 'BoxOpacity', 1, ...
        'FontSize', 14);
    
    
        
        if(size(bbox,1) > size(bbox2,1))
            %bbox2 = bbox;
            cnt2 = [cnt 0];
        elseif(size(bbox,1) < size(bbox2,1))
            %bbox2 = [bbox; repmat(pictureSize(2)+1, size(bbox2)-size(bbox), 4)];
            cnt2 = cnt(1, 2:end);
        else
            %bbox2 = bbox;
            cnt2 = cnt;
        end 
        bbox2 = bbox;
    else
        if(size(bbox, 1) > size(bbox2, 1))
        elseif(size(bbox, 1) < size(bbox2, 1))
        else            
        end 
            bbox2 = repmat(pictureSize(2)+1, 1, 4);
    
    end   

    
    % Draw bounding boxes around the detected cars and lines
    result = insertShape(result, 'Rectangle', bbox, 'Color', cbbox);
    result = insertShape(result, 'line', lines, 'Color', color);


   
    
    taggedCars(:,:,:,i) = result;
    
    
    percent = i/nframes;  
    perc = sprintf('\t\t %.2f %% \n', percent * 100);
    if(i ~= 1)
        fprintf(repmat('\b', 1, persSize));
    end
    persSize = size(perc, 2);
    fprintf('%s', perc);
    
    %step(videoPlayer, result);  % display the results
end

fprintf(repmat('\b', 1, persSize));
fprintf('End \t Car Detection \n');

fprintf('Show processed Video \n');
implay(taggedCars, fps/2);

release(videoReader); % close the video file

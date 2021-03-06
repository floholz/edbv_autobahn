function test()
    clc;
    for t = 1:60
        if (t < 10)
            str = sprintf('Clip #00%d.mp4', t);
        else            
            str = sprintf('Clip #0%d.mp4', t);
        end
        fprintf("%s\n", str);
        main(str);
    end    
end

function main(videoSource)
%read Video
video = 0;
%videoSource = 'Clip #002.mp4';
try
    video = VideoReader(videoSource);
catch e
    warning = warndlg('Video not Found!');
    return
end

%starting waitbar
percentage = 0;
bar = waitbar(0,strcat('Loading Video... | ', {' '}, num2str(uint8(percentage*100)), '%'), 'Name', 'EDBV: Car Detection');

%Set tolerance for video
%tolerance threshold for background
tolerance = 20;
%boxes having that distance will be joined
bboxDistTolerance = 10;
%Size for struct Element (ungerade)
structElementFactor = 5;

%get FrameSize and start of Video
frame1 = readFrame(video);
pictureSize = size(frame1);
videoStart = video.CurrentTime;

%waitbar
estimateFrames = ceil(video.FrameRate*video.Duration);
estimateDur = 0.1/(estimateFrames+10);

%get exact number of Frames
nframes = 1;

while hasFrame(video)
    readFrame(video);
    nframes = nframes +1;
    %waitbar
    percentage = percentage + estimateDur;
    waitbar(percentage,bar,strcat('Loading Video... |', {' '}, num2str(uint8(percentage*100)), '%'));
end

%reset Video to start
video.CurrentTime = videoStart;

%waitbar
percentage = 0.1;
waitbar(percentage,bar,strcat('Identifying Background... |', {' '}, num2str(uint8(percentage*100)), '%'));
estimateDur = 0.05/50;

%get Background
%take 50 frames and get mode from every pixel
countMatrix = zeros(pictureSize(1), pictureSize(2), 50);
for i = 1:50
    %Jump over 20 Frames
    for j=1:floor(nframes/70)
        readFrame(video);
    end
    countMatrix(1:end, 1:end, i) = rgb2gray(readFrame(video));
    %waitbar
    percentage = percentage + estimateDur;
    waitbar(percentage,bar,strcat('Identifying Background... |', {' '}, num2str(uint8(percentage*100)), '%'));
end
background = zeros(pictureSize(1), pictureSize(2));
%waitbar
estimateDur = 0.05/pictureSize(1);
%%get mode for every pixel
for i = 1:pictureSize(1)
    for j = 1:pictureSize(2)
        background(i,j) = mode(squeeze(countMatrix(i,j,1:50)));
    end
    %waitbar
    percentage = percentage + estimateDur;
    waitbar(percentage,bar,strcat('Identifying Background... |', {' '}, num2str(uint8(percentage*100)), '%'));
end

%waitbar
percentage = 0.2;
waitbar(percentage,bar,strcat('Detecting Lines... |', {' '}, num2str(uint8(percentage*100)), '%'));
estimateDur = 0.05/pictureSize(1);

%get detection lines
%extract all white elements of background
lines = background >= 215;
%extract all lines, skeletonization
lines = thinning(lines);
%opening
lines = opening(lines, strel('line', 7, 90));
%get beginning of lines
line1begin=0;
line2begin=0;
schwarz1 = 0;
weiss1 = 0;
schwarz2 = 0;
%scan for most white lines
whites = zeros(pictureSize(2));
for i = 100:pictureSize(2)-100
    temp = 0;
    for j=1:pictureSize(1)
        if lines(j,i) == 1
            temp = temp+1;
        end
    end
    whites(i) = temp;
end
mostWhites = 0;
index = 0;
for i = 1:size(whites)
    if mostWhites<whites(i)
        index =i;
        mostWhites = whites(i);
    end
end
%tolerance middle
tolerance = 20;
if (index-20)<1 || (index+20)>pictureSize(2)
    index = pictureSize(2)/2;
end
for i = 1:pictureSize(1)-1
    percentage = percentage + estimateDur;
    waitbar(percentage,bar,strcat('Detecting Lines... |', {' '}, num2str(uint8(percentage*100)), '%'));
    if (schwarz1 == 0)
        for j = index-tolerance:index+tolerance
            if (lines(pictureSize(1)-i, j) ~= 0)
                schwarz1 = 1;
            end
        end
    end
    if schwarz1 == 1
        if(weiss1==0)
            if(~(lines(pictureSize(1)-i,index-tolerance:index+tolerance) ~= 0))
                weiss1 = 1;
                line1begin=pictureSize(1)-i;
            end
        end
    end
    if weiss1 == 1
        if(schwarz2==0)
            for j = index-tolerance:index+tolerance
                if (lines(pictureSize(1)-i, j) ~= 0)
                    schwarz2 = 1;
                    line2begin = pictureSize(1)-i;
                end
            end
        end
    end
end

line1begin=line1begin-3;
line2begin=line2begin+3;

video.CurrentTime = videoStart;

videoPlayer = vision.VideoPlayer('Name', 'Detected Cars');
videoPlayer.Position(3:4) = [650,400];  % window size: [width, height]
se = strel('square', structElementFactor); % morphological filter for noise removal
i=0;
background = uint8(background);

fps = video.FrameRate;
taggedCars = zeros([pictureSize(1) pictureSize(2) pictureSize(3) nframes], 'single');
cnt2 = 0;
bbox2 = zeros(1, 4);

percentage = 0.25;
estimateDur = 0.75/nframes;
waitbar(percentage,bar,strcat('Analysing Frames... |', {' '}, num2str(uint8(percentage*100)), '%'));
while hasFrame(video)
    i=i+1;
    frame = readFrame(video);
    result = frame;
    frameGray = rgb2gray(frame);
    pixeldifference = frameGray - background;
    pixeldifference = mode(mode(pixeldifference));
    % Detect the foreground in the current video frame
    fgFrame = frame;
    fgFrame = rgb2gray(fgFrame);
    fgFrame = uint8(fgFrame);
    if (pixeldifference ~= 0)
        tempbackground = background+pixeldifference;
    else
        tempbackground=background;
    end
    fg = uint8(tempbackground) - fgFrame;
    fg = (fg >= tolerance) | (fg <= -tolerance);
    % Use morphological opening to remove noise in the foreground
    filteredForeground = fg;
    %filteredForeground = erosion(filteredForeground, se);
    filteredForeground = opening(filteredForeground, se);
    
    % Detect the connected components with the specified minimum area, and
    % compute their bounding boxes
    bbox = ccl(filteredForeground);
    

    
    %union overlapping boxes
    modified = true;
    %repeat until no box was modified
    while (modified)
        modified = false;
        if(bbox ~= 0)
            for k = 1:size(bbox,1)
                for j = k:size(bbox,1)
                    if (j<=size(bbox,1) && k<=size(bbox,1))
                        if j ~= k
                            %if boxes are in a certain distance to each
                            %other join them
                            dist = distance(bbox(k,1), bbox(k,2), bbox(k,3), bbox(k,4),bbox(j,1), bbox(j,2), bbox(j,3), bbox(j,4));
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
       
    
    
    bboxCnt = size(bbox, 1);
    lines = [0 line2begin pictureSize(2) line2begin; 0 line1begin pictureSize(2) line1begin];
    color = {'yellow', 'white'};
    cbbox = {};
    txtPos = [];
    txtStr = []; 
    vel = [];
    cnt = zeros(1, size(bbox, 1));
    
% sort bbox by Y-Coordinate
    [temp, order] = sort(bbox(:,2));
    bbox = bbox(order, :);    
    cnt = cnt(:, order);  
    
    if(size(bbox,1) > size(bbox2,1))
        bbox2 = [bbox2; repmat(pictureSize(2)+1, size(bbox, 1)-size(bbox2, 1), 4)];
    elseif(size(bbox,1) < size(bbox2,1))
        bbox2 = bbox2(1:end-1, :);
    end 
        
    if(size(cnt,2) > size(cnt2,2))
        cnt2 = [cnt2, zeros(1, size(cnt, 2)-size(cnt2, 2))];
    elseif(size(cnt,2) < size(cnt2,2))
        cnt2 = cnt2(1, 1:end-1);
    end 
    
    if(bbox ~= 0)
        vel = zeros(1, size(bbox, 1)); 
        
        for k = 1:size(bbox, 1)
            lines = [lines ; 0 bbox(k, 2)+bbox(k, 4) pictureSize(2) bbox(k, 2)+bbox(k, 4)];          
            cbbox{1, k} = 'yellow';   
            

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
                        cbbox{1, k} = 'cyan';
                    elseif(vel(1, k) > 130)
                        cbbox{1, k} = 'red';
                    else
                        cbbox{1, k} = 'green'; 
                    end
                end
            end
                        
            txtPos = [txtPos; bbox(k, 1) bbox(k, 2)];            
            txtStr = [txtStr; vel(1, k)];
        end
       
        % Display the number of cars found in the video frame
        result = insertText(result, txtPos, txtStr, 'BoxOpacity', 1, ...
        'FontSize', 14);
    
    
        
        if(size(bbox,1) > size(bbox2,1))
            cnt2 = [cnt zeros(1, size(cnt, 2)-size(cnt2, 2))];
        elseif(size(bbox,1) < size(bbox2,1))
            cnt2 = cnt(1, 1:end-1);
        else
            cnt2 = cnt;
        end 
        bbox2 = bbox;
    else
        bbox2 = repmat(pictureSize(2)+1, 1, 4);    
    end   

    
    % Draw bounding boxes around the detected cars and lines
    
    select = (bbox(:, 2)+bbox(:, 4))< line2begin;
    bboxFill = bbox(select, :);
    cbboxFill = cbbox(select);
    
    result = insertShape(result, 'FilledRectangle', bboxFill,'Color', cbboxFill);
    result = insertShape(result, 'Rectangle', bbox, 'Color', cbbox);
    result = insertShape(result, 'line', lines, 'Color', color);

    result = double(result);
    taggedCars(:,:,:,i) = result/255;
    
    percentage = percentage + estimateDur;
    waitbar(percentage,bar,strcat('Analysing Frames... |', {' '}, num2str(uint8(percentage*100)), '%'));
end
percentage = 1;
waitbar(1,bar,strcat('Finished... |', {' '}, num2str(uint8(percentage*100)), '%'));
pause(.5);
delete(bar);
%implay(taggedCars, fps);
end

%returns minimal distance between two rectangles
function dist = distance(x1, y1, width1, height1, x2, y2, width2, height2)

if (bboxOverlapRatio([x1 y1 width1 height1], [x2 y2 width2 height2])~=0)
    dist = 0;
else
    
    width1 = width1+x1;
    height1 = height1+y1;
    width2 = width2+x2;
    height2 = height2+y2;
    
    left = width2 < x1;
    right = width1 < x2;
    bottom = height2 < y1;
    top = height1 < y2;
    
    if (top && left)
        dist = calcDistance(x1, height1, width2, y2);
    elseif (left && bottom)
        dist = calcDistance(x1, y1, width2, height2);
    elseif (bottom && right)
        dist = calcDistance(width1, y1, x2, height2);
    elseif (right && top)
        dist = calcDistance(width1, height1, x2, y2);
    elseif (left)
        dist = x1 - width2;
    elseif (right)
        dist = x2 - width1;
    elseif (bottom)
        dist = y1 - height2;
    elseif (top)
        dist = y2 - height1;
    else
        dist = 0;
    end
end
end

%euclidian distance
function dist = calcDistance(x1, y1, x2, y2)
dist = sqrt(double((x2-x1)^2+(y2-y1)^2));
end

%opening
function result = opening(frame, structElement)
    result = dilation(erosion(frame, structElement), structElement);
end

%erosion
function result = erosion(frame, structElement)
%     logical = structElement.Neighborhood;
%     logicalDimension = size(logical);
%     logicalDimensionYHalf = floor(logicalDimension(1)/2);
%     logicalDimensionXHalf = floor(logicalDimension(2)/2);
%     frameDimension = size(frame);
%     result = false(frameDimension(1), frameDimension(2));
%     for i = logicalDimensionYHalf+1:frameDimension(1)-logicalDimensionYHalf-1
%         for j = logicalDimensionXHalf+1:frameDimension(2)-logicalDimensionXHalf-1
%             temp = frame(i-logicalDimensionYHalf:i+logicalDimensionYHalf,j-logicalDimensionXHalf:j+logicalDimensionXHalf);
%             temp = temp & logical;
%             %if all(frame(i-logicalDimensionYHalf:i+logicalDimensionYHalf,j-logicalDimensionXHalf:j+logicalDimensionXHalf))
%             if all(temp)
%                 result(i,j) = 1;
%             end
%         end
%     end
%     
    result = imerode(frame, structElement);
end

%dilation
function result = dilation(frame, structElement)
%     logical = structElement.Neighborhood;
%     logicalDimension = size(logical);
%     logicalDimensionYHalf = floor(logicalDimension(1)/2);
%     logicalDimensionXHalf = floor(logicalDimension(2)/2);
%     frameDimension = size(frame);
%     result = false(frameDimension(1), frameDimension(2));
%     for i = 1:frameDimension(1)
%         for j = 1:frameDimension(2)
%             if frame(i,j) == 1
%                for k = -logicalDimensionYHalf:logicalDimensionYHalf
%                    for l = -logicalDimensionXHalf:logicalDimensionXHalf
%                        if (i+k>0&&j+l>0&&i+k<=frameDimension(1)&&j+l<=frameDimension(2))
%                             result(i+k,j+l) = 1;
%                        end
%                    end
%                end
%             end
%         end
%     end
    result = imdilate(frame, structElement);
end

%thining
function result = thinning(frame)
changed = 1;

[rows, columns] = size(frame);
thinned_frame = frame;
remove = ones(rows, columns);

while changed
    changed = 0;
    
    % Step 1
    for i=2:rows-1
        for j = 2:columns-1
            P = [thinned_frame(i,j) thinned_frame(i-1,j) thinned_frame(i-1,j+1) thinned_frame(i,j+1) thinned_frame(i+1,j+1) thinned_frame(i+1,j) thinned_frame(i+1,j-1) thinned_frame(i,j-1) thinned_frame(i-1,j-1) thinned_frame(i-1,j)]; % P1, P2, P3, ... , P8, P9, P2
            if (thinned_frame(i,j) == 1 && sum(P(2:end-1))<=6 && sum(P(2:end-1)) >=2 && P(2)*P(4)*P(6)==0 && P(4)*P(6)*P(8)==0)   % conditions
                
                count = 0;
                for k = 2:size(P,2)-1
                    if P(k) == 0 && P(k+1)==1
                        count = count+1;
                    end
                end
                if (count==1)
                    remove(i,j)=0;
                    changed = 1;
                end
            end
        end
    end
    thinned_frame = thinned_frame.*remove;  
    
    % Step 2 
    for i=2:rows-1
        for j = 2:columns-1
            P = [thinned_frame(i,j) thinned_frame(i-1,j) thinned_frame(i-1,j+1) thinned_frame(i,j+1) thinned_frame(i+1,j+1) thinned_frame(i+1,j) thinned_frame(i+1,j-1) thinned_frame(i,j-1) thinned_frame(i-1,j-1) thinned_frame(i-1,j)];
            if (thinned_frame(i,j) == 1 && sum(P(2:end-1))<=6 && sum(P(2:end-1)) >=2 && P(2)*P(4)*P(8)==0 && P(2)*P(6)*P(8)==0)   % conditions
                count = 0;
                for k = 2:size(P,2)-1
                    if P(k) == 0 && P(k+1)==1
                       count = count+1;
                    end
                end
                if (count==1)
                    remove(i,j)=0;
                    changed = 1;
                end
            end
        end
    end
    thinned_frame = thinned_frame.*remove;
end
result = thinned_frame;
end

%conected component labelling
function result = ccl(frame)
    blobAnalysis = vision.BlobAnalysis('BoundingBoxOutputPort', true,'AreaOutputPort', false, 'CentroidOutputPort', false, 'MinimumBlobArea', 150);
    result = step(blobAnalysis, frame);
end

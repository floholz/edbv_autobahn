videoSource = 'Video 3.0 #1_STAB.mp4';
%videoSource = 'autobahn_qf.mp4';
%read Video
video = VideoReader(videoSource);

%tolerance for background
tolerance = 20;
bboxDistTolerance = 15;

%get FrameSize
frame1 = read(video, 1);
pictureSize = size(frame1);

%get Background
%take 50 frames and get mode from every pixel
countMatrix = zeros(pictureSize(1), pictureSize(2), 50);
for i = 1:50
    countMatrix(1:end, 1:end, i) = rgb2gray(read(video, i*20));   
end
background = zeros(pictureSize(1), pictureSize(2));
for i = 1:pictureSize(1)
    for j = 1:pictureSize(2)
        background(i,j) = mode(squeeze(countMatrix(i,j,1:50)));
    end
end
imshow(background, [0 255]);
%get detection lines
lines = background >= 250;
lines = bwmorph(lines, 'skel', 8);
lines = imopen(lines, strel('line', 6, 90));
figure, imshow(lines, [0 1]);
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
end

videoReader = vision.VideoFileReader(videoSource);
videoPlayer = vision.VideoPlayer('Name', 'Detected Cars');

blobAnalysis = vision.BlobAnalysis('BoundingBoxOutputPort', true, ...
    'AreaOutputPort', false, 'CentroidOutputPort', false, ...
    'MinimumBlobArea', 300);
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
    filteredForeground = imopen(filteredForeground, se);
    filteredForeground = imerode(fg, se);

    % Detect the connected components with the specified minimum area, and
    % compute their bounding boxes
    bbox = step(blobAnalysis, filteredForeground);
    
        lines = [0 line2begin pictureSize(2) line2begin; 0 line1begin pictureSize(2) line1begin];
    color = {'yellow', 'white'};
    cbbox = {};
    txtPos = [10 10];
    txtStr = size(bbox, 1);
    
    cnt = {};
    
    bboxCnt = size(bbox, 1);
    
    if(bboxCnt < bboxCntPre)
        
    elseif(bboxCnt > bboxCntPre)
        
    end
    
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
    
    
    
    if(bbox ~= 0)
        vel = zeros(1, size(bbox, 1));        
        cnt = mcnt;
        for k = 1:size(bbox, 1)
            lines = [lines ; 0 bbox(k, 2)+bbox(k, 4) pictureSize(2) bbox(k, 2)+bbox(k, 4)];
            color{1, 2+k} = 'blue';
            
            cbbox{1, k} = 'green';               
            
            if( (bbox(size(bbox, 1)-(k-1), 2) < line1begin) && ... 
                    ( bbox(size(bbox, 1)-(k-1), 2) > line2begin)) 
                %cnt(1, size(bbox, 1)-(k-1)) = cnt(1, size(bbox, 1)-(k-1))+1;
            elseif ( bbox(size(bbox, 1)-(k-1), 2) > line2begin)
                %vel(1, size(bbox, 1)-(k-1)) = (cnt(1, size(bbox, 1)-(k-1))/fps) * 12*3.6;
            end 
            mcnt = cnt;
            txtPos = [txtPos; bbox(size(bbox, 1)-(k-1), 1) bbox(size(bbox, 1)-(k-1), 2)];            
            txtStr = [txtStr; k];
       end
    end
    

    % Draw bounding boxes around the detected cars and lines
    result = insertShape(result, 'Rectangle', bbox, 'Color', cbbox);
    result = insertShape(result, 'line', lines, 'Color', color);

    % Display the number of cars found in the video frame
    result = insertText(result, txtPos, txtStr, 'BoxOpacity', 1, ...
        'FontSize', 14);
    

    taggedCars(:,:,:,i) = result;
    
    percent = i/nframes;
    disp(percent);
    
    %step(videoPlayer, result);  % display the results
end

implay(taggedCars, fps);

release(videoReader); % close the video file

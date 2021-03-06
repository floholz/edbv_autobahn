%read Video
video = VideoReader('Video 3.0 #1_STAB.mp4');

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

%get detection lines
lines = background >= 250;
lines = bwmorph(lines, 'skel', 10);
lines = imopen(lines, strel('line', 6, 90));
line1begin=0;
line2begin=0;
schwarz1 = 0;
weiss1 = 0;
schwarz2 = 0;
for i = 1:pictureSize(1)-1
    if (schwarz1 == 0) 
        for j = 1:pictureSize(2)-1
            if (lines(pictureSize(1)-i, j) ~= 0)
                schwarz1 = 1;
            end
        end
    end
    if schwarz1 == 1
        if(weiss1==0)
            if(~(lines(pictureSize(1)-i,1:end) ~= 0))
                weiss1 = 1;
                line1begin=pictureSize(1)-i;
            end
        end
    end
    if weiss1 == 1
        if(schwarz2==0)
            for j = 1:pictureSize(2)-1
                if (lines(pictureSize(1)-i, j) ~= 0)
                    schwarz2 = 1;
                    line2begin = pictureSize(1)-i;
                end
            end
        end 
    end
end

videoReader = vision.VideoFileReader('Video 3.0 #1_STAB.mp4');
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
taggedCars = zeros([pictureSize(1) pictureSize(2) pictureSize(3) nframes], 'single'); %class(read(video, 1)));

mcnt = [];


while ~isDone(videoReader)
    i=i+1;
    frame = step(videoReader); % read the next video frame
    result = frame;
    if(i > 210)
    end
    
    % Detect the foreground in the current video frame
    fgFrame = read(video, i);
    fgFrame = rgb2gray(fgFrame);
    fgFrame = uint8(fgFrame);
    fg = background - fgFrame;
    fg = (fg >= 10) | (fg <= -10);
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
    
    if(bbox ~= 0)
        vel = zeros(1, size(bbox, 1));        
        cnt = mcnt;
        for k = 1:size(bbox, 1)
            lines = [lines ; 0 bbox(k, 2) pictureSize(2) bbox(k, 2)];
            color{1, 2+k} = 'blue';
            
            cbbox{1, k} = 'green';               
            
            if( (bbox(size(bbox, 1)-(k-1), 2) < line1begin) && ( bbox(size(bbox, 1)-(k-1), 2) > line2begin)) 
                cnt(1, size(bbox, 1)-(k-1)) = cnt(1, size(bbox, 1)-(k-1))+1;
            elseif ( bbox(size(bbox, 1)-(k-1), 2) > line2begin)
                vel(1, size(bbox, 1)-(k-1)) = (cnt(1, size(bbox, 1)-(k-1))/fps) * 12*3.6;
            end 
            mcnt = cnt;
            txtPos = [txtPos; bbox(size(bbox, 1)-(k-1), 1) bbox(size(bbox, 1)-(k-1), 2)];            
            txtStr = [txtStr; cnt(1,size(bbox, 1)-(k-1))];
       end
    end
    
    % Draw bounding boxes around the detected cars and lines
    result = insertShape(result, 'Rectangle', bbox, 'Color', cbbox);
    result = insertShape(result, 'line', lines, 'Color', color);

    % Display the number of cars found in the video frame
    result = insertText(result, txtPos, txtStr, 'BoxOpacity', 1, ...
        'FontSize', 14);
    

    taggedCars(:,:,:,i) = result;
    %step(videoPlayer, result);  % display the results
end

implay(taggedCars, fps);

release(videoReader); % close the video file

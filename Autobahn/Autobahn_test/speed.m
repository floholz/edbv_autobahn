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

% nframes = videoReader.NumberOfFrames
% taggedCars = zeros([size(I,1) size(I,2) 3 nframes], class(I));
% taggedCars = zeros([pictureSize(1) picturesize(2) picturesize(3) ], single);

while ~isDone(videoReader)
    i=i+1;
    frame = step(videoReader); % read the next video frame

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
    color = {'yellow', 'yellow'};
    
    if(bbox ~= 0)
        for k = 1:size(bbox, 1)
            lines = [lines ; 0 bbox(k, 2) pictureSize(2) bbox(k, 2)];
            color{1,2+k} = 'blue';
        end
    end
    
    % Draw bounding boxes around the detected cars and lines
    result = insertShape(frame, 'Rectangle', bbox, 'Color', 'green');
    result = insertShape(result, 'line', lines, 'Color', color);

    % Display the number of cars found in the video frame
    numCars = size(bbox, 1);
    result = insertText(result, [10 10], numCars, 'BoxOpacity', 1, ...
        'FontSize', 14);
    
%     taggedCars(:,:,:,i) = result;

    step(videoPlayer, result);  % display the results
end

release(videoReader); % close the video file

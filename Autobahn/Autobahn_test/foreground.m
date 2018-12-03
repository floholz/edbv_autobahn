videoSource = 'Video 3.0 #1_STAB.mp4';
%videoSource = 'autobahn_qf.mp4';
%read Video
video = VideoReader(videoSource);

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
imshow(lines, [0 1]);
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
    'MinimumBlobArea', 150);
videoPlayer = vision.VideoPlayer('Name', 'Detected Cars');
videoPlayer.Position(3:4) = [650,400];  % window size: [width, height]
se = strel('square', 3); % morphological filter for noise removal
i=0;
background = uint8(background);
while ~isDone(videoReader)
    i=i+1;
    frame = step(videoReader); % read the next video frame
    frameGray = (rgb2gray(frame)*255);
    backgroundSingle = single(background);
    pixeldifference = frameGray(pictureSize(1), pictureSize(2))-backgroundSingle(pictureSize(1), pictureSize(2));
    % Detect the foreground in the current video frame
    fgFrame = read(video, i);
    fgFrame = rgb2gray(fgFrame);
    fgFrame = uint8(fgFrame);
    if (pixeldifference > 5 || pixeldifference < -5)
        tempbackground = backgroundSingle+pixeldifference;
    else
        tempbackground=backgroundSingle;
    end
    fg = uint8(tempbackground) - fgFrame;
    fg = (fg >= 10) | (fg <= -10);
    % Use morphological opening to remove noise in the foreground
    filteredForeground = fg;
    filteredForeground = imopen(filteredForeground, se);
    filteredForeground = imerode(fg, se);

    % Detect the connected components with the specified minimum area, and
    % compute their bounding boxes
    bbox = step(blobAnalysis, filteredForeground);

    % Draw bounding boxes around the detected cars and lines
    result = insertShape(frame, 'Rectangle', bbox, 'Color', 'green');
    result = insertShape(result, 'line', [0 line2begin pictureSize(2) line2begin; 0 line1begin pictureSize(2) line1begin]);

    step(videoPlayer, result);  % display the results
end

release(videoReader); % close the video file

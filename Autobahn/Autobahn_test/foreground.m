%read Video
videoReader = VideoReader('Video 3.0 #1_STAB.mp4');

%get FrameSize
frame1 = read(videoReader, 1);
pictureSize = size(frame1);

%get Background
countMatrix = zeros(pictureSize(1), pictureSize(2), 50);
for i = 1:50
    countMatrix(1:end, 1:end, i) = rgb2gray(read(videoReader, i*20));   
end
background = zeros(pictureSize(1), pictureSize(2));
for i = 1:pictureSize(1)
    for j = 1:pictureSize(2)
        background(i,j) = mode(squeeze(countMatrix(i,j,1:50)));
    end
end
imshow(background, [0 365]); title('Video Frame');


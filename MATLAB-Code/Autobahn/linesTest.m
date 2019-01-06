%read Video
video = VideoReader('Video 3.0 #1_STAB.mp4');

%get FrameSize
frame1 = read(video, 1);
pictureSize = size(frame1);

%get Background
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
imshow(background, [0 255]); title('Video Frame');

lines = background >= 250;
lines = bwmorph(lines, 'skel', 10);
test = imopen(lines, strel('line', 6, 90));
imshow(test);
line1begin=0;
line2begin=0;
schwarz1 = 0;
weiss1 = 0;
schwarz2 = 0;
for i = 1:pictureSize(1)-1
    if (schwarz1 == 0) 
        for j = 1:pictureSize(2)-1
            if (test(pictureSize(1)-i, j) ~= 0)
                schwarz1 = 1;
            end
        end
    end
    if schwarz1 == 1
        if(weiss1==0)
            if(~(test(pictureSize(1)-i,1:end) ~= 0))
                weiss1 = 1;
                line1begin=pictureSize(1)-i;
            end
        end
    end
    if weiss1 == 1
        if(schwarz2==0)
            if (test(pictureSize(1)-i, j) ~= 0)
                schwarz2 = 1;
                line2begin = pictureSize(1)-i;
            end
        end
    end
end
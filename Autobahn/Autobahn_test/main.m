% Load Video
%Git
%/////////////////////////////////////////////////////////////////////////
trafficVid = VideoReader('edbv_autobahn_cut.mp4')
%trafficVid = VideoReader('traffic.mj2')
get(trafficVid)
%implay('edbv_autobahn_cut.mp4');  % show Video

% Select Reference-Image
%/////////////////////////////////////////////////////////////////////////

darkCarValue = 80;
darkCar = rgb2gray(read(trafficVid,262));
noDarkCar = imextendedmax(darkCar, darkCarValue);
imshow(darkCar)

figure, imshow(noDarkCar)

sedisk = strel('disk',2);
noSmallStructures = imopen(noDarkCar, sedisk);
figure, imshow(noSmallStructures)



% Algorithm 
%/////////////////////////////////////////////////////////////////////////

nframes = trafficVid.NumberOfFrames;
I = read(trafficVid, 1);
taggedCars = zeros([size(I,1) size(I,2) 3 nframes], class(I));

for k = 1 : nframes
    singleFrame = read(trafficVid, k);
    
    % Convert to grayscale to do morphological processing.
    I = rgb2gray(singleFrame);
    
    % Remove dark cars.
    noDarkCars = imextendedmax(I, darkCarValue); 
    
    % Remove lane markings and other non-disk shaped structures.
    noSmallStructures = imopen(noDarkCars, sedisk);

    % Remove small structures.
    noSmallStructures = bwareaopen(noSmallStructures, 150);
   
    % Get the area and centroid of each remaining object in the frame. The
    % object with the largest area is the light-colored car.  Create a copy
    % of the original frame and tag the car by changing the centroid pixel
    % value to red.
    taggedCars(:,:,:,k) = singleFrame;
   
    stats = regionprops(noSmallStructures, {'Centroid','Area'});
    if ~isempty([stats.Area])
        areaArray = [stats.Area];
        [junk,idx] = max(areaArray);
        c = stats(idx).Centroid;
        c = floor(fliplr(c));
        width = 2;
        row = c(1)-width:c(1)+width;
        col = c(2)-width:c(2)+width;
        taggedCars(row,col,1,k) = 255;
        taggedCars(row,col,2,k) = 0;
        taggedCars(row,col,3,k) = 0;
    end
end


% Post-Processed-Image 
%/////////////////////////////////////////////////////////////////////////

frameRate = trafficVid.FrameRate;
implay(taggedCars,frameRate);

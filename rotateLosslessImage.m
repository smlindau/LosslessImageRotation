%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function getRotatedPixelValues.m
% Written by: Scott Lindauer
% Last Edited: 07/10/2018
% Description: Input the start and end frame of a steady state pile from a
% video. First return the rotation angle required for the pile to be in
% line with the horizontal, as well as the far left and far right points in
% the pile and the pile height, then average these values against all of
% the frames. Use a trigonometric methodology to compute the subpixel
% rotation of each x-line of the pile.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function getRotatedPixelValues(startFrame,endFrame,fileName,pileNumber,...
    partNumber,x1,x2,y1,y2,theta)

if nargin == 9
    numberFrames = endFrame-startFrame;
    pixelValue = imrotate(importRawData(512,512,fileName,startFrame...
        ,numberFrames),90);
    pixelValue = pixelValue(y1:y2,x1:x2,:); %#ok<NASGU>
    save(strcat('pixelValue',num2str(partNumber),'Pile',num2str(pileNumber),...
        '.mat'),'pixelValue','-v7.3');
    clear pixelValue
    return
end

tic

if nargin == 10
    numberFrames = endFrame - startFrame;
    baseStack = imrotate(importRawData(512,512,fileName,startFrame,...
        numberFrames),-90);
    imageStack = baseStack(y1:y2,x1:x2,:);
    clear baseStack
    meanPileHeight = y2 - y1;
    numPixelScan = x2 - x1;
    pixelLocation = zeros(numPixelScan,2);
    pixelValue = zeros(y2-y1,x2-x1,numberFrames);
    meanAngle = theta;
    meanLeftPile = [213,87];
else
    % Set the total number of frames to be analyzed
    numberFrames = endFrame - startFrame;
    % Estimate the size of the stack in GB to determine RAM needed
    %estimatedSize = (numberFrames * 512^2 * 2) / 10^9;
    % Preset variables to speed up code
    angle = zeros(numberFrames,1);
    leftPile = zeros(numberFrames,2);
    rightPile = zeros(numberFrames,2);
    pileHeight = zeros(numberFrames,1);
    
    % For each frame in the image stack, determine the rotation angle, pile
    % height, and the leftmost and rightmost points on the pile
    parfor i = 1:numberFrames
        % Call a single frame and rotate it so that flow is -y direction
        baseImage = imrotate(importRawData(512,512,fileName,i+startFrame...
            ,1),90);
        % Use getRotationROI.m to determine the angle, height, and
        % leftmost/rightmost points of the pile
        [angle(i),~,leftPile(i,:),rightPile(i,:),...
            pileHeight(i)] = getRotationROI(baseImage);
    end
    
    % Determine averages to use for interpreting the data
    meanAngle = mean(angle);
    meanLeftPile(1,:) = mean(leftPile);
    meanRightPile(1,:) = mean(rightPile);
    meanPileHeight = ceil(mean(pileHeight))+5;
    
    % Set the total distance of the base of the pile and set the scan length to
    % be this distance plus 7 buffer pixels in each direction
    baseDistance = sqrt((meanLeftPile(1)-meanRightPile(1)).^2+...
        (meanLeftPile(2)-meanRightPile(2)).^2);
    numPixelScan = ceil(baseDistance)+20;
    
    % Preallocate variables for speed
    pixelLocation = zeros(numPixelScan,2);
    
    % Check if the image stack will be larger than the total RAM available; if
    % so, set up the variables for a for loop that steps through all of the
    % frames in a memory concise manner
    %if estimatedSize > 50
    %    forLoops = ceil(estimatedSize / 50);
    %    numberFrames = 10000;
    %else
    %    forLoops = 1;
    %end
    
    pixelValue = zeros(meanPileHeight,numPixelScan,numberFrames);
    
    % Step through a for loop once for every 50 GB of data to analyze
    %for i = 1:forLoops
    % Call the image stack from the source
    imageStack = im2double(imrotate(importRawData(512,512,fileName,...
        startFrame,numberFrames),-90));
end

j = 0;
% For the total height of the pile in pixels, step through the pile in
% horizontal slices one pixel at a time from bottom to top
for h = 1:meanPileHeight
    % For the total base distance of the pile, step through each pixel
    % horizontally to determine the rotated location of the pixel while
    % maintaining subpixel accuracy
    for d = 1:numPixelScan
        % For each step horizontally and each step vertically, compute
        % a new pixel location (non-integer) in the cartesian space
        pixelLocation(d,:) = [meanLeftPile(1) + (d-8)*cosd(meanAngle)...
            + (h-1)*sind(meanAngle),meanLeftPile(2)...
            + (d-8)*sind(meanAngle) - (h-1)*cosd(meanAngle)];
        %             plot(pixelLocation(d,1),pixelLocation(d,2),'r.');
        % Set a test rectangle around the rotated pixel location such
        % that a 1x1 px square is created with the new rotation angle
        testRectangle = getTestRectangle(pixelLocation(d,1),...
            pixelLocation(d,2),meanAngle);
        %             plot(testRectangle(:,1),testRectangle(:,2),'g.');
        % For each pixel within 1 px distance of the pixel location,
        % step through each pixel and determine the total overlap of
        % the pixel to the new pixel location
        for l = floor(min(testRectangle(:,1))):...
                ceil(max(testRectangle(:,1)))
            for m = floor(min(testRectangle(:,2))):...
                    ceil(max(testRectangle(:,2)))
                % Define the rectangle pixel to check for overlaps
                overlapPixel = [[l-.5 m-.5]' [l+.5 m-.5]'...
                    [l+.5 m+.5]' [l-.5 m+.5]']';
                % Run function getAreaOverlap.m to determine the total
                % area overlap of the pixels
                areaOverlap = getAreaOverlap(testRectangle,...
                    overlapPixel);
                % Assign the pixel value for the all images in the
                % stack multiplied by pixel overlap
                pixelValue(h,d,:) = pixelValue(h,d,:)...
                    + areaOverlap*imageStack(m,l,:);
            end
        end
        j = j + 1;
        disp(strcat(num2str(j),'/',num2str(meanPileHeight*numPixelScan),...
        ' pixels'))
    end
end
% Save the variable which contains the pixel values of the image stack
% of the pile to a single .mat file (it's max size should be ~ 5 GB)
clear imageStack
save(strcat('pixelValue',num2str(partNumber),'Pile',num2str(pileNumber),...
    '.mat'),'pixelValue','-v7.3');
clear pixelValue
% If the image stack is too large for the memory, then set the new
% start frame to be 10000 frames beyond the start position and loop
% back around
%    startFrame = numberFrames*i + 1;
%    if i == forLoops - 1
%        numberFrames = endFrame - startFrame;
%    end
%end

toc

end

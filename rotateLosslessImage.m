function rotatedImage = rotateLosslessImage(baseImage,rotateAngle)

baseImage = getNormalized(double(baseImage));

% Determine the size of the image
imageSize = size(baseImage);

% Pad the edges of the base image to be larger than the of maximum rotation
padLength = ceil(sqrt(imageSize(1)^2+imageSize(2)^2));
padLength = ceil([padLength-imageSize(1),padLength-imageSize(2)]);
baseImage = padarray(baseImage,padLength,'both');

% Initialize rotated image
if numel(imageSize) == 2
    rotatedImage = zeros(imageSize(1),imageSize(2));
else
    rotatedImage = zeros(imageSize(1),imageSize(2),imageSize(3));
end

rotatedImage = padarray(rotatedImage,padLength,'both');

clf
imshow(baseImage)
hold on

for row = 1+padLength(1):imageSize(1)+padLength(1)
    % Step through each pixel in the row and compute a new pixel location
  	for col = 1+padLength(2):imageSize(2)+padLength(2)
        
        plot(row,col,'ro')
        
		newPixelLoc(col,:) =...
            [col*cosd(rotateAngle) - row*sind(rotateAngle),...
            col*sind(rotateAngle) + row*cosd(rotateAngle)]; %#ok<AGROW>
			
        plot(newPixelLoc(col,2),newPixelLoc(col,1),'go')
        
        % Set a test rectangle around the rotated pixel location
		testRectangle = getTestRectangle(newPixelLoc(col,1),...
            newPixelLoc(col,2),rotateAngle);
        
        plot(testRectangle(:,2),testRectangle(:,1),'bo')
		
        % For each pixel within 1 px of the pixel location, find the overlap
		for i = floor(min(testRectangle(:,1))):...
                ceil(max(testRectangle(:,1)))
			for j = floor(min(testRectangle(:,2))):...
                    ceil(max(testRectangle(:,2)))
				
                % Define the rectangle pixel to check for overlaps
				overlapPixel = [[i-.5 j-.5]' [i+.5 j-.5]' ...
                    [i+.5 j+.5]' [i-.5 j+.5]']';
                
                plot(overlapPixel(:,2),overlapPixel(:,1),'r.')
				
                % Determine the area overlap of the pixels
				areaOverlap = getAreaOverlap(testRectangle,overlapPixel);
				
                % Assign the pixel value for the rotated image
				rotatedImage(row+padLength(2),col+padLength(1),:) = ...
                    rotatedImage(row,col,:) +...
                    areaOverlap*baseImage(j+padLength(2),i+padLength(1),:);
			end
		end
    end
    disp(row)
end

end

%%%%%%%%%% --- Anonymous Functions --- %%%%%%%%%%

%% Anonymous function for generating test rectangles
function rect = getTestRectangle(x,y,angle)

% Set the initial pixel location to create a rectangle around
point = [x,y];

% Generate a unit vector using the rotation angle
[xUnit, yUnit] = pol2cart(angle*pi/180,1);
unitVector = [xUnit, yUnit];

% Set the conjugate unit vector to complete the rotation matrix
conjUnitVector = [unitVector(2),-unitVector(1)];

% Evaluate the rotation matrix 
rowA = unitVector * .5;
rowB = conjUnitVector * .5;

% Assign the edges of the rectangle based on the rotation matrix
rect(1,:) = point + rowA + rowB;
rect(2,:) = point + rowA - rowB;
rect(3,:) = point - rowA - rowB;
rect(4,:) = point - rowA + rowB;

end

%% Anonymous function for determining the area overlap
% Uses the points of two quadrangles to determine the area overlap
function overlap = getAreaOverlap(testQuadrangle,overlapPixelQuadrangle)

% Assign the x and y coordinates of the test quadrangle to new variables
% and rotate them into a clockwise alignment; do the same for the overlap
% pixel quadrangle
xa = testQuadrangle(:,1);
ya = testQuadrangle(:,2);
[xa,ya] = poly2cw(xa,ya);
xb = overlapPixelQuadrangle(:,1);
yb = overlapPixelQuadrangle(:,2);
[xb,yb] = poly2cw(xb,yb);

% Use matlab's polybool function to determine the total overlap of the two
% quadrangles in clockwise alignment
[xc,yc] = polybool('and',xa,ya,xb,yb);
overlap = polyarea(xc,yc);

end

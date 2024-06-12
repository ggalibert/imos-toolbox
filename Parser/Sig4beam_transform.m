%%%%%%%%%%%%%%%%%%%%%
%% Import raw data %%
%%%%%%%%%%%%%%%%%%%%%

% Find .mat data file
[FILENAME,PATHNAME,FILTERINDEX] = uigetfile('*.mat','Choose Signature .mat file');
cd(PATHNAME);
clear FILTERINDEX

% Import velocity and sensor data
load(FILENAME);
clear PATHNAME FILENAME Descriptions Units

coord = Config.Average_CoordSystem;

% Extract data
datetime = double(Data.Average_Time);
if coord=='ENU'
    disp('Coordinate system is ENU.')
    v1 = double(Data.Average_VelEast);
    v2 = double(Data.Average_VelNorth);
    v3 = double(Data.Average_VelUp1);
    v4 = double(Data.Average_VelUp2);
elseif coord=='XYZ'
    disp('Coordinate system is XYZ.')
    v1 = double(Data.Average_VelX);
    v2 = double(Data.Average_VelY);
    v3 = double(Data.Average_VelZ1);
    v4 = double(Data.Average_VelZ2);
elseif coord=='BEAM'
    disp('Coordinate system is BEAM.')
    v1 = double(Data.Average_VelBeam1);
    v2 = double(Data.Average_VelBeam2);
    v3 = double(Data.Average_VelBeam3);
    v4 = double(Data.Average_VelBeam4);
end
A1 = double(Data.Average_AmpBeam1);
A2 = double(Data.Average_AmpBeam2);
A3 = double(Data.Average_AmpBeam3);
A4 = double(Data.Average_AmpBeam4);
C1 = double(Data.Average_CorBeam1);
C2 = double(Data.Average_CorBeam2);
C3 = double(Data.Average_CorBeam3);
C4 = double(Data.Average_CorBeam4);
heading = double(Data.Average_Heading);
pitch = double(Data.Average_Pitch);
roll = double(Data.Average_Roll);





%%%%%%%%%%%%%%%%%%%
%% Plot raw data %%
%%%%%%%%%%%%%%%%%%%

figure(1); clf
subplot(4,3,1)
pcolor(v1')
shading flat
colorbar
if coord=='ENU'
    title('Velocity ENU (m/s)')
elseif coord=='XYZ'
    title('Velocity XYZ (m/s)')
elseif coord=='BEAM'
    title('Velocity BEAM (m/s)')
end
subplot(4,3,4)
pcolor(v2')
shading flat
colorbar
subplot(4,3,7)
pcolor(v3')
shading flat
colorbar
subplot(4,3,10)
pcolor(v4')
shading flat
colorbar

subplot(4,3,2)
pcolor(A1')
shading flat
colorbar
title('Amplitude (dB)')
subplot(4,3,5)
pcolor(A2')
shading flat
colorbar
subplot(4,3,8)
pcolor(A3')
shading flat
colorbar
subplot(4,3,11)
pcolor(A4')
shading flat
colorbar

subplot(4,3,3)
pcolor(C1')
shading flat
colorbar
title('Correlation (%)')
subplot(4,3,6)
pcolor(C2')
shading flat
colorbar
subplot(4,3,9)
pcolor(C3')
shading flat
colorbar
subplot(4,3,12)
pcolor(C4')
shading flat
colorbar





%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Coordinate transforms %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Tranformation matrix for Signature
T = Config.Average_Beam2xyz;

clear Config

% Transform attitude data to radians
hh = pi * (heading-90)/180;
pp = pi * pitch/180;
rr = pi * roll/180;

[row,col] = size(v1);
Tmat = repmat(T,[1 1 row]);

clear T

% Make heading/tilt matrices
Hmat = zeros(3,3,row);
Pmat = zeros(3,3,row);

for i = 1:row
    Hmat(:,:,i) = [ cos(hh(i)) sin(hh(i))     0; ...
                   -sin(hh(i)) cos(hh(i))     0; ...
                             0          0     1];
    Pmat(:,:,i) = [cos(pp(i)) -sin(pp(i))*sin(rr(i)) -cos(rr(i))*sin(pp(i)); ...
                       0              cos(rr(i))            -sin(rr(i))    ; ...
                   sin(pp(i))  sin(rr(i))*cos(pp(i))  cos(pp(i))*cos(rr(i))];
end

clear heading pitch roll hh pp rr
 
% Add a fourth line in the matrix based on Transformation matrix by 
% copying line 3, and set (3,4) and (4,3) to 0. B3 and B4 will contribute 
% equally to the X and Y components, so (1,3) and (1,4) = (1,3)/2. The 
% same goes for (2,3) and (2,4)
% (1,1) (1,2) (1,3) (1,4)
% (2,1) (2,2) (2,3) (2,4)
% (3,1) (3,2) (3,3) (3,4)
% (4,1) (4,2) (4,3) (4,4)

% Make resulting transformation matrix
R1mat = zeros(4,4,row);
for i = 1:row
    R1mat(1:3,1:3,i) = Hmat(:,:,i)*Pmat(:,:,i);
    R1mat(4,1:4,i) = R1mat(3,1:4,i);
    R1mat(1:4,4,i) = R1mat(1:4,3,i);
end

R1mat(3,4,:) = 0; R1mat(4,3,:) = 0;
for i = 1:row
    Rmat(:,:,i) = R1mat(:,:,i)*Tmat(:,:,i);
end

clear Hmat Pmat R1mat

if coord=='ENU'
    E = v1; N = v2; U1 = v3; U2 = v4;
    
    %% ENU to BEAM [B1; B2; B3; B4] = inv(R) * [E; N; U1; U2]    
    BEAM = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            BEAM(i,j,:) = inv(Rmat(:,:,i)) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    B1 = BEAM(:,:,1); B2 = BEAM(:,:,2);
    B3 = BEAM(:,:,3); B4 = BEAM(:,:,4);
    
    %% ENU to XYZ [X; Y; Z1; Z2] = T * inv(R) * [E; N; U1; U2];
    XYZ = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            XYZ(i,j,:) = Tmat(:,:,i) * inv(Rmat(:,:,i)) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    X = XYZ(:,:,1); Y = XYZ(:,:,2);
    Z1 = XYZ(:,:,3); Z2 = XYZ(:,:,4);
    
elseif coord=='XYZ'
    X = v1; Y = v2; Z1 = v3; Z2 = v4;
    
    %% XYZ to ENU [E; N; U1; U2] = R * inv(T) * [X; Y; Z1; Z2]
    ENU = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            ENU(i,j,:) = Rmat(:,:,i) * inv(Tmat(:,:,i)) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    E = ENU(:,:,1); N = ENU(:,:,2);
    U1 = ENU(:,:,3); U2 = ENU(:,:,4);
    
    %% ENU to BEAM [B1; B2; B3; B4] = inv(R) * [E; N; U1; U2]
    BEAM = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            BEAM(i,j,:) = inv(Rmat(:,:,i)) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    B1 = BEAM(:,:,1); B2 = BEAM(:,:,2);
    B3 = BEAM(:,:,3); B4 = BEAM(:,:,4);
    
elseif coord=='BEAM'
    B1 = v1; B2 = v2; B3 = v3; B4 = v4;
    
    %% BEAM to ENU [E; N; U1; U2] = R * [B1; B2; B3; B4]
    ENU = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            ENU(i,j,:) = Rmat(:,:,i) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    E = ENU(:,:,1); N = ENU(:,:,2);
    U1 = ENU(:,:,3); U2 = ENU(:,:,4);
    
    %% ENU to XYZ [X; Y; Z1; Z2] = T * inv(R) * [E; N; U1; U2];
    XYZ = zeros(row,col,4);
    for i = 1:row
        for j = 1:col
            XYZ(i,j,:) = Tmat(:,:,i) * inv(Rmat(:,:,i)) * [v1(i,j); v2(i,j); v3(i,j); v4(i,j)];
        end
    end
    X = XYZ(:,:,1); Y = XYZ(:,:,2);
    Z1 = XYZ(:,:,3); Z2 = XYZ(:,:,4);
end

clear i j row col v1 v2 v3 v4 ENU XYZ BEAM Rmat Tmat





%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Plot transformed data %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%

figure(2); clf
subplot(4,3,1)
pcolor(B1')
shading flat
colorbar
title('Velocity BEAM (m/s)')
subplot(4,3,4)
pcolor(B2')
shading flat
colorbar
subplot(4,3,7)
pcolor(B3')
shading flat
colorbar
subplot(4,3,10)
pcolor(B4')
shading flat
colorbar

subplot(4,3,2)
pcolor(X')
shading flat
colorbar
title('Velocity XYZ (m/s)')
subplot(4,3,5)
pcolor(Y')
shading flat
colorbar
subplot(4,3,8)
pcolor(Z1')
shading flat
colorbar
subplot(4,3,11)
pcolor(Z2')
shading flat
colorbar

subplot(4,3,3)
pcolor(E')
shading flat
colorbar
title('Velocity ENU (m/s)')
subplot(4,3,6)
pcolor(N')
shading flat
colorbar
subplot(4,3,9)
pcolor(U1')
shading flat
colorbar
subplot(4,3,12)
pcolor(U2')
shading flat
colorbar




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Compare transformed data %%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isfield(Data,'Average_VelBeam1')

    figure(3); clf
    subplot(4,2,1)
    pcolor(B1')
    shading flat
    colorbar
    title('Velocity BEAM transformed (m/s)')
    subplot(4,2,3)
    pcolor(B2')
    shading flat
    colorbar
    subplot(4,2,5)
    pcolor(B3')
    shading flat
    colorbar
    subplot(4,2,7)
    pcolor(B4')
    shading flat
    colorbar

    subplot(4,2,2)
    pcolor(double(Data.Average_VelBeam1)')
    shading flat
    colorbar
    title('Velocity BEAM from software (m/s)')
    subplot(4,2,4)
    pcolor(double(Data.Average_VelBeam2)')
    shading flat
    colorbar
    subplot(4,2,6)
    pcolor(double(Data.Average_VelBeam3)')
    shading flat
    colorbar
    subplot(4,2,8)
    pcolor(double(Data.Average_VelBeam4)')
    shading flat
    colorbar

    figure(4); clf
    subplot(4,2,1)
    pcolor(X')
    shading flat
    colorbar
    title('Velocity XYZ transformed (m/s)')
    subplot(4,2,3)
    pcolor(Y')
    shading flat
    colorbar
    subplot(4,2,5)
    pcolor(Z1')
    shading flat
    colorbar
    subplot(4,2,7)
    pcolor(Z2')
    shading flat
    colorbar

    subplot(4,2,2)
    pcolor(double(Data.Average_VelX)')
    shading flat
    colorbar
    title('Velocity XYZ from software (m/s)')
    subplot(4,2,4)
    pcolor(double(Data.Average_VelY)')
    shading flat
    colorbar
    subplot(4,2,6)
    pcolor(double(Data.Average_VelZ1)')
    shading flat
    colorbar
    subplot(4,2,8)
    pcolor(double(Data.Average_VelZ2)')
    shading flat
    colorbar

    figure(5); clf
    subplot(4,2,1)
    pcolor(E')
    shading flat
    colorbar
    title('Velocity ENU transformed (m/s)')
    subplot(4,2,3)
    pcolor(N')
    shading flat
    colorbar
    subplot(4,2,5)
    pcolor(U1')
    shading flat
    colorbar
    subplot(4,2,7)
    pcolor(U2')
    shading flat
    colorbar

    subplot(4,2,2)
    pcolor(double(Data.Average_VelEast)')
    shading flat
    colorbar
    title('Velocity ENU from software (m/s)')
    subplot(4,2,4)
    pcolor(double(Data.Average_VelNorth)')
    shading flat
    colorbar
    subplot(4,2,6)
    pcolor(double(Data.Average_VelUp1)')
    shading flat
    colorbar
    subplot(4,2,8)
    pcolor(double(Data.Average_VelUp2)')
    shading flat
    colorbar

    figure(6); clf
    plot(datetime,B1(:,5),'b')
    hold on
    plot(datetime,double(Data.Average_VelBeam1(:,5)),'r')
    
end



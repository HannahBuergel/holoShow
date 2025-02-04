function mask_script(app, event)
% Performs:
%     - common mode correction
%     - shifting of scattering pattern and mask


%% PARAMETERS

HP_filter = app.handles.HPfiltering;
HP_radius = app.handles.HPfrequency;
LP_filter = app.handles.LPfiltering;
LP_radius = app.handles.LPfrequency;
IF_filter = app.handles.IF_filtering;
IF_value = app.handles.IF_value;
CM_thresh = app.handles.cm_thresh;
rowsToshift = round(app.handles.ycenter);
columnsToShift =  round(app.handles.xcenter);
slit = app.handles.add_slit;
shift = app.handles.add_shift;
SMOOTH_FACTOR = 5; % smooth parameter for mask
DO_SMOOTHING = app.handles.smoothMask;

% Switches for what to show
showMASKS = false; % show used mask
showCM = false; % show common mode correction
showSMOOTH = false; % show smoothed mask and pattern

%% LOAD DATA & MASK

origdata = app.handles.hologram.orig;
% try
%     origdata = origdata  .* (~app.handles.hummingbird_mask);
% catch
% %     warning('could not apply hummingbird mask')
%     fprintf('No applicable hummingbird mask.\n')
% end

origdata(abs(origdata)>=app.handles.adu_max) = 0; % set saturated pixels to 0
if IF_filter
    origdata(abs(origdata)>IF_value) = 0;
end
origdata(origdata<-50)=0;

if app.handles.load_mask
    mask = app.handles.origmask;
else
    mask = ones(1024);
end

mask(origdata==0)=0;

if showMASKS
    figure(113345) %#ok<*UNRCH>
    set(gcf, 'Name', 'showMASKS');
    subplot(131); imagesc(app.handles.origmask); axis image;
    subplot(132); imagesc(mask); axis image;
    subplot(133); imagesc(origdata); axis image; set(gca, 'ColorScale', 'log');
end

if ~isfield(app.handles,'hummingbird_mask')
    app.handles.hummingbird_mask = ones(size(app.handles.origmask));
end

% figure(3343); imagesc(app.handles.hummingbird_mask>0);

%% CENTER PICTURE & COMMON MODE

% CORRECTION OF CENTER SHIFT
data = simpleshift(origdata,[rowsToshift columnsToShift]);
mask = simpleshift(mask,[rowsToshift columnsToShift]);

% SECOND CORRECTION THROUH VARIANCE AND DETECTOR SHIFTS
dataShifted = simpleshift(data,[slit, shift]);
maskShifted = simpleshift(mask,[slit, shift]);
data(513+slit:end,:) = dataShifted(513+slit:end,:);
mask(513+slit:end,:) = maskShifted(513+slit:end,:);
mask(513:513+slit,:) = 0;
data(isnan(data)) = 0;

% HIGHPASS FILTERING %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Modified see below!
if HP_filter
    [X, Y] = meshgrid(-512:511,-512:511);
    lowp = X.^2+Y.^2<HP_radius^2; 
    mask(lowp)=0;
end

% LOWPASS FILTERING
if LP_filter
    [X, Y] = meshgrid(-512:511,-512:511);
    highp = X.^2+Y.^2>LP_radius^2;
    mask(highp)=0;
end

% COMMON MODE CORRECTION
if app.handles.do_cm
    for m=1:1024
        dat = data(1:512-columnsToShift,m);
        dat = dat(mask(1:512-columnsToShift,m)>0);
        dat = dat(dat<CM_thresh);
        CM = median(dat);
        if ~isnan(CM)
            data(1:512-columnsToShift,m) = data(1:512-columnsToShift,m)-CM.*mask(1:512-columnsToShift,m);
        end
        
        dat = data(513-columnsToShift:1024,m);
        dat = dat(mask(513-columnsToShift:1024,m)>0);
        dat = dat(dat<CM_thresh);
        CM = median(dat);
        if ~isnan(CM)
            data(513-columnsToShift:1024,m) = data(513-columnsToShift:1024,m)-CM.*mask(513-columnsToShift:1024,m);
        end
    end
end
data(data<app.handles.adu_min)=0;

if showCM
    cmFig = figure(22); clf;
    set(cmFig, 'Name', 'showCM');
    cmTL = tiledlayout(cmFig, 'flow');
    
    cmAx(1) = nexttile(cmTL);
    imagesc(cmAx(1), origdata.*mask);
    colormap(hesperia);
    axis(cmAx(1), 'image');
    cmAx(1).ColorScale = 'log';
    cmAx(1).CLim(1) = 0.1;
    
    cmAx(2) = nexttile(cmTL);
    imagesc(cmAx(2), mask); 
    axis(cmAx(2), 'image');
%     cmAx(2).ColorScale = 'log';
%     cmAx(3).CLim(1) = 0.1;
%     subplot(222);
%     imagesc(mask);
%     axis image;
    
    cmAx(3) = nexttile(cmTL);
    imagesc(cmAx(3), data.*mask); 
    axis(cmAx(3), 'image');
    cmAx(3).ColorScale = 'log';
    cmAx(3).CLim(1) = 0.1;
end

%% SMOOTH MASK

if DO_SMOOTHING
    blurred=imgaussfilt(mask,SMOOTH_FACTOR);
    newMask = 1-(blurred<0.99);
    newMask=imgaussfilt(newMask,SMOOTH_FACTOR);
else
    newMask = mask;
end

newMask(~mask)=0;

if showSMOOTH
    figure(35234); clf;
    set(gcf, 'Name', 'showSMOOTH');
    subplot(121); imagesc(newMask); axis square; colormap gray; colorbar;
    subplot(122); imagesc(log(abs(newMask)),[0 8]); axis square; colormap fire; colorbar;
end

app.handles.mask = newMask;
app.handles.hardmask = mask;
app.handles.hologram.masked = data.*newMask;

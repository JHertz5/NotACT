clc
close all
clearvars -EXCEPT showPlots SNR_dB

%add data directory to path
if contains(pwd, 'ACT')
    dataPath = strcat( extractBefore(pwd, 'ACT'), 'ACT/data');
    addpath(char(dataPath));
else
    dataPath = ''; %dataPath is empty vector
    fprintf('Move to ACT directory\n');
end

fprintf('Q2\n')

%% Initialise Values

% SNR_dB
if ~exist('SNR_dB', 'var')
    SNR_dB = input('INPUT REQUIRED: Enter channel SNR level in dB: ');
    if isempty(SNR_dB)
        SNR_dB = 40;
        fprintf('\tNo value entered, SNR set to default value\n')
    end
end
fprintf('SNR set to %i dB\n', SNR_dB);

% showPlots
if ~exist('showPlots', 'var') || isempty(showPlots)
    showPlots = input('INPUT REQUIRED: Enter showPlots value: ');
    if isempty(SNR_dB)
        showPlots = 1;
        fprintf('\tshowPlots set to default value of 1\n')
    end
end
if showPlots == 0
    fprintf('showPlots == 0, no plots will be shown\n')
else
    fprintf('showPlots == %i\n', showPlots)
end

% phi
X = 8;  % H => 8
Y = 10; % J => 10
phi = X + 2*Y;
fprintf('X = %i, Y = %i -> phi = %i\n', X, Y, phi)

%% Read & Convert Photos

fprintf('Reading and converting images ... \n')

imgSize = 160*112*3*8;

figure

fprintf('\tReading image 1\n')
subplot(1,3,1)
[img1, imgW, imgH] = fImageSource('Photo1.jpg', imgSize);
fprintf('\tReading image 2\n')
subplot(1,3,2)
[img2, ~, ~] = fImageSource('Photo2.jpg', imgSize);
title('Original Images - 1, 2, 3')
fprintf('\tReading image 3\n')
subplot(1,3,3)
[img3, ~, ~] = fImageSource('Photo3.jpg', imgSize);
fprintf('\tComplete\n')

%% Transmitter Start

fprintf('Transmitter\n')

%% Generate M sequences

fprintf('\tGenerating M sequences ...\n')

MSeq1 = fMSeqGen([1 0 0 1 1]); % D^4 + D^1 + 1
MSeq2 = fMSeqGen([1 1 0 0 1]); % D^4 + D^3 + 1

fprintf('\t\tComplete\n')

%% Generate Gold sequences

fprintf('\tGenerating Gold sequences ...\n')

delayGold = 1 + mod(X + Y, 12); % all values above initial delayGold satisfy the inequality
goldSeq1 = fGoldSeq(MSeq1, MSeq2, delayGold);

while sum(goldSeq1, 1) ~= 8 % while gold code is not balanced
    fprintf('\t\tdelayGold = %i does not provide balanced gold sequence\n', delayGold);
    delayGold = delayGold + 1;
    goldSeq1 = fGoldSeq(MSeq1, MSeq2, delayGold);
end

fprintf('\t\tdelayGold = %i  is the smallest integer to satsfy inequality and provide balanced gold sequence\n', delayGold);

goldSeq2 = fGoldSeq(MSeq1, MSeq2, delayGold + 1); % gold sequence for user 2 uses d + 1
goldSeq3 = fGoldSeq(MSeq1, MSeq2, delayGold + 2); % gold sequence for user 3 uses d + 2

if exist('showPlots', 'var') && showPlots >= 3
    figure
    
    subplot (2,2,1) % top left
    stairs(MSeq1, 'LineWidth', 2, 'Marker', 'x')
    ylabel('PN Sequence 1')
    xlim([1 15])
    
    subplot (2,2,3) % bottom left
    stairs(MSeq2, 'LineWidth', 2, 'Marker', 'x')
    ylabel('PN Sequence 2')
    xlabel('Sequence index')
    xlim([1 15])
    
    subplot (3,2,2) % top right
    stairs(goldSeq1, 'LineWidth', 2, 'Marker', 'x')
    ylabel('Gold Seq 1')
    xlim([1 15])
    
    subplot (3,2,4) % middle right
    stairs(goldSeq2, 'LineWidth', 2, 'Marker', 'x')
    ylabel('Gold Seq 2')
    xlim([1 15])
    
    subplot (3,2,6) % bottom right
    stairs(goldSeq3, 'LineWidth', 2, 'Marker', 'x')
    ylabel('Gold Seq 3')
    xlabel('Sequence index')
    xlim([1 15])
end

fprintf('\t\tComplete\n')

%% Generate Pilot Sequences and Concatenate Transmissions

% Pilot Sequence is prepended to each transmission to allow the receiver to
% estimate channel delay, which is then used to synchronise matched filters

pilotSeq = [ 1 1 0 1 1 0 0 0 1 1 ]';
transmissiondata1 = cat(1,pilotSeq,img1);
transmissiondata2 = cat(1,pilotSeq,img2);
transmissiondata3 = cat(1,pilotSeq,img3);

%% Perform DS-QPSK modulation 

fprintf('\tPerforming DS-QPSK modulation ...\n')

fprintf('\t\tModulating image 1\n')
symbols1 = fDSQPSKModulator(transmissiondata1, goldSeq1, phi);
fprintf('\t\tModulating image 2\n')
symbols2 = fDSQPSKModulator(transmissiondata2, goldSeq2, phi);
fprintf('\t\tModulating image 3\n')
symbols3 = fDSQPSKModulator(transmissiondata3, goldSeq3, phi);

%% Plotting Transmitter Data

if exist('showPlots', 'var') && showPlots >= 1
    
    figure
    scatter(real(symbols1), imag(symbols1), 75, 'x')
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('Constellation Diagram of QPSK symbols - Transmitter 1 Output')
    ylabel('Quadrature')
    xlabel('In Phase')
    grid on
end

fprintf('\t\tComplete\n')

%% Channel Start

fprintf('Channel\n')

%% Initialise Channel Values

fprintf('\tInitialising channel values ...\n')

paths = [ 3; 1; 1 ];
symbolsIn = (cat(2, symbols1, symbols2, symbols3))';
delay = [ mod(X+Y,4); 4+mod(X+Y,5); 9+mod(X+Y,6); 8; 13 ];
beta  = [ 0.8; 0.4*exp(-1j*deg2rad(40)); 0.8*exp(1j*deg2rad(80)); 0.5; 0.2 ];
DOA = [ 30 0; 45 0; 20 0; 80 0; 150 0 ];
array = [ 0 0 0 ]; % no array in this case

fprintf('\t\tComplete\n')

%% Apply Channel Effects

fprintf('\tApplying channel effects ...\n')

symbolsOut = fChannel(paths, symbolsIn, delay, beta, DOA, SNR_dB, array); % SNR = 0dB

fprintf('\t\tComplete\n')

%% Plotting Channel Data
if exist('showPlots', 'var') && showPlots >= 5
    
    % Plot SNR examples
    
    symbolsOut_0  = fChannel(paths, symbolsIn, delay, beta, DOA,  0, array); % SNR = 0dB
    symbolsOut_20 = fChannel(paths, symbolsIn, delay, beta, DOA, 20, array); % SNR = 20dB
    symbolsOut_30 = fChannel(paths, symbolsIn, delay, beta, DOA, 30, array); % SNR = 30dB
    symbolsOut_40 = fChannel(paths, symbolsIn, delay, beta, DOA, 40, array); % SNR = 40dB
    
    figure
    
    subplot(2,2,1)
    scatter(real(symbolsOut_0), imag(symbolsOut_0), 'yx')
    hold on
    scatter(real(symbols1), imag(symbols1), 'bx', 'LineWidth', 2)
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('Channel Outpt - SNR = 0dB')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    grid on
    
    subplot(2,2,2)
    scatter(real(symbolsOut_20), imag(symbolsOut_20), 'yx')
    hold on
    scatter(real(symbols1), imag(symbols1), 'bx', 'LineWidth', 2)
    xlim([-2 2]);
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('SNR = 20dB')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    grid on
    
    subplot(2,2,3)
    scatter(real(symbolsOut_30), imag(symbolsOut_30), 'yx')
    hold on
    scatter(real(symbols1), imag(symbols1), 'bx', 'LineWidth', 2)
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('SNR = 30dB')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    grid on
    
    subplot(2,2,4)
    scatter(real(symbolsOut_40), imag(symbolsOut_40), 'yx')
    hold on
    scatter(real(symbols1), imag(symbols1), 'bx', 'LineWidth', 2)
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('SNR = 40dB')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    grid on
    
    clearvars symbolsOut_* % clear temporary values
end

if exist('showPlots', 'var') && showPlots >= 3
    
    % Plot examples for individual paths
    symbolsOut_singlePath1 = fChannel(1, symbols1', delay(1), beta(1), DOA(1,:), 40, array);
    symbolsOut_singlePath2 = fChannel(1, symbols2', delay(2), beta(2), DOA(2,:), 40, array);
    symbolsOut_singlePath3 = fChannel(1, symbols3', delay(3), beta(3), DOA(3,:), 40, array);
    
    % plot clean channel
    figure
    hold on
    scatter(real(symbolsOut_singlePath1), imag(symbolsOut_singlePath1), 'rx')
    scatter(real(symbolsOut_singlePath2), imag(symbolsOut_singlePath2), 'gx')
    scatter(real(symbolsOut_singlePath3), imag(symbolsOut_singlePath3), 'yx')
    scatter(real(symbols1), imag(symbols1), 'bx', 'LineWidth', 2)
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('Constellation Diagram of QPSK symbols - Individual Paths of Transmission 1, SNR = 40dB')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    legend('User 1','User 2','User 3','Ideal','Location','southeast')
    grid on
    
    symbolsOut_cleanChannel = symbols1 + symbols2 + symbols3;
    
    figure
    hold on
    scatter(real(symbolsOut_cleanChannel), imag(symbolsOut_cleanChannel), 'rx')
    scatter(real(symbols1), imag(symbols1), 'b.', 'LineWidth', 2)
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('Constellation Diagram of QPSK symbols - Clean Channel Ouput')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    legend('Clean Channel','Ideal','Location','southeast')
    grid on
    
    clearvars symbolsOut_cleanChannel symbolsOut_singlePath*
end

%% Receiver Start

fprintf('Receiver\n')

%% Estimate Delay using Pilot Sequence

fprintf('\tEstimating channel delay ...\n')


pilotSeqLength = length(pilotSeq);
pilotSymbolsLength = pilotSeqLength/2*length(goldSeq1);
pathSymbolsStart = zeros(3,1);
pathSymbolsEnd   = zeros(3,1);
pathSymbolsReceived = zeros(length(symbols1) - pilotSymbolsLength,3);
delayEstimates = -ones(3,1);
maxDelay = length(symbolsOut) - length(symbolsIn);

for pathIndex = 1:3 % for each path of user 1's transmission
    testOffset = 0;
    pilotSeqReceived = zeros(pilotSeqLength,1);
    while (delayEstimates(pathIndex) == -1) && (testOffset <= maxDelay)
        
        pilotSymbolsRange = testOffset+1:pilotSymbolsLength+testOffset;
        pilotSeqReceived = fDSQPSKDemodulator(symbolsOut(pilotSymbolsRange)./beta(pathIndex), goldSeq1, phi);
        
        % beta(2) causes a phase shift < 45 deg, so path1 can still be detected
        % when looking at path 2. Path 1 has a shorter delay than path 2, so 
        % when looking for path 2 pilot symbols, we will find those from path 1 
        % first. Therefore, we skip a detected delay if another path has already
        % been assigned this delay.
        if (all(pilotSeqReceived == pilotSeq)) && ~(any(delayEstimates == testOffset))
            delayEstimates(pathIndex) = testOffset; % set delay once received pilot matches original
            fprintf('\t\tDelay of path %i estimated to be %i\n', pathIndex, delayEstimates(pathIndex))
        else
            testOffset = testOffset + 1;
        end
    end
    
    % if delay could not be found, we will 'cheat' for the purposes of
    % completing the simulation
    if delayEstimates(pathIndex) == -1
        delayEstimates(pathIndex) = delay(pathIndex);
        fprintf('NOTE: Delay %i could not be found, using actual value without estimation\n', pathIndex)
    end
        
    % Extract delayed signal and compensate for fading by dividing with beta
    pathSymbolsStart(pathIndex) = pilotSymbolsLength + delayEstimates(pathIndex) + 1;
    pathSymbolsEnd(pathIndex)   = length(symbols1) + delayEstimates(pathIndex); % symbols1 includes pilot symbols, so no need to add pilot symbols length
    pathSymbolsReceived(:,pathIndex) = symbolsOut(pathSymbolsStart(pathIndex):pathSymbolsEnd(pathIndex))./beta(pathIndex);
end

fprintf('\t\tComplete\n')

%% Plot Receiver input

if exist('showPlots', 'var') && showPlots >= 1
    % Plot constellation diagram
    figure
    hold on
    scatter(real(symbolsOut), imag(symbolsOut), 'b.')
    line(xlim, [0 0], 'Color', 'black') % x axis line
    line([0 0], ylim, 'Color', 'black') % y axis line
    title('Constellation Diagram of QPSK symbols - Receiver Input')
    ylabel('Imaginary Axis')
    xlabel('Real Axis')
    grid on
end

%% Perform DS-QPSK demodulation

fprintf('\tPerforming DS-QPSK de-modulation ...\n')

pathImgReceived = zeros(length(img1), 3);
for pathIndex = 1:3
    fprintf('\t\tDe-modulating path %i\n', pathIndex)
    pathImgReceived(:,pathIndex) = fDSQPSKDemodulator(pathSymbolsReceived(:,pathIndex) , goldSeq1, phi);
end

fprintf('\t\tComplete\n')

%% Analysis of Receiver Data

figure
subplot(2,2,1)
fImageSink(img1, imgSize, imgW, imgH)
title('Original')

pathErrorRatio = zeros(3,1);

for pathIndex = 1:3
    pathErrorRatio(pathIndex) = length(find(img1 ~= pathImgReceived(:,pathIndex)))/length(img1);
    fprintf('\t%f%% of received image values are incorrect\n',pathErrorRatio(pathIndex)*100)
    
    if exist('showPlots', 'var') && showPlots >= 1
        % Display images
        fprintf('\tPlotting received image 1\n')
        
        subplot(2,2,pathIndex+1)
        fImageSink(pathImgReceived(:,pathIndex), imgSize, imgW, imgH)
        title('Received')
    end
end

%% End of Simulation

fprintf('Simulation complete\n')
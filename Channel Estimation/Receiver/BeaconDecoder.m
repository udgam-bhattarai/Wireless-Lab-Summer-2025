%% Enhanced WiFi Beacon Detection and Channel Estimation using USRP B210
% This script captures 802.11n WiFi signals, detects beacon frames using STF correlation,
% and performs channel estimation using LTF analysis with improved robustness

clear; clc; close all;

% ------------ SDR Parameters ------------
centerFreq = 2.437e9;      % Channel 1 (2.4 GHz band)
sampleRate = 20e6;         % 20 MHz bandwidth for 802.11n
captureTime = 10;          % Duration in seconds
gain = 30;                 % Adjust as needed
samplesPerFrame = 2048;

% ------------ Detection Parameters ------------
corrThreshold = 1.2;       % STF correlation threshold (increased to reduce false positives)
minPeakDistance = 1600;    % Minimum samples between detections (80us at 20MHz)
maxDetectionsPerFrame = 2; % Limit detections per frame
beaconInterval = 0.1;      % Expected beacon interval (100ms)
numFrames = ceil(captureTime * sampleRate / samplesPerFrame);

% ------------ SDRu Receiver Setup ------------
try
    rx = comm.SDRuReceiver( ...
        'Platform', 'B210', ...
        'SerialNum', '344C4DE', ... % Replace with your USRP B210 serial
        'CenterFrequency', centerFreq, ...
        'SampleRate', sampleRate, ...
        'Gain', gain, ...
        'SamplesPerFrame', samplesPerFrame, ...
        'OutputDataType', 'double');
    
    fprintf('📡 USRP B210 initialized successfully\n');
    fprintf('📊 Center Freq: %.3f GHz | Sample Rate: %.1f MHz | Gain: %d dB\n', ...
            centerFreq/1e9, sampleRate/1e6, gain);
catch ME
    error('Failed to initialize USRP: %s', ME.message);
end

% ------------ Generate Reference Signals ------------
fprintf('🔧 Generating 802.11n reference signals...\n');
stf = generate80211nSTF();
ltf = generate80211nLTF();
stfConj = conj(flip(stf));  % Pre-compute conjugate for correlation

% ------------ Pre-allocate Storage ------------
beaconCount = 0;
detectionLog = [];
channelEstimates = [];
signalPowers = [];

% Valid subcarriers for channel analysis (avoid DC and guard bands)
validSubcarriers = [7:31, 34:58]; % Skip DC (33) and edge carriers

fprintf('\n📡 Starting capture for %.1f seconds...\n\n', captureTime);
fprintf('Frame | Time(s) | Peak | SNR(dB) | Channel Info\n');
fprintf('------|---------|------|---------|-------------\n');

% ------------ Main Detection Loop ------------
for k = 1:numFrames
    % Capture samples
    [rxData, len] = rx();
    if len == 0
        continue;
    end
    
    % Calculate timestamp
    timestamp = k * samplesPerFrame / sampleRate;
    
    % Normalize received data
    rxPower = mean(abs(rxData).^2);
    rxData = rxData / sqrt(rxPower); % Preserve power information
    
    % STF correlation for packet detection
    corrSignal = abs(conv(stfConj, rxData));
    
    % Find correlation peaks with stricter criteria
    [peaks, locs] = findpeaks(corrSignal, ...
        'MinPeakHeight', corrThreshold, ...
        'MinPeakDistance', minPeakDistance, ...
        'NPeaks', maxDetectionsPerFrame, ...  % Limit peaks per frame
        'SortStr', 'descend');  % Get strongest peaks first
    
    % Process each detected peak with additional validation
    for p = 1:length(peaks)
        peakVal = peaks(p);
        peakIdx = locs(p);
        
        % Time-based filtering: ensure reasonable spacing between beacons
        if exist('lastDetectionTime', 'var') && timestamp - lastDetectionTime < beaconInterval * 0.8
            continue; % Skip if too soon after last detection
        end
        
        % Estimate SNR
        noiseFloor = median(corrSignal);
        snrEstimate = 20 * log10(peakVal / noiseFloor);
        
        % Additional SNR threshold
        if snrEstimate < 6  % Minimum 6dB SNR
            continue;
        end
        
        % Validate peak location for LTF extraction
        ltfStart = peakIdx + length(stf);
        ltfLength = 160; % 2 x 64-sample symbols + 16-sample CPs
        
        if ltfStart + ltfLength - 1 <= length(rxData) && peakIdx > length(stf)
            beaconCount = beaconCount + 1;
            lastDetectionTime = timestamp;  % Update last detection time
            
            % Extract and process LTF
            ltfRx = rxData(ltfStart : ltfStart + ltfLength - 1);
            
            % Channel estimation
            [channelEst, channelMag, channelPhase] = estimateChannel(ltfRx);
            
            % Store results
            detectionLog(end+1,:) = [k, timestamp, peakVal, snrEstimate];
            channelEstimates(end+1,:) = channelEst;
            signalPowers(end+1) = rxPower;
            
            % Channel statistics
            avgChannelGain = mean(channelMag);
            channelStd = std(channelMag);
            phaseSpread = std(unwrap(channelPhase)) * 180/pi;
            
            % Display detection info (limit output frequency)
            if mod(beaconCount, 5) == 1 || beaconCount <= 10  % Show every 5th detection after first 10
                fprintf('%5d | %7.3f | %4.2f | %6.1f | Gain:%.2f±%.2f, Phase:%.1f°\n', ...
                    k, timestamp, peakVal, snrEstimate, avgChannelGain, channelStd, phaseSpread);
            end
            
            % Optional: Plot channel response for first few detections
            if beaconCount <= 3
                plotChannelResponse(channelEst, validSubcarriers, beaconCount);
            end
        end
    end
end

% ------------ Cleanup and Summary ------------
release(rx);
fprintf('\n📊 Capture completed!\n');
fprintf('📈 Statistics:\n');
fprintf('   Total frames processed: %d\n', numFrames);
fprintf('   Beacons detected: %d\n', beaconCount);
fprintf('   Detection rate: %.1f%%\n', 100 * beaconCount / numFrames);

if beaconCount > 0
    fprintf('   Average SNR: %.1f dB\n', mean(detectionLog(:,4)));
    fprintf('   SNR range: %.1f - %.1f dB\n', min(detectionLog(:,4)), max(detectionLog(:,4)));
    
    % Plot detection timeline
    plotDetectionSummary(detectionLog, channelEstimates, validSubcarriers);
end

%% ------------ Helper Functions ------------

function stf = generate80211nSTF()
    % Generate 802.11n Short Training Field (same as 802.11a/g)
    % STF uses specific subcarriers with known pattern
    
    freqDomain = zeros(1, 64);
    
    % STF non-zero subcarriers (every 4th from -24 to +24, excluding DC)
    stfSubcarriers = [-24, -20, -16, -12, -8, -4, 4, 8, 12, 16, 20, 24];
    stfIndices = stfSubcarriers + 33; % Convert to MATLAB 1-based indexing
    
    % STF values for these subcarriers
    stfValues = sqrt(13/6) * [1, -1, 1, 1, -1, 1, 1, 1, -1, -1, 1, -1];
    
    % Assign values to frequency domain
    freqDomain(stfIndices) = stfValues;
    
    % Convert to time domain
    timeDomain = ifft(ifftshift(freqDomain));
    
    % STF consists of 10 repetitions of first 16 samples
    stf = repmat(timeDomain(1:16), 1, 10);
end

function ltf = generate80211nLTF()
    % Generate 802.11n Legacy Long Training Field
    freqDomain = zeros(1, 64);
    indices = [-26:-1, 1:26] + 33; % MATLAB 1-based indexing
    
    % LTF sequence in frequency domain
    ltfSequence = [1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 ...
                   1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1];
    
    freqDomain(indices) = ltfSequence;
    timeDomain = ifft(ifftshift(freqDomain));
    
    % Create LTF: Cyclic prefix (last 32 samples) + 2 complete symbols
    ltf = [timeDomain(33:64), timeDomain, timeDomain];
end

function [channelEst, channelMag, channelPhase] = estimateChannel(ltfRx)
    % Estimate channel using received LTF
    N = 64;
    cpLen = 32; % LTF uses 32-sample CP (not 16 like data)
    
    % Extract two LTF symbols (remove CP)
    if length(ltfRx) >= cpLen + 2*N
        ltf1 = ltfRx(cpLen + (1:N));
        ltf2 = ltfRx(cpLen + N + (1:N));
        
        % FFT of received symbols
        H1 = fft(ltf1);
        H2 = fft(ltf2);
        
        % Average for better estimate
        channelEst = (H1 + H2) / 2;
    else
        % Fallback if insufficient samples
        ltfSymbol = ltfRx(end-N+1:end);
        channelEst = fft(ltfSymbol);
    end
    
    % Calculate magnitude and phase
    channelMag = abs(channelEst);
    channelPhase = angle(channelEst);
end

function plotChannelResponse(channelEst, validSubcarriers, detectionNum)
    % Plot channel frequency response
    figure(100 + detectionNum);
    
    % Magnitude response
    subplot(2,1,1);
    plot(validSubcarriers-33, 20*log10(abs(channelEst(validSubcarriers))), 'b.-', 'LineWidth', 1.5);
    grid on;
    title(sprintf('Channel Magnitude Response - Detection #%d', detectionNum));
    xlabel('Subcarrier Index');
    ylabel('Magnitude (dB)');
    
    % Phase response
    subplot(2,1,2);
    plot(validSubcarriers-33, unwrap(angle(channelEst(validSubcarriers)))*180/pi, 'r.-', 'LineWidth', 1.5);
    grid on;
    title('Channel Phase Response');
    xlabel('Subcarrier Index');
    ylabel('Phase (degrees)');
end

function plotDetectionSummary(detectionLog, channelEstimates, validSubcarriers)
    % Create summary plots
    figure(200);
    
    % Detection timeline
    subplot(3,1,1);
    plot(detectionLog(:,2), detectionLog(:,3), 'bo-', 'LineWidth', 1);
    grid on;
    title('Beacon Detection Timeline');
    xlabel('Time (seconds)');
    ylabel('Correlation Peak');
    
    % SNR over time
    subplot(3,1,2);
    plot(detectionLog(:,2), detectionLog(:,4), 'ro-', 'LineWidth', 1);
    grid on;
    title('SNR Estimation');
    xlabel('Time (seconds)');
    ylabel('SNR (dB)');
    
    % Average channel magnitude
    if size(channelEstimates, 1) > 0
        subplot(3,1,3);
        avgChannel = mean(abs(channelEstimates(:, validSubcarriers)), 1);
        plot(validSubcarriers-33, 20*log10(avgChannel), 'g.-', 'LineWidth', 1.5);
        grid on;
        title('Average Channel Magnitude Response');
        xlabel('Subcarrier Index');
        ylabel('Magnitude (dB)');
    end
    
    % Adjust figure size
    set(gcf, 'Position', [100, 100, 800, 600]);
end

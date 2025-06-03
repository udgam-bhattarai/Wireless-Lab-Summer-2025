%%% Enhanced WiFi Beacon Detection and Channel Estimation using USRP B210
% This script captures 802.11n WiFi signals, detects beacon frames using STF correlation,
% and performs channel estimation using LTF analysis with improved robustness

clear; clc; close all;

% ------------ SDR Parameters ------------
centerFreq = 2.437e9;      % Channel 6 (2.437 GHz)
sampleRate = 20e6;         % 20 MHz bandwidth for 802.11n
captureTime = 10;          % Duration in seconds
gain = 30;                 % Adjust as needed
samplesPerFrame = 2048;

% ------------ Detection Parameters ------------
corrThreshold = 1.4;       % Increased STF correlation threshold
minPeakDistance = 1600;    % Minimum spacing between peaks (80us at 20MHz)
maxDetectionsPerFrame = 2; % Limit detections per frame
beaconInterval = 0.1;      % Expected beacon interval in seconds
numFrames = ceil(captureTime * sampleRate / samplesPerFrame);

% ------------ SDRu Receiver Setup ------------
try
    rx = comm.SDRuReceiver( ...
        'Platform', 'B210', ...
        'SerialNum', '344C57A', ... % Replace with your USRP B210 serial
        'CenterFrequency', centerFreq, ...
        'SampleRate', sampleRate, ...
        'Gain', gain, ...
        'SamplesPerFrame', samplesPerFrame, ...
        'OutputDataType', 'double');
    fprintf('📡 USRP B210 initialized successfully\n');
catch ME
    error('Failed to initialize USRP: %s', ME.message);
end

% ------------ Generate Reference Signals ------------
stf = generate80211nSTF();
ltf = generate80211nLTF();
stfConj = conj(flip(stf));

% ------------ Pre-allocate Storage ------------
beaconCount = 0;
detectionLog = [];
channelEstimates = [];
signalPowers = [];
validSubcarriers = [7:31, 34:58];

fprintf('\n📡 Starting capture for %.1f seconds...\n\n', captureTime);
fprintf('Frame | Time(s) | Peak | SNR(dB) | Channel Info\n');
fprintf('------|---------|------|---------|-------------\n');

for k = 1:numFrames
    [rxData, len] = rx();
    if len == 0
        continue;
    end

    timestamp = k * samplesPerFrame / sampleRate;
    rxPower = mean(abs(rxData).^2);

    % Skip very low power frames
    if rxPower < 0.005
        continue;
    end

    rxData = rxData / sqrt(rxPower);
    corrSignal = abs(conv(stfConj, rxData));

    [peaks, locs] = findpeaks(corrSignal, ...
        'MinPeakHeight', corrThreshold, ...
        'MinPeakDistance', minPeakDistance, ...
        'NPeaks', maxDetectionsPerFrame, ...
        'SortStr', 'descend');

    for p = 1:length(peaks)
        peakVal = peaks(p);
        peakIdx = locs(p);

        % Time spacing filter
        minSpacing = beaconInterval * 0.8;
        maxSpacing = beaconInterval * 1.2;
        if exist('lastDetectionTime', 'var')
            timeSinceLast = timestamp - lastDetectionTime;
            if timeSinceLast < minSpacing || (beaconCount > 2 && timeSinceLast > maxSpacing * 3)
                continue;
            end
        end

        noiseFloor = median(corrSignal);
        snrEstimate = 20 * log10(peakVal / noiseFloor);
        if snrEstimate < 8
            continue;
        end

        ltfStart = peakIdx + length(stf);
        ltfLength = 160;
        if ltfStart + ltfLength - 1 <= length(rxData) && peakIdx > length(stf)
            ltfRx = rxData(ltfStart : ltfStart + ltfLength - 1);
            [channelEst, channelMag, channelPhase] = estimateChannel(ltfRx);

            % CFR similarity filter
            if beaconCount >= 2
                prevCFR = channelEstimates(end, validSubcarriers);
                currCFR = channelEst(validSubcarriers);
                similarity = norm(currCFR - prevCFR) / norm(prevCFR);
                if similarity > 0.5
                    continue;
                end
            end

            beaconCount = beaconCount + 1;
            lastDetectionTime = timestamp;

            detectionLog(end+1,:) = [k, timestamp, peakVal, snrEstimate];
            channelEstimates(end+1,:) = channelEst;
            signalPowers(end+1) = rxPower;

            avgChannelGain = mean(channelMag);
            channelStd = std(channelMag);
            phaseSpread = std(unwrap(channelPhase)) * 180/pi;

            if mod(beaconCount, 5) == 1 || beaconCount <= 10
                fprintf('%5d | %7.3f | %4.2f | %6.1f | Gain:%.2f±%.2f, Phase:%.1f°\n', ...
                    k, timestamp, peakVal, snrEstimate, avgChannelGain, channelStd, phaseSpread);
            end

            if beaconCount <= 3
                plotChannelResponse(channelEst, validSubcarriers, beaconCount);
            end
        end
    end
end

release(rx);
fprintf('\n📊 Capture completed!\n');
fprintf('📈 Total frames processed: %d\n', numFrames);
fprintf('📈 Beacons detected: %d\n', beaconCount);
fprintf('📈 Detection rate: %.1f%%\n', 100 * beaconCount / numFrames);

if beaconCount > 0
    fprintf('📈 Avg SNR: %.1f dB\n', mean(detectionLog(:,4)));
    fprintf('📈 SNR range: %.1f - %.1f dB\n', min(detectionLog(:,4)), max(detectionLog(:,4)));
    plotDetectionSummary(detectionLog, channelEstimates, validSubcarriers);
end

% === Helper Functions ===
% (unchanged helper functions follow...)

% === Helper Functions ===
function stf = generate80211nSTF()
    freqDomain = zeros(1, 64);
    stfSubcarriers = [-24, -20, -16, -12, -8, -4, 4, 8, 12, 16, 20, 24];
    stfIndices = stfSubcarriers + 33;
    stfValues = sqrt(13/6) * [1, -1, 1, 1, -1, 1, 1, 1, -1, -1, 1, -1];
    freqDomain(stfIndices) = stfValues;
    timeDomain = ifft(ifftshift(freqDomain));
    stf = repmat(timeDomain(1:16), 1, 10);
end

function ltf = generate80211nLTF()
    freqDomain = zeros(1, 64);
    indices = [-26:-1, 1:26] + 33;
    ltfSequence = [1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 1 1 -1 -1 1 1 -1 1 -1 1 1 1 1 ...
                   1 -1 -1 1 1 -1 1 -1 1 -1 -1 -1 -1 -1 1 1 -1 -1 1 -1 1 -1 1 1 1 1];
    freqDomain(indices) = ltfSequence;
    timeDomain = ifft(ifftshift(freqDomain));
    ltf = [timeDomain(33:64), timeDomain, timeDomain];
end

function [channelEst, channelMag, channelPhase] = estimateChannel(ltfRx)
    N = 64;
    cpLen = 32;
    if length(ltfRx) >= cpLen + 2*N
        ltf1 = ltfRx(cpLen + (1:N));
        ltf2 = ltfRx(cpLen + N + (1:N));
        H1 = fft(ltf1);
        H2 = fft(ltf2);
        channelEst = (H1 + H2) / 2;
    else
        ltfSymbol = ltfRx(end-N+1:end);
        channelEst = fft(ltfSymbol);
    end
    channelMag = abs(channelEst);
    channelPhase = angle(channelEst);
end

function plotChannelResponse(channelEst, validSubcarriers, detectionNum)
    figure(100 + detectionNum);
    subplot(2,1,1);
    plot(validSubcarriers-33, 20*log10(abs(channelEst(validSubcarriers))), 'b.-', 'LineWidth', 1.5);
    grid on;
    title(sprintf('Channel Magnitude Response - Detection #%d', detectionNum));
    xlabel('Subcarrier Index'); ylabel('Magnitude (dB)');

    subplot(2,1,2);
    plot(validSubcarriers-33, unwrap(angle(channelEst(validSubcarriers)))*180/pi, 'r.-', 'LineWidth', 1.5);
    grid on;
    title('Channel Phase Response');
    xlabel('Subcarrier Index'); ylabel('Phase (degrees)');
end

function plotDetectionSummary(detectionLog, channelEstimates, validSubcarriers)
    figure(200);
    subplot(3,1,1);
    plot(detectionLog(:,2), detectionLog(:,3), 'bo-', 'LineWidth', 1); grid on;
    title('Beacon Detection Timeline'); xlabel('Time (s)'); ylabel('Correlation Peak');

    subplot(3,1,2);
    plot(detectionLog(:,2), detectionLog(:,4), 'ro-', 'LineWidth', 1); grid on;
    title('SNR Over Time'); xlabel('Time (s)'); ylabel('SNR (dB)');

    if size(channelEstimates, 1) > 0
        subplot(3,1,3);
        avgChannel = mean(abs(channelEstimates(:, validSubcarriers)), 1);
        plot(validSubcarriers-33, 20*log10(avgChannel), 'g.-', 'LineWidth', 1.5);
        grid on;
        title('Average Channel Magnitude Response');
        xlabel('Subcarrier Index'); ylabel('Magnitude (dB)');
    end
    set(gcf, 'Position', [100, 100, 800, 600]);
end

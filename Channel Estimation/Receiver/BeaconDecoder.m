% ------------ SDR Parameters ------------
centerFreq = 2.412e9;       % Channel 1 (2.4 GHz band)
sampleRate = 20e6;          % 20 MHz bandwidth for 802.11n
captureTime = 10;           % Duration in seconds
gain = 30;                  % Adjust as needed
samplesPerFrame = 2048;

% ------------ SDRu Receiver Setup ------------
rx = comm.SDRuReceiver( ...
    'Platform', 'B210', ...
    'SerialNum', '30F59A1', ... % Replace with your USRP B210 serial
    'CenterFrequency', centerFreq, ...
    'SampleRate', sampleRate, ...
    'Gain', gain, ...
    'SamplesPerFrame', samplesPerFrame, ...
    'EnableTimestamps', true, ...
    'OutputDataType', 'double');

% ------------ Constants ------------
stf = generate80211nSTF();   % 802.11n STF
ltf = generate80211nLTF();   % 802.11n L-LTF
corrThreshold = 0.6;
numFrames = ceil(captureTime * sampleRate / samplesPerFrame);
beaconCount = 0;

% ------------ Main Loop ------------
fprintf('\n📡 Starting capture...\n\n');
for k = 1:numFrames
    [rxData, len, ts] = rx();
    if len == 0
        continue;
    end

    % Normalize
    rxData = rxData / max(abs(rxData));

    % Detect packet via STF correlation
    corr = abs(conv(conj(flip(stf)), rxData));
    [peakVal, peakIdx] = max(corr);

    if peakVal > corrThreshold
        fprintf('✅ Beacon detected at frame %d | Timestamp: %.6f\n', k, ts);
        beaconCount = beaconCount + 1;

        % Extract LTF assuming packet alignment
        ltfStart = peakIdx + length(stf);  % After STF
        ltfLength = 160;  % 2 x 64-sample symbols + 16-sample CPs

        if ltfStart + ltfLength - 1 <= length(rxData)
            ltfRx = rxData(ltfStart : ltfStart + ltfLength - 1);

            % Remove CP and split
            N = 64; cpLen = 16;
            ltf1 = ltfRx(cpLen + (1:N));
            ltf2 = ltfRx(cpLen + N + cpLen + (1:N));

            % Channel Estimation
            H1 = fft(ltf1);
            H2 = fft(ltf2);
            Havg = (H1 + H2) / 2;

            % Print Channel Info
            fprintf('🔍 Channel Magnitude (|H|):\n');
            disp(abs(Havg).');

            fprintf('🔍 Channel Phase (∠H) [radians]:\n');
            disp(angle(Havg).');
        end
    end
end

% ------------ Wrap up ------------
release(rx);
fprintf('\n📊 Total beacons detected: %d\n', beaconCount);

%% ------------ Helper Functions ------------

function stf = generate80211nSTF()
    % 802.11n STF same as 802.11a/g
    freqDomain = zeros(1,64);
    indices = [-24:-1 1:24] + 33;  % MATLAB 1-based
    bpsk = [1 -1 1 1 -1 1 1 1 -1 -1 1 -1 1 -1 1 1 ...
           -1 1 -1 1 -1 1 1 1 1 1 -1 -1 1 1 -1 -1 ...
            1 -1 -1 -1 -1 1 -1 1 1 1 -1 -1 -1 1 1 -1];
    freqDomain(indices) = bpsk;
    timeDomain = ifft(ifftshift(freqDomain));
    stf = repmat(timeDomain(1:16), 1, 10);  % 10 short symbols
end

function ltf = generate80211nLTF()
    % 802.11n Legacy Long Training Field (same as 802.11a LTF)
    freqDomain = zeros(1,64);
    indices = [-26:-1 1:26] + 33;  % MATLAB 1-based
    ltfBpsk = [1 -1 1 1 -1 1 1 1 -1 -1 1 -1 1 -1 1 1 ...
               -1 1 -1 1 -1 1 1 1 1 1 -1 -1 1 1 -1 -1 ...
                1 -1 -1 -1 -1 1 -1 1 1 1 -1 -1 -1 1 1 -1 ...
               1];  % 53 subcarriers, DC omitted
    freqDomain(indices) = ltfBpsk;
    timeDomain = ifft(ifftshift(freqDomain));
    ltf = [timeDomain(49:64), timeDomain, timeDomain];  % CP + 2 LTFs
end

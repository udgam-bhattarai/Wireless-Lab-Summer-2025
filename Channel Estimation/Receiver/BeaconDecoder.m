% Define parameters
centerFreq = 2.412e9; % Center frequency for Wi-Fi channel 1 (2.4 GHz band)
sampleRate = 20e6;   % Sample rate (20 MHz)
captureTime = 10;    % Capture duration in seconds
gain = 30;           % Receiver gain (adjust as needed)

% Create SDRuReceiver object
rx = comm.SDRuReceiver(...
    'Platform', 'B210', ...
    'SerialNum', '30F59A1', ... % Replace with your USRP B210 serial number
    'CenterFrequency', centerFreq, ...
    'SampleRate', sampleRate, ...
    'Gain', gain, ...
    'SamplesPerFrame', 1024, ...
    'EnableTimestamps', true, ...
    'ClockSource', 'Internal', ...
    'PPSSource', 'None');

% Initialize variables
numFrames = ceil(captureTime * sampleRate / 1024);
beaconCount = 0;

% Loop to receive and process frames
for frameIdx = 1:numFrames
    % Receive data
    [rxData, ~, ts] = rx();
    
    % Process the received data (e.g., detect and decode beacon frames)
    % This is a placeholder for your beacon detection and decoding logic
    % Example: if detectBeacon(rxData)
    %              beaconCount = beaconCount + 1;
    %              fprintf('Beacon detected at timestamp %.6f\n', ts);
    %          end
end

% Release the receiver
release(rx);

% Display the number of detected beacons
fprintf('Total beacons detected: %d\n', beaconCount);
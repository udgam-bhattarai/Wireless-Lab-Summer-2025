%% WLAN 802.11n Channel Estimation using USRP B210
% This script performs channel estimation on 802.11n beacon signals
% received through USRP B210 at 2.4 GHz

clear; clc; close all;

%% Configuration Parameters
cfg = struct();
cfg.SampleRate = 20e6;          % 20 MHz sample rate for 802.11n
cfg.CenterFrequency = 2.437e9;  % 2.4 GHz (Channel 6)
cfg.Gain = 30;                  % Receiver gain (adjust as needed)
cfg.FramesToCapture = 1000;     % Number of frames to search for first beacon
cfg.PacketDetectionThreshold = 0.5; % Packet detection threshold
cfg.StopAfterFirstBeacon = true;    % Stop after finding first valid beacon

% 802.11 Non-HT Configuration (for beacon frames)
% Beacon frames are typically transmitted using non-HT format (legacy OFDM)
wlanConfig = wlanNonHTConfig;
wlanConfig.ChannelBandwidth = 'CBW20';  % 20 MHz bandwidth
wlanConfig.MCS = 0;                     % BPSK with 1/2 coding rate (typical for beacons)
wlanConfig.PSDULength = 100;            % Typical beacon frame size in bytes

%% Initialize USRP B210
% Note: Ensure you have Communications Toolbox Support Package for USRP Radio

% First, try to find available USRP devices
fprintf('Searching for available USRP devices...\n');
try
    % Get list of available USRP devices
    devices = findsdru;
    
    if isempty(devices)
        error('No USRP devices found. Please check:\n1. USRP B210 is connected via USB 3.0\n2. UHD drivers are installed\n3. Device is powered and recognized by system');
    end
    
    % Display found devices
    fprintf('Found %d USRP device(s):\n', length(devices));
    for i = 1:length(devices)
        fprintf('  Device %d: Platform=%s, SerialNum=%s\n', i, devices(i).Platform, devices(i).SerialNum);
    end
    
    % Use the first available device
    selectedDevice = devices(1);
    fprintf('Using device: Platform=%s, SerialNum=%s\n', selectedDevice.Platform, selectedDevice.SerialNum);
    
    % Initialize the selected USRP device
    radio = comm.SDRuReceiver('Platform', selectedDevice.Platform, ...
        'SerialNum', selectedDevice.SerialNum, ...
        'CenterFrequency', cfg.CenterFrequency, ...
        'Gain', cfg.Gain, ...
        'SampleRate', cfg.SampleRate, ...
        'SamplesPerFrame', 4096, ...
        'OutputDataType', 'double');
    
    fprintf('USRP B210 initialized successfully with SerialNum: %s\n', selectedDevice.SerialNum);
    
catch ME
    fprintf('Error details: %s\n', ME.message);
    error(['Failed to initialize USRP B210. Please check:\n' ...
           '1. USRP B210 is connected via USB 3.0 cable\n' ...
           '2. UHD drivers are properly installed\n' ...
           '3. Run "uhd_find_devices" in command prompt to verify detection\n' ...
           '4. Try different USB 3.0 port\n' ...
           '5. Device is not being used by another application\n' ...
           '6. MATLAB has proper permissions to access USB devices']);
end

%% Main Processing Loop - Search for First Beacon
channelEstimate = [];
snrEstimate = [];
noSignalCount = 0;
signalDetectedCount = 0;
firstBeaconFound = false;

fprintf('Starting WLAN beacon signal capture and channel estimation...\n');
fprintf('Listening for first 802.11 Non-HT beacon signal at %.3f GHz...\n', cfg.CenterFrequency/1e9);
fprintf('Will stop after capturing first valid beacon...\n');

for frameIdx = 1:cfg.FramesToCapture
    % Break if we already found our beacon
    if firstBeaconFound && cfg.StopAfterFirstBeacon
        fprintf('First beacon captured successfully. Stopping acquisition.\n');
        break;
    end
    
    try
        %% Receive Signal from USRP
        rxSignal = step(radio);
        
        % Check signal power level
        signalPower = mean(abs(rxSignal).^2);
        signalPowerDbm = 10*log10(signalPower) + 30; % Convert to dBm (approximate)
        
        % Display signal power every 100 frames
        if mod(frameIdx, 100) == 0
            fprintf('Frame %d: Signal power = %.2f dBm\n', frameIdx, signalPowerDbm);
        end
        
        % Check if we have sufficient signal strength
        if signalPower < 1e-12  % Very low threshold for signal presence
            noSignalCount = noSignalCount + 1;
            if mod(noSignalCount, 200) == 0
                fprintf('WARNING: No significant signal detected for %d consecutive frames\n', noSignalCount);
                fprintf('Current signal power: %.2e (%.2f dBm)\n', signalPower, signalPowerDbm);
                fprintf('Check antenna connection and ensure WiFi transmitter is active\n');
            end
            continue;
        else
            if noSignalCount > 0
                fprintf('Signal detected after %d frames without signal\n', noSignalCount);
                noSignalCount = 0;
            end
            signalDetectedCount = signalDetectedCount + 1;
        end
        
        %% Packet Detection
        try
            [pktOffset, metric] = wlanPacketDetect(rxSignal, wlanConfig.ChannelBandwidth, ...
                'Threshold', cfg.PacketDetectionThreshold);
            
            % Ensure metric is a scalar for display purposes
            if ~isempty(metric) && ~isscalar(metric)
                metric = metric(1); % Use first element if metric is an array
            elseif isempty(metric)
                metric = 0; % Default value if no metric returned
            end
            
        catch ME
            % If packet detection fails, set default values and continue
            pktOffset = [];
            metric = 0;
            if mod(frameIdx, 100) == 0
                fprintf('Packet detection failed for frame %d: %s\n', frameIdx, ME.message);
            end
        end
        
        if ~isempty(pktOffset)
            fprintf('BEACON DETECTED at offset %d (Frame %d)!\n', pktOffset, frameIdx);
            % Extract packet starting from detected offset
            pktStart = pktOffset + 1;
            
            % Ensure we have enough samples for L-LTF processing
            if length(rxSignal) >= pktStart + 319  % L-LTF is 320 samples long
                packet = rxSignal(pktStart:end);
                
                %% Extract L-STF and L-LTF for Non-HT packets
                % For Non-HT (legacy OFDM) packets like beacons:
                % L-STF: samples 1-160 (for AGC and timing)
                % L-LTF: samples 161-320 (for channel estimation)
                
                if length(packet) >= 320
                    lSTF = packet(1:160);
                    lLTF = packet(161:320);
                    
                    %% Perform Channel Estimation using L-LTF
                    try
                        % Demodulate L-LTF first (required for wlanLLTFChannelEstimate)
                        lltfDemod = wlanLLTFDemodulate(lLTF, wlanConfig.ChannelBandwidth);
                        
                        % Use the built-in MATLAB function for channel estimation
                        channelEst = wlanLLTFChannelEstimate(lltfDemod, wlanConfig);
                        
                        % Store THE channel estimate (only one)
                        channelEstimate = channelEst(:).';
                        
                        % Estimate SNR (simplified method since pilotEst might not be available)
                        snr = estimateSNRFromChannel(channelEst, signalPower);
                        snrEstimate = snr;
                        
                        % Mark that we found our beacon
                        firstBeaconFound = true;
                        
                        fprintf('SUCCESS: First beacon processed!\n');
                        fprintf('Channel estimate size: %dx%d\n', size(channelEstimate));
                        fprintf('SNR estimate: %.2f dB\n', snr);
                        fprintf('Signal power: %.2f dBm\n', signalPowerDbm);
                        fprintf('Detection metric: %.3f\n', metric);
                        
                        % Break from inner processing since we have our beacon
                        break;
                        
                    catch ME
                        fprintf('Channel estimation failed for beacon frame %d: %s\n', ...
                            frameIdx, ME.message);
                    end
                end
            end
        else
            % No beacon detected in this frame
            if mod(frameIdx, 500) == 0 && signalDetectedCount > 0
                fprintf('Still searching for beacon... Frame %d (signal present but no valid beacon)\n', frameIdx);
            end
        end
        
        % If we found our beacon, break out of the main loop
        if firstBeaconFound && cfg.StopAfterFirstBeacon
            break;
        end
        
    catch ME
        fprintf('Error in frame %d: %s\n', frameIdx, ME.message);
        continue;
    end
end

%% Release USRP resources
release(radio);

%% Display Final Statistics
fprintf('\n=== First Beacon Reception Results ===\n');
fprintf('Total frames searched: %d\n', frameIdx);
fprintf('Frames with signal detected: %d (%.1f%%)\n', signalDetectedCount, ...
    100*signalDetectedCount/frameIdx);
fprintf('Frames without signal: %d (%.1f%%)\n', frameIdx - signalDetectedCount, ...
    100*(frameIdx - signalDetectedCount)/frameIdx);

if firstBeaconFound
    fprintf('First beacon successfully captured and processed!\n');
else
    fprintf('No valid beacon found in search window.\n');
end

%% Results Analysis and Visualization
if firstBeaconFound && ~isempty(channelEstimate)
    fprintf('\n=== Channel Estimation Results ===\n');
    fprintf('Successfully processed first beacon\n');
    fprintf('SNR estimate: %.2f dB\n', snrEstimate);
    fprintf('Channel estimate vector size: %dx%d\n', size(channelEstimate));
    
    % Create simple visualization for single beacon
    figure('Name', 'First Beacon Channel Estimation', 'Position', [100 100 1000 600]);
    
    % Subplot 1: Channel magnitude response
    subplot(2,2,1);
    plot(abs(channelEstimate), 'b-o');
    grid on;
    title('Channel Magnitude Response');
    xlabel('Subcarrier Index');
    ylabel('Magnitude');
    
    % Subplot 2: Channel phase response
    subplot(2,2,2);
    plot(angle(channelEstimate), 'r-o');
    grid on;
    title('Channel Phase Response');
    xlabel('Subcarrier Index');
    ylabel('Phase (radians)');
    
    % Subplot 3: Channel impulse response
    subplot(2,2,3);
    impulseResponse = ifft(channelEstimate);
    plot(abs(impulseResponse), 'g-o');
    grid on;
    title('Channel Impulse Response');
    xlabel('Sample Index');
    ylabel('Magnitude');
    
    % Subplot 4: Channel estimate constellation
    subplot(2,2,4);
    scatter(real(channelEstimate), imag(channelEstimate), 'filled');
    grid on;
    title('Channel Estimate Constellation');
    xlabel('Real');
    ylabel('Imaginary');
    axis equal;
    
    % Save results
    save('first_beacon_channel_estimate.mat', 'channelEstimate', 'snrEstimate', 'cfg');
    fprintf('Results saved to first_beacon_channel_estimate.mat\n');
else
    fprintf('\n=== NO BEACON CAPTURED ===\n');
    if signalDetectedCount == 0
        fprintf('ISSUE: No RF signal detected at all\n');
        fprintf('SUGGESTIONS:\n');
        fprintf('1. Check antenna connection to USRP B210\n');
        fprintf('2. Verify WiFi transmitter is active at %.3f GHz\n', cfg.CenterFrequency/1e9);
        fprintf('3. Increase receiver gain (current: %d dB)\n', cfg.Gain);
        fprintf('4. Move closer to WiFi source\n');
        fprintf('5. Check USRP B210 is receiving on correct frequency\n');
    else
        fprintf('ISSUE: Signal detected but no valid beacon frames found\n');
        fprintf('SUGGESTIONS:\n');
        fprintf('1. Verify the signal source is transmitting legacy 802.11 beacon frames (Non-HT format)\n');
        fprintf('2. Check if signal is on correct channel bandwidth (20 MHz)\n');
        fprintf('3. Adjust packet detection threshold (current: %.2f)\n', cfg.PacketDetectionThreshold);
        fprintf('4. Increase signal strength or receiver gain\n');
        fprintf('5. Ensure beacon transmission interval allows packet capture\n');
    end
    
    fprintf('\nTroubleshooting completed. Please address the issues above and run again.\n');
end

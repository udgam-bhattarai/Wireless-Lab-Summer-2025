clc;
clear;
%% Define USRP or Simulation

useUSRP = true;
transmit = false;
%% Creating Beacon 
% Defining the beacon signal parameters

ssid = "TEST_BEACON";
beaconInterval = 0;
band = 2.4;
chNum = 6;

% Creating a MAC frame-body configuration object, setting the SSID and Beacon Interval field value.
frameBodyConfig = wlanMACManagementConfig( ...
    BeaconInterval=beaconInterval, ...
    SSID=ssid);


% Adding the DS Parameter information element (IE) to the frame body.
dsElementID = 3;
dsInformation = dec2hex(chNum,2);
frameBodyConfig = frameBodyConfig.addIE(dsElementID,dsInformation);

% Creating beacon frame configuration object.
beaconFrameConfig = wlanMACFrameConfig(FrameType="Beacon", ...
    ManagementConfig=frameBodyConfig);

% Generating beacon frame bits.
[mpduBits,mpduLength] = wlanMACFrame(beaconFrameConfig,OutputFormat="bits");

% Calculating center frequency for the specified operating band and channel number.
fc = wlanChannelFrequency(chNum,band);
% Creating Beacon Packet
% Configuring a non-HT beacon packet with the relevant PSDU length, specifying 
% a channel bandwidth of 20 MHz, one transmit antenna, and BPSK modulation with 
% a coding rate of 1/2 (corresponding to MCS index 0) by using the wlanNonHTConfig 
% object.

cfgNonHT = wlanNonHTConfig(PSDULength = 61);

% Generating an oversampled beacon packet by using the wlanWaveformGenerator function, specifying an idle time.
osf = 1;
tbtt = beaconInterval*1024e-6;
txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,... 
    OversamplingFactor=osf,Idletime=tbtt);

% Getting the waveform sample rate.
Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);
%% Transmitting data 
% Defining USRP transmit characteristics

if(useUSRP)
    if(transmit)
        tx = comm.SDRuTransmitter(...
            'Platform', 'B210', ...
            'SerialNum', '344C57A', ...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ', ...
            'CenterFrequency', fc, ...
            'MasterClockRate', 20e6, ...
            'Gain', 60, 'InterpolationFactor', 1); %#ok<*UNRCH> % Adjust gain as needed
        
        % Normalizing the data to be transmitted
        txWaveform = txWaveform./max(abs(txWaveform));
        % txWaveform = txWaveform(1:27201);
        % txWaveform = repmat(txWaveform,[5 1]);
        
        % Stream the waveform
        Nsig = 100000000;
        for k = 1:Nsig
            tx(txWaveform);
            disp(k/Nsig)
        end
        % Release the transmitter when done
        release(tx);
    end


    if ~(transmit) %receive
        Beacon_detected = 0;
        Nrx = 1000;
        SSIDs = cell(1, Nrx);
        CRC_Pass = 0;
        capture_time = 0.005;
        total_noise=0;
        % Packet Detection
        rfRxFreq = 2.437e9; % Center frequency
        packetsDetected = 0; % Number of packets detected
        ind = wlanFieldIndices(cfgNonHT);  % Get non-HT fields
        
        % must match transmitter side, except gain
        rx = comm.SDRuReceiver( ...
            'Platform', 'B210', ...
            'SerialNum', '344C57A', ... % can be found by running findsdru in terminal
            'MasterClockRate', 20e6, ...
            'CenterFrequency', rfRxFreq, ...
            'Gain', 60, ...
            'OutputDataType', 'double', ...
            'DecimationFactor', 1,...   
            'ReceiveAntennaPort','RX2');
        
        

%% Receiving Data

        % For each sample
        for i = 1:Nrx
            disp(i / Nrx);
            [rxData, ~] = capture(rx, capture_time, 'Seconds');
             startOffset1 = wlanPacketDetect(rxData, 'CBW20', 0, 0.5);
            % Detect the packet      
                % if empty no packet detected. if > packet clipped or noise
                if ~isempty(startOffset1) && startOffset1 < (size(rxData,1) - ind.NonHTData(2)) %beginning index of packet+end index must be less than total data length 

                   
                    idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF'); % Calculate the LLTF index points
                    coarseFrame = rxData(startOffset1 + (ind.LSTF(1):ind.LSIG(2)), :);
                    startOffset2 = wlanSymbolTimingEstimate(coarseFrame, "CBW20"); % Finer preamble detection
        
                    if startOffset2 >= 0
                        packetsDetected = packetsDetected + 1;
                        % If startOffset2 is negative, packet detection likely failed
                        fineFrame = rxData(startOffset1 + startOffset2 + (ind.LSTF(1):ind.NonHTData(2)), :);
                     
                        % Demodulate the LLTF
                        demodLLTF = wlanLLTFDemodulate(fineFrame(idxLLTF(1):idxLLTF(2), :), cfgNonHT);
        
                        % Get channel estimation
                        subcarrier_index = [(7:32) (34:59)]; % Subcarrier 32 is DC 0 in Wifi
                        H_hat = zeros(64, 1);
                        H_hat(subcarrier_index) = wlanLLTFChannelEstimate(demodLLTF, cfgNonHT); % Channel Estimation LTF
                        noiseEst = wlanLLTFNoiseEstimate(demodLLTF);
                        total_noise = total_noise + noiseEst;
                        DataField = wlanNonHTDataRecover(fineFrame(ind.NonHTData(1):ind.NonHTData(2),:),H_hat(subcarrier_index),noiseEst,cfgNonHT);
                        %CRC error check
                        [cfgMAC,payload,status] = wlanMPDUDecode(DataField,cfgNonHT);
                        disp( cfgMAC.ManagementConfig.SSID);
                        if strcmp(status, 'Success') %CRC check
                            disp("CRC Passed");
                            CRC_Pass = CRC_Pass+1;
                            if matches(cfgMAC.FrameType,"Beacon")
                                disp("Beacon Detected");
                                Beacon_detected = Beacon_detected + 1;
                                SSIDs{Beacon_detected} = cfgMAC.ManagementConfig.SSID;
                            end
                            figure(1)
                            subplot(1, 2, 1)
                            plot(10 * log10(abs(H_hat).^2), '-', 'DisplayName', 'Estimated Channel, abs');
            
                            if(Beacon_detected>0)
                                title(SSIDs{Beacon_detected});
                            end
                            ylim([-40 0])
                            h_hat = ifft(fftshift(H_hat));
                            subplot(1, 2, 2)
                            plot(abs(h_hat));
                            ylim([0 0.15])
                            drawnow;
            
                            % Performance metrics
                            estimated_delay = startOffset1 + startOffset2;
                            disp(['Estimated delay: ' num2str(estimated_delay)]);
                            pause(0.01)
                            disp(['Packet detected: ' num2str(i)])
                        else
                            disp("Failed CRC");
                        end
                    else
                        disp(['Packet not detected ' num2str(i)])
                        pause(0.001)
                    end
                else
                    disp(['Packet not detected ' num2str(i)])
                    pause(0.001)
                end
        end
        
        release(rx);
        
% Probability of Detection
Test_Beacons =0;
for i=1:size(SSIDs,2)
     if strcmp(SSIDs{i}, 'TEST_BEACON')
        Test_Beacons = Test_Beacons + 1;
    end
end
disp('Per loop: ');
disp(['Percent of Packet Detection per loop: ', num2str(100*packetsDetected/Nrx)]);
disp(['Percent of CRC PASS out of loop: ', num2str(100*CRC_Pass/Nrx)]);
disp(['Percent of Beacon Detection per loop:', num2str(100*Beacon_detected/Nrx)]);
disp('');

disp('Per packet: ')
disp(['Percent of CRC PASS out of packets: ', num2str(100*CRC_Pass/packetsDetected)]);
disp(['Percent of Beacons out of packets: ', num2str(100*Beacon_detected/packetsDetected)]);
disp('');
disp('Per Beacon: ')
disp(['Percent of Test Beacon out of Beacons: ', num2str(100*Test_Beacons/Beacon_detected)]);
disp(['Packets detected per second: ', num2str(packetsDetected/(capture_time*Nrx))]);
disp(['Beacons detected per second: ', num2str(Beacon_detected/(capture_time*Nrx))]);
disp(['Test Beacons detected per second: ', num2str(Test_Beacons/(capture_time*Nrx))]);
disp(['Average Noise is: ' num2str(total_noise/packetsDetected)]);
    end
end
%% Simulation 

if  ~(useUSRP)
% Additional Signal Transformations for testing
% Padding 0s before the packet to validate packet detection index.

    rxWaveform = [zeros(delay, 1); txWaveform];
    rxWaveform = conv(rxWaveform(:), H); % Signal after channel
    rxWaveform = rxWaveform + (sqrt(noise_power/2) * (randn(size(rxWaveform)) + 1i * randn(size(rxWaveform)))); %  Adding complex Additive White Gaussian Noise (AWGN) to simulate real-world channel noise.
% Creating Channel
% Defining the number of subcarriers that the total bandwidth is to be split 
% into i.e. number of discrete FFT channels

    Nfft = 64;
    
    % Defining the nnumber of discrete-time multipaths, L = 1 means no multipath, pure AWGN
    L = 4; % Number of discrete-time multipaths, L = 1 means no multipath, pure AWGN
    channel_pdp = [1 0.3 0.1 0.05]'; %  Power delay profile for each of the multipaths
    noise_power = .001; % Noise Power
    delay = randi(100); 
    
    % Generating a random channel impulse response for a frequency-selective fading wireless channel 
    % based on the given Power Delay Profile (PDP).
    h = sqrt(channel_pdp) .* (sqrt(1/2) * (randn(L,1) + 1i * randn(L,1)));
    % % % randn(...) + 1i*randn(...) creates complex Gaussian noise.
    % % % sqrt(1/2) normalizes it to have unit power. 
    % % % sqrt(channel_pdp) gives per-tap amplitude scaling based on desired power.
    % % % .* applies that scaling per tap to get the final multipath channel h.
    
    % Plotting the impulse response
    figure
    stem(abs(h).^2); 
    title('channel in time domain')
    xlim([1 2*L])
    
    % Plotting the frequency response
    H = fftshift(fft(h,Nfft)); % Converting the impulse response into frequency response using FFT
    figure;
    plot(10*log10(abs(H).^2))
    title('Channel in Frequency Domain')
    
% Channel Estimation

    rxData = rxWaveform;
    % Calculate the index points for different fields in the Preamble
    idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');
    % Get non-HT fields
    ind = wlanFieldIndices(cfgNonHT);
    
    % Center Frequency
    rfRxFreq = fc; 
    
    % Coarse Packet Detection - Roughly detects the start of a packet and
    % extracts the preamble from the WLAN packet
    startOffset1 = wlanPacketDetect(rxData, 'CBW20'); % Detect start of packet
    nonHTFields = rxData(startOffset1+(ind.LSTF(1):ind.LSIG(2)),:); % Extract Preamble
    
    % Fine Packet Detection - Performs packet detection again on the already
    % detected and segmented packet, to get an even better estimate of the
    % start of the beacon packet
    startOffset2 = wlanSymbolTimingEstimate(nonHTFields, "CBW20"); % Detect start of packet in the segmented data
    nonHTFields = rxData(startOffset1+startOffset2+(ind.LSTF(1):ind.LSIG(2)),:); % Re-extracts Preamble from the Received Data with better offset estimation
    
    % Demodulate the LLTF 
    demodSig = wlanLLTFDemodulate(nonHTFields(idxLLTF(1):idxLLTF(2), :), cfgNonHT);
    
    % Get channel estimation using the L-LTF
    H_hat = wlanLLTFChannelEstimate(demodSig, cfgNonHT);
    subcarrier_index = [(6:31) (33:58)] + 1;
    
    figure
    ylim([-40 20])
    legend('location','best')
    plot(subcarrier_index,10*log10(abs(H_hat).^2),'o','DisplayName','Estimated Channel, abs');
    
    ylim([-40 20])
    legend('location','best')
end

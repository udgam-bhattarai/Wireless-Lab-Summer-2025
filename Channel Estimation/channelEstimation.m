clc;
% clear;
%% Define USRP or Simulation
useUSRP = true;
transmit = true;

%% Creating Beacon Frame
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


%% Creating Beacon Packet
% Configuring a non-HT beacon packet with the relevant PSDU length, specifying a channel bandwidth of 20 MHz, one transmit antenna,
% and BPSK modulation with a coding rate of 1/2 (corresponding to MCS index 0) by using the wlanNonHTConfig object.
cfgNonHT = wlanNonHTConfig(PSDULength = 61);

% Generating an oversampled beacon packet by using the wlanWaveformGenerator function, specifying an idle time.
osf = 1;
tbtt = beaconInterval*1024e-6;
txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,... 
    OversamplingFactor=osf,Idletime=tbtt);

% Getting the waveform sample rate.
Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);

%% Transmitting data
% txWaveform = txWaveform;
% Defining USRP transmit characteristics
if(useUSRP)
    try 
        usrp = findsdru;
        if (usrp.Status ~= "Success")
            disp('USRP is busy. Proceeding with simulation mode.');
            useUSRP = false;
        end
    catch
        warning('USRP not found. Proceeding with simulation mode.');
        useUSRP = false;
    end
end 

if (useUSRP)
    if(transmit)
        tx = comm.SDRuTransmitter(...
            'Platform', usrp.Platform, ...
            'SerialNum', usrp.SerialNum, ...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ', ...
            'CenterFrequency', fc, ...
            'MasterClockRate', 10e6, ...
            'Gain', 89, 'InterpolationFactor', 1); % Adjust gain as needed
        
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
        Nrx = 5000;
        SSIDs = cell(1, Nrx);
        
        % Packet Detection
        rfRxFreq = 2.437e9; % Center frequency
        packetsDetected = 0; % Number of packets detected
        ind = wlanFieldIndices(cfgNonHT);  % Get non-HT fields
        
        % must match transmitter side, except gain
        rx = comm.SDRuReceiver( ...
            'Platform', usrp.Platform, ...
            'SerialNum', usrp.SerialNum, ... % can be found by running findsdru in terminal
            'MasterClockRate', 20e6, ...
            'CenterFrequency', rfRxFreq, ...
            'Gain', 60, ...
            'OutputDataType', 'double', ...
            'DecimationFactor', 1,...   
            'ReceiveAntennaPort','RX2');
        
        %% Samples Collection
        
        % For each sample
        for i = 1:Nrx
            disp(i / Nrx);
            [rxData, ~] = capture(rx, 0.005, 'Seconds');
             startOffset1 = wlanPacketDetect(rxData, 'CBW20', 0, 0.5);
            % Detect the packet      
                % No packet detected (rudimentary). If high, likely no packet detected
                if ~isempty(startOffset1) && startOffset1 < (size(rxData,1) - ind.NonHTData(2))
                   
                    idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF'); % Calculate the LLTF index points
                    coarseFrame = rxData(startOffset1 + (ind.LSTF(1):ind.LSIG(2)), :);
                    startOffset2 = wlanSymbolTimingEstimate(coarseFrame, "CBW20"); % Finer preamble detection
        
                    if startOffset2 > 1
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
                        DataField = wlanNonHTDataRecover(fineFrame(ind.NonHTData(1):ind.NonHTData(2),:),H_hat(subcarrier_index),noiseEst,cfgNonHT);
                        [cfgMAC,payload,status] = wlanMPDUDecode(DataField,cfgNonHT);
                        cfgMAC.ManagementConfig.SSID
                        if matches(cfgMAC.FrameType,"Beacon")
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
                        disp(['Packet not detected ' num2str(i)])
                        pause(0.001)
                    end
                else
                    disp(['Packet not detected ' num2str(i)])
                    pause(0.001)
                end
        end
        
        release(rx);
        
        %% Probability of Detection
        disp(['Probability of Packet Detection:', num2str(packetsDetected/Nrx)])
    end
end
  

%% Simulation Side
if  ~(useUSRP)
    %% Additional Signal Transformations for testing
    % Padding 0s before the packet to validate packet detection index.
    rxWaveform = [zeros(delay, 1); txWaveform];
    rxWaveform = conv(rxWaveform(:), H); % Signal after channel
    rxWaveform = rxWaveform + (sqrt(noise_power/2) * (randn(size(rxWaveform)) + 1i * randn(size(rxWaveform)))); %  Adding complex Additive White Gaussian Noise (AWGN) to simulate real-world channel noise.

    %% Creating Channel (for simulation)
    % Defining the number of subcarriers that the total bandwidth is to be split into i.e.
    % number of discrete FFT channels
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
    
    %% Channel Estimation for Simulation
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

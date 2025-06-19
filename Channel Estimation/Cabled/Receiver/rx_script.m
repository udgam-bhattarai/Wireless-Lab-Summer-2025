clc;
clear;

cfgNonHT = wlanNonHTConfig(PSDULength=61);
Beacon_detected = 0;
Nrx = 5000;
SSIDs = cell(1, Nrx);

%% Packet Detection
rfRxFreq = 2.437e9; % Center frequency
packetsDetected = 0; % Number of packets detected
ind = wlanFieldIndices(cfgNonHT);  % Get non-HT fields

% must match transmitter side, except gain
rx = comm.SDRuReceiver( ...
    'Platform', 'B210', ...
    'SerialNum', '344C4DE', ... % can be found by running findsdru in terminal
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


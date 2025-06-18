clc;
clear;

cfgNonHT = wlanNonHTConfig(PSDULength=61);

%% Packet Detection
rfRxFreq = 2.437e9; % Center frequency
packetsDetected = 0; % Number of packets detected

% must match transmitter side, except gain
rx = comm.SDRuReceiver( ...
    'Platform', 'B210', ...
    'SerialNum', '344C4DE', ... % can be found by running findsdru in terminal
    'MasterClockRate', 20e6, ...
    'CenterFrequency', rfRxFreq, ...
    'Gain', 60, ...
    'OutputDataType', 'double', ...
    'DecimationFactor', 1);

%% Samples Collection
Nrx = 5000;

% For each sample
for i = 1:Nrx
    disp(i / Nrx)
    [rxData, ~] = capture(rx, 0.001, 'Seconds');

    % Detect the packet
    try
        startOffset1 = wlanPacketDetect(rxData, 'CBW20', 0, 0.25);

        % No packet detected (rudimentary). If high, likely no packet detected
        if ~isempty(startOffset1)
            % Calculate the LLTF index points
            idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');

            % Get non-HT fields
            ind = wlanFieldIndices(cfgNonHT);
            nonHTFields = rxData(startOffset1 + (ind.LSTF(1):ind.LSIG(2)), :);
            startOffset2 = wlanSymbolTimingEstimate(nonHTFields, "CBW20"); % Finer preamble detection

            if startOffset2 > 1
                packetsDetected = packetsDetected + 1;
                % If startOffset2 is negative, packet detection likely failed
                nonHTFields = rxData(startOffset1 + startOffset2 + (ind.LSTF(1):ind.LSIG(2)), :);

                % Demodulate the LLTF
                demodSig = wlanLLTFDemodulate(nonHTFields(idxLLTF(1):idxLLTF(2), :), cfgNonHT);

                % Get channel estimation
                subcarrier_index = [(6:31) (33:58)] + 1; % Subcarrier 32 is DC 0 in Wifi
                H_hat = zeros(64, 1);
                H_hat(subcarrier_index) = wlanLLTFChannelEstimate(demodSig, cfgNonHT); % Channel Estimation LTF

                figure(1)
                subplot(1, 2, 1)
                plot(10 * log10(abs(H_hat).^2), '-', 'DisplayName', 'Estimated Channel, abs');
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
    catch
        disp(['Packet not detected ' num2str(i)])
        pause(0.001)
    end
end

release(rx);

%% Probability of Detection
disp(['Probability of Packet Detection:', num2str(packetsDetected/Nrx)])


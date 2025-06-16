clc;
clear;


cfgNonHT = wlanNonHTConfig(PSDULength=61);

%% Packet Detection

rfRxFreq = 2.437e9; %% Center frequency

rx = comm.SDRuReceiver( ... %%must match transmitter side, except gain
    'Platform',         'B210', ...
    'SerialNum',        '344C4DE', ... %%can be found by runnin findsdru in terminal
    'MasterClockRate', 20e6, ...
    'CenterFrequency',  rfRxFreq,...
    'Gain', 60,...
    'OutputDataType', 'double',...
    'DecimationFactor', 1);
%%
%

Nrx = 5000;

for i = 1:Nrx

    disp(i/Nrx)
    [rxData, ~] = capture(rx, 0.001, 'Seconds');

    %%
    % detect the packet

    try
    startOffset1 = wlanPacketDetect(rxData, 'CBW20',0,0.25); % roughly detects how many samples away a preamble is from the start of the data


    if ~isempty(startOffset1)%no packet detected (rudimentary). If high, likely no packet detected
        
        %%
        % Calculate the LLTF index points

        idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');
        %%
        % Get non-HT fields

        ind = wlanFieldIndices(cfgNonHT);
        nonHTFields = rxData(startOffset1+(ind.LSTF(1):ind.LSIG(2)),:);
        startOffset2 = wlanSymbolTimingEstimate(nonHTFields, "CBW20"); % fine preamble detection

        if startOffset2>1 %if startoffset2 is negative packetdetection likely failed
        nonHTFields = rxData(startOffset1+startOffset2+(ind.LSTF(1):ind.LSIG(2)),:);
        %%
        % Demodulate the LLTF

        demodSig = wlanLLTFDemodulate(nonHTFields(idxLLTF(1):idxLLTF(2), :), cfgNonHT);
        %%
        % Get channel estimation

        subcarrier_index = [(6:31) (33:58)] + 1; %subcarrier 32 is DC 0 in Wifi
        H_hat = zeros(64,1);
        H_hat(subcarrier_index) = wlanLLTFChannelEstimate(demodSig, cfgNonHT); % channel estimation LTF

        figure(1)
        subplot(1,2,1)
        plot(10*log10(abs(H_hat).^2),'-','DisplayName','Estimated Channel, abs');
 
        ylim([-40 0])

        h_hat = ifft(fftshift(H_hat));
        subplot(1,2,2)

        plot(abs(h_hat));
        ylim([0 0.15])
        drawnow;
        % performance metrics

        estimated_delay = startOffset1 + startOffset2;
        % disp(['True delay: ' num2str(delay)])
        disp(['Estimated delay: ' num2str(estimated_delay)]);
        pause(0.01)
        disp(['packet detected: ' num2str(i)])
        else
            disp(['packed not detected ' num2str(i)])
            pause(0.001)
        end

    else
        disp(['packed not detected ' num2str(i)])
        pause(0.001)
    end
    catch
        disp(['packed not detected ' num2str(i)])
        pause(0.001)
    end

end

release(rx);

% mse = mean(abs(H_hat-H(subcarrier_index)).^2)
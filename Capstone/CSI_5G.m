

clc; clear;

receive = true;
carrier = nrCarrierConfig;
carrier.SubcarrierSpacing = 15;
carrier.NSizeGrid = 52;

csirs = nrCSIRSConfig;
csirs.CSIRSType = {'nzp','nzp','nzp'};
csirs.RowNumber = [4 4 4];
csirs.NumRB = 52;
csirs.RBOffset = 0;
csirs.CSIRSPeriod = [4 0];      % Transmit every 4 slots
csirs.SymbolLocations = {0, 0, 0};
csirs.Density = {'one','one','one'};
csirs.SubcarrierLocations = {0, 4, 8};

usrp = findsdru();
waveformInfo = nrOFDMInfo(carrier);
sampleRate = waveformInfo.SampleRate; % Approx 15.36 MSps
centerFreq = 2.4e9;
masterClock = 30.72e6; % B210 Standard
interp = masterClock / sampleRate;
decimation = interp;

if (~receive)
    framesToGen = 1;
    slotsPerFrame = carrier.SlotsPerFrame;
    totSlotsGen = framesToGen * slotsPerFrame;
    txGridVolume = [];

    disp('Generating 5G Waveform...');
    for nslot = 0:totSlotsGen-1
        carrier.NSlot = nslot;
        slotGrid = nrResourceGrid(carrier, csirs.NumCSIRSPorts(1));
        csirsInd = nrCSIRSIndices(carrier,csirs);
        csirsSym = nrCSIRS(carrier,csirs);
        if ~isempty(csirsInd)
            slotGrid(csirsInd) = csirsSym;
        end
        txGridVolume = [txGridVolume slotGrid]; %#ok<AGROW>
    end

    % Modulate and Normalize
    txWaveform = nrOFDMModulate(carrier, txGridVolume);
    scaleFactor = 1 / max(abs(txWaveform(:)));
    txWaveform = txWaveform * scaleFactor;



    disp(['Configuring USRP Tx at ' num2str(sampleRate/1e6) ' MSps...']);
    usrp = findsdru;
    txRadio = comm.SDRuTransmitter(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum, ...
        'ChannelMapping',       1, ...
        'CenterFrequency',      centerFreq, ...
        'Gain',                 0, ...
        'MasterClockRate',      masterClock, ...
        'InterpolationFactor',  interp);

    Nsig = 10;
    for k = 1:Nsig
        tx(txWaveform);
        disp(k/Nsig)
    end
    % Release the transmitter when done
    release(tx);




else
    disp('Configuring USRP Rx...');

    framesToCapture = 25;
    samplesPerSlot = length(nrOFDMModulate(carrier, nrResourceGrid(carrier,1)));
    samplesPerFrame = samplesPerSlot * 10;
    captureSize = samplesPerFrame * framesToCapture;

    rxRadio = comm.SDRuReceiver(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum, ...
        'ChannelMapping',       1, ...
        'CenterFrequency',      centerFreq, ...
        'Gain',                 50, ...
        'MasterClockRate',      masterClock, ...
        'DecimationFactor',     decimation, ...
        'SamplesPerFrame',      length(nrOFDMModulate(carrier, nrResourceGrid(carrier,1))) * 10 * 3);
    % We request 3 frames worth of samples to ensure we catch a full frame boundary

    % --- 3. Capture & Synchronization ---
    disp('Capturing signal...');
    rxWaveformFull = rxRadio(); % Capture 30ms of data
    release(rxRadio);

    disp('Synchronizing...');
    % We just need one slot with CSI-RS for synchronization reference
    carrier.NSlot = 0;
    disp('Capturing signal...');
    rxBufferFull = rxRadio();
    release(rxRadio);
    disp('Synchronizing...');
    % Re-generate a clean reference waveform for correlation
    refGrid = nrResourceGrid(carrier, 1);
    carrier.NSlot = 0;

    refGrid(nrCSIRSIndices(carrier,csirs)) = nrCSIRS(carrier,csirs);
    refWaveform = nrOFDMModulate(carrier, refGrid);

    % A. Coarse Frequency Correction (Two USRPs always have drift!)
    frequencyOffset = nrFrequencyOffset(carrier, rxWaveformFull, refWaveform);
    rxWaveformFull = freqshift(rxWaveformFull, -frequencyOffset, sampleRate);
    disp(['Compensated Frequency Offset: ' num2str(frequencyOffset) ' Hz']);

    % B. Timing Synchronization
    [t, mag] = nrTimingEstimate(carrier, rxWaveformFull, refWaveform);
    startIdx = 1 + t;
    frameLenSamp = length(refWaveform) * 10; % Length of 10ms frame

    % Extract one aligned frame
    if startIdx + frameLenSamp > length(rxWaveformFull)
        error('Sync found too late in capture. Try capturing again.');

        [t, mag] = nrTimingEstimate(carrier,rxBufferFull, refGrid);
        disp(['Sync Confidence (mag): ' num2str(mag(t))]);
        if mag(t) < 0.1
            warning('Low Sync Confidence! Check Tx Gain and connections.');

        end

        rxBufferClean = rxBufferFull(1+t:end);

        % % --- 4. Demodulation & Your Analysis Loop ---
        % disp('Demodulating and Running User Loop...');
        cdmLengths = getCDMLengths(csirs);
        symbolsPerSlot = carrier.SymbolsPerSlot;


        % Visualize the Grid to check if signal exists
        figure(1); imagesc(abs(rxGridVolume(:,:,1))); title('Rx Grid Magnitude (All Slots)');

        % Loop through the 10 slots in the captured frame
        for nslot = 0:9
            carrier.NSlot = nslot;

            % 1. Extract the specific symbols for this slot from the volume
            symStart = nslot * symbolsPerSlot + 1;
            symEnd = symStart + symbolsPerSlot - 1;
            rxGridPractical = rxGridVolume(:, symStart:symEnd, :);

            % 2. Generate Reference CSI-RS
            csirsInd = nrCSIRSIndices(carrier,csirs);
            csirsSym = nrCSIRS(carrier,csirs);

            % --- YOUR LOGIC ---
            if ~isempty(csirsInd)
                disp(['[Slot ' num2str(nslot) '] CSI-RS Detected. Estimating Channel...']);

                nzpCSIRSSym = csirsSym(csirsSym ~= 0);
                nzpCSIRSInd = csirsInd(csirsSym ~= 0);

                [PracticalHest, nVarPractical] = nrChannelEstimate(carrier, rxGridPractical, ...
                    nzpCSIRSInd, nzpCSIRSSym, 'CDMLengths', cdmLengths, 'AveragingWindow', [0 5]);

                % Plot result for this slot
                figure(2);
                surf(abs(PracticalHest(:,:,1,1)));
                title(['H_est Magnitude (Slot ' num2str(nslot) ')']);
                shading interp; view(2); colorbar;
                pause(0.5);
            else
                % disp(['[Slot ' num2str(nslot) '] No CSI-RS.']);
            end

        end

    end

    figure('Name', 'Live Channel Frequency Response');
    hPlot = plot(1:carrier.NSizeGrid*12, nan(carrier.NSizeGrid*12, 1));
    grid on; xlabel('Subcarrier Index'); ylabel('Magnitude');


    % Loop through the 10 slots in the captured frame
    for i = 1:framesToCapture
        oneFrame = rxBufferClean(1:samplesPerFrame);
        rxBufferClean = rxBufferClean(samplesPerFrame+1:end);
        rxGridFrame = nrOFDMDemodulate(carrier, oneFrame);
        for nslot = 0:9
            carrier.NSlot = nslot;
            csirsInd = nrCSIRSIndices(carrier,csirs);
            csirsSym = nrCSIRS(carrier,csirs);
            if ~isempty(csirsInd)
                symStart = nslot * symbolsPerSlot + 1;
                symEnd = symStart + symbolsPerSlot - 1;
                rxGridSlot = rxGridFrame(:, symStart:symEnd, :);


                [PracticalHest, nVarPractical] = nrChannelEstimate(carrier, rxGridSlot, ...
                    csirsInd, csirsSym);

                freqResponse = abs(PracticalHest(:,1));

                set(hPlot, 'YData', freqResponse);
                drawnow;


                pause(0.5);
                drawnow;

            else
                disp(['[Slot ' num2str(nslot) '] No CSI-RS.']);
            end


        end
    end

end


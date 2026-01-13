

clc; clear; 

receive = true;

    carrier = nrCarrierConfig;
    carrier.SubcarrierSpacing = 15;
    carrier.NSizeGrid = 52;
    
    csirs = nrCSIRSConfig;
    csirs.CSIRSType = {'nzp','nzp','nzp'};
    csirs.RowNumber = [1 1 1]; 
    csirs.NumRB = 52;
    csirs.RBOffset = 0;
    csirs.CSIRSPeriod = [4 0];      % Transmit every 4 slots
    csirs.SymbolLocations = {0, 6, 12};
    csirs.Density = {'three','three','three'};
    csirs.SubcarrierLocations = {0, 0, 0};

    waveformInfo = nrOFDMInfo(carrier);
    sampleRate = waveformInfo.SampleRate; % Approx 15.36 MSps
    centerFreq = 2.4e9;
    masterClock = 30.72e6; % B210 Standard
    interp = masterClock / sampleRate;
    decimation = masterClock / sampleRate;

    usrp = findsdru;
if (~receive)
    % We generate 1 frame (10ms). The USRP will repeat this seamlessly.
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
    scaleFactor = 0.8 / max(abs(txWaveform(:)));
    txWaveform = txWaveform * scaleFactor;

    
    disp(['Configuring USRP Tx at ' num2str(sampleRate/1e6) ' MSps...']);
    txRadio = comm.SDRuTransmitter(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum, ...        
        'ChannelMapping',       1, ...
        'CenterFrequency',      centerFreq, ...
        'Gain',                 -10, ...         n
        'MasterClockRate',      masterClock, ...
        'InterpolationFactor',  interp);
    
    % --- 4. Start Transmission ---
    disp('Transmitting... (Press Ctrl+C to stop)');
    transmitRepeat(txRadio, txWaveform);

    Nsig = 10;
    for k = 1:Nsig
            tx(txWaveform);
            disp(k/Nsig)
     end
        % Release the transmitter when done
        release(tx);

%%
% *RX* 

else

    disp('Configuring USRP Rx...'); 
    
    rxRadio = comm.SDRuReceiver(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum, ...       
        'ChannelMapping',       1, ...
        'CenterFrequency',      centerFreq, ...
        'Gain',                 40, ...       
        'MasterClockRate',      masterClock, ...
        'DecimationFactor',     decimation, ...
        'SamplesPerFrame',      length(nrOFDMModulate(carrier, nrResourceGrid(carrier,1))) * 10 * 3,...
        'OutputDataType','double'); 

    
for i = 1:20
    disp('Capturing signal...');
    rxWaveformFull = rxRadio();

    
    disp('Synchronizing...');
    % Re-generate a clean reference waveform for correlation
    refGrid = nrResourceGrid(carrier, csirs.NumCSIRSPorts(1));
    refGrid(nrCSIRSIndices(carrier,csirs)) = nrCSIRS(carrier,csirs);
    refWaveform = nrOFDMModulate(carrier, refGrid);

    % B. Timing Synchronization
    [t, mag] = nrTimingEstimate(carrier, rxWaveformFull, refGrid);
    startIdx = 1 + t;
    frameLenSamp = length(refWaveform) * 10; % Length of a frame
    
    % Extract one aligned frame
    if startIdx + frameLenSamp > length(rxWaveformFull)
        error('Sync found too late in capture. Try capturing again.');
    end
    rxWaveform = rxWaveformFull(startIdx : startIdx+frameLenSamp-1, :);
    
    % --- 4. Demodulation & Your Analysis Loop ---
    disp('Demodulating and Running User Loop...');
    rxGridVolume = nrOFDMDemodulate(carrier, rxWaveform);
    cdmLengths = getCDMLengths(csirs);
    symbolsPerSlot = carrier.SymbolsPerSlot;
    
    % Visualize the Grid to check if signal exists
    figure(1); imagesc(abs(rxGridVolume(:,:,1))); title('Rx Grid Magnitude (All Slots)');
    PracticalHest = zeros(624,14);
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
            
            % % Plot result for this slot
            % figure(2); 
            % surf(abs(PracticalHest(:,:,1,1))); 
            % title(['H_est Magnitude (Slot ' num2str(nslot) ')']);
            % shading interp; view(2); colorbar;
            % pause(0.5); 
            % Plot the frequency response of the 1st symbol in the slot
              plot(abs(PracticalHest(:, 1, 1, 1))); 
                grid on;
                title(['Channel Frequency Response (Symbol 0, Slot ' num2str(nslot) ')']);
                xlabel('Subcarrier Index');
                ylabel('Magnitude');
                pause(0.5);
            
        else
             disp(['[Slot ' num2str(nslot) '] No CSI-RS.']);
        end
      
    
        end
        
    end
release(rxRadio);
end 
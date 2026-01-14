clc; clear;
receive = false;
nrb = 20;              
scs = 15;
ncellid = 42;
ibar_SSB = 0;
carrier = nrCarrierConfig('NSizeGrid',nrb,'SubcarrierSpacing',scs);
dmrsSym = nrPBCHDMRS(ncellid,ibar_SSB);
dmrsInd = nrPBCHDMRSIndices(ncellid);
usrp = findsdru;
if (receive)
    txGrid = nrResourceGrid(carrier, 1);
    txGrid(dmrsInd) = dmrsSym;

    % Modulate
    txWaveform = nrOFDMModulate(carrier, txGrid);

    info = nrOFDMInfo(carrier);
    sampleRate = info.SampleRate;

    txRadio = comm.SDRuTransmitter(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum,...
        'ChannelMapping',       1, ...
        'CenterFrequency',      2.4e9, ...
        'Gain',                 30, ...       % High gain for detection
        'MasterClockRate',      30.72e6, ...  % Standard 4G/5G clock
        'InterpolationFactor',  30.72e6 / sampleRate);


    disp('Transmitting PBCH DMRS... (Press Ctrl+C to stop)');
    disp(['Sample Rate: ' num2str(sampleRate/1e6) ' MHz']);

    % Scale waveform to prevent clipping on USRP
    txWaveform = txWaveform / max(abs(txWaveform));

    for i = 1:1000
        txRadio(txWaveform);
        disp(1/i);
    end


else
    refGrid = nrResourceGrid(carrier, 1);
    refGrid(dmrsInd) = dmrsSym;
    refWaveform = nrOFDMModulate(carrier, refGrid);

 
    info = nrOFDMInfo(carrier);
    sampleRate = info.SampleRate;

    rxRadio = comm.SDRuReceiver(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum,...
        'ChannelMapping',       1, ...
        'CenterFrequency',      2.4e9, ...
        'Gain',                 30, ...        % Good Rx Gain
        'MasterClockRate',      30.72e6, ...
        'DecimationFactor',     30.72e6 / sampleRate, ...
        'SamplesPerFrame',      length(refWaveform) * 50); % Capture 50 frames


    disp('Capturing...');
    rxBuffer = rxRadio();
    release(rxRadio);

    
    [t, mag] = nrTimingEstimate(carrier,rxBuffer, refGrid);


    if maxMag(t) < 0.1
        warning('Signal not found. Check Tx is running and Gains are high.');
    end

    % Correct Timing
    rxWaveformSync = rxBuffer(1+t:end);
    samplesPerSlot = length(refWaveform);
    if length(rxWaveformSync) < samplesPerSlot
        error('Not enough samples left after sync.');
    end

    rxWaveformCut = rxWaveformSync(1:samplesPerSlot);

    % Turn waveform back into grid
    rxGrid = nrOFDMDemodulate(carrier, rxWaveformCut);

    % --- 7. Channel Estimation (Your requested logic) ---
    % Note: 'dmrsInd' tells it exactly where to look for pilots
    [H, nVar] = nrChannelEstimate(rxGrid, dmrsInd, dmrsSym);

    % --- 8. Visualization ---
    figure;
    % Plot Magnitude of the Channel Estimate
    % We take the mean across symbols to see the frequency response clearly
    subplot(2,1,1);
    plot(abs(H(:, 1))); % Plot first symbol column
    title('Practical Channel Estimate (Frequency Response)');
    xlabel('Subcarrier'); ylabel('Magnitude');
    grid on;

    subplot(2,1,2);
    imagesc(abs(H));
    title('Channel Magnitude Map (Time vs Freq)');
    xlabel('OFDM Symbol'); ylabel('Subcarrier');
    colorbar;
end

clc; clear;
receive = true;
nrb = 20;
scs = 15;
ncellid = 42;
ibar_SSB = 0;
carrier = nrCarrierConfig('NSizeGrid',nrb,'SubcarrierSpacing',scs);
dmrsSym = nrPBCHDMRS(ncellid,ibar_SSB);
dmrsInd = nrPBCHDMRSIndices(ncellid);
usrp = findsdru;

if (~receive)
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
    for i = 1:20
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
            'Gain',                 60, ...        % Good Rx Gain
            'MasterClockRate',      30.72e6, ...
            'DecimationFactor',     30.72e6 / sampleRate, ...
            'SamplesPerFrame',      length(refWaveform) * 50,...
            'OutputDataType',       'double'); % Capture 50 frames


        disp('Capturing...');
        rxBuffer = rxRadio();



        [t, mag] = nrTimingEstimate(carrier,rxBuffer, refGrid);


        if mag(t) < 0.1
            warning('Signal not found. Check Tx is running and Gains are high.');
        end

        % Correct Timing
        rxWaveformSync = rxBuffer(1+t:end);
        samplesPerSlot = length(refWaveform);
        if length(rxWaveformSync) < samplesPerSlot
            warning('Not enough samples left after sync.');
        end

        rxWaveformCut = rxWaveformSync(1:samplesPerSlot);

        % Turn waveform back into grid
        rxGrid = nrOFDMDemodulate(carrier, rxWaveformCut);
    
        [H, nVar] = nrChannelEstimate(rxGrid, dmrsInd, dmrsSym);

        % --- 8. Visualization ---
        subplot(2,1,1);
        plot(abs(H(:, 1))); % Plot first symbol column
        title('Practical Channel Estimate (Frequency Response)');
        xlabel('Subcarrier'); ylabel('Magnitude');
        grid on;
   

        hold on;
        pause(0.5)
    end
    hold off;
end
release(rxRadio);

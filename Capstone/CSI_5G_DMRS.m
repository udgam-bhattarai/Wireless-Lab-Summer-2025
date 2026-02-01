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

    refGrid = nrResourceGrid(carrier, 1);
    refGrid(dmrsInd) = dmrsSym;
    refWaveform = nrOFDMModulate(carrier, refGrid);
    info = nrOFDMInfo(carrier);
    sampleRate = info.SampleRate;

    % --- 1. Setup Visualization (Create 14 subplots once) ---
    figHandle = figure('Name', 'Channel Magnitude per Symbol', 'Position', [100 100 1200 800]);

    % Pre-configure axes for the 14 symbols (One slot has 14 symbols)
    axHandles = gobjects(14,1);
    for s = 1:14
        axHandles(s) = subplot(4, 4, s); % 4x4 grid
        title(axHandles(s), ['Symbol ' num2str(s-1)]);
        xlabel('Subcarrier'); ylabel('Mag');
        grid(axHandles(s), 'on');
        hold(axHandles(s), 'on'); % Crucial: This keeps previous lines!
    end

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


    for i = 1:50
        % A. Capture
        rxBuffer = rxRadio();

        % B. Sync (Using Waveform Correlation for stability)
        [t_raw, mag_vector] = nrTimingEstimate(carrier,rxBuffer, refGrid);
        [maxMag, peakIdx] = max(mag_vector);
        t = peakIdx - 1;

        % Safety check
        if maxMag < 0.1
            warning(['Iter ' num2str(i) ': Low Sync (' num2str(maxMag) '). Skipping.']);
             continue;
        end

        % C. Slice and Demodulate
        rxWaveformSync = rxBuffer(1+t:end);
        samplesPerSlot = length(refWaveform);

        if length(rxWaveformSync) < samplesPerSlot
            warning('Buffer too short after sync.');
            continue;
        end

        rxWaveformCut = rxWaveformSync(1:samplesPerSlot);
        rxGrid = nrOFDMDemodulate(carrier, rxWaveformCut);

        % D. Channel Estimate
        % H is [Subcarriers x 14 Symbols x 1 Rx x 1 Tx]
        [H, ~] = nrChannelEstimate(rxGrid, dmrsInd, dmrsSym);

        % E. Plotting Loop (Plot each symbol in its own subplot)
        for s = 1:14
            % Extract magnitude for Symbol (s-1)
            magData = abs(H(:, s));

            % Plot on the specific subplot for this symbol
            plot(axHandles(s), magData, 'DisplayName', ['Iter ' num2str(i)]);
            ylim(axHandles(s), [-5, 10]);
        end

        % Force update of the figure
        drawnow;
        pause(0.1);
    end

    release(rxRadio);
    disp('Finished.');
end
function [H, valid] = processNR(rxBuffer, carrier, refGrid, refWaveform, dmrsInd, dmrsSym)

    valid = false;
    H = [];

    % Timing estimation
    [t, mag] = nrTimingEstimate(carrier, rxBuffer, refGrid);

    if mag(t) < 0.1
        warning('Signal not found. Check Tx is running and Gains are high.');
        return;
    end

    % Timing correction
    rxWaveformSync = rxBuffer(1+t:end);
    samplesPerSlot = length(refWaveform);

    if length(rxWaveformSync) < samplesPerSlot
        warning('Not enough samples left after sync.');
        return;
    end

    rxWaveformCut = rxWaveformSync(1:samplesPerSlot);

    % OFDM demod
    rxGrid = nrOFDMDemodulate(carrier, rxWaveformCut);

    % Channel estimate
    [H, ~] = nrChannelEstimate(rxGrid, dmrsInd, dmrsSym);
        
    valid = true;
end

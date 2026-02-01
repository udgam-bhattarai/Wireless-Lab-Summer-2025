function [H, valid] = processWiFi(rxBuffer, cfgNonHT)

    valid = false;
    H = [];

    if isempty(rxBuffer)
        return;
    end

    rxBuffer = rxBuffer(:);

    % ---- Field indices ----
    ind = wlanFieldIndices(cfgNonHT);

    % Active subcarriers for 64-FFT Wi-Fi (no DC)
    subcarrier_index = [(7:32) (34:59)];

    % ---- Coarse packet detection ----
    startOffset1 = wlanPacketDetect(rxBuffer, 'CBW20', 0, 0.5);

    if isempty(startOffset1)
        return;
    end

    % Ensure enough samples remain
    if startOffset1 >= (length(rxBuffer) - ind.NonHTData(2))
        return;
    end

    % ---- Coarse frame (for fine timing + CFO) ----
    coarseFrame = rxBuffer(startOffset1 + (ind.LSTF(1):ind.LSIG(2)));

    % ---- CFO estimate + correction ----
    lstf = coarseFrame(ind.LSTF(1):ind.LSTF(2));
    cfo = wlanCoarseCFOEstimate(lstf, 'CBW20');
    rxBuffer = wlanCoarseCFOCorrect(rxBuffer, 'CBW20', cfo);

    % Re-extract after correction
    coarseFrame = rxBuffer(startOffset1 + (ind.LSTF(1):ind.LSIG(2)));

    % ---- Fine timing ----
    startOffset2 = wlanSymbolTimingEstimate(coarseFrame, 'CBW20');

    if isempty(startOffset2) || startOffset2 < 0
        return;
    end

    if (startOffset1 + startOffset2 + ind.NonHTData(2)) > length(rxBuffer)
        return;
    end

    fineFrame = rxBuffer(startOffset1 + startOffset2 + ...
                         (ind.LSTF(1):ind.NonHTData(2)));

    % ---- L-LTF demod ----
    idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');

    if idxLLTF(2) > length(fineFrame)
        return;
    end

    demodLLTF = wlanLLTFDemodulate( ...
        fineFrame(idxLLTF(1):idxLLTF(2)), cfgNonHT);

    % ---- Channel estimate ----
    H_active = wlanLLTFChannelEstimate(demodLLTF, cfgNonHT);

    H = zeros(64,1,'like',H_active);
    H(subcarrier_index) = H_active;

    valid = true;
end

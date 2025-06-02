function snr = estimateSNR(pilotEst)
    % Estimate SNR from pilot estimates
    if isempty(pilotEst)
        snr = 0;
        return;
    end
    
    % Simple SNR estimation based on pilot symbol variance
    signalPower = mean(abs(pilotEst).^2);
    noisePower = var(abs(pilotEst));
    
    if noisePower > 0
        snr = 10 * log10(signalPower / noisePower);
    else
        snr = 50; % High SNR case
    end
    
    % Clamp SNR to reasonable range
    snr = max(-10, min(50, snr));
end

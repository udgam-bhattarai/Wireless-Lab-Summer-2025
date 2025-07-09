function p = estimate_channel(p,is_plot)

if nargin == 1
    is_plot = false;
end

rxWaveform = p.rxWaveform;
cfgNonHT = p.wifi.cfgNonHT;

% Calculate the index points for different fields in the Preamble
idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');
% Get non-HT fields
ind = wlanFieldIndices(cfgNonHT);

% Coarse Packet Detection - Roughly detects the start of a packet and
% extracts the preamble from the WLAN packet
startOffset1 = wlanPacketDetect(rxWaveform, 'CBW20'); % Detect start of packet
nonHTFields = rxWaveform(startOffset1+(ind.LSTF(1):ind.LSIG(2)),:); % Extract Preamble

% Fine Packet Detection - Performs packet detection again on the already
% detected and segmented packet, to get an even better estimate of the
% start of the beacon packet
startOffset2 = wlanSymbolTimingEstimate(nonHTFields, "CBW20"); % Detect start of packet in the segmented data
nonHTFields = rxWaveform(startOffset1+startOffset2+(ind.LSTF(1):ind.LSIG(2)),:); % Re-extracts Preamble from the Received Data with better offset estimation

% Demodulate the LLTF
demodSig = wlanLLTFDemodulate(nonHTFields(idxLLTF(1):idxLLTF(2), :), cfgNonHT);

% Get channel estimation using the L-LTF
p.est.H_hat = wlanLLTFChannelEstimate(demodSig, cfgNonHT);
p.est.sc_index = [(6:31) (33:58)] + 1;


if is_plot
    H = p.ch_param.H;
    H_hat = p.est.H_hat;
    sc_index = p.est.sc_index;

    % Plot Real Part of Frequency Response
    figure;
    subplot(3,1,1)
    plot(10*log10(real(H).^2), 'DisplayName','True Channel, R'); hold on; grid on;
    % Plot the true channel's real part in dB
    plot(sc_index, 10*log10(real(H_hat).^2), 'o', 'DisplayName','Estimated Channel, R');
    % Overlay estimated real part from channel estimator
    ylim([-40 20])
    legend('location','best')

    % Plot Imaginary Part of Frequency Response
    subplot(3,1,2)
    plot(10*log10(imag(H).^2), 'DisplayName','True Channel, I'); hold on; grid on;
    % Plot the true channel's imaginary part in dB
    plot(sc_index, 10*log10(imag(H_hat).^2), 'o', 'DisplayName','Estimated Channel, I');
    % Overlay estimated imaginary part
    ylim([-40 20])
    legend('location','best')

    % Plot Magnitude (Absolute) of Frequency Response
    subplot(3,1,3)
    plot(10*log10(abs(H).^2), 'DisplayName','True Channel, abs'); hold on; grid on;
    % Plot true channel magnitude in dB
    plot(sc_index, 10*log10(abs(H_hat).^2), 'o', 'DisplayName','Estimated Channel, abs');
    % Overlay estimated magnitude
    ylim([-40 20])
    legend('location','best')

end

end
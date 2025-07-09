function p = generate_tx_signal_wifi(p,is_plot)

if nargin == 1
    is_plot = false;
end

% Generating an oversampled beacon packet by using the wlanWaveformGenerator function, specifying an idle time.
osf = 1;
tbtt = p.wifi.beaconInterval*1024e-6;
p.txWaveform = wlanWaveformGenerator(p.wifi.mpduBits,p.wifi.cfgNonHT,...
    OversamplingFactor=osf,Idletime=tbtt);

index_non_zero = find(p.txWaveform ~= 0);
p.P_tx = mean(abs(p.txWaveform(index_non_zero)).^2);

if is_plot
    % plot TX waveform
    figure
    plot(abs(p.txWaveform),'DisplayName','TX waveform')
    legend('location','best');
end

end
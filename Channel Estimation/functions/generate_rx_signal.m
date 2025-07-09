function p = generate_rx_signal(p,is_plot)

if nargin == 1
    is_plot = false;
end

txWaveform = [zeros(p.ch_param.integer_delay,1); p.txWaveform];
h = p.ch_param.h;

% noise free rx signal
rxWaveform = conv(txWaveform,h);

n_vec = (0:numel(rxWaveform)-1)';
cfo_sig = exp(-1i*2*pi*n_vec./p.Nfft * p.ch_param.cfo);
rxWaveform = rxWaveform.*cfo_sig;

sigma2_noise = p.P_tx./10^(p.ch_param.snr_dB/10);
w = sqrt(sigma2_noise/2).*(randn(size(rxWaveform)) + 1i * randn(size(rxWaveform)));

p.rxWaveform = rxWaveform + w;

if is_plot
    figure
    plot(abs(p.txWaveform),'DisplayName','TX waveform'); hold on; grid on;
    plot(abs(p.rxWaveform),'DisplayName','RX waveform');
    legend('location','best');
end
end
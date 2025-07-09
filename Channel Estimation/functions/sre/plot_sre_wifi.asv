function plot_sre_wifi(p,gen_param,fig_i)

delay_norm_hat = gen_param.batch{end}.delay_norm * p.delay_factor;
delay_norm = p.ch_param.delay_norm;
gamma_hat = gen_param.batch{end}.gamma;
dmc_awgn = gen_param.batch{end}.noise_dmc_power;

func_snr_dB = @(x) 10 .* log10(abs(x).^2) + p.ch_param.snr_dB;

figure(fig_i)
clf;
plot(p.ch_param.n_vec,func_snr_dB(p.ch_param.h .* sqrt(p.sre.Mf)),'DisplayName','SNR PDP Nfft'); hold on; grid on;
plot(p.ch_param.n_vec(1:p.sre.Mf).*p.delay_factor,func_snr_dB(sqrt(gen_param.X_power)),'DisplayName','SNR PDP Mf'); hold on; grid on;
stem(delay_norm,func_snr_dB(p.ch_param.gamma .* sqrt(p.sre.Mf)),'DisplayName','True Path SNR'); hold on; grid on;
stem(delay_norm_hat,func_snr_dB(gamma_hat .* sqrt(p.sre.Mf)),'--x','DisplayName','Estimated Path SNR'); hold on; grid on;
plot(p.ch_param.n_vec(1:p.sre.Mf).*p.delay_factor,func_snr_dB(sqrt(dmc_awgn)),'--x','DisplayName','EST DMC AWGN'); hold on; grid on;
xlim([0 32])
ylim([-10 40])
legend('location','best')

end
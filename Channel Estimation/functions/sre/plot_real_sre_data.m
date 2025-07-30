function plot_real_sre_data(p, gen_param, fig_i)

% Retrieve estimates
delay_norm_hat = gen_param.batch{end}.delay_norm * p.delay_factor;
gamma_hat = gen_param.batch{end}.gamma;
dmc_awgn = gen_param.batch{end}.noise_dmc_power;

% You can set this to 0 if you don't have an SNR estimate
snr_dB_offset = 0;
func_snr_dB = @(x) 10 .* log10(abs(x).^2) + snr_dB_offset;

% Prepare figure
figure(fig_i)
clf;

% Plot CSI-based PDP (from X_power)
plot((0:p.sre.Mf-1) * p.delay_factor, func_snr_dB(sqrt(gen_param.X_power)), ...
     'DisplayName','SNR PDP Mf'); hold on; grid on;

% Plot estimated paths
stem(delay_norm_hat, func_snr_dB(gamma_hat .* sqrt(p.sre.Mf)), '--x', ...
     'DisplayName','Estimated Path SNR'); hold on;

% Plot DMC/AWGN noise floor
plot((0:p.sre.Mf-1) * p.delay_factor, func_snr_dB(sqrt(dmc_awgn)), '--x', ...
     'DisplayName','Estimated DMC AWGN');

xlim([0 32])
ylim([-10 40])
legend('location','best')

end

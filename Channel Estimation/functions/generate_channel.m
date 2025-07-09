function p = generate_channel(p,is_plot)

if nargin == 1
    is_plot = false;
end

ch_param = p.ch_param;

% channel simulation
L = ch_param.L;
decay_rate = ch_param.decay_rate;
delay_max = ch_param.delay_max;
delay = sort(unifrnd(ch_param.delay_first,delay_max,L,1));
delay(1) = ch_param.delay_first;
% gain = exp(-delay./delay_max * decay_rate).* (randn(L,1) + 1i.*randn(L,1));
gain = exp(-delay./delay_max * decay_rate) .* exp(1i*2*pi*unifrnd(0,1,L,1));

% the variable gamma used to denote the path gain
p.ch_param.gamma = gain;
p.ch_param.delay_norm = delay; % normalized delay between 0 and Nfft-1



K = 2; % increases discrete-time impulse response to simulate long tail filter effects
n_vec = (0:K * p.Nfft-1)';
h = zeros(size(n_vec));

for i = 1:L
    hi = fftshift(gain(i).*p.filter.g(n_vec - delay(i)-p.Nfft/2*K,p.filter.a));
    h = h + hi;
end

% discrete-time channel
p.ch_param.h = h;
p.ch_param.n_vec = n_vec;
p.ch_param.H = fftshift(fft(h,p.Nfft));

if is_plot

    subplot(2,1,1)
    plot(p.ch_param.n_vec,(abs(p.ch_param.h).^2),'DisplayName','discrete-time'); hold on; grid on;
    stem(p.ch_param.delay_norm,(abs(p.ch_param.gamma).^2),'DisplayName','continuous-time')
    xlim([0 16])
    title('channel impulse response')
    legend('location','best')
    % obs.: we observe the discrete-time but want to estimate the continuous
    % time, somtimes it is a hard task!

    subplot(2,1,2)
    plot(10*log10(abs(p.ch_param.H).^2)); hold on; grid on;
    title('channel discrete-frequency response')

end

end
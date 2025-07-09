function p = load_filter(p,is_plot)

if nargin == 1
    is_plot = false;
end
p.filter.f1 = @(t,a) sinc(t).*cos(pi.*(t).*a);
p.filter.f2 = @(t,a) 1-(2.*a.*(t)).^2;
p.filter.f3 = @(a) pi/4*sinc(1/2/a);

p.filter.g_base = @(t,a) ...
    p.filter.f1((p.filter.f2(t,a)~=0).*t,a)./p.filter.f2((p.filter.f2(t,a)~=0).*t,a) ...
    .*(p.filter.f2(t,a)~=0)+not((p.filter.f2(t,a)~=0)).*p.filter.f3(a);
p.filter.g = @(t,a) p.filter.g_base(t,a);

% in case of measurerements this filter should be calibrated
n_vec = (0:p.Nfft - 1)';
G = fftshift(fft(fftshift(p.filter.g(n_vec-p.Nfft/2,p.filter.a))));
p.filter.G = G./sqrt(mean(abs(G).^2));

if is_plot
    % plot filter response and discrete-time channel
    t = -10:0.001:10;
    figure
    subplot(2,1,1)
    plot(t,p.filter.g(t,p.filter.a)); grid on;
    title('low pass filter response')

    subplot(2,1,2)
    plot(10*log10(abs(p.filter.G).^2)); grid on;
    title('filter in FD')
    ylim([-10 10])
end

end
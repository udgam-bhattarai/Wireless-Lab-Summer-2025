function p = format_estimated_channel(p,is_plot)

if nargin == 1
    is_plot = false;
end

% prepare channel estimation
sc_index = p.est.sc_index;
H_hat = p.est.H_hat;

X = zeros(p.sre.Mf,1);
X(sc_index-sc_index(1)+1) = H_hat;
index_zero = find(X==0);
X(index_zero) = (X(index_zero-1) + X(index_zero+1))/2;

n_vec = (0:p.sre.Mf-1)';
x_shift = exp(-1i * 2 * pi * n_vec .* p.sre.n_shift./ p.sre.Mf);
X = X .* x_shift;

if ~isfield(p,'X')
    p.X = X;
else
    p.X = [p.X X];
end

if is_plot
    figure
    stem(abs(X))
end

end
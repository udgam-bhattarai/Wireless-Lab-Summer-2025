function [gen_param,meas_param]  = load_sre_param(p)

% DO NOT CHANGE
% Parametrization
meas_param.enable_calibration = false; % set to false if no calibration is available
meas_param.cfo_correction =  true;
meas_param.antenna_spacing = 0.02; % in meters -> used to compute angles in degrees

%
% Mf is the fft size and should be Mf <= 256,
% higher Mf leads to better results but with higher complexity
% small Mfs, e.g., Mf = 128 should be used ONLY for quick testing
%
% we can also define some guard bands by making Mf < Msamples, e.g., for 4 guard carriers and we
% would have:
% - meas_param.Mf = 256
% - meas_param.Msamples = 256;
meas_param.Mf = p.sre.Mf;
meas_param.Msamples = p.sre.Mf;
% shift impulse repsonse for plotting
meas_param.sample_shift = 20;

meas_param.Nt = 1;
meas_param.Nr = 1;

% load system parameters
[gen_param,meas_param] = load_gen_param(meas_param);

% measurement configurations
gen_param.is_simulation = false; % keep false for wifi
gen_param.N_sim = 1024;

% LM related
gen_param.psi = 1000;
gen_param.counter_max = 16;
gen_param.threshold = 10^(6.03/10);
gen_param.enable_snr_check = true;
gen_param.enable_converg_metric = false;

% number of paths estimated per section,
% the higher this number, we look for more paths
% while this is good to look for the true specular components,
% it also adds more false peaks to be removed in post-processing, and
% complexity is also increase
% L_search can be made small for testing
gen_param.L_search = p.sre.L_search;
gen_param.L_ini = 1; % number of paths estimated in the first step

% if true, process snapshopts independendly
gen_param.independent_snapshot = true;
gen_param.N_group = p.sre.N_group; % number of snapshopts used to compute metric

% check if path is present in many snapshops, this may reduce false peaks incidence
gen_param.cross_check.flag = false;
% the smaller the threshold, more false peaks it filters
gen_param.cross_check.threshold = 0.9;

% dmc update rate, the less this value, less it takes for DMC to converge but in turn it is more difficult for the specular to be hidden below the DMC
gen_param.dmc_new_frac = 0.25;
% use neibouring samples to smooth out DMC
% if gen_param.dmc_window = 0, the specular path be misinterpreted as DMC
% if we make gen_param.dmc_window = 1, assuming that the DMC statistics
% does not change considebray for each time-bin, we have a better
% discrimination between DMC and specular
% if gen_param.dmc_window is too high, the DMC estimation becomes
% innacurate because dmc power different accros different time-bins will be
% significant
gen_param.dmc_window = 0;
gen_param.N_reset_dmc = 32000; % after gen_param.N_reset_dmc snapshots, dmc estimation starts from scratch to increase changes of convergence

% first element is duration, second element is max dmc window
gen_param.dmc_window_min = 0;
gen_param.dmc_window_max = 0;
gen_param.dmc_wd_adapt = [4,gen_param.dmc_window_max];

% clustering
gen_param.cluster_percent = 0.75;

gen_param.perfect_dmc_est = false;
gen_param.enable_dmc_est = true;



end
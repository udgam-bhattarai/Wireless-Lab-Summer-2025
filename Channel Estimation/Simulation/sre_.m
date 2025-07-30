function estimation = sre_(csi_data)
    % Predefining variables
    % parameters wifi
    p.wifi.beaconInterval = 1;
    p.wifi.band = 2.4;
    p.wifi.chNum = 6;
    
    % include all useful parameters in the struct p
    p = load_wifi_config(p);
    
    % parameters channel
    p.ch_param.L = 3;
    p.ch_param.delay_first = 3.45;
    p.ch_param.delay_max = 8;
    p.ch_param.cfo = 0;
    p.ch_param.integer_delay = 10;
    p.ch_param.snr_dB = 20; %
    p.ch_param.decay_rate = 2;
    
    % general parameters
    p.Nfft = 64;
    p.sre.Mf = 53; % number of allocated carriers + 1
    p.sre.n_shift = p.ch_param.delay_first-1;
    p.sre.L_search = 4; % number of paths that the algorithm will search
    p.delay_factor = p.Nfft/p.sre.Mf; % correct delay after carrier allocation
    p.sre.N_group = 8;
    
    rng(10)
    
    % enable/disable plots
    is_plot = true;
    
    csi_data = [csi_data; csi_data(end)];
        
    % Loading SRE parameters
    [gen_param, ~] = load_sre_param(p);
    
    gen_param.X = csi_data;
    
    % ini variables
    gen_param = ini_variables(gen_param);
    
    gen_param.enable_dmc_est = false; % keep DMC estimation false when using a single channel
    
    gen_param.X = csi_data;
    [gen_param,gen_param.X] = align_measurements(gen_param,gen_param.X);
    
    % inicial estimate of noise
    gen_param = estimate_noise_power(gen_param,false);
    
    
    gen_param.index_x = 1;
    [gen_param,output_valid] = search_paths_test(gen_param.X,gen_param);
    
    if output_valid
        gen_param = update_batch(gen_param);
    end
    
    fig_i = 6;
    plot_real_sre_data(p,gen_param,fig_i)
end

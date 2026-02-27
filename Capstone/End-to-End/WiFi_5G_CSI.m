clc;
clear;
usrp = findsdru;

%% 5G Variables
type = "CSIRS"; %SSB/CSIRS

[refGrid, refWaveform, carrier, ind, sym, SampleRate] = NR_param(type);


%% WiFi Variables
wifi_cfgNonHT = wlanNonHTConfig("PSDULength", 488);

%% Defining RX1
fiveG_rxRadio = comm.SDRuReceiver( ...
    'Platform',        usrp(1).Platform, ...
    'SerialNum',       usrp(1).SerialNum, ...
    'ChannelMapping',  1, ...
    'CenterFrequency', 5e9, ...
    'Gain',            70, ...
    'MasterClockRate', 30.72e6, ...   % ↓ halve clock
    'DecimationFactor',30.72e6 / SampleRate, ...          % keep math simple
    'SamplesPerFrame', length(refWaveform) * 50, ...
    'OutputDataType', 'single');

% Defining RX2
% wifi_rxRadio = comm.SDRuReceiver( ...
%     'Platform',        usrp(2).Platform, ...
%     'SerialNum',       usrp(2).SerialNum, ...
%     'ChannelMapping',  1, ...
%     'CenterFrequency', 2.437e9, ...
%     'Gain',            70, ...
%     'MasterClockRate', 20e6, ...   % ↓ halve clock
%     'DecimationFactor',1, ...
%     'SamplesPerFrame', 13520*50, ...% keep math simple
%     'OutputDataType', 'single');
% figure(1);
% Capture and Process 5G CSI data

testSSID = "TEST_BEACON";
%% Capture and Process 5G CSI data

while true
    disp('Capturing 5G...');
    rxBuf1 = fiveG_rxRadio();

    % disp('Capturing Wi-Fi...');
    % rxBuf2 = wifi_rxRadio();

    % Process both buffers
    [H1, valid1] = processNR(rxBuf1, carrier, refGrid, refWaveform, ind, sym);
    %
    % [H2, valid2] = processWiFi(rxBuf2, wifi_cfgNonHT);

    % Visualization

    clf;
    subplot(2,1,1);

    grid on;
    if valid1

        H1_pilots=zeros(size(H1));
        H1_pilots(ind) = H1(ind);
        mag_dB = 20*log10(abs(H1_pilots) + 1e-9);

        % Create a heatmap
        imagesc(mag_dB);
        colorbar;          % Add a color scale on the right
        clim([-50 30]);    % Lock the colors to your desired range

        % Formatting
        set(gca, 'YDir', 'normal'); % Flips Y-axis so subcarrier 1 is at the bottom
        title('CSI-RS Pilot Locations (Resource Grid)');
        xlabel('OFDM Symbol (1 to 14)');
        ylabel('Subcarrier Index (1 to 624)');
        pause(0.1);
    else
        title('5G: Signal Not Found');
    end
    %
    % subplot(2,1,2);
    %
    % if valid2
    %     plot(20*log10(abs(H2)));
    %     title("WiFi Channel Estimate, Beacon: " + wifiSSID);
    %     xlabel('Subcarrier'); ylabel('Magnitude');
    %     grid on;
    % else
    %     title('WiFi: Signal Not Found');
    % end

    drawnow;
end

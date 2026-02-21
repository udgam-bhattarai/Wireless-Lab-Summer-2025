clc;
clear all;
usrp = findsdru;

%% 5G Variables
nrb = 20;
scs = 15;
ncellid = 42;
ibar_SSB = 0;
carrier = nrCarrierConfig('NSizeGrid',nrb,'SubcarrierSpacing',scs);
dmrsSym = nrPBCHDMRS(ncellid,ibar_SSB);
dmrsInd = nrPBCHDMRSIndices(ncellid);

refGrid = nrResourceGrid(carrier, 1);
refGrid(dmrsInd) = dmrsSym;
refWaveform = nrOFDMModulate(carrier, refGrid);

info = nrOFDMInfo(carrier);
sampleRate = info.SampleRate;

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
    'DecimationFactor',30.72e6 / sampleRate, ...          % keep math simple
    'SamplesPerFrame', length(refWaveform) * 50, ...
    'OutputDataType', 'single');

% Defining RX2
wifi_rxRadio = comm.SDRuReceiver( ...
    'Platform',        usrp(2).Platform, ...
    'SerialNum',       usrp(2).SerialNum, ...
    'ChannelMapping',  1, ...
    'CenterFrequency', 2.437e9, ...
    'Gain',            70, ...
    'MasterClockRate', 20e6, ...   % ↓ halve clock
    'DecimationFactor',1, ...
    'SamplesPerFrame', 13520*50, ...% keep math simple
    'OutputDataType', 'single');
figure(1); 
% Capture and Process 5G CSI data

testSSID = "TEST_BEACON";
%% Capture and Process 5G CSI data

while true
    disp('Capturing 5G...');
    rxBuf1 = fiveG_rxRadio();

    disp('Capturing Wi-Fi...');
    rxBuf2 = wifi_rxRadio();

    % Process both buffers
    [H1, valid1] = processNR(rxBuf1, carrier, refGrid, refWaveform, dmrsInd, dmrsSym);

    [H2, valid2] = processWiFi(rxBuf2, wifi_cfgNonHT);

    % Visualization
    
    clf;
    subplot(2,1,1);
      ylim([-50 30]);
    if valid1
        H1_pilots=zeros(size(H1));
        H1_pilots(dmrsInd) = H1(dmrsInd);
        dmrsRows = 3:4:size(H1_pilots, 1);
        plot(dmrsRows, 20*log10(abs(H1_pilots(dmrsRows, 2))));
        title('5G Channel Estimate');
        xlabel('Subcarrier'); ylabel('Magnitude');
        grid on;
    else
        title('5G: Signal Not Found');
    end

    subplot(2,1,2);

    if valid2
        plot(20*log10(abs(H2)));
        title("WiFi Channel Estimate, Beacon: " + wifiSSID);
        xlabel('Subcarrier'); ylabel('Magnitude');
        grid on;
    else
        title('WiFi: Signal Not Found');
    end

    drawnow;
end

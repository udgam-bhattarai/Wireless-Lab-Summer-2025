clc;
clear all;
usrp = findsdru;

%% Variables
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


%% Defining RX1
fiveG_rxRadio = comm.SDRuReceiver( ...
    'Platform',        usrp(1).Platform, ...
    'SerialNum',       usrp(1).SerialNum, ...
    'ChannelMapping',  1, ...
    'CenterFrequency', 5e9, ...
    'Gain',            60, ...
    'MasterClockRate', 30.72e6, ...   % ↓ halve clock
    'DecimationFactor',30.72e6 / sampleRate, ...          % keep math simple
    'SamplesPerFrame', length(refWaveform) * 50, ...
    'OutputDataType', 'single');

%% Defining RX2
wifi_rxRadio = comm.SDRuReceiver( ...
    'Platform',        usrp(2).Platform, ...
    'SerialNum',       usrp(2).SerialNum, ...
    'ChannelMapping',  1, ...
    'CenterFrequency', 2.4e9, ...
    'Gain',            60, ...
    'MasterClockRate', 30.72e6, ...   % ↓ halve clock
    'DecimationFactor',30.72e6 / sampleRate, ...          % keep math simple
    'SamplesPerFrame', length(refWaveform) * 50, ...
    'OutputDataType', 'single');
figure(1); 
%% Capture and Process 5G CSI data
while true
    disp('Capturing 5G1...');
    rxBuf1 = fiveG_rxRadio();

    disp('Capturing 5G2...');
    rxBuf2 = wifi_rxRadio();

    % Process both buffers
    [H1, valid1] = processNR(rxBuf1, carrier, refGrid, refWaveform, dmrsInd, dmrsSym);
    [H2, valid2] = processNR(rxBuf2, carrier, refGrid, refWaveform, dmrsInd, dmrsSym);

    % --- Visualization ---
    
    clf;
    subplot(2,1,1);
    if valid1
        plot(abs(H1(:,1)));
        title('5GHz Channel Estimate');
        xlabel('Subcarrier'); ylabel('Magnitude');
        grid on;
    else
        title('5GHz: Signal Not Found');
    end

    subplot(2,1,2);
    if valid2
        plot(abs(H2(:,1)));
        title('2.4Ghz Channel Estimate');
        xlabel('Subcarrier'); ylabel('Magnitude');
        grid on;
    else
        title('2.4GHz: Signal Not Found');
    end

    drawnow;
end

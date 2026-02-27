clc;
clear;
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


figure('Name', 'Real-Time 5G Radar', 'NumberTitle', 'off');
hImage = imagesc(zeros(144 * 4, 2 * 16));
colormap('jet');
colorbar;
title('Live 5G CSI Range-Doppler Map');
xlabel('Doppler Axis (Symbols)');
ylabel('Range Axis (Subcarriers)');
clim([-80 0]);
while true
  
    rxBuf1 = fiveG_rxRadio();
    [H1, valid1] = processNR(rxBuf1, carrier, refGrid, refWaveform, dmrsInd, dmrsSym);

    if valid1  
        disp('Valid');
         % H1 = H1 -mean(H1,2);

        H1_pilots = zeros(size(H1));
        H1_pilots(dmrsInd) = H1(dmrsInd);

        i_col = floor(double(dmrsInd)./size(H1,1))+1;
        i_row = mod(double(dmrsInd),size(H1,1));

        H1_pilots = H1_pilots(:,2);
        H1_pilots = H1_pilots(i_row,:);

 
        range_matrix = (ifft(H1_pilots,size(H1_pilots,1) * 4));
        doppler_matrix = fftshift((ifft(range_matrix.',size(H1_pilots,2) * 16)).');
        
        % range_matrix = ifft(H1_pilots, [], 1);
        % doppler_matrix = fft(range_matrix, [], 2);
        % shifted_matrix = fftshift(doppler_matrix, 2);
        magnitude_matrix = 20*log10(abs(doppler_matrix));
        set(hImage, 'CData', magnitude_matrix);
        drawnow limitrate;
        pause(0.01);
    end
end

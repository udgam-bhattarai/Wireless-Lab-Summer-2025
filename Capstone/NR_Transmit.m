clc; clear;
receive = true;
nrb = 20;
scs = 15;
ncellid = 42;
ibar_SSB = 0;
carrier = nrCarrierConfig('NSizeGrid',nrb,'SubcarrierSpacing',scs);
dmrsSym = nrPBCHDMRS(ncellid,ibar_SSB);
dmrsInd = nrPBCHDMRSIndices(ncellid);
usrp = findsdru;

if (~receive)
    txGrid = nrResourceGrid(carrier, 1);
    txGrid(dmrsInd) = dmrsSym;

    % Modulate
    txWaveform = nrOFDMModulate(carrier, txGrid);

    info = nrOFDMInfo(carrier);
    sampleRate = info.SampleRate;

    txRadio = comm.SDRuTransmitter(...
        'Platform',             usrp.Platform, ...
        'SerialNum',            usrp.SerialNum,...
        'ChannelMapping',       1, ...
        'CenterFrequency',      2.4e9, ...
        'Gain',                 30, ...       % High gain for detection
        'MasterClockRate',      30.72e6, ...  % Standard 4G/5G clock
        'InterpolationFactor',  30.72e6 / sampleRate);


    % Scale waveform to prevent clipping on USRP
    txWaveform = txWaveform / max(abs(txWaveform));

    for i = 1:1000
        txRadio(txWaveform);
        disp(1/i);
    end


end
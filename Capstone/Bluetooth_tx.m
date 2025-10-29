%% Generating Bluetooth Signal
phyMode = 'LE1M';

cfgLLAdv = bleLLAdvertisingChannelPDUConfig(PDUType="Advertising indication", ...
    AdvertisingData="0123456789ABCDEF", ...
    AdvertiserAddress="1234567890AB");

messageBits = bleLLAdvertisingChannelPDU(cfgLLAdv);

sps = 8;

channelIndex = 37;

accessAddressLen = 32;

accessAddressHex = "8E89BED6";
accessAddressBin = int2bit(hex2dec(accessAddressHex),accessAddressLen,false);

sampleRate = sps*1e6*(1+1*(phyMode=="LE2M"));

txWaveform = bleWaveformGenerator(messageBits, ...
    Mode=phyMode, ...
    SamplesPerSymbol=sps, ...
    ChannelIndex=channelIndex, ...
    AccessAddress=accessAddressBin);

spectrumScope = spectrumAnalyzer(Method="welch", ...
    SampleRate=sampleRate, ...
    SpectrumType="Power density", ...
    YLimits=[-130 0], ...
    Title="Baseband Bluetooth LE Signal Spectrum", ...
    YLabel="Power spectral density");

spectrumScope(txWaveform);


%% Transmitting 
txCenterFrequency = 2.402e9;        % In Hz
txFrameLength = length(txWaveform);
txNumberOfFrames = 1e4;
txFrontEndSampleRate = sampleRate;


try 
    usrp = findsdru;
catch e
    fprintf("Couldn't find SDRU");
    exit;
end 

tx = comm.SDRuTransmitter( ...
    Platform = usrp.Platform, ...
    IPAddress = usrp.IPAddress, ...
    SerialNum = usrp.SerialNum, ...
    CenterFrequency = txCenterFrequency, ...
    Gain = txGain, ...
    MasterClockRate = 20e6);

currentFrame = 1;

try 
    while currentFrame <= txNumberofFrames
        tx(txWaveform);
        currentFrame = currentFrame + 1;
    end
catch ME
    fprintf("Error during USRP Transmission");
    exit;
end 

release(tx);

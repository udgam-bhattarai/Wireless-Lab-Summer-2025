clc;
clear;
%% Define USRP or Simulation
useUSRP = true;
transmit = true;

%% Creating Beacon Frame
% Defining the beacon signal parameters
ssid = "TEST_BEACON";
beaconInterval = 0;
band = 2.4;
chNum = 6;

% Creating a MAC frame-body configuration object, setting the SSID and Beacon Interval field value.
frameBodyConfig = wlanMACManagementConfig( ...
    BeaconInterval=beaconInterval, ...
    SSID=ssid);


% Adding the DS Parameter information element (IE) to the frame body.
dsElementID = 3;
dsInformation = dec2hex(chNum,2);
frameBodyConfig = frameBodyConfig.addIE(dsElementID,dsInformation);

% Creating beacon frame configuration object.
beaconFrameConfig = wlanMACFrameConfig(FrameType="Beacon", ...
    ManagementConfig=frameBodyConfig);

% Generating beacon frame bits.
[mpduBits,mpduLength] = wlanMACFrame(beaconFrameConfig,OutputFormat="bits");

% Calculating center frequency for the specified operating band and channel number.
fc = wlanChannelFrequency(chNum,band);


%% Creating Beacon Packet
% Configuring a non-HT beacon packet with the relevant PSDU length, specifying a channel bandwidth of 20 MHz, one transmit antenna,
% and BPSK modulation with a coding rate of 1/2 (corresponding to MCS index 0) by using the wlanNonHTConfig object.
cfgNonHT = wlanNonHTConfig("PSDULength", 488);

% Generating an oversampled beacon packet by using the wlanWaveformGenerator function, specifying an idle time.
osf = 1;
tbtt = beaconInterval*1024e-6;
txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,... 
    OversamplingFactor=osf,Idletime=tbtt);

% Getting the waveform sample rate.
Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);

%% Transmitting data
% txWaveform = txWaveform;
% Defining USRP transmit characteristics
if(useUSRP)
    try 
        usrp = findsdru;
        if (usrp.Status ~= "Success")
            disp('USRP is busy. Proceeding with simulation mode.');
            useUSRP = false;
        end
    catch
        warning('USRP not found. Proceeding with simulation mode.');
        useUSRP = false;
    end
end 

if (useUSRP)
    if(transmit)
        tx = comm.SDRuTransmitter(...
            'Platform', usrp.Platform, ...
            'SerialNum', usrp.SerialNum, ...                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ', ...
            'CenterFrequency', fc, ...
            'MasterClockRate', 20e6, ...
            'Gain', 70 , 'InterpolationFactor', 1); % Adjust gain as needed
        
        % Normalizing the data to be transmitted
        txWaveform = txWaveform./max(abs(txWaveform));
        % txWaveform = txWaveform(1:27201);
        % txWaveform = repmat(txWaveform,[5 1]);
        
        % Stream the waveform
        Nsig = 100000000;
        for k = 1:Nsig
            tx(txWaveform);
            disp(k/Nsig)
        end
        % Release the transmitter when done
        release(tx);
    end
end
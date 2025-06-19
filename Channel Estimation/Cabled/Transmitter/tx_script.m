clc;
% clear;

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
cfgNonHT = wlanNonHTConfig(PSDULength = 61);

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
tx = comm.SDRuTransmitter(...
    'Platform', 'B210', ...
    'SerialNum', '344C57A', ...
    'CenterFrequency', fc, ...
    'MasterClockRate', Rs, ...
    'Gain', 60, 'InterpolationFactor', 1); % Adjust gain as needed

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


%% Expected Receiver Behavior
rxData = txWaveform;
% Calculate the index points for different fields in the Preamble
idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');
% Get non-HT fields
ind = wlanFieldIndices(cfgNonHT);


rfRxFreq = fc; 

% Coarse Packet Detection - Roughly detects the start of a packet and
% extracts the preamble from the WLAN packet
startOffset1 = wlanPacketDetect(rxData, 'CBW20'); % Detect start of packet
nonHTFields = rxData(startOffset1+(ind.LSTF(1):ind.LSIG(2)),:); % Extract Preamble

% Fine Packet Detection - Performs packet detection again on the already
% detected and segmented packet, to get an even better estimate of the
% start of the beacon packet
startOffset2 = wlanSymbolTimingEstimate(nonHTFields, "CBW20"); % Detect start of packet in the segmented data
nonHTFields = rxData(startOffset1+startOffset2+(ind.LSTF(1):ind.LSIG(2)),:); % Re-extracts Preamble from the Received Data with better offset estimation

% Demodulate the LLTF 
demodSig = wlanLLTFDemodulate(nonHTFields(idxLLTF(1):idxLLTF(2), :), cfgNonHT);

% Get channel estimation using the L-LTF
H_hat = wlanLLTFChannelEstimate(demodSig, cfgNonHT);
subcarrier_index = [(6:31) (33:58)] + 1;

figure
ylim([-40 20])
legend('location','best')
plot(subcarrier_index,10*log10(abs(H_hat).^2),'o','DisplayName','Estimated Channel, abs');

ylim([-40 20])
legend('location','best')

clc;
clear;

%% Creating Beacon Frame
% Defining the beacon signal parameters
ssid = "TEST_BEACON";
beaconInterval = 1;
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
cfgNonHT = wlanNonHTConfig(PSDULength=61);

% Generating an oversampled beacon packet by using the wlanWaveformGenerator function, specifying an idle time.
osf = 1;
tbtt = beaconInterval*1024e-6;
txWaveform = wlanWaveformGenerator(mpduBits,cfgNonHT,... 
    OversamplingFactor=osf,Idletime=tbtt);

% Getting the waveform sample rate.
Rs = wlanSampleRate(cfgNonHT,OversamplingFactor=osf);

%% Creating Channel (for simulation)
% Defining the number of subcarriers that the total bandwidth is to be split into i.e.
% number of discrete FFT channels
Nfft = 64;

% Defining the nnumber of discrete-time multipaths, L = 1 means no multipath, pure AWGN
L = 4; % Number of discrete-time multipaths, L = 1 means no multipath, pure AWGN
channel_pdp = [1 0.3 0.1 0.05]; %  Power delay profile for each of the multipaths
noise_power = .001; % Noise Power
delay = randi(100); 

% Generating a random channel impulse response for a frequency-selective fading wireless channel 
% based on the given Power Delay Profile (PDP).
h = sqrt(channel_pdp) .* (sqrt(1/2) * (randn(L,1) + 1i * randn(L,1)));
% % % randn(...) + 1i*randn(...) creates complex Gaussian noise.
% % % sqrt(1/2) normalizes it to have unit power. 
% % % sqrt(channel_pdp) gives per-tap amplitude scaling based on desired power.
% % % .* applies that scaling per tap to get the final multipath channel h.

% Plotting the impulse response
figure
stem(abs(h).^2); 
title('Channel in Time Domain')
xlim([1 2*L])

% Plotting the frequency response
H = fftshift(fft(h,Nfft)); % Converting the impulse response into frequency response using FFT
figure
plot(10*log10(abs(H).^2))
title('Channel in Frequency Domain')

%% Additional Signal Transformations for testing
% Padding 0s before the packet to validate packet detection index.
rxWaveform = [zeros(delay, 1); txWaveform];
rxWaveform = conv(rxWaveform,h); % Signal after channel
rxWaveform = rxWaveform + (sqrt(noise_power/2) * (randn(size(rxWaveform)) + 1i * randn(size(rxWaveform)))); %  Adding complex Additive White Gaussian Noise (AWGN) to simulate real-world channel noise.

%% Transmitting data
txWaveform = rxWaveform;

% Defining USRP transmit characteristics
tx = comm.SDRuTransmitter(...
    'Platform', 'B210', ...
    'SerialNum', '344C57A', ...
    'CenterFrequency', fc, ...
    'MasterClockRate', Rs, ...
    'Gain', 50, 'InterpolationFactor', 1); % Adjust gain as needed

% Normalizing the data to be transmitted
txWaveform = txWaveform./max(abs(txWaveform));

% Stream the waveform
Nsig = 100000;
for k = 1:Nsig
    tx(txWaveform);
    disp(k/Nsig)
    
end
% Release the transmitter when done
release(tx);


%% Expected Receiver Behavior
rxData = rxWaveform;
% Calculate the index points for different fields in the Preamble
idxLLTF = wlanFieldIndices(cfgNonHT, 'L-LTF');
% Get non-HT fields
ind = wlanFieldIndices(cfgNonHT);


rfRxFreq = Rc; 

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

figure(1)
subplot(3,1,1)
plot(10*log10(real(H).^2),'DisplayName','True Channel, R'); hold on; grid on;
plot(subcarrier_index,10*log10(real(H_hat).^2),'o','DisplayName','Estimated Channel, R');
ylim([-40 20])
legend('location','best')

subplot(3,1,2)
plot(10*log10(imag(H).^2),'DisplayName','True Channel, I'); hold on; grid on;
plot(subcarrier_index,10*log10(imag(H_hat).^2),'o','DisplayName','Estimated Channel, I');

ylim([-40 20])
legend('location','best')
subplot(3,1,3)
plot(10*log10(abs(H).^2),'DisplayName','True Channel, abs'); hold on; grid on;
plot(subcarrier_index,10*log10(abs(H_hat).^2),'o','DisplayName','Estimated Channel, abs');

ylim([-40 20])
legend('location','best')
% performance metrics
estimated_delay = startOffset1 + startOffset2;
disp(['True delay: ' num2str(delay)])
disp(['Estimated delay: ' num2str(estimated_delay)])
mse = mean(abs(H_hat-H(subcarrier_index)).^2)
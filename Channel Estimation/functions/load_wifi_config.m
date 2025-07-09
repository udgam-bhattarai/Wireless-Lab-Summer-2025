function p = load_wifi_config(p)

% Defining the beacon signal parameters
ssid = "TEST_BEACON";

% Creating a MAC frame-body configuration object, setting the SSID and Beacon Interval field value.
frameBodyConfig = wlanMACManagementConfig( ...
    BeaconInterval = p.wifi.beaconInterval, ...
    SSID=ssid);

% Adding the DS Parameter information element (IE) to the frame body.
dsElementID = 3;
dsInformation = dec2hex(p.wifi.chNum,2);
frameBodyConfig = frameBodyConfig.addIE(dsElementID,dsInformation);

% Creating beacon frame configuration object.
beaconFrameConfig = wlanMACFrameConfig(FrameType="Beacon", ...
    ManagementConfig=frameBodyConfig);

% Generating beacon frame bits.
[p.wifi.mpduBits,p.wifi.mpduLength] = wlanMACFrame(beaconFrameConfig,OutputFormat="bits");

% Calculating center frequency for the specified operating band and channel number.
p.wifi.fc = wlanChannelFrequency(p.wifi.chNum,p.wifi.band);


% Configuring a non-HT beacon packet with the relevant PSDU length, specifying a channel bandwidth of 20 MHz, one transmit antenna,
% and BPSK modulation with a coding rate of 1/2 (corresponding to MCS index 0) by using the wlanNonHTConfig object.
p.wifi.cfgNonHT = wlanNonHTConfig(PSDULength=61);
end
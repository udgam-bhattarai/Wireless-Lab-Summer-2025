function prmFreqCalibRx = configureFreqCalibRx(platform, rfRxFreq, bbRxFreq)
% The function is called by
% FrequencyOffsetCalibrationReceiverUSRPHardwareExample.m MATLAB script for
% System object initialization.

%   Copyright 2013-2024 The MathWorks, Inc.

switch platform
  case {'B200','B210'}
    prmFreqCalibRx.MasterClockRate = 20e6;  %Hz
    prmFreqCalibRx.Fs = 200e3; % sps
  case {'E320'}
    prmFreqCalibRx.MasterClockRate = 50e6; %Hz
    prmFreqCalibRx.Fs = 200e3; % sps
  case {'X300','X310'}
    prmFreqCalibRx.MasterClockRate = 200e6; %Hz
    prmFreqCalibRx.Fs = 400e3; % sps
  case {'X410'}
    prmFreqCalibRx.MasterClockRate = 250e6; %Hz
    prmFreqCalibRx.Fs = 390.625e3; % sps
  case {'N200/N210/USRP2'}
    prmFreqCalibRx.MasterClockRate = 100e6; %Hz
    prmFreqCalibRx.Fs = 200e3; % sps
  case {'N300','N310'}
    prmFreqCalibRx.MasterClockRate = 153.6e6; %Hz
    prmFreqCalibRx.Fs = 200e3; % sps
  case {'N320/N321'}
    prmFreqCalibRx.MasterClockRate = 200e6; %Hz
    prmFreqCalibRx.Fs = 200e3; % sps
  otherwise
    error(message('sdru:examples:UnsupportedPlatform', ...
      platform))
end

% SDRu Receiver System object
prmFreqCalibRx.RxCenterFrequency = rfRxFreq; 
prmFreqCalibRx.Gain              = 38;
prmFreqCalibRx.DecimationFactor  = ...
  prmFreqCalibRx.MasterClockRate/prmFreqCalibRx.Fs;

prmFreqCalibRx.FrameLength       = 4096; 
prmFreqCalibRx.TotalFrames       = 1000;
prmFreqCalibRx.RxSineFrequency   = bbRxFreq; 
prmFreqCalibRx.OutputDataType    = 'double'; 

% Coarse Freq Offset estimation 
prmFreqCalibRx.FocFFTSize        = 2048;    

% EOF

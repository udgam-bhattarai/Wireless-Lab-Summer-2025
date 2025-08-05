

function [csi,rssi,mcs,gain] = CSI_extract(filename)

if(nargin<1)
    filename="packets_scenario_1.h5";
end

%% 1.  Load the index columns (cheap – they are uint / int64)

room_id   = h5read(filename,"/room_id");      % [N  ] uint8
setting_id= h5read(filename,"/setting_id");   % [N  ] uint8
pkt_idx   = h5read(filename,"/pkt_idx");      % [N  ] int32
seg_idx   = h5read(filename,"/seg_idx");      % [N  ] int32

%% 2.  Choose a **room / setting / segment** of interest

% Different segments have a different number of packets
ROOM    = 0;      % 0 → Room A , 1 → Room B
SETTING = 1;      % 0 → “_1”   , 1 → “_2”
SEGMENT =  140;    % 0 … 149

sel = (room_id   == ROOM   ) & ...
      (setting_id== SETTING) & ...
      (seg_idx   == SEGMENT);

read_sel = @(path) h5read(filename, path, ...
                          fliplr(find(sel,1,'first')),        ...
                          [nnz(sel); ones( ndims(h5info(filename,path).Dataspace.Size)-1 ,1)]);

td_us = h5read(filename,"/td_us");
td_us = td_us(sel);                       % micro-second time-stamps

rssi  = h5read(filename,"/rssi");   rssi  = rssi(:,sel).';   % [n_pkts,2]
mcs   = h5read(filename,"/mcs");    mcs   = mcs(sel);        % [n_pkts,1]

gain  = h5read(filename,"/gain");                           % struct → complex
gain  = complex(gain.r, gain.i);        gain  = gain(:,sel).';

csi   = h5read(filename,"/csi");                            % [250,4, N] or [248,4, N]
csi = complex(csi.r(:,:,sel), csi.i(:,:,sel));
% csi
end
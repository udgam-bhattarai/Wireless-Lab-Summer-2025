
 function array = parsedata(filename)


fileID = fopen(filename);
data= cell2mat(textscan(fileID, "%f"));
packetsize = 268;
activeindeces = [7:32, 34:59];

packet = data(1:packetsize);
timestamp = packet(1:3);        % [hour, min, sec]
rssi = packet(4:7);            % 4 RSSI values
mcs = packet(8);               % Single MCS value
gain = packet(9:12);           % 4 gain values
csi_raw = packet(13:268); % 256 CSI values

antenna1 = csi_raw(1:64);
antenna1 = antenna1(activeindeces);

antenna2= csi_raw(65:128);
antenna2 = antenna2(activeindeces);

antenna3 = csi_raw(129:192);
antenna3 = antenna3(activeindeces);

antenna4 = csi_raw(193:256);
antenna4 = antenna4(activeindeces);

array = [antenna1, antenna2, antenna3, antenna4];
 end



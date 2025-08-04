
for i = 1:100
data =parsedata('csi_2023_10_16_1.txt',i);
plot(abs((data(:,1))));
drawnow;
end

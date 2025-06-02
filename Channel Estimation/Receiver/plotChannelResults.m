function plotChannelResults(channelEstimates, snrEstimates, sampleRate)
    % Plot channel estimation results
    
    figure('Name', 'WLAN Channel Estimation Results', 'Position', [100 100 1200 800]);
    
    % Subplot 1: Channel magnitude response over time
    subplot(2,3,1);
    imagesc(abs(channelEstimates));
    colorbar;
    title('Channel Magnitude Response vs Time');
    xlabel('Subcarrier Index');
    ylabel('Packet Number');
    
    % Subplot 2: Channel phase response over time
    subplot(2,3,2);
    imagesc(angle(channelEstimates));
    colorbar;
    title('Channel Phase Response vs Time');
    xlabel('Subcarrier Index');
    ylabel('Packet Number');
    
    % Subplot 3: Average channel magnitude
    subplot(2,3,3);
    avgChannelMag = mean(abs(channelEstimates), 1);
    plot(avgChannelMag);
    grid on;
    title('Average Channel Magnitude Response');
    xlabel('Subcarrier Index');
    ylabel('Magnitude');
    
    % Subplot 4: SNR over time
    subplot(2,3,4);
    plot(snrEstimates, 'b-o');
    grid on;
    title('SNR Estimates Over Time');
    xlabel('Packet Number');
    ylabel('SNR (dB)');
    
    % Subplot 5: Channel magnitude histogram
    subplot(2,3,5);
    histogram(abs(channelEstimates(:)), 50);
    title('Channel Magnitude Distribution');
    xlabel('Magnitude');
    ylabel('Count');
    
    % Subplot 6: Channel impulse response (IFFT of first estimate)
    subplot(2,3,6);
    if ~isempty(channelEstimates)
        impulseResponse = ifft(channelEstimates(1,:));
        plot(abs(impulseResponse));
        grid on;
        title('Channel Impulse Response (First Packet)');
        xlabel('Sample Index');
        ylabel('Magnitude');
    end
    
    sgtitle(sprintf('WLAN 802.11n Channel Estimation Results (%d packets)', ...
        size(channelEstimates, 1)));
end

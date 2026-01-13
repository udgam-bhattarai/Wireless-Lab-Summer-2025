function plotWBCQISINR(perfectVals,practicalVals,subplotIdx,activeSlotNum,inpText)
%   Plots the wideband SINR and wideband CQI values for each codeword
%   across all specified active slots (1-based) (in which the CQI is
%   reported as other than NaN) for practical and perfect channel
%   estimation cases.

    subplot(subplotIdx)
    plot(perfectVals(:,:,1),'r-o');
    hold on;
    plot(practicalVals(:,:,1),'b-*');
    if ~all(isnan(perfectVals(:,:,2))) % Two codewords
        hold on;
        plot(perfectVals(:,:,2),'r:s');
        hold on;
        plot(practicalVals(:,:,2),'b:d');
        title(['Wideband ' inpText ' Values for Codeword 1&2']);
        legend({'Codeword 1:Perfect channel est.','Codeword 1:Practical channel est.','Codeword 2:Perfect channel est.','Codeword 2:Practical channel est.'});
    else
        title(['Wideband ' inpText ' Values for Codeword 1']);
        legend({'Codeword 1:Perfect channel est.','Codeword 1:Practical channel est.'});
    end
    xlabel('Slots');
    if strcmpi(inpText,'SINR')
        units = ' in dB';
    else
        units = '';
    end
    ylabel(['Wideband ' inpText ' Values' units]);
    xticks(1:size(perfectVals,2));
    xTickLables = num2cell(activeSlotNum(:)-1);
    xticklabels(xTickLables);
    [lowerBound,upperBound] = bounds([practicalVals(:);perfectVals(:)]);
    ylim([lowerBound-1 upperBound+3.5]);
end


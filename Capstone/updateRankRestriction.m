function RIRestriction = updateRankRestriction(dmrsConfig,CSIReportConfig)
% Adjust the CSI report configuration to limit the possible ranks for the given DMRS configuration
    RIRestriction    =  CSIReportConfig.RIRestriction;
    
    if ~dmrsConfig.DMRSEnhancedR18 && (dmrsConfig.DMRSLength == 1) && strcmpi(CSIReportConfig.CodebookType, 'Type1SinglePanel')
        if (dmrsConfig.DMRSConfigurationType == 1)
            % Allow ranks up to four for DMRS configuration type 1
            dmrsAllowedRanks    = [ones(1,4) zeros(1,4)];
        else
            % Allow ranks up to six for DMRS configuration type 2
            dmrsAllowedRanks    = [ones(1,6) zeros(1,2)];
        end

        RIRestriction = RIRestriction.*dmrsAllowedRanks;
    end
end


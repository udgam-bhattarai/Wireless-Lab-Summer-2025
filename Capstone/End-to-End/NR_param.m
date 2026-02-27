function [refGrid, refWaveform, carrier, ind, sym, SampleRate] = NR_param(type)

if type=="CSIRS"
    carrier = nrCarrierConfig;
    carrier.NSlot = 1;
    carrier.NSizeGrid = 52; % 52 RBs
    numRes = 8;
    csirs = nrCSIRSConfig;
    csirs.CSIRSType           = repmat({'nzp'}, 1, numRes);
    csirs.CSIRSPeriod         = repmat({[10 1]}, 1, numRes);
    csirs.RowNumber           = ones(1, numRes);              % Row 1 = 1 Port, Max Density
    csirs.Density             = repmat({'three'}, 1, numRes);
    csirs.NumRB               = repmat(52, 1, numRes);
    csirs.SubcarrierLocations = repmat({0}, 1, numRes);       % Keep the same subcarrier offset
    csirs.SymbolLocations     = {4, 5, 6, 7, 8, 9, 10, 11};
    ind_cell = nrCSIRSIndices(carrier, csirs, "OutputResourceFormat", "cell");
    sym_cell = nrCSIRS(carrier, csirs, "OutputResourceFormat", "cell");
    ind = nrCSIRSIndices(carrier,csirs);
    sym = nrCSIRS(carrier,csirs);
    % 6. Map to Grid
    refGrid = nrResourceGrid(carrier, 1);
    for i = 1:numRes
        refGrid(ind_cell{i}) = sym_cell{i};
    end
    refWaveform = nrOFDMModulate(carrier, refGrid);

    info = nrOFDMInfo(carrier);
    SampleRate = info.SampleRate;

elseif type=="SSB"
    nrb = 20;
    scs = 15;
    ncellid = 42;
    ibar_SSB = 0;
    carrier = nrCarrierConfig('NSizeGrid',nrb,'SubcarrierSpacing',scs);
    sym = nrPBCHDMRS(ncellid,ibar_SSB);
    ind = nrPBCHDMRSIndices(ncellid);

    refGrid = nrResourceGrid(carrier, 1);
    refGrid(ind) = sym;
    refWaveform = nrOFDMModulate(carrier, refGrid);

    info = nrOFDMInfo(carrier);
    SampleRate = info.SampleRate;
end
end
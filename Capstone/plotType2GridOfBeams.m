function plotType2GridOfBeams(PMISet,panelDims,numBeams,chEstType,subplotNum)
%   Plots the grid of beams by highlighting the beams that are used for the
%   type II codebook based precoding matrix generation.

    N1 = panelDims(1);
    N2 = panelDims(2);    
    % Get the oversampling factors
    O1 = 4;
    O2 = 1 + 3*(N2 ~= 1);

    % Extract q1, q2 values
    qSet = PMISet.i1(1:2);
    q1 = qSet(1)-1;
    q2 = qSet(2)-1;

    % Extract i12 value
    i12 = PMISet.i1(3);
    s = 0;
    % Find the n1, n2 values for all the beams, as defined in TS 38.214
    % Section 5.2.2.2.3
    n1_i12 = zeros(1,numBeams);
    n2_i12 = zeros(1,numBeams);
    for beamIdxI = 0:numBeams-1
        i12minussVal = i12 - s;
        xValues = numBeams-1-beamIdxI:N1*N2-1-beamIdxI;
        CValues = zeros(numel(xValues),1);
        for xIdx = 1:numel(xValues)
            if xValues(xIdx) >= numBeams-beamIdxI
                CValues(xIdx) = nchoosek(xValues(xIdx),numBeams-beamIdxI);
            end
        end
        indices = i12minussVal >= CValues;
        maxIdx = find(indices,1,'last');
        xValue = xValues(maxIdx);
        ei = CValues(maxIdx);
        s = s+ei;
        ni = N1*N2 - 1 - xValue;
        n1_i12(beamIdxI+1) = mod(ni,N1);
        n2_i12(beamIdxI+1) = (ni-n1_i12(beamIdxI+1))/N1;
    end
    m1 = O1*(0:N1-1) + q1;
    m2 = O2*(0:N2-1) + q2;

    % Calculate the indices of orthogonal basis set which corresponds to
    % the reported i12 value
    m1_LBeams = O1*(n1_i12) + q1;
    m2_LBeams = O2*(n2_i12) + q2;
    OrthogonalBeams = [repmat(m1,1,length(m2));reshape(repmat(m2,length(m1),1),1,[])]';

    % Plot the grid of beams
    numCirlcesInRow = N1*O1;
    numCirlcesInCol = N2*O2;
    subplot(2,1,subplotNum);
    circleRadius = 1;
    for colIdx = 0:numCirlcesInCol-1
        for rowIdx = 0:numCirlcesInRow-1
            p = nsidedpoly(1000, 'Center', [2*rowIdx 2*colIdx], 'Radius', circleRadius);
            if any(prod(OrthogonalBeams == [rowIdx colIdx],2))
                h2 = plot(p, 'FaceColor', 'w','EdgeColor','r','LineWidth',2.5);
                hold on;
                if any(prod([m1_LBeams' m2_LBeams'] == [rowIdx colIdx],2))
                    h3 = plot(p, 'FaceColor', 'g','LineStyle','-.');                
                end
            else
                h1 = plot(p, 'FaceColor', 'w');
            end
            hold on;
        end
    end
    rowLength = 2*circleRadius*O1;
    colLength = 2*circleRadius*O2;
    for n2 = 0:N2-1
        for n1 = 0:N1-1
            x1 = -1*circleRadius + rowLength*n1;
            x2 = x1 + rowLength;
            y1 = -1*circleRadius + colLength*n2;
            y2 = y1 + colLength;
            x = [x1, x2, x2, x1, x1];
            y = [y1, y1, y2, y2, y1];
            plot(x, y, 'b-', 'LineWidth', 2);
            hold on;
        end
    end
    
    xlabel('N1O1 beams');
    ylabel('N2O2 beams');
    axis equal;
    set(gca,'xtick',[],'ytick',[]);
    legend([h1 h2 h3],{'Oversampled DFT beams',['Orthogonal basis set with [q1 q2] = [' num2str(q1) ' ' num2str(q2) ']'],'Selected beam group'},'Location','northeast');
    title(['Grid of Beams or DFT Vectors for ' chEstType]);
end


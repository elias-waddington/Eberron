%DEMO_KHORVAIRE Build, analyze, and plot the Khorvaire transport model.
% Put all package files on the MATLAB path, then run this script.

% Build model, export CSV/MAT files, and draw the operating rail network.
M = khorvaire_network;

% Find fastest path using only edges with known travel times.
R = M.TimedRoute(M.BASE,"Sharn","Flamekeep");
disp(strjoin(R.Path," -> "));
fprintf('Running time: %.2f hours; distance: %.0f miles\n',R.Hours,R.Miles);
disp(R.Edges(:,{'EdgeID','Mode','DistanceMiles','TravelHours'}));

% Rank baseline settlements by normalized, unweighted betweenness.
T = M.Metrics(M.BASE);
T = sortrows(T,'BetweennessNormalized','descend');
disp(T(1:min(10,height(T)),:));

% Display operating connections together with assumed charter access.
M.Plot(M.CHARTER_ACCESS,'Title','Baseline + possible airship charters');

% Restore ONLY the Thaliost--Rekkenmark bridge (no Mournland restoration).
M.Plot(M.BRIDGE_RESTORED_RAIL,'Title','Rail with hypothetical bridge restoration');

% Select modes and assumptions independently.
H = M.View(M.All,'IncludeProposals',true,'Modes',["road","water"]);
M.Plot(H,'Title','Road/water layer, including campaign proposals');

% Test a city outage. All incident transport edges are removed with the city.
Houtage = rmnode(M.BASE,"Starilaskur");
Routage = M.TimedRoute(Houtage,"Sharn","Flamekeep");
fprintf('Timed route after Starilaskur outage available: %d\n',Routage.Found);

% Example: assign an explicitly user-defined charter time in a copy.
% This is an assumption, not a source-derived flight time.
% G = M.All;
% e = G.Edges.Mode == "air" & ...
%     ((string(G.Edges.EndNodes(:,1)) == "Sharn" & ...
%       string(G.Edges.EndNodes(:,2)) == "Wroat") | ...
%      (string(G.Edges.EndNodes(:,1)) == "Wroat" & ...
%       string(G.Edges.EndNodes(:,2)) == "Sharn"));
% G.Edges.TravelHours(e) = 4; % Replace with your campaign's chosen value.
% H = M.View(G,'IncludeCharters',true);
% Rcharter = M.TimedRoute(H,"Sharn","Wroat");
% disp(Rcharter.Edges);

% Export a plot manually if desired (schematic, not a geographic map).
% [fig,p] = M.Plot(M.RAIL_ONLY);
% print(fig,'operating_rail.png','-dpng','-r200');

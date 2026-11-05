function test_khorvaire()
%TEST_KHORVAIRE Regression checks. Run in MATLAB after adding this folder.
M = khorvaire_network([],false);
assert(numnodes(M.All) == 45);
assert(numedges(M.All) == 88);
assert(numedges(M.BASE) == 24);
assert(numedges(M.RAIL_ONLY) == 22);
assert(numedges(M.CHARTER_ACCESS) == 60);
assert(numedges(M.CAMPAIGN_NETWORK) == 82);
assert(numedges(M.RESTORED_RAIL) == 28);
assert(numedges(M.BRIDGE_RESTORED_RAIL) == 23);
assert(ismultigraph(M.All));
assert(sum(M.Edges.Status == "closed") == 6);
assert(sum(M.Edges.Status == "charter_candidate") == 36);
assert(sum(M.Edges.Status == "proposed") == 22);
assert(all(isnan(M.Edges.TravelHours(M.Edges.Mode ~= "rail"))));
assert(~ismember('Weight',M.All.Edges.Properties.VariableNames));
assert(numnodes(M.RAIL_ONLY) == 45); % Isolates retained in analysis.

% Source tables and graph tables must agree even though graph sorts edges.
[found,ix] = ismember(M.All.Edges.EdgeID,M.Edges.EdgeID);
assert(all(found));
assert(isequaln(M.All.Edges.TravelHours,M.Edges.TravelHours(ix)));

R = M.TimedRoute(M.BASE,"Sharn","Flamekeep");
expected = ["Sharn";"Wroat";"Starilaskur";"Vathirond"; ...
    "Aruldusk";"Sigilstar";"Flamekeep"];
assert(R.Found && abs(R.Hours - 83.75) < 1e-10);
assert(isequal(R.Path(:),expected));
assert(R.Miles == 2510);
assert(height(R.Edges) == 6);
assert(R.ExcludedUnknownTimeEdges == 2);

% Missing travel times are not zero-cost edges.
R = M.TimedRoute(M.BASE,"Ardev","Graywall");
assert(~R.Found && isinf(R.Hours));
assert(isempty(R.Path) && height(R.Edges) == 0);
R = M.TimedRoute(M.BASE,"Sharn","Korth");
assert(~R.Found);
R = M.TimedRoute(M.BASE,"Sharn","Sharn");
assert(R.Found && R.Hours == 0 && R.Miles == 0);

% Three rail components after excluding isolated settlement nodes.
H = subgraph(M.RAIL_ONLY,find(degree(M.RAIL_ONLY) > 0));
assert(max(conncomp(H)) == 3);
H = subgraph(M.BRIDGE_RESTORED_RAIL, ...
    find(degree(M.BRIDGE_RESTORED_RAIL) > 0));
assert(max(conncomp(H)) == 2);
% Bridge has unknown time, so connectivity improves but timed routing does not.
R = M.TimedRoute(M.BRIDGE_RESTORED_RAIL,"Sharn","Korth");
assert(~R.Found);

% Parallel air and rail edges must remain separate in timed routing.
G = M.All;
u = string(G.Edges.EndNodes(:,1));
v = string(G.Edges.EndNodes(:,2));
e = G.Edges.Mode == "air" & ...
    ((u == "Sharn" & v == "Wroat") | ...
     (u == "Wroat" & v == "Sharn"));
assert(sum(e) == 1);
G.Edges.TravelHours(e) = 4; % Test fixture only, not campaign data.
H = M.View(G,'IncludeCharters',true);
R = M.TimedRoute(H,"Sharn","Wroat");
assert(R.Found && R.Hours == 4);
assert(R.Edges.Mode == "air");
assert(isnan(R.Miles));

% Metrics use distinct neighbors, not number of parallel services.
T = M.Metrics(M.CAMPAIGN_NETWORK);
assert(all(T.DistinctNeighbors == degree(simplify(M.CAMPAIGN_NETWORK))));
assert(all(T.BetweennessNormalized >= 0));
assert(all(T.BetweennessNormalized <= 1 + 1e-12));
fprintf('All Khorvaire model regression checks passed.\n');
end

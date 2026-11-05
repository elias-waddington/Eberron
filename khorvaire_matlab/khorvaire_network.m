function M = khorvaire_network(outputDir, makePlot)
%KHORVAIRE_NETWORK Multilayer undirected Khorvaire transport model.
%   M = KHORVAIRE_NETWORK() builds the model, exports to khorvaire_model,
%   and plots operating rail connections (isolated nodes hidden in plot).
%   M = KHORVAIRE_NETWORK([], false) builds without exports or figures.
%   Target: MATLAB R2018a or later; base MATLAB only. Not runtime-tested here.
%
%   M.All                 Full multigraph, including closed/proposed edges.
%   M.Nodes, M.Edges       Editable source tables with stable edge IDs.
%   M.BASE                Operating published rail and road corridors.
%   M.RAIL_ONLY           Operating rail only; retains all 45 nodes.
%   M.CHARTER_ACCESS      Baseline + modeled airship charter candidates.
%   M.CAMPAIGN_NETWORK    Baseline + charters + proposed road/water links.
%   M.RESTORED_RAIL       All historical rail edges enabled, hypothetically.
%   M.BRIDGE_RESTORED_RAIL Operating rail + Thaliost--Rekkenmark bridge only.
%
%   H = M.View(M.All, 'IncludeCharters', true, 'Modes', ["rail","air"])
%   R = M.TimedRoute(M.BASE, "Sharn", "Flamekeep")
%   T = M.Metrics(H)
%   [fig,p] = M.Plot(H, 'ShowIsolates', false)
%   files = M.Export(M, 'my_output_folder')
%
%   Master graphs intentionally have no Weight column: mixed-mode times are
%   incompletely known. TimedRoute creates a time-weighted graph using only
%   finite, nonnegative TravelHours. Unknown distances/times are NaN, not 0.
%   Air links are POSSIBLE CHARTERS, not documented scheduled routes.
%   Proposed road/water links are worldbuilding assumptions, not canon.
%   Source data reproduce the preceding Python model without a new lore audit.
%
%   MATLAB documentation:
%   https://www.mathworks.com/help/matlab/ref/graph.html
%   https://www.mathworks.com/help/matlab/ref/graph.shortestpath.html
%   https://www.mathworks.com/help/matlab/ref/graph.centrality.html

if nargin < 1
    outputDir = fullfile(pwd, 'khorvaire_model');
end
if nargin < 2
    makePlot = true;
end
validateattributes(makePlot, {'logical'}, {'scalar'});

S.Explorer = "https://dl.icdst.org/pdfs/files3/4a4c486fae3b4d115bcb7acfda7436c2.pdf";
S.Gazetteer = "https://anyflip.com/qnhap/wykm/basic";
S.PlayerGuide = "http://image.lundo.com/rpg/dnd/Books/Eberron%20Player's%20Guide.pdf";
S.Ardev = "https://eberron.fandom.com/wiki/Ardev";
S.BorderRoad = "https://roll20.net/compendium/dnd5e/Rules:The%20Border%20Road?expansion=34904";

regions = {
    'Breland', {'Sharn','Wroat','Hatheril','Sword Keep','Starilaskur', ...
        'Sterngate','Vathirond','Ardev','New Cyre'};
    'Aundair', {'Marketplace','Passage','Fairhaven','Stormhome','Arcanix'};
    'Thrane', {'Aruldusk','Sigilstar','Flamekeep','Thaliost'};
    'Zilargo', {'Zolanberg','Korranberg','Trolanport'};
    'Karrnath', {'Korth','Rekkenmark','Atur','Vedykar','Fort Zombie', ...
        'Irontown','Vulyar','Karrlakton'};
    'Mror Holds', {'Krona Peak'};
    'Talenta Plains', {'Gatherhold'};
    'Valenar', {'Taer Valaestas'};
    'Eldeen Reaches', {'Varna','Greenheart','Sylbaran'};
    'Darguun', {'Rhukaan Draal'};
    'Droaam', {'Graywall','The Great Crag'};
    'Q''barra', {'Newthrone'};
    'Lhazaar Principalities', {'Regalport','Port Verge'};
    'Shadow Marches', {'Zarash''ak'};
    'Thronehold', {'Throneport'};
    'Mournland', {'Eston','Metrol'}
};
airTowers = ["Sharn";"Wroat";"Stormhome";"Fairhaven";"Flamekeep"; ...
    "Taer Valaestas";"Korth";"Trolanport";"Krona Peak"];
Name = strings(0,1);
Region = strings(0,1);
for k = 1:size(regions,1)
    cities = string(regions{k,2}(:));
    Name = [Name; cities]; %#ok<AGROW>
    Region = [Region; repmat(string(regions{k,1}),numel(cities),1)]; %#ok<AGROW>
end
SettlementStatus = repmat("inhabited",numel(Name),1);
SettlementStatus(Region == "Mournland") = "ruined";
AirshipTower = ismember(Name,airTowers);
InventoryProvenance = repmat( ...
    "Carried forward from preceding model; node-by-node sources not re-audited.", ...
    numel(Name),1);
Nodes = table(Name,Region,SettlementStatus,AirshipTower,InventoryProvenance);

% Explorer's Handbook pp. 20-21. Each row is an individual table segment.
rail = {
    'Sharn','Wroat',212,7;
    'Wroat','Hatheril',735,24.5;
    'Hatheril','Sword Keep',184,6.25;
    'Sword Keep','Marketplace',331,11;
    'Marketplace','Passage',322,10.75;
    'Passage','Fairhaven',461,15.5;
    'Fairhaven','Thaliost',620,20.75;
    'Wroat','Starilaskur',1007,33.5;
    'Starilaskur','Vathirond',315,10.5;
    'Vathirond','Aruldusk',342,11.5;
    'Aruldusk','Sigilstar',164,5.5;
    'Sigilstar','Flamekeep',470,15.75;
    'Starilaskur','Sterngate',396,13.25;
    'Sterngate','Zolanberg',260,8.75;
    'Zolanberg','Korranberg',271,9;
    'Korth','Rekkenmark',128,4.25;
    'Korth','Atur',274,9.25;
    'Atur','Vedykar',248,8.25;
    'Vedykar','Fort Zombie',256,8.5;
    'Krona Peak','Irontown',267,9;
    'Irontown','Vulyar',509,17;
    'Vulyar','Gatherhold',514,17
};
historical = {
    'Vathirond','Eston',630,21;
    'Vathirond','Metrol',710,23.75;
    'Fort Zombie','Metrol',418,14;
    'Metrol','Eston',780,26;
    'Gatherhold','Metrol',794,26.5;
    'Thaliost','Rekkenmark',NaN,NaN
};
Edges = empty_edges();
for k = 1:size(rail,1)
    Edges = append_edge(Edges,rail{k,1},rail{k,2},"rail", ...
        "operating","published_table",S.Explorer,rail{k,3},rail{k,4}, ...
        "Running time excludes station delays.");
end
for k = 1:size(historical,1)
    if k == size(historical,1)
        note = "Destroyed bridge; restoration is a hypothetical scenario.";
    else
        note = "No regular House Orien service after the Mourning.";
    end
    Edges = append_edge(Edges,historical{k,1},historical{k,2},"rail", ...
        "closed","published_historical",S.Explorer, ...
        historical{k,3},historical{k,4},note);
end
Edges = append_edge(Edges,"Ardev","Graywall","road","operating", ...
    "documented_corridor",S.Ardev,NaN,NaN, ...
    "Corridor may include unrepresented intermediate settlements.");
Edges = append_edge(Edges,"Ardev","Sylbaran","road","operating", ...
    "documented_corridor",S.BorderRoad,NaN,NaN, ...
    "Aggregated Border Road corridor, not a single-stage journey.");

sortedTowers = sort(airTowers);
pairIndex = nchoosek(1:numel(sortedTowers),2);
pairs = sortedTowers(pairIndex);
for k = 1:size(pairs,1)
    Edges = append_edge(Edges,pairs(k,1),pairs(k,2),"air", ...
        "charter_candidate","modeled_possibility",S.Explorer,NaN,NaN, ...
        "Tower endpoints documented; direct service, cost and time unknown.");
end
proposedRoad = [
    "Wroat","Ardev";
    "Graywall","The Great Crag";
    "Passage","Varna";
    "Varna","Greenheart";
    "Sylbaran","Varna";
    "Wroat","New Cyre";
    "New Cyre","Rhukaan Draal";
    "Sterngate","Rhukaan Draal";
    "Passage","Arcanix";
    "Korth","Karrlakton";
    "Vedykar","Vulyar";
    "Gatherhold","Taer Valaestas";
    "Trolanport","Zolanberg"
];
proposedWater = [
    "Sharn","Zarash'ak";
    "Sharn","Trolanport";
    "Trolanport","Korranberg";
    "Korranberg","Newthrone";
    "Newthrone","Regalport";
    "Regalport","Port Verge";
    "Stormhome","Throneport";
    "Throneport","Korth";
    "Stormhome","Zarash'ak"
];
for mode = ["road","water"]
    if mode == "road"
        pairs = proposedRoad;
    else
        pairs = proposedWater;
    end
    for k = 1:size(pairs,1)
        Edges = append_edge(Edges,pairs(k,1),pairs(k,2),mode, ...
            "proposed","campaign_assumption","",NaN,NaN, ...
            "Worldbuilding proposal, not a verified route; review geography.");
    end
end

assert(height(Nodes) == 45 && height(Edges) == 88);
assert(numel(unique(Nodes.Name)) == height(Nodes));
assert(all(ismember(Edges.Origin,Nodes.Name)));
assert(all(ismember(Edges.Destination,Nodes.Name)));

M.Metadata = struct('Name','Khorvaire city transport network', ...
    'Baseline','Published postwar setting, approximately 998 YK', ...
    'Scope','Selected settlements and major rail stations', ...
    'Geography','No coordinates; force layouts are not geographic', ...
    'DataNote','Replicates preceding Python dataset, including source uncertainty', ...
    'UnknownNumericValues','NaN, never zero-filled');
M.Sources = S;
M.Nodes = Nodes;
M.Edges = Edges;
M.All = make_graph(Nodes,Edges);
M.BASE = network_view(M.All);
M.RAIL_ONLY = network_view(M.All,'Modes',"rail");
M.CHARTER_ACCESS = network_view(M.All,'IncludeCharters',true);
M.CAMPAIGN_NETWORK = network_view(M.All, ...
    'IncludeCharters',true,'IncludeProposals',true);
M.RESTORED_RAIL = network_view(M.All, ...
    'RestoreHistorical',true,'Modes',"rail");
bridge = Edges.Mode == "rail" & Edges.Status == "closed" & ...
    ((Edges.Origin == "Thaliost" & Edges.Destination == "Rekkenmark") | ...
     (Edges.Origin == "Rekkenmark" & Edges.Destination == "Thaliost"));
M.BRIDGE_RESTORED_RAIL = network_view(M.All,'Modes',"rail", ...
    'RestoreEdgeIDs',Edges.EdgeID(bridge));
M.BaselineMetrics = network_metrics(M.BASE);
M.ExampleRoute = timed_route(M.BASE,"Sharn","Flamekeep");
M.View = @network_view;
M.TimedRoute = @timed_route;
M.Metrics = @network_metrics;
M.Plot = @plot_network;
M.Export = @export_model;

if ~isempty(outputDir) && strlength(string(outputDir)) > 0
    export_model(M,outputDir);
end
if makePlot
    plot_network(M.RAIL_ONLY,'Title','Operating lightning rail (schematic)');
end
end

function E = empty_edges()
E = table(strings(0,1),strings(0,1),strings(0,1),strings(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),zeros(0,1),zeros(0,1), ...
    strings(0,1),'VariableNames',{'Origin','Destination','EdgeID', ...
    'Mode','Status','Evidence','Source','DistanceMiles','TravelHours','Note'});
end

function E = append_edge(E,u,v,mode,status,evidence,source,miles,hours,note)
id = string(sprintf('E%03d',height(E)+1));
row = table(string(u),string(v),id,string(mode),string(status), ...
    string(evidence),string(source),miles,hours,string(note), ...
    'VariableNames',E.Properties.VariableNames);
E = [E; row];
end

function G = make_graph(N,E)
EndNodes = [E.Origin,E.Destination];
attributes = E(:,3:end);
G = graph([table(EndNodes),attributes],N);
end

function H = network_view(G,varargin)
% All node identities retained, including isolated/ruined settlements.
p = inputParser;
flag = @(x) islogical(x) && isscalar(x);
addParameter(p,'IncludeCharters',false,flag);
addParameter(p,'IncludeProposals',false,flag);
addParameter(p,'RestoreHistorical',false,flag);
addParameter(p,'RestoreEdgeIDs',strings(0,1));
addParameter(p,'Modes',strings(0,1));
parse(p,varargin{:});
a = p.Results;
ids = string(a.RestoreEdgeIDs);
assert(all(ismember(ids,G.Edges.EdgeID)), ...
    'RestoreEdgeIDs contains an unknown edge ID.');
restore = G.Edges.Status == "closed" & ...
    (a.RestoreHistorical | ismember(G.Edges.EdgeID,ids));
keep = G.Edges.Status == "operating" | restore;
if a.IncludeCharters
    keep = keep | G.Edges.Status == "charter_candidate";
end
if a.IncludeProposals
    keep = keep | G.Edges.Status == "proposed";
end
modes = string(a.Modes);
if ~isempty(modes)
    assert(all(ismember(modes,["rail","road","water","air"])), ...
        'Modes must be rail, road, water, or air.');
    keep = keep & ismember(G.Edges.Mode,modes);
end
% Edge removal preserves node order and edge metadata.
H = rmedge(G,find(~keep));
H.Edges.IsScenarioRestored = H.Edges.Status == "closed";
end

function R = timed_route(H,origin,destination)
% Exclude unknown travel times rather than treating them as free travel.
s = findnode(H,string(origin));
t = findnode(H,string(destination));
assert(isscalar(s) && s > 0,'Unknown origin.');
assert(isscalar(t) && t > 0,'Unknown destination.');
hours = H.Edges.TravelHours;
known = isfinite(hours) & hours >= 0;
T = rmedge(H,find(~known));
T.Edges.Weight = T.Edges.TravelHours;
[path,total,edgePath] = shortestpath(T,s,t,'Method','positive');
R.Origin = string(origin);
R.Destination = string(destination);
R.Path = string(T.Nodes.Name(path));
R.Hours = total;
R.Found = isfinite(total);
R.Edges = T.Edges(edgePath,:);
R.ExcludedUnknownTimeEdges = sum(~known);
if ~R.Found
    R.Miles = NaN;
    R.Note = "No route with fully specified travel times; this does not imply inaccessibility.";
else
    miles = R.Edges.DistanceMiles;
    if all(isfinite(miles))
        R.Miles = sum(miles);
    else
        R.Miles = NaN;
    end
    R.Note = "Running times only: waiting, transfers and border delays excluded.";
end
end

function T = network_metrics(H)
% Collapse parallel edges for distinct-neighbor and unweighted metrics.
S = simplify(H);
n = numnodes(S);
d = degree(S);
b = centrality(S,'betweenness');
if n > 2
    b = 2*b/((n-1)*(n-2));
else
    b = zeros(n,1);
end
component = conncomp(S);
component = component(:);
sizes = accumarray(component,1);
T = table(string(S.Nodes.Name),d,b,component,sizes(component),d == 0, ...
    'VariableNames',{'City','DistinctNeighbors','BetweennessNormalized', ...
    'Component','ComponentSize','IsolatedInSelectedData'});
end

function [f,p] = plot_network(H,varargin)
q = inputParser;
addParameter(q,'ShowIsolates',false,@(x)islogical(x) && isscalar(x));
addParameter(q,'Title','Khorvaire transport network (schematic)');
parse(q,varargin{:});
a = q.Results;
if ~a.ShowIsolates
    H = subgraph(H,find(degree(H) > 0));
end
f = figure('Color','w','Name','Khorvaire transport network');
ax = axes('Parent',f);
if numnodes(H) == 0
    text(ax,0.5,0.5,'No connected settlements in this selection.', ...
        'HorizontalAlignment','center');
    axis(ax,'off');
    p = [];
    return
end
oldRng = rng;
cleanup = onCleanup(@()rng(oldRng)); %#ok<NASGU>
rng(4,'twister');
p = plot(H,'Parent',ax,'Layout','force', ...
    'NodeLabel',cellstr(string(H.Nodes.Name)), ...
    'NodeColor',[0.15 0.28 0.34],'EdgeColor',[0.60 0.62 0.63], ...
    'LineWidth',1.4,'MarkerSize',5);
hold(ax,'on');
modes = ["rail","road","water","air"];
colors = [0.00 0.40 0.42; 0.55 0.36 0.17; 0.08 0.38 0.66; 0.53 0.40 0.68];
handles = gobjects(0,1);
labels = cell(0,1);
for k = 1:numel(modes)
    idx = find(H.Edges.Mode == modes(k));
    if ~isempty(idx)
        highlight(p,'Edges',idx,'EdgeColor',colors(k,:));
        handles(end+1,1) = plot(ax,NaN,NaN,'-', ...
            'Color',colors(k,:),'LineWidth',1.8); %#ok<AGROW>
        labels{end+1,1} = char(modes(k)); %#ok<AGROW>
    end
end
assumed = find(ismember(H.Edges.Status,["proposed","charter_candidate"]));
if ~isempty(assumed)
    highlight(p,'Edges',assumed,'LineStyle',':');
    handles(end+1,1) = plot(ax,NaN,NaN,':','Color',[0.3 0.3 0.3]);
    labels{end+1,1} = 'Modeled/proposed';
end
closed = find(H.Edges.Status == "closed");
if ~isempty(closed)
    highlight(p,'Edges',closed,'LineStyle','--','EdgeColor',[0.72 0.25 0.18]);
    handles(end+1,1) = plot(ax,NaN,NaN,'--','Color',[0.72 0.25 0.18]);
    labels{end+1,1} = 'Historical/closed in source';
end
towers = find(H.Nodes.AirshipTower);
if ~isempty(towers)
    highlight(p,towers,'MarkerSize',8,'NodeColor',[0.64 0.43 0.09]);
end
title(ax,char(a.Title),'Interpreter','none');
if ~isempty(handles)
    legend(ax,handles,labels,'Location','bestoutside');
end
axis(ax,'off');
hold(ax,'off');
end

function files = export_model(M,outputDir)
outputDir = char(outputDir);
if ~exist(outputDir,'dir')
    mkdir(outputDir);
end
files.Nodes = fullfile(outputDir,'nodes.csv');
files.Edges = fullfile(outputDir,'edges.csv');
files.Metrics = fullfile(outputDir,'node_metrics_baseline.csv');
files.MAT = fullfile(outputDir,'khorvaire_model.mat');
writetable(M.Nodes,files.Nodes);
writetable(M.Edges,files.Edges);
writetable(network_metrics(M.BASE),files.Metrics);
% Save portable graph/table data, not local-function handles.
Data = rmfield(M,{'View','TimedRoute','Metrics','Plot','Export'});
save(files.MAT,'Data');
end

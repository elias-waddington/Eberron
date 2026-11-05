# Khorvaire network — MATLAB port

A self-contained translation of the preceding Python/NetworkX model, with plotting, scenario selection, shortest-time routing, centrality metrics, and CSV/MAT exports.

## Quick start

Place the three `.m` files in one folder, open it in MATLAB (or add it to your path), and run:

```matlab
M = khorvaire_network;
```

This builds the model, writes data to `./khorvaire_model/`, and opens a schematic operating-rail plot. No internet connection or downloaded dataset is needed.

```matlab
M = khorvaire_network([], false);  % No exports or figures.
demo_khorvaire                    % Worked examples.
test_khorvaire                    % Run regression checks in MATLAB.
```

Target: MATLAB R2018a or later, base MATLAB only. Multigraph support was added in R2018a. Syntax has been checked with MISS_HIT; a MATLAB runtime was unavailable, so the code and included regression tests have not been executed in MATLAB. R2018a compatibility is a target, not a verified runtime result. See [MathWorks graph documentation](https://www.mathworks.com/help/matlab/ref/graph.html).

## Model inventory

- 45 nodes, 88 edges in the complete multigraph.
- 22 operating rail edges.
- 6 closed historical rail edges, retained for hypothetical restoration.
- 2 operating road-corridor edges.
- 36 possible charter connections among nine tower cities; NOT scheduled flights.
- 22 campaign-designed road/water links; NOT verified established services.

This is a code translation, not a fresh audit of Eberron geography or sources. All cities, topology, distances and running times are carried forward from the previous answer. Original source pointers are retained on edges. Node provenance explicitly records that node-by-node attribution has not been re-audited. Proposed water links may require coastal waypoints/geographic revision.

## Scenarios

| Field | Included edges |
|---|---|
| `M.All` | All 88 edges, regardless of status |
| `M.BASE` | 24 operating rail/road edges |
| `M.RAIL_ONLY` | 22 operating rail edges |
| `M.CHARTER_ACCESS` | 60 edges: baseline + charter candidates |
| `M.CAMPAIGN_NETWORK` | 82 edges: baseline + charters + proposals |
| `M.RESTORED_RAIL` | 28 edges: operating + all historical rail |
| `M.BRIDGE_RESTORED_RAIL` | 23 edges: operating rail + only the destroyed bridge |

All 45 nodes are retained in analysis, including isolates. An isolate means insufficient connectivity in the selected dataset, not an inaccessible settlement. Restored edges retain their source status `closed`; `IsScenarioRestored` distinguishes their scenario inclusion. `M.All` is an inventory, not an operational network: do not route through it unless intentionally allowing closed and proposed edges.

## Routes

```matlab
R = M.TimedRoute(M.BASE, "Sharn", "Flamekeep");
disp(strjoin(R.Path, " -> "));
disp(R.Hours);
disp(R.Edges);
```

Expected result from the supplied data: Sharn → Wroat → Starilaskur → Vathirond → Aruldusk → Sigilstar → Flamekeep, 83.75 running hours and 2,510 miles. This excludes waiting, transfers and border delays.

Unknown `TravelHours` and `DistanceMiles` are `NaN`, never zero. The master graph has no implicit `Weight`. `TimedRoute` removes edges with unknown/invalid times and assigns `Weight = TravelHours` only in its temporary routing graph. It returns the specific parallel edges selected, their stable IDs and attributes. An unavailable timed route has `Found = false`, `Hours = Inf`, and an empty path; this does not prove that no physical route exists. See [MathWorks shortestpath documentation](https://www.mathworks.com/help/matlab/ref/graph.shortestpath.html).

Connectivity without times can be explored separately:

```matlab
[path, hops] = shortestpath(M.CHARTER_ACCESS, "Sharn", "Korth", ...
    'Method', 'unweighted');
```

This finds the fewest modeled links, not the fastest journey or a verified scheduled service.

## Editing data

`M.Nodes` and `M.Edges` are source tables. Graph construction sorts edges; stable `EdgeID` values, not source-table row positions, should identify edges after construction. Each graph contains its own copy of the data; updating a source table does not automatically refresh existing scenarios.

To rebuild from edited tables:

```matlab
E = M.Edges;
N = M.Nodes;
% Edit E or N here.
EndNodes = [E.Origin, E.Destination];
G = graph([table(EndNodes), E(:,3:end)], N);
H = M.View(G, 'IncludeCharters', true);
```

Alternatively, edit properties directly in a graph copy, then regenerate the needed view. `demo_khorvaire.m` includes a commented example of assigning a user-defined charter time.

Custom filtering:

```matlab
H = M.View(M.All, 'IncludeProposals', true, ...
    'Modes', ["road", "water"]);
```

Selective restoration:

```matlab
ids = M.Edges.EdgeID(M.Edges.Status == "closed" & ...
    M.Edges.Origin == "Thaliost");
H = M.View(M.All, 'Modes', "rail", 'RestoreEdgeIDs', ids);
```

The bridge distance/time remain unknown after restoration. Connectivity can therefore improve without creating a fully timed path. `RestoreHistorical = true` enables every historical rail edge, including Mournland links; it is a hypothetical scenario, not a statement about current service.

## Metrics and figures

```matlab
T = M.Metrics(M.BASE);
T = sortrows(T, 'BetweennessNormalized', 'descend');
[fig, p] = M.Plot(M.CAMPAIGN_NETWORK);
M.Plot(M.BASE, 'ShowIsolates', true);
```

Distinct-neighbor degree and unweighted betweenness are calculated on a simplified copy so parallel services do not inflate neighbor counts. Betweenness is normalized by `2/((n-1)*(n-2))`, matching the undirected NetworkX normalization in the previous model. The normalization uses all selected nodes, including isolates. Component IDs are arbitrary labels, not persistent region identifiers. See [MathWorks centrality documentation](https://www.mathworks.com/help/matlab/ref/graph.centrality.html).

The force-directed layout is schematic, NOT geographic. Plotting hides isolates by default without removing them from the model. Edge colors distinguish modes; dotted edges are modeled/proposed; dashed red edges are historical/closed in the source. Larger ochre nodes identify airship towers. No fabricated coordinates or distance estimates are introduced.

## Outputs

The default call creates:

- `nodes.csv`: settlement inventory.
- `edges.csv`: complete multilayer edge inventory, source pointers and stable IDs.
- `node_metrics_baseline.csv`: baseline unweighted network metrics.
- `khorvaire_model.mat`: graph objects, data tables, scenario graphs and metadata in `Data`.

MAT replaces the Python implementation's GraphML export with a native MATLAB format. Loading `Data` does not restore helper-function handles; build `M = khorvaire_network([],false)` to obtain those handles, then use them on loaded graphs. Helpers are omitted deliberately from the MAT file to avoid serializing file-local function handles.

```matlab
load('khorvaire_model/khorvaire_model.mat', 'Data');
M = khorvaire_network([], false);
R = M.TimedRoute(Data.BASE, "Sharn", "Flamekeep");
```

To write updated model exports, update `M.Nodes`, `M.Edges`, and `M.BASE` consistently, then call `M.Export(M, 'new_folder')`. Default data exports do not automatically save plot images.

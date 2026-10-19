import pandas as pd
import networkx as nx
import math
import ast
from community import community_louvain

# --- THUẬT TOÁN ĐỊNH TUYẾN ---
def haversine(lat1, lon1, lat2, lon2):
    R = 6371 # Bán kính Trái Đất (km)
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

def heuristic(a, b, G):
    return haversine(G.nodes[a]["lat"], G.nodes[a]["lon"], G.nodes[b]["lat"], G.nodes[b]["lon"])

def find_boundary_nodes(G, partition):
    boundary_nodes = [node for node in G.nodes() if any(partition.get(neighbor) != partition[node] for neighbor in G.neighbors(node))]
    return list(set(boundary_nodes))

import numpy as np
from sklearn.neighbors import BallTree

def connect_components_if_needed(G, start, goal):
    """Automatically connects disconnected graph components via spatial nearest bridge if no path exists."""
    if nx.has_path(G, start, goal):
        return None
        
    try:
        comp_start = list(nx.node_connected_component(G, start))
        comp_goal = list(nx.node_connected_component(G, goal))
        
        coords_goal = np.radians([[G.nodes[n]['lat'], G.nodes[n]['lon']] for n in comp_goal])
        coords_start = np.radians([[G.nodes[n]['lat'], G.nodes[n]['lon']] for n in comp_start])
        
        tree = BallTree(coords_goal, metric='haversine')
        dist, ind = tree.query(coords_start, k=1)
        
        min_idx = np.argmin(dist)
        u_best = comp_start[min_idx]
        v_best = comp_goal[ind[min_idx][0]]
        bridge_dist = float(dist[min_idx][0] * 6371)
        
        print(f"[ROUTING] Dynamic Bridge created between node {u_best} and {v_best} (dist={bridge_dist:.2f} km)")
        G.add_edge(u_best, v_best, weight=bridge_dist, is_temp_bridge=True)
        return (u_best, v_best)
    except Exception as e:
        print(f"[ROUTING] Failed to create dynamic bridge: {e}")
        return None

def louvain_astar(G, partition, start, goal):
    if start not in G or goal not in G: 
        return None
        
    temp_bridge = connect_components_if_needed(G, start, goal)
    
    try:
        if partition.get(start) == partition.get(goal):
            try: 
                path = nx.astar_path(G, start, goal, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
                cost = nx.path_weight(G, path, weight="weight")
                print(f"[ROUTING] A* Path found (same partition). Cost/Weight: {cost:.2f}")
                return path
            except: 
                pass
        
        boundary_nodes = find_boundary_nodes(G, partition)
        relevant_boundaries = [n for n in boundary_nodes if partition.get(n) == partition.get(start)]
        
        # Tối ưu hóa: Sắp xếp các node biên theo khoảng cách Heuristic Haversine hướng về đích (goal)
        # Chỉ đánh giá top-3 node biên có tiềm năng tối ưu nhất về mặt địa lý thay vì duyệt vét cạn toàn bộ
        relevant_boundaries.sort(key=lambda n: heuristic(n, goal, G))
        candidate_boundaries = relevant_boundaries[:3] if len(relevant_boundaries) > 3 else relevant_boundaries
        
        best_path, best_cost = None, float("inf")
        for node in candidate_boundaries:
            try:
                p1 = nx.astar_path(G, start, node, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
                p2 = nx.astar_path(G, node, goal, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
                full_path = p1 + p2[1:]
                cost = nx.path_weight(G, full_path, weight="weight")
                if cost < best_cost: 
                    best_cost, best_path = cost, full_path
            except: 
                continue
                
        if best_path:
            print(f"[ROUTING] Louvain A* Path found (cross partition). Cost/Weight: {best_cost:.2f}")
            return best_path

        # Fallback to standard A*
        try:
            fallback_path = nx.astar_path(G, start, goal, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
            print(f"[ROUTING] Fallback A* Path found. Cost/Weight: {nx.path_weight(G, fallback_path, weight='weight'):.2f}")
            return fallback_path
        except Exception as e:
            print(f"[ROUTING] No path found between {start} and {goal}: {e}")
            return None
    finally:
        if temp_bridge:
            u, v = temp_bridge
            if G.has_edge(u, v) and G.edges[u, v].get("is_temp_bridge"):
                G.remove_edge(u, v)

# --- TÍNH NĂNG ĐỊNH TUYẾN ĐỘNG THÍCH ỨNG RỦI RO (RISK-AWARE DYNAMIC DETOUR) ---

def update_edge_risk(G, u, v, risk_factor=1.0, beta=10.0):
    """
    Gán trọng số phạt rủi ro lên cung đường (u, v) khi nhận cảnh báo chấn động/sạt lở.
    Formula: w' = w * (1 + beta * risk_factor)
    """
    if G.has_edge(u, v):
        orig_weight = G[u][v].get("base_weight", G[u][v].get("weight", 1.0))
        G[u][v]["base_weight"] = orig_weight
        penalty = 1.0 + beta * risk_factor
        G[u][v]["weight"] = orig_weight * penalty
        G[u][v]["risk_factor"] = risk_factor
        return True
    return False

def report_hazard_at_coordinates(G, lat, lon, radius_km=0.5, risk_factor=1.0, beta=10.0):
    """
    Tìm tất cả các cạnh/cung đường nằm trong bán kính radius_km của tọa độ nguy hiểm và phạt trọng số.
    """
    affected_edges = []
    for u, v, data in G.edges(data=True):
        u_lat, u_lon = G.nodes[u]["lat"], G.nodes[u]["lon"]
        v_lat, v_lon = G.nodes[v]["lat"], G.nodes[v]["lon"]
        d_u = haversine(lat, lon, u_lat, u_lon)
        d_v = haversine(lat, lon, v_lat, v_lon)
        if min(d_u, d_v) <= radius_km:
            update_edge_risk(G, u, v, risk_factor, beta)
            affected_edges.append((u, v))
    print(f"[DYNAMIC ROUTING] Phát hiện điểm nguy hiểm tại ({lat:.4f}, {lon:.4f}). Đã phạt trọng số {len(affected_edges)} đoạn đường xung quanh.")
    return affected_edges

def reset_graph_risks(G):
    """Khôi phục lại trọng số khoảng cách địa lý gốc cho toàn bộ đồ thị."""
    for u, v, data in G.edges(data=True):
        if "base_weight" in data:
            data["weight"] = data["base_weight"]
            data.pop("base_weight", None)
            data.pop("risk_factor", None)

def dynamic_risk_aware_astar(G, partition, start, goal, hazards=None):
    """
    Tìm đường tự động né tránh rủi ro khi có danh sách các điểm nguy hiểm (lat, lon, risk_factor).
    """
    if hazards:
        for h in hazards:
            report_hazard_at_coordinates(G, h["lat"], h["lon"], h.get("radius_km", 0.5), h.get("risk", 1.0))
    
    detour_path = louvain_astar(G, partition, start, goal)
    return detour_path



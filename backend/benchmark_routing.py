#!/usr/bin/env python3
"""
benchmark_routing.py — So sánh hiệu suất A* thuần vs A* + Louvain Clustering
Dùng dataset thực tế của dự án DATN_253.

Output: Biểu đồ line chart (PNG) + bảng kết quả console.
"""

import os
import sys
import io
import math
import ast
import time
import random
import statistics

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import pandas as pd
import networkx as nx
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for saving PNGs

# ============================================================
# 1. THUẬT TOÁN (copy từ main.py)
# ============================================================
def haversine(lat1, lon1, lat2, lon2):
    R = 6371
    lat1, lon1, lat2, lon2 = map(math.radians, [lat1, lon1, lat2, lon2])
    dlat, dlon = lat2 - lat1, lon2 - lon1
    a = math.sin(dlat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

def heuristic(a, b, G):
    return haversine(G.nodes[a]["lat"], G.nodes[a]["lon"], G.nodes[b]["lat"], G.nodes[b]["lon"])

def astar_only(G, start, goal):
    """A* thuần — không dùng Louvain clustering."""
    try:
        return nx.astar_path(G, start, goal, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
    except nx.NetworkXNoPath:
        return None

def find_boundary_nodes(G, partition):
    return list(set(
        node for node in G.nodes()
        if any(partition.get(neighbor) != partition[node] for neighbor in G.neighbors(node))
    ))

def louvain_astar(G, partition, start, goal):
    """A* + Louvain — routing qua boundary nodes nếu khác cluster."""
    if start not in G or goal not in G:
        return None
    if partition[start] == partition[goal]:
        try:
            return nx.astar_path(G, start, goal, heuristic=lambda u, v: heuristic(u, v, G), weight="weight")
        except:
            return None
    
    boundary_nodes = find_boundary_nodes(G, partition)
    relevant_boundaries = [n for n in boundary_nodes if partition[n] == partition[start]]
    
    # Tối ưu hóa: Sắp xếp các node biên theo khoảng cách Heuristic Haversine hướng về đích (goal)
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
    return best_path


# ============================================================
# 2. LOAD DATASET
# ============================================================
base_dir = os.path.dirname(os.path.abspath(__file__))
csv_path = os.path.join(base_dir, "dataset.csv")

print(f"📂 Loading dataset from: {csv_path}")
df = pd.read_csv(csv_path, encoding="utf-8")

# Build full graph
G_full = nx.Graph()
for _, row in df.iterrows():
    G_full.add_node(int(row["id"]), lat=float(row["latitude"]), lon=float(row["longitude"]))

adj_col = "adjacent_nodes" if "adjacent_nodes" in df.columns else "connected_nodes"
for _, row in df.iterrows():
    source = int(row["id"])
    conn_str = str(row.get(adj_col, "")).strip()
    if not conn_str or conn_str == "nan":
        continue
    try:
        if not conn_str.startswith("["):
            conn_str = f"[{conn_str}]"
        neighbors = ast.literal_eval(conn_str)
        if isinstance(neighbors, int):
            neighbors = [neighbors]
        for target in neighbors:
            target = int(target)
            if target not in G_full:
                continue
            d = haversine(
                G_full.nodes[source]["lat"], G_full.nodes[source]["lon"],
                G_full.nodes[target]["lat"], G_full.nodes[target]["lon"]
            )
            G_full.add_edge(source, target, weight=d)
    except:
        continue

total_nodes = G_full.number_of_nodes()
total_edges = G_full.number_of_edges()
print(f"✅ Full graph loaded: {total_nodes} nodes, {total_edges} edges")


# ============================================================
# 3. BENCHMARK FUNCTION
# ============================================================
def create_subgraph(G, target_size):
    """Tạo subgraph bằng BFS từ 1 node ngẫu nhiên."""
    if target_size >= G.number_of_nodes():
        return G.copy()
    
    all_nodes = list(G.nodes())
    start = random.choice(all_nodes)
    
    # BFS expansion
    visited = set()
    queue = [start]
    while queue and len(visited) < target_size:
        node = queue.pop(0)
        if node in visited:
            continue
        visited.add(node)
        for neighbor in G.neighbors(node):
            if neighbor not in visited:
                queue.append(neighbor)
    
    return G.subgraph(visited).copy()


def benchmark_graph(G_sub, num_trials=20):
    """Chạy benchmark A* thuần vs A*+Louvain trên 1 graph."""
    nodes = list(G_sub.nodes())
    if len(nodes) < 2:
        return None, None
    
    # Pre-compute Louvain partition
    try:
        from community import community_louvain
        partition = community_louvain.best_partition(G_sub)
    except:
        return None, None
    
    astar_times = []
    louvain_times = []
    
    success_count = 0
    attempt = 0
    max_attempts = num_trials * 5  # Allow more attempts to get enough successful routes
    
    while success_count < num_trials and attempt < max_attempts:
        attempt += 1
        start, goal = random.sample(nodes, 2)
        
        # Check connectivity first
        if not nx.has_path(G_sub, start, goal):
            continue
        
        # Benchmark A* thuần
        t0 = time.perf_counter()
        path_a = astar_only(G_sub, start, goal)
        t1 = time.perf_counter()
        
        if path_a is None:
            continue
        
        # Benchmark A* + Louvain
        t2 = time.perf_counter()
        path_l = louvain_astar(G_sub, partition, start, goal)
        t3 = time.perf_counter()
        
        if path_l is None:
            continue
        
        astar_times.append((t1 - t0) * 1000)  # ms
        louvain_times.append((t3 - t2) * 1000)  # ms
        success_count += 1
    
    if len(astar_times) == 0:
        return None, None
    
    return {
        "mean": statistics.mean(astar_times),
        "median": statistics.median(astar_times),
        "min": min(astar_times),
        "max": max(astar_times),
        "stdev": statistics.stdev(astar_times) if len(astar_times) > 1 else 0,
    }, {
        "mean": statistics.mean(louvain_times),
        "median": statistics.median(louvain_times),
        "min": min(louvain_times),
        "max": max(louvain_times),
        "stdev": statistics.stdev(louvain_times) if len(louvain_times) > 1 else 0,
    }


# ============================================================
# 4. RUN BENCHMARKS
# ============================================================
graph_sizes = [100, 500, 1000, 5000, 10000, total_nodes]
num_trials = 20

results = []
print(f"\n{'='*70}")
print(f"{'BENCHMARK: A* thuần vs A* + Louvain Clustering':^70}")
print(f"{'='*70}")
print(f"{'Graph Size':>12} | {'A* thuần (ms)':>16} | {'A*+Louvain (ms)':>16} | {'Speedup':>8}")
print(f"{'-'*12}-+-{'-'*16}-+-{'-'*16}-+-{'-'*8}")

for size in graph_sizes:
    actual_size = min(size, total_nodes)
    print(f"\n🔄 Benchmarking graph with ~{actual_size} nodes...", end=" ", flush=True)
    
    G_sub = create_subgraph(G_full, actual_size)
    actual_n = G_sub.number_of_nodes()
    actual_e = G_sub.number_of_edges()
    
    astar_stats, louvain_stats = benchmark_graph(G_sub, num_trials)
    
    if astar_stats is None:
        print(f"SKIPPED (insufficient connected paths)")
        continue
    
    speedup = astar_stats["mean"] / louvain_stats["mean"] if louvain_stats["mean"] > 0 else 0
    
    results.append({
        "nodes": actual_n,
        "edges": actual_e,
        "astar_mean": astar_stats["mean"],
        "astar_median": astar_stats["median"],
        "louvain_mean": louvain_stats["mean"],
        "louvain_median": louvain_stats["median"],
        "speedup": speedup,
    })
    
    print(f"Done!")
    print(f"{actual_n:>12,} | {astar_stats['mean']:>13.2f} ms | {louvain_stats['mean']:>13.2f} ms | {speedup:>7.2f}x")


# ============================================================
# 5. VẼ BIỂU ĐỒ
# ============================================================
if len(results) >= 2:
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    
    nodes_list = [r["nodes"] for r in results]
    astar_means = [r["astar_mean"] for r in results]
    louvain_means = [r["louvain_mean"] for r in results]
    speedups = [r["speedup"] for r in results]
    
    # Chart 1: Execution Time Comparison
    ax1.plot(nodes_list, astar_means, 'o-', color='#e74c3c', linewidth=2, markersize=8, label='A* thuần (Brute-force)')
    ax1.plot(nodes_list, louvain_means, 's-', color='#2ecc71', linewidth=2, markersize=8, label='A* + Louvain Clustering')
    ax1.set_xlabel('Số lượng Node trong đồ thị', fontsize=12)
    ax1.set_ylabel('Thời gian trung bình (ms)', fontsize=12)
    ax1.set_title('So sánh thời gian thực thi\nA* thuần vs A* + Louvain', fontsize=13, fontweight='bold')
    ax1.legend(fontsize=11)
    ax1.grid(True, alpha=0.3)
    ax1.set_xscale('log')
    ax1.set_yscale('log')
    
    # Chart 2: Speedup Factor
    colors = ['#3498db' if s >= 1 else '#e74c3c' for s in speedups]
    bars = ax2.bar(range(len(nodes_list)), speedups, color=colors, alpha=0.8, edgecolor='black', linewidth=0.5)
    ax2.set_xticks(range(len(nodes_list)))
    ax2.set_xticklabels([f"{n:,}" for n in nodes_list], rotation=45, ha='right')
    ax2.set_xlabel('Số lượng Node', fontsize=12)
    ax2.set_ylabel('Hệ số tăng tốc (Speedup)', fontsize=12)
    ax2.set_title('Hệ số tăng tốc khi dùng Louvain\n(>1 = Louvain nhanh hơn)', fontsize=13, fontweight='bold')
    ax2.axhline(y=1.0, color='red', linestyle='--', alpha=0.5, label='Baseline (1x)')
    ax2.legend(fontsize=10)
    ax2.grid(True, alpha=0.3, axis='y')
    
    # Add value labels on bars
    for bar, val in zip(bars, speedups):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05,
                f'{val:.2f}x', ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    plt.tight_layout()
    
    output_path = os.path.join(base_dir, "benchmark_astar_vs_louvain.png")
    plt.savefig(output_path, dpi=150, bbox_inches='tight')
    print(f"\n📊 Biểu đồ đã lưu: {output_path}")
    
    # Also save detailed results
    print(f"\n{'='*70}")
    print(f"{'KẾT QUẢ CHI TIẾT':^70}")
    print(f"{'='*70}")
    print(f"{'Nodes':>8} | {'Edges':>8} | {'A* (ms)':>10} | {'Louvain (ms)':>12} | {'Speedup':>8}")
    print(f"{'-'*8}-+-{'-'*8}-+-{'-'*10}-+-{'-'*12}-+-{'-'*8}")
    for r in results:
        print(f"{r['nodes']:>8,} | {r['edges']:>8,} | {r['astar_mean']:>9.2f} | {r['louvain_mean']:>11.2f} | {r['speedup']:>7.2f}x")
    
    print(f"\n💡 KẾT LUẬN:")
    if results[-1]["speedup"] > 1:
        print(f"   Với đồ thị {results[-1]['nodes']:,} nodes, Louvain giúp tăng tốc {results[-1]['speedup']:.1f}x")
        # Find crossover point
        crossover = None
        for i, r in enumerate(results):
            if r["speedup"] >= 1.0 and (i == 0 or results[i-1]["speedup"] < 1.0):
                crossover = r["nodes"]
                break
        if crossover:
            print(f"   Ngưỡng hiệu quả: Louvain bắt đầu có lợi từ ~{crossover:,} nodes trở lên")
    else:
        print(f"   Louvain chưa thể hiện lợi thế ở quy mô hiện tại — phù hợp với đồ thị dày đặc")
else:
    print("\n⚠️ Không đủ dữ liệu để vẽ biểu đồ")

print(f"\n✅ Benchmark hoàn tất!")

#!/usr/bin/env python3
"""
benchmark_balltree.py — Benchmark BallTree scalability cho bài toán giám sát lệch tuyến
Đo: query time, throughput (queries/sec) theo số điểm route và số xe.

Output: Biểu đồ PNG + bảng Big-O analysis.
"""

import os
import sys
import io
import time
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
import statistics
import numpy as np
from sklearn.neighbors import BallTree
import matplotlib.pyplot as plt
import matplotlib
matplotlib.use('Agg')

base_dir = os.path.dirname(os.path.abspath(__file__))

# ============================================================
# 1. BENCHMARK: Query time theo số điểm route (n)
# ============================================================
def benchmark_query_time(route_sizes, num_queries=1000):
    """Đo thời gian query nearest-neighbor trên BallTree với kích thước route khác nhau."""
    results = []
    
    for n in route_sizes:
        # Tạo route ngẫu nhiên (mô phỏng tuyến đường)
        # Sử dụng tọa độ thực tế ở Việt Nam (10-12°N, 106-108°E)
        lats = np.random.uniform(10.0, 12.0, n)
        lons = np.random.uniform(106.0, 108.0, n)
        coords = np.column_stack([lats, lons])
        
        # Build BallTree
        t_build_start = time.perf_counter()
        tree = BallTree(np.deg2rad(coords), metric='haversine')
        t_build_end = time.perf_counter()
        build_time_ms = (t_build_end - t_build_start) * 1000
        
        # Query nhiều lần
        query_times = []
        for _ in range(num_queries):
            query_lat = np.random.uniform(10.0, 12.0)
            query_lon = np.random.uniform(106.0, 108.0)
            query_point = np.deg2rad([[query_lat, query_lon]])
            
            t0 = time.perf_counter()
            dist, idx = tree.query(query_point, k=1)
            t1 = time.perf_counter()
            
            query_times.append((t1 - t0) * 1_000_000)  # microseconds
        
        result = {
            "n_points": n,
            "build_time_ms": build_time_ms,
            "query_mean_us": statistics.mean(query_times),
            "query_median_us": statistics.median(query_times),
            "query_p99_us": np.percentile(query_times, 99),
            "queries_per_sec": 1_000_000 / statistics.mean(query_times),
        }
        results.append(result)
        
        print(f"  n={n:>8,} | Build: {build_time_ms:>8.2f} ms | Query avg: {result['query_mean_us']:>8.1f} µs | "
              f"Throughput: {result['queries_per_sec']:>12,.0f} queries/sec")
    
    return results


# ============================================================
# 2. BENCHMARK: Throughput với nhiều xe đồng thời
# ============================================================
def benchmark_multi_vehicle(num_vehicles_list, route_size=500):
    """Mô phỏng nhiều xe, mỗi xe có 1 BallTree riêng."""
    results = []
    
    for num_vehicles in num_vehicles_list:
        # Tạo BallTree cho mỗi xe
        trees = {}
        for vid in range(num_vehicles):
            n = route_size
            lats = np.random.uniform(10.0, 12.0, n)
            lons = np.random.uniform(106.0, 108.0, n)
            coords = np.column_stack([lats, lons])
            trees[vid] = BallTree(np.deg2rad(coords), metric='haversine')
        
        # Mô phỏng 1 batch: mỗi xe query 1 lần
        t0 = time.perf_counter()
        for vid in range(num_vehicles):
            query_lat = np.random.uniform(10.0, 12.0)
            query_lon = np.random.uniform(106.0, 108.0)
            query_point = np.deg2rad([[query_lat, query_lon]])
            dist, idx = trees[vid].query(query_point, k=1)
        t1 = time.perf_counter()
        
        batch_time_ms = (t1 - t0) * 1000
        per_vehicle_us = (t1 - t0) * 1_000_000 / num_vehicles
        
        # Ước tính: nếu polling mỗi 10 giây, cần bao nhiêu queries/sec?
        polling_interval_sec = 10
        required_qps = num_vehicles / polling_interval_sec
        actual_qps = num_vehicles / (t1 - t0)
        headroom = actual_qps / required_qps if required_qps > 0 else float('inf')
        
        result = {
            "num_vehicles": num_vehicles,
            "batch_time_ms": batch_time_ms,
            "per_vehicle_us": per_vehicle_us,
            "required_qps": required_qps,
            "actual_qps": actual_qps,
            "headroom": headroom,
        }
        results.append(result)
        
        print(f"  {num_vehicles:>6,} xe | Batch: {batch_time_ms:>8.1f} ms | "
              f"Per vehicle: {per_vehicle_us:>6.1f} µs | "
              f"Headroom: {headroom:>6.1f}x (vs 10s polling)")
    
    return results


# ============================================================
# 3. MAIN
# ============================================================
print(f"{'='*70}")
print(f"{'BENCHMARK: BallTree Scalability Analysis':^70}")
print(f"{'='*70}")

# Benchmark 1: Query time vs route size
print(f"\n📊 Benchmark 1: Query time theo số điểm trên tuyến đường")
print(f"   (Mỗi kích thước: 1,000 queries)")
print(f"{'-'*70}")

route_sizes = [50, 100, 500, 1000, 5000, 10000, 50000]
query_results = benchmark_query_time(route_sizes)

# Benchmark 2: Multi-vehicle throughput
print(f"\n📊 Benchmark 2: Throughput với nhiều xe (route_size=500 điểm/xe)")
print(f"{'-'*70}")

vehicle_counts = [10, 100, 500, 1000, 5000, 10000]
vehicle_results = benchmark_multi_vehicle(vehicle_counts)


# ============================================================
# 4. VẼ BIỂU ĐỒ
# ============================================================
fig, axes = plt.subplots(2, 2, figsize=(14, 10))

# Chart 1: Query time vs route size (log-log)
ax1 = axes[0][0]
ns = [r["n_points"] for r in query_results]
means = [r["query_mean_us"] for r in query_results]
ax1.plot(ns, means, 'o-', color='#3498db', linewidth=2, markersize=8)
ax1.set_xlabel('Số điểm trên tuyến đường (n)', fontsize=11)
ax1.set_ylabel('Thời gian query (µs)', fontsize=11)
ax1.set_title('Thời gian Query BallTree\nvs Số điểm route', fontsize=12, fontweight='bold')
ax1.set_xscale('log')
ax1.set_yscale('log')
ax1.grid(True, alpha=0.3)

# Add O(log n) reference line
x_ref = np.array(ns)
y_ref = means[0] * np.log2(x_ref) / np.log2(ns[0])
ax1.plot(x_ref, y_ref, '--', color='gray', alpha=0.5, label='O(log n) tham chiếu')
ax1.legend(fontsize=10)

# Chart 2: Throughput vs route size
ax2 = axes[0][1]
qps = [r["queries_per_sec"] for r in query_results]
ax2.bar(range(len(ns)), qps, color='#2ecc71', alpha=0.8, edgecolor='black', linewidth=0.5)
ax2.set_xticks(range(len(ns)))
ax2.set_xticklabels([f"{n:,}" for n in ns], rotation=45, ha='right', fontsize=9)
ax2.set_xlabel('Số điểm trên tuyến đường', fontsize=11)
ax2.set_ylabel('Queries / giây', fontsize=11)
ax2.set_title('Throughput BallTree\n(queries/giây)', fontsize=12, fontweight='bold')
ax2.grid(True, alpha=0.3, axis='y')

for i, v in enumerate(qps):
    ax2.text(i, v + max(qps)*0.02, f'{v:,.0f}', ha='center', va='bottom', fontsize=8, fontweight='bold')

# Chart 3: Multi-vehicle batch time
ax3 = axes[1][0]
veh_nums = [r["num_vehicles"] for r in vehicle_results]
batch_times = [r["batch_time_ms"] for r in vehicle_results]
ax3.plot(veh_nums, batch_times, 's-', color='#e74c3c', linewidth=2, markersize=8)
ax3.set_xlabel('Số lượng xe', fontsize=11)
ax3.set_ylabel('Thời gian xử lý batch (ms)', fontsize=11)
ax3.set_title('Thời gian xử lý batch\nvs Số lượng xe', fontsize=12, fontweight='bold')
ax3.set_xscale('log')
ax3.grid(True, alpha=0.3)

# Chart 4: Headroom (capacity margin)
ax4 = axes[1][1]
headrooms = [r["headroom"] for r in vehicle_results]
colors = ['#2ecc71' if h > 10 else '#f39c12' if h > 2 else '#e74c3c' for h in headrooms]
bars = ax4.bar(range(len(veh_nums)), headrooms, color=colors, alpha=0.8, edgecolor='black', linewidth=0.5)
ax4.set_xticks(range(len(veh_nums)))
ax4.set_xticklabels([f"{v:,}" for v in veh_nums], rotation=45, ha='right', fontsize=9)
ax4.set_xlabel('Số lượng xe', fontsize=11)
ax4.set_ylabel('Hệ số dư thừa (Headroom)', fontsize=11)
ax4.set_title('Khả năng chịu tải\n(so với polling 10s)', fontsize=12, fontweight='bold')
ax4.axhline(y=1.0, color='red', linestyle='--', alpha=0.7, label='Giới hạn (1x)')
ax4.legend(fontsize=10)
ax4.grid(True, alpha=0.3, axis='y')

for bar, val in zip(bars, headrooms):
    ax4.text(bar.get_x() + bar.get_width()/2, bar.get_height() + max(headrooms)*0.02,
            f'{val:.0f}x', ha='center', va='bottom', fontsize=9, fontweight='bold')

plt.suptitle('BallTree Scalability Analysis — Giám sát lệch tuyến', fontsize=14, fontweight='bold', y=1.02)
plt.tight_layout()

output_path = os.path.join(base_dir, "benchmark_balltree.png")
plt.savefig(output_path, dpi=150, bbox_inches='tight')
print(f"\n📊 Biểu đồ đã lưu: {output_path}")


# ============================================================
# 5. BIG-O ANALYSIS TABLE
# ============================================================
print(f"\n{'='*70}")
print(f"{'PHÂN TÍCH ĐỘ PHỨC TẠP BIG-O':^70}")
print(f"{'='*70}")
print(f"""
┌─────────────────────────┬──────────────┬───────────────────────────────┐
│ Thao tác                │ Độ phức tạp  │ Ghi chú                      │
├─────────────────────────┼──────────────┼───────────────────────────────┤
│ Build BallTree          │ O(n log n)   │ n = số điểm trên tuyến       │
│ Query nearest-neighbor  │ O(log n)     │ Trung bình, worst-case O(n)  │
│ Batch query (m xe)      │ O(m × log n) │ m = số xe, n = điểm/tuyến    │
│ Memory per tree         │ O(n)         │ ~32 bytes/điểm (lat+lon)     │
└─────────────────────────┴──────────────┴───────────────────────────────┘

📐 Ước tính capacity với 10,000 xe (polling interval = 10 giây):
   - Required: {10000/10:,.0f} queries/giây
   - Actual throughput: ~{query_results[2]['queries_per_sec']:,.0f} queries/giây (n=500 điểm/tuyến)
   - Headroom: ~{query_results[2]['queries_per_sec']/(10000/10):.0f}x → DƯ SỨC chịu tải

🏗️ Kiến trúc mở rộng (nếu cần scale >100,000 xe):
   - Sharding theo khu vực địa lý (mỗi BallTree quản lý 1 vùng/tỉnh)
   - Cache Redis cho tuyến đường truy vấn thường xuyên
   - Horizontal scaling: mỗi server xử lý 1 nhóm xe
""")

print(f"\n✅ Benchmark hoàn tất!")

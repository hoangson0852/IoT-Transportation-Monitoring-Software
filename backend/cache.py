"""
===============================================================================
MODULE BỘ ĐỆM IN-MEMORY CACHE & KHỬ TRÙNG LẶP DỮ LIỆU (IN-MEMORY CACHE & DEDUP)
Backend Server - Đồ án Tốt nghiệp 2026
===============================================================================
"""

import time
from typing import Dict, Any, Optional

class TelemetryCacheManager:
    """Bộ đệm RAM lưu trữ trạng thái mới nhất của các phương tiện với độ trễ < 1ms"""
    def __init__(self):
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._seen_packet_keys: set = set()
        self._max_seen_history = 5000

    def get_latest(self, node_id: str) -> Optional[Dict[str, Any]]:
        return self._cache.get(node_id)

    def get_all_latest(self) -> Dict[str, Dict[str, Any]]:
        return self._cache.copy()

    def set_latest(self, node_id: str, telemetry_data: Dict[str, Any]):
        self._cache[node_id] = telemetry_data

    def is_duplicate_packet(self, node_id: str, seq: int, timestamp: int) -> bool:
        """Khử trùng lặp tin nhắn dựa trên khóa (node_id, seq, timestamp)"""
        packet_key = f"{node_id}:{seq}:{timestamp}"
        if packet_key in self._seen_packet_keys:
            return True
        
        # Quản lý giới hạn bộ nhớ cache lịch sử
        if len(self._seen_packet_keys) > self._max_seen_history:
            self._seen_packet_keys.clear()
            
        self._seen_packet_keys.add(packet_key)
        return False

# Global Cache Instance
global_cache = TelemetryCacheManager()

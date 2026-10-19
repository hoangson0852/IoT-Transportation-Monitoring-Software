"""
MobileApp/backend/dqm_engine.py
Data Quality Management (DQM) Engine for IoT Telemetry Streams
DATN 253 - Real-Time Ammo Storage & Vehicle Monitoring
"""

import math
from typing import List, Dict, Any, Tuple

class DQMEngine:
    def __init__(self, alpha: float = 0.3):
        """
        :param alpha: Smoothing factor for Exponential Moving Average (0 < alpha <= 1)
        """
        self.alpha = alpha
        self.history_buffers: Dict[str, List[float]] = {}
        self.ema_states: Dict[str, float] = {}

    def filter_telemetry(self, node_id: str, temp: float, humidity: float, vibration: float = 0.0) -> Dict[str, Any]:
        """
        Applies Outlier Detection (IQR/Range bounds) and EMA Smoothing on telemetry data.
        Returns filtered telemetry data and DQM Quality Score.
        """
        is_temp_valid, clean_temp = self._validate_and_clean(node_id, "temp", temp, min_val=-40.0, max_val=85.0)
        is_hum_valid, clean_hum = self._validate_and_clean(node_id, "humidity", humidity, min_val=0.0, max_val=100.0)
        is_vib_valid, clean_vib = self._validate_and_clean(node_id, "vibration", vibration, min_val=0.0, max_val=50.0)

        # Calculate DQM Quality Score
        valid_count = sum([is_temp_valid, is_hum_valid, is_vib_valid])
        dqm_score = round((valid_count / 3.0) * 100.0, 1)

        # Status badge string
        if dqm_score == 100.0:
            status_badge = "RELIABLE"
        elif dqm_score >= 66.0:
            status_badge = "FILTERED_NOISE"
        else:
            status_badge = "UNRELIABLE"

        return {
            "temp_raw": temp,
            "temp_clean": round(clean_temp, 2),
            "humidity_raw": humidity,
            "humidity_clean": round(clean_hum, 2),
            "vibration_raw": vibration,
            "vibration_clean": round(clean_vib, 2),
            "dqm_score": dqm_score,
            "dqm_badge": status_badge,
            "is_outlier_detected": not (is_temp_valid and is_hum_valid and is_vib_valid)
        }

    def _validate_and_clean(self, node_id: str, param: str, value: float, min_val: float, max_val: float) -> Tuple[bool, float]:
        key = f"{node_id}_{param}"
        
        # 1. Range Validation Check
        if value < min_val or value > max_val:
            # Fallback to last known EMA state if available, else standard min/max clip
            clean_val = self.ema_states.get(key, (min_val + max_val) / 2.0)
            return False, clean_val

        # 2. History buffer & IQR Spike Check
        if key not in self.history_buffers:
            self.history_buffers[key] = []
        
        buf = self.history_buffers[key]
        buf.append(value)
        if len(buf) > 20:
            buf.pop(0)

        # Check IQR bounds if buffer has at least 8 data points
        is_valid = True
        if len(buf) >= 8:
            sorted_buf = sorted(buf)
            q1 = sorted_buf[int(len(sorted_buf) * 0.25)]
            q3 = sorted_buf[int(len(sorted_buf) * 0.75)]
            iqr = q3 - q1
            if iqr > 0:
                lower = q1 - 2.0 * iqr
                upper = q3 + 2.0 * iqr
                if value < lower or value > upper:
                    is_valid = False

        # 3. Exponential Moving Average (EMA) Smoothing
        if is_valid:
            if key not in self.ema_states:
                self.ema_states[key] = value
            else:
                self.ema_states[key] = self.alpha * value + (1.0 - self.alpha) * self.ema_states[key]
            clean_val = self.ema_states[key]
        else:
            clean_val = self.ema_states.get(key, value)

        return is_valid, clean_val


# Singleton Instance
dqm_engine = DQMEngine()

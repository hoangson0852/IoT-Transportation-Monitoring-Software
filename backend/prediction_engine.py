"""
MobileApp/backend/prediction_engine.py
Predictive Analytics & Dew Point Forecasting Engine
DATN 253 - Environmental Trend & Condensation Alert
"""

import math
import time
from typing import Dict, Any, List

class PredictiveEngine:
    def __init__(self):
        # Store time series for trend calculation: {node_id: [(timestamp, temp, humidity)]}
        self.node_history: Dict[str, List[tuple]] = {}

    def calculate_dew_point(self, temp_c: float, humidity_pct: float) -> float:
        """
        Calculates Dew Point Temperature (°C) using Magnus-Tetens Formula.
        """
        if humidity_pct <= 0.0:
            humidity_pct = 0.01
        if humidity_pct > 100.0:
            humidity_pct = 100.0

        a = 17.27
        b = 237.7
        alpha = ((a * temp_c) / (b + temp_c)) + math.log(humidity_pct / 100.0)
        dew_point = (b * alpha) / (a - alpha)
        return round(dew_point, 2)

    def analyze_node_trend(self, node_id: str, current_temp: float, current_hum: float) -> Dict[str, Any]:
        """
        Analyzes 2-hour environmental trend and calculates Condensation Dew Point Risk.
        """
        now = time.time()
        dew_point = self.calculate_dew_point(current_temp, current_hum)
        
        # Condensation risk alert when margin between Temp and DewPoint is <= 2.0°C
        temp_margin = current_temp - dew_point
        condensation_risk = temp_margin <= 2.0

        # Maintain last 30 minutes of telemetry points for velocity trend
        if node_id not in self.node_history:
            self.node_history[node_id] = []
        
        history = self.node_history[node_id]
        history.append((now, current_temp, current_hum))
        
        # Clean older history (> 30 mins = 1800s)
        self.node_history[node_id] = [p for p in history if (now - p[0]) <= 1800]
        history = self.node_history[node_id]

        # Calculate rate of change per hour
        temp_rate_per_hr = 0.0
        hum_rate_per_hr = 0.0
        if len(history) >= 2:
            first_p = history[0]
            dt_sec = now - first_p[0]
            if dt_sec > 10:  # At least 10 seconds difference
                dt_hr = dt_sec / 3600.0
                temp_rate_per_hr = (current_temp - first_p[1]) / dt_hr
                hum_rate_per_hr = (current_hum - first_p[2]) / dt_hr

        # 2-hour forecast projection
        forecast_temp_2h = round(current_temp + (temp_rate_per_hr * 2.0), 2)
        forecast_hum_2h = round(min(100.0, max(0.0, current_hum + (hum_rate_per_hr * 2.0))), 2)
        forecast_dew_pt_2h = self.calculate_dew_point(forecast_temp_2h, forecast_hum_2h)

        # Risk severity
        if condensation_risk:
            risk_level = "HIGH_CONDENSATION_RISK"
            warning_msg = f"Nguy cơ đọng sương tại {node_id}! Nhiệt độ ({current_temp}°C) gần Điểm Sương ({dew_point}°C)."
        elif temp_margin <= 4.0:
            risk_level = "WARNING"
            warning_msg = f"Đang tiến sát điểm đọng sương ({dew_point}°C)."
        else:
            risk_level = "NORMAL"
            warning_msg = "Điều kiện môi trường kho đạn an toàn."

        return {
            "dew_point_current": dew_point,
            "temp_margin": round(temp_margin, 2),
            "condensation_risk": condensation_risk,
            "risk_level": risk_level,
            "warning_message": warning_msg,
            "trend_velocity": {
                "temp_rate_deg_per_hr": round(temp_rate_per_hr, 2),
                "hum_rate_pct_per_hr": round(hum_rate_per_hr, 2)
            },
            "forecast_2h": {
                "temp_2h": forecast_temp_2h,
                "humidity_2h": forecast_hum_2h,
                "dew_point_2h": forecast_dew_pt_2h
            }
        }


# Singleton Instance
prediction_engine = PredictiveEngine()

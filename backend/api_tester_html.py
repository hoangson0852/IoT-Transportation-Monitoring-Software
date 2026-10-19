# -*- coding: utf-8 -*-

TESTER_HTML = r"""<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ammo Monitor - API Tester Console</title>
    <link rel="icon" type="image/png" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>🛡️</text></svg>">
    <style>
        @import url('https://fonts.googleapis.com/css2?family=Fira+Code:wght@400;500&family=Inter:wght@300;400;500;600;700&display=swap');
        
        :root {
            --bg-base: #070913;
            --bg-surface: #0f1225;
            --bg-surface-elevated: #161b35;
            --border-color: rgba(255, 255, 255, 0.08);
            --border-hover: rgba(255, 255, 255, 0.16);
            --text-primary: #f8fafc;
            --text-secondary: #94a3b8;
            --text-muted: #64748b;
            
            --color-get: #10b981;
            --color-post: #f59e0b;
            --color-patch: #a855f7;
            --color-delete: #ef4444;
            --color-primary: #3b82f6;
            
            --shadow-glow: 0 0 20px rgba(59, 130, 246, 0.15);
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }

        body {
            font-family: 'Inter', sans-serif;
            background-color: var(--bg-base);
            color: var(--text-primary);
            display: flex;
            flex-direction: column;
            height: 100vh;
            overflow: hidden;
        }

        /* --- Header --- */
        header {
            background-color: var(--bg-surface);
            border-bottom: 1px solid var(--border-color);
            padding: 12px 24px;
            display: flex;
            justify-content: space-between;
            align-items: center;
            z-index: 10;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.3);
        }

        .logo-section {
            display: flex;
            align-items: center;
            gap: 12px;
        }

        .logo-pulse {
            width: 12px;
            height: 12px;
            background-color: #10b981;
            border-radius: 50%;
            box-shadow: 0 0 10px #10b981, 0 0 20px #10b981;
            animation: pulse 2s infinite;
        }

        @keyframes pulse {
            0% { transform: scale(0.9); opacity: 0.7; }
            50% { transform: scale(1.2); opacity: 1; box-shadow: 0 0 14px #10b981, 0 0 24px #10b981; }
            100% { transform: scale(0.9); opacity: 0.7; }
        }

        .logo-title h1 {
            font-size: 18px;
            font-weight: 700;
            letter-spacing: 0.5px;
            background: linear-gradient(135deg, #60a5fa, #3b82f6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }

        .logo-title p {
            font-size: 11px;
            color: var(--text-secondary);
            font-family: 'Fira Code', monospace;
        }

        .status-panel {
            display: flex;
            gap: 16px;
            font-size: 12px;
        }

        .status-badge {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--border-color);
            padding: 6px 12px;
            border-radius: 6px;
            display: flex;
            align-items: center;
            gap: 8px;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background-color: #10b981;
        }

        .status-dot.loading {
            background-color: #f59e0b;
        }

        .status-dot.error {
            background-color: #ef4444;
        }

        /* --- Main Layout --- */
        .app-container {
            display: flex;
            flex: 1;
            overflow: hidden;
            position: relative;
        }

        /* --- Sidebar --- */
        .sidebar {
            width: 320px;
            background-color: var(--bg-surface);
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            overflow: hidden;
            flex-shrink: 0;
        }

        .search-box {
            padding: 16px;
            border-bottom: 1px solid var(--border-color);
        }

        .search-box input {
            width: 100%;
            padding: 10px 14px;
            background-color: var(--bg-base);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            color: var(--text-primary);
            font-size: 13px;
            outline: none;
            transition: all 0.2s;
        }

        .search-box input:focus {
            border-color: var(--color-primary);
            box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.2);
        }

        .endpoints-list {
            flex: 1;
            overflow-y: auto;
            padding: 16px;
        }

        .category-group {
            margin-bottom: 20px;
        }

        .category-title {
            font-size: 11px;
            font-weight: 700;
            text-transform: uppercase;
            color: var(--text-muted);
            letter-spacing: 1px;
            margin-bottom: 8px;
            padding-left: 8px;
        }

        .endpoint-item {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 10px 12px;
            border-radius: 8px;
            cursor: pointer;
            transition: all 0.2s;
            margin-bottom: 4px;
            border: 1px solid transparent;
        }

        .endpoint-item:hover {
            background-color: rgba(255, 255, 255, 0.02);
            border-color: var(--border-color);
        }

        .endpoint-item.active {
            background-color: rgba(59, 130, 246, 0.08);
            border-color: rgba(59, 130, 246, 0.3);
        }

        .badge {
            font-size: 10px;
            font-weight: 700;
            padding: 3px 6px;
            border-radius: 4px;
            width: 52px;
            text-align: center;
            font-family: 'Fira Code', monospace;
        }

        .badge.get { background-color: rgba(16, 185, 129, 0.15); color: var(--color-get); border: 1px solid rgba(16, 185, 129, 0.3); }
        .badge.post { background-color: rgba(245, 158, 11, 0.15); color: var(--color-post); border: 1px solid rgba(245, 158, 11, 0.3); }
        .badge.patch { background-color: rgba(168, 85, 247, 0.15); color: var(--color-patch); border: 1px solid rgba(168, 85, 247, 0.3); }
        .badge.delete { background-color: rgba(239, 68, 68, 0.15); color: var(--color-delete); border: 1px solid rgba(239, 68, 68, 0.3); }

        .endpoint-path {
            font-family: 'Fira Code', monospace;
            font-size: 12px;
            color: var(--text-secondary);
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            flex: 1;
        }

        .endpoint-item.active .endpoint-path {
            color: var(--text-primary);
            font-weight: 500;
        }

        /* --- Workspace --- */
        .workspace {
            flex: 1;
            display: flex;
            flex-direction: column;
            overflow: hidden;
            background-color: var(--bg-base);
        }

        .panel-header {
            padding: 20px 24px;
            background-color: var(--bg-surface);
            border-bottom: 1px solid var(--border-color);
        }

        .endpoint-title {
            display: flex;
            align-items: center;
            gap: 12px;
            margin-bottom: 8px;
        }

        .endpoint-title h2 {
            font-size: 20px;
            font-weight: 600;
        }

        .endpoint-desc {
            font-size: 13px;
            color: var(--text-secondary);
            line-height: 1.5;
        }

        .panel-content {
            flex: 1;
            display: flex;
            overflow: hidden;
        }

        /* --- Editor Column --- */
        .editor-column {
            flex: 1;
            padding: 24px;
            overflow-y: auto;
            border-right: 1px solid var(--border-color);
            display: flex;
            flex-direction: column;
            gap: 20px;
        }

        .section-title {
            font-size: 12px;
            font-weight: 700;
            text-transform: uppercase;
            color: var(--text-muted);
            letter-spacing: 0.5px;
            margin-bottom: 10px;
        }

        .form-group {
            margin-bottom: 14px;
        }

        .form-group label {
            display: block;
            font-size: 12px;
            color: var(--text-secondary);
            margin-bottom: 6px;
            font-family: 'Fira Code', monospace;
        }

        .form-group input, .form-group select {
            width: 100%;
            padding: 10px 14px;
            background-color: var(--bg-surface-elevated);
            border: 1px solid var(--border-color);
            border-radius: 6px;
            color: var(--text-primary);
            font-size: 13px;
            outline: none;
            transition: all 0.2s;
        }

        .form-group input:focus {
            border-color: var(--color-primary);
        }

        /* Telemetry Simulator Dashboard */
        .simulator-grid {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 12px;
            background-color: rgba(255, 255, 255, 0.02);
            padding: 16px;
            border-radius: 8px;
            border: 1px dashed var(--border-color);
        }

        .sim-control {
            display: flex;
            flex-direction: column;
            gap: 4px;
        }

        .sim-control label {
            font-size: 11px;
            color: var(--text-secondary);
            display: flex;
            justify-content: space-between;
        }

        .sim-val {
            font-family: 'Fira Code', monospace;
            color: var(--color-primary);
            font-weight: 600;
        }

        .sim-control input[type="range"] {
            -webkit-appearance: none;
            width: 100%;
            height: 6px;
            border-radius: 3px;
            background: var(--bg-surface-elevated);
            outline: none;
        }

        .sim-control input[type="range"]::-webkit-slider-thumb {
            -webkit-appearance: none;
            appearance: none;
            width: 14px;
            height: 14px;
            border-radius: 50%;
            background: var(--color-primary);
            cursor: pointer;
            box-shadow: 0 0 5px var(--color-primary);
        }

        .sim-toggle {
            display: flex;
            align-items: center;
            justify-content: space-between;
            background-color: var(--bg-surface-elevated);
            padding: 8px 12px;
            border-radius: 6px;
            border: 1px solid var(--border-color);
        }

        /* Toggle switch */
        .switch {
            position: relative;
            display: inline-block;
            width: 38px;
            height: 20px;
        }

        .switch input {
            opacity: 0;
            width: 0;
            height: 0;
        }

        .slider {
            position: absolute;
            cursor: pointer;
            top: 0;
            left: 0;
            right: 0;
            bottom: 0;
            background-color: var(--bg-base);
            transition: .3s;
            border-radius: 20px;
            border: 1px solid var(--border-color);
        }

        .slider:before {
            position: absolute;
            content: "";
            height: 14px;
            width: 14px;
            left: 2px;
            bottom: 2px;
            background-color: var(--text-secondary);
            transition: .3s;
            border-radius: 50%;
        }

        input:checked + .slider {
            background-color: var(--color-primary);
        }

        input:checked + .slider:before {
            transform: translateX(18px);
            background-color: white;
        }

        .json-editor-container {
            flex: 1;
            min-height: 200px;
            display: flex;
            flex-direction: column;
        }

        .json-editor-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 6px;
        }

        .btn-small {
            padding: 4px 8px;
            font-size: 11px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-color);
            border-radius: 4px;
            color: var(--text-secondary);
            cursor: pointer;
            transition: all 0.2s;
        }

        .btn-small:hover {
            color: var(--text-primary);
            border-color: var(--border-hover);
        }

        textarea.json-textarea {
            width: 100%;
            flex: 1;
            min-height: 200px;
            background-color: #070913;
            border: 1px solid var(--border-color);
            border-radius: 6px;
            color: #34d399;
            font-family: 'Fira Code', monospace;
            font-size: 13px;
            padding: 12px;
            resize: vertical;
            outline: none;
            tab-size: 2;
        }

        textarea.json-textarea:focus {
            border-color: var(--color-primary);
        }

        .actions-bar {
            display: flex;
            gap: 12px;
        }

        .btn-send {
            flex: 1;
            padding: 12px;
            background: linear-gradient(135deg, #3b82f6, #1d4ed8);
            border: none;
            border-radius: 6px;
            color: white;
            font-weight: 600;
            font-size: 14px;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 8px;
            box-shadow: var(--shadow-glow);
            transition: all 0.2s;
        }

        .btn-send:hover {
            opacity: 0.95;
            transform: translateY(-1px);
        }

        .btn-send:active {
            transform: translateY(1px);
        }

        /* --- Response Column --- */
        .response-column {
            width: 45%;
            background-color: #070913;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }

        .response-meta {
            padding: 16px 24px;
            background-color: var(--bg-surface);
            border-bottom: 1px solid var(--border-color);
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 12px;
        }

        .meta-group {
            display: flex;
            gap: 16px;
        }

        .meta-item {
            color: var(--text-secondary);
        }

        .meta-item span {
            font-family: 'Fira Code', monospace;
            font-weight: 600;
        }

        .meta-item.status-2xx span { color: var(--color-get); }
        .meta-item.status-4xx span { color: var(--color-post); }
        .meta-item.status-5xx span { color: var(--color-delete); }

        .response-body-wrapper {
            flex: 1;
            padding: 24px;
            overflow: auto;
            position: relative;
        }

        .btn-copy {
            position: absolute;
            top: 16px;
            right: 16px;
            background: var(--bg-surface-elevated);
            border: 1px solid var(--border-color);
            color: var(--text-secondary);
            padding: 6px 12px;
            border-radius: 6px;
            cursor: pointer;
            font-size: 11px;
            transition: all 0.2s;
            display: flex;
            align-items: center;
            gap: 6px;
        }

        .btn-copy:hover {
            color: var(--text-primary);
            border-color: var(--border-hover);
        }

        pre.response-pre {
            margin: 0;
            font-family: 'Fira Code', monospace;
            font-size: 13px;
            line-height: 1.5;
            white-space: pre-wrap;
            word-break: break-all;
        }

        /* JSON Syntax Coloring */
        pre .string { color: #34d399; }
        pre .number { color: #fb923c; }
        pre .boolean { color: #60a5fa; }
        pre .null { color: #94a3b8; }
        pre .key { color: #f87171; font-weight: 500; }

        .no-request {
            display: flex;
            flex-direction: column;
            align-items: center;
            justify-content: center;
            height: 100%;
            color: var(--text-muted);
            text-align: center;
            gap: 12px;
        }

        .no-request svg {
            width: 48px;
            height: 48px;
            stroke: var(--text-muted);
        }

        /* --- Scrollbars --- */
        ::-webkit-scrollbar {
            width: 8px;
            height: 8px;
        }

        ::-webkit-scrollbar-track {
            background: transparent;
        }

        ::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.1);
            border-radius: 4px;
        }

        ::-webkit-scrollbar-thumb:hover {
            background: rgba(255, 255, 255, 0.2);
        }

        /* Responsive */
        @media (max-width: 1024px) {
            .app-container {
                flex-direction: column;
            }
            .sidebar {
                width: 100%;
                height: 250px;
                border-right: none;
                border-bottom: 1px solid var(--border-color);
            }
            .panel-content {
                flex-direction: column;
            }
            .response-column {
                width: 100%;
                height: 350px;
                border-top: 1px solid var(--border-color);
            }
        }
    </style>
</head>
<body>

    <!-- Header -->
    <header>
        <div class="logo-section">
            <div class="logo-pulse"></div>
            <div class="logo-title">
                <h1>AMMO MONITOR</h1>
                <p>Local API Developer Console</p>
            </div>
        </div>
        <div class="status-panel">
            <div class="status-badge">
                <span class="status-dot" id="server-status-dot"></span>
                <span>Server: <span id="server-status-text" style="font-weight:600;">Connecting...</span></span>
            </div>
            <div class="status-badge">
                <span>Database: <strong style="color: #60a5fa;">SQLite</strong></span>
            </div>
            <div class="status-badge">
                <span>Port: <strong style="color: #60a5fa;">5001</strong></span>
            </div>
        </div>
    </header>

    <!-- Main Container -->
    <div class="app-container">
        
        <!-- Sidebar -->
        <div class="sidebar">
            <div class="search-box">
                <input type="text" id="search-input" placeholder="Tìm kiếm API (nhập url hoặc tên)...">
            </div>
            <div class="endpoints-list" id="endpoints-list">
                <!-- Grouped API list will be rendered here dynamically -->
            </div>
        </div>

        <!-- Workspace -->
        <div class="workspace">
            <div class="panel-header">
                <div class="endpoint-title" id="endpoint-title-container">
                    <!-- Dynamic Title Badge -->
                </div>
                <div class="endpoint-desc" id="endpoint-desc">
                    Chọn một API ở thanh bên để bắt đầu kiểm tra và tương tác.
                </div>
            </div>

            <div class="panel-content">
                
                <!-- Editor Column (Left) -->
                <div class="editor-column">
                    <div id="no-api-selected" class="no-request">
                        <svg viewBox="0 0 24 24" fill="none" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
                            <path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
                        </svg>
                        <p>Vui lòng chọn một API ở sidebar bên trái để cấu hình tham số.</p>
                    </div>

                    <div id="api-workspace-form" style="display: none; height: 100%; flex-direction: column; gap: 20px;">
                        
                        <!-- Path Params Section -->
                        <div id="path-params-section" style="display: none;">
                            <div class="section-title">Tham số đường dẫn (Path parameters)</div>
                            <div id="path-inputs-container">
                                <!-- Dynamic Path inputs -->
                            </div>
                        </div>

                        <!-- Telemetry Custom Simulator Box -->
                        <div id="simulator-section" style="display: none;">
                            <div class="section-title" style="display: flex; justify-content: space-between; align-items: center;">
                                <span>Bộ mô phỏng dữ liệu Gateway (LoRa Telemetry)</span>
                                <span class="badge get" style="font-size:9px; background: rgba(59, 130, 246, 0.1); color: #60a5fa; border-color: rgba(59, 130, 246, 0.2); width: auto;">Simulation Mode</span>
                            </div>
                            <div class="simulator-grid">
                                <div class="sim-control">
                                    <label>Vĩ độ (Latitude) <span class="sim-val" id="val-lat">21.0285</span></label>
                                    <input type="range" id="sim-lat" min="20.9000" max="21.1500" step="0.0001" value="21.0285">
                                </div>
                                <div class="sim-control">
                                    <label>Kinh độ (Longitude) <span class="sim-val" id="val-lng">105.8542</span></label>
                                    <input type="range" id="sim-lng" min="105.7000" max="106.0000" step="0.0001" value="105.8542">
                                </div>
                                <div class="sim-control">
                                    <label>Nhiệt độ (Temperature) <span class="sim-val" id="val-temp">24.5</span> °C</label>
                                    <input type="range" id="sim-temp" min="15.0" max="60.0" step="0.1" value="24.5">
                                </div>
                                <div class="sim-control">
                                    <label>Độ ẩm (Humidity) <span class="sim-val" id="val-hum">65.0</span> %</label>
                                    <input type="range" id="sim-hum" min="20.0" max="100.0" step="0.5" value="65.0">
                                </div>
                                <div class="sim-control">
                                    <label>Gia tốc rung (Accel) <span class="sim-val" id="val-accel">1.02</span> g</label>
                                    <input type="range" id="sim-accel" min="0.0" max="8.0" step="0.01" value="1.02">
                                </div>
                                <div class="sim-control">
                                    <label>Ánh sáng (Light level) <span class="sim-val" id="val-light">120</span> lux</label>
                                    <input type="range" id="sim-light" min="0" max="1000" step="5" value="120">
                                </div>
                                <div class="sim-control">
                                    <label>Tín hiệu RSSI <span class="sim-val" id="val-rssi">-85</span> dBm</label>
                                    <input type="range" id="sim-rssi" min="-120" max="-30" step="1" value="-85">
                                </div>
                                <div class="sim-control">
                                    <label>Tín hiệu SNR <span class="sim-val" id="val-snr">8</span> dB</label>
                                    <input type="range" id="sim-snr" min="-20" max="15" step="1" value="8">
                                </div>
                                
                                <div class="sim-toggle">
                                    <span style="font-size:12px; color: var(--text-secondary);">Mở nắp hộp (Tamper)</span>
                                    <label class="switch">
                                        <input type="checkbox" id="sim-tamper">
                                        <span class="slider"></span>
                                    </label>
                                </div>
                                <div class="sim-toggle">
                                    <span style="font-size:12px; color: var(--text-secondary);">Cảnh báo Sensor (TinyML Anomaly)</span>
                                    <label class="switch">
                                        <input type="checkbox" id="sim-anomaly">
                                        <span class="slider"></span>
                                    </label>
                                </div>
                            </div>
                        </div>

                        <!-- JSON Body Section -->
                        <div class="json-editor-container" id="json-body-section" style="display: none;">
                            <div class="json-editor-header">
                                <span class="section-title">Nội dung JSON gửi lên (Request Body)</span>
                                <button class="btn-small" id="btn-reset-json">Khôi phục mặc định</button>
                            </div>
                            <textarea class="json-textarea" id="json-textarea-input" spellcheck="false"></textarea>
                        </div>

                        <!-- Send Button -->
                        <div class="actions-bar">
                            <button class="btn-send" id="btn-send-request">
                                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <line x1="22" y1="2" x2="11" y2="13"></line>
                                    <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                                </svg>
                                <span>Gửi Yêu Cầu (Send Request)</span>
                            </button>
                        </div>

                    </div>
                </div>

                <!-- Response Column (Right) -->
                <div class="response-column">
                    <div class="response-meta">
                        <span class="section-title">Kết quả phản hồi (Response Output)</span>
                        <div class="meta-group" id="response-status-info" style="display: none;">
                            <div class="meta-item" id="resp-status-badge">Status: <span>---</span></div>
                            <div class="meta-item">Time: <span id="resp-time-val">0</span>ms</div>
                        </div>
                    </div>
                    
                    <div class="response-body-wrapper">
                        <div id="no-response-yet" class="no-request">
                            <svg viewBox="0 0 24 24" fill="none" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                                <polyline points="4 17 10 11 14 15 20 9"></polyline>
                                <polyline points="14 9 20 9 20 15"></polyline>
                            </svg>
                            <p>Kết quả từ API Local Server sẽ hiển thị tại đây.</p>
                        </div>
                        <div id="response-success-container" style="display: none; height: 100%;">
                            <button class="btn-copy" id="btn-copy-response">
                                <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                                </svg>
                                <span>Copy JSON</span>
                            </button>
                            <pre class="response-pre"><code id="response-output-code"></code></pre>
                        </div>
                    </div>
                </div>

            </div>
        </div>

    </div>

    <script>
        // --- API DATABASE DEFINITION ---
        const apis = [
            {
                id: "health",
                category: "System",
                method: "GET",
                path: "/health",
                desc: "Kiểm tra trạng thái sức khỏe tổng quát của Local Backend Server và trạng thái SQLite Database.",
                hasBody: false
            },
            {
                id: "places",
                category: "System",
                method: "GET",
                path: "/places",
                desc: "Lấy danh sách tất cả địa điểm (nút giao bản đồ) đã được tải từ dataset.csv để hiển thị trên Dashboard.",
                hasBody: false
            },
            {
                id: "get_route",
                category: "System",
                method: "POST",
                path: "/get_route",
                desc: "Tính toán lộ trình di chuyển tối ưu giữa 2 địa điểm bản đồ sử dụng giải thuật tích hợp Louvain Partition + A*.",
                hasBody: true,
                exampleBody: {
                    "start": 1,
                    "goal": 10
                }
            },
            {
                id: "login",
                category: "Authentication",
                method: "POST",
                path: "/api/auth/login",
                desc: "Đăng nhập tài khoản điều phối viên hoặc tài xế. (Mặc định tài khoản hệ thống: admin@gmail.com / mật khẩu: admin)",
                hasBody: true,
                exampleBody: {
                    "email": "admin@gmail.com",
                    "password": "admin"
                }
            },
            {
                id: "register",
                category: "Authentication",
                method: "POST",
                path: "/api/auth/register",
                desc: "Đăng ký một tài khoản tài xế mới lên hệ thống và lưu trữ bảo mật trong cơ sở dữ liệu SQLite.",
                hasBody: true,
                exampleBody: {
                    "email": "driver1@gmail.com",
                    "password": "password123"
                }
            },
            {
                id: "get_vehicles",
                category: "Vehicles",
                method: "GET",
                path: "/api/vehicles",
                desc: "Lấy danh sách tất cả các phương tiện vận tải đang được quản lý bởi hệ thống cùng thông số giám sát mới nhất.",
                hasBody: false
            },
            {
                id: "get_vehicle_detail",
                category: "Vehicles",
                method: "GET",
                path: "/api/vehicles/{vehicle_id}",
                desc: "Lấy thông tin chi tiết và trạng thái tức thời của một phương tiện cụ thể theo ID.",
                hasBody: false,
                pathParams: ["vehicle_id"],
                exampleParams: { "vehicle_id": "Transport-1" }
            },
            {
                id: "update_telemetry",
                category: "Vehicles",
                method: "POST",
                path: "/api/vehicles/{vehicle_id}/telemetry",
                desc: "API tiếp nhận dữ liệu telemetry từ LoRa Gateway chuyển tiếp lên. Tự động kiểm tra phát hiện Anomaly (TinyML), mở nắp hộp (Tamper), lệch lộ trình (ML Supervisor với BallTree) và lưu vào cơ sở dữ liệu.",
                hasBody: true,
                pathParams: ["vehicle_id"],
                exampleParams: { "vehicle_id": "Transport-1" },
                exampleBody: {
                    "online": true,
                    "latitude": 21.0285,
                    "longitude": 105.8542,
                    "temperature": 24.5,
                    "humidity": 65.0,
                    "accel_magnitude": 1.02,
                    "light_level": 120,
                    "tamper": 0,
                    "anomaly_flag": 0,
                    "rf_anomaly_state": "NORMAL",
                    "knn_prediction": "NORMAL",
                    "gateway_rssi": -85,
                    "gateway_snr": 8
                }
            },
            {
                id: "get_vehicle_logs",
                category: "Vehicles",
                method: "GET",
                path: "/api/vehicles/{vehicle_id}/logs",
                desc: "Lấy nhật ký dữ liệu cảm biến lịch sử (telemetry logs) gửi về từ xe phục vụ việc phân tích biểu đồ.",
                hasBody: false,
                pathParams: ["vehicle_id"],
                exampleParams: { "vehicle_id": "Transport-1" },
                queryParams: ["limit"],
                exampleQueryParams: { "limit": 20 }
            },
            {
                id: "get_active_route",
                category: "Vehicles",
                method: "GET",
                path: "/api/active_routes/{vehicle_id}",
                desc: "Lấy danh sách các điểm tọa độ GPS của lộ trình đang hoạt động (Active Route) của một phương tiện.",
                hasBody: false,
                pathParams: ["vehicle_id"],
                exampleParams: { "vehicle_id": "Transport-1" }
            },
            {
                id: "get_missions",
                category: "Transport Missions",
                method: "GET",
                path: "/api/missions",
                desc: "Lấy danh sách toàn bộ nhiệm vụ vận tải đạn dược trên hệ thống, sắp xếp theo thời gian tạo mới nhất.",
                hasBody: false
            },
            {
                id: "get_driver_missions",
                category: "Transport Missions",
                method: "GET",
                path: "/api/missions/driver/{driver_uid}",
                desc: "Lấy danh sách nhiệm vụ vận chuyển được phân công cho một tài xế cụ thể.",
                hasBody: false,
                pathParams: ["driver_uid"],
                exampleParams: { "driver_uid": "user_admin" }
            },
            {
                id: "create_mission",
                category: "Transport Missions",
                method: "POST",
                path: "/api/missions",
                desc: "Tạo một nhiệm vụ vận tải mới, lưu trữ lộ trình đăng ký để làm căn cứ phát hiện lệch đường bằng ML Supervisor.",
                hasBody: true,
                exampleBody: {
                    "vehicle_id": "Transport-1",
                    "driver_uid": "user_admin",
                    "origin": "Kho Tổng A",
                    "destination": "Chốt Biên Phòng B",
                    "cargo_description": "Thùng đạn bộ binh 7.62mm",
                    "notes": "Vận chuyển ban đêm, lưu ý giữ nhiệt độ dưới 35 độ C",
                    "route_points": [
                        {"lat": 21.0285, "lng": 105.8542},
                        {"lat": 21.0315, "lng": 105.8572},
                        {"lat": 21.0350, "lng": 105.8600},
                        {"lat": 21.0392, "lng": 105.8631}
                    ]
                }
            },
            {
                id: "update_mission_status",
                category: "Transport Missions",
                method: "PATCH",
                path: "/api/missions/{mission_id}",
                desc: "Cập nhật trạng thái nhiệm vụ (pending, inProgress, completed, cancelled). Khi hoàn thành hoặc hủy, hệ thống sẽ tự động gỡ lộ trình hoạt động để dừng ML Supervisor.",
                hasBody: true,
                pathParams: ["mission_id"],
                exampleParams: { "mission_id": "mission_202606240000" },
                exampleBody: {
                    "status": "inProgress"
                }
            },
            {
                id: "create_alert",
                category: "Alerts & Logs",
                method: "POST",
                path: "/api/alerts",
                desc: "Gửi thủ công một cảnh báo an ninh hoặc sự cố cho một xe chỉ định lên bảng quản trị trung tâm.",
                hasBody: true,
                exampleBody: {
                    "vehicle_id": "Transport-1",
                    "alert_type": "sensor_abnormal",
                    "severity": "high",
                    "message": "Phát hiện nhiệt độ tăng vọt đột ngột trong khoang chứa đạn dược!"
                }
            },
            {
                id: "get_alerts",
                category: "Alerts & Logs",
                method: "GET",
                path: "/api/alerts",
                desc: "Lấy danh sách các cảnh báo an ninh, cảnh báo lệch đường, hoặc sự kiện tháo lắp (tamper) mới nhất.",
                hasBody: false,
                queryParams: ["limit"],
                exampleQueryParams: { "limit": 20 }
            },
            {
                id: "get_system_logs",
                category: "Alerts & Logs",
                method: "GET",
                path: "/api/system_logs",
                desc: "Lấy nhật ký hệ thống hoạt động của server ghi nhận các sự kiện nghiệp vụ (người dùng đăng nhập, đổi trạng thái hành trình, lỗi kết nối database).",
                hasBody: false,
                queryParams: ["limit"],
                exampleQueryParams: { "limit": 50 }
            },
            {
                id: "export_report_csv",
                category: "Alerts & Logs",
                method: "GET",
                path: "/api/reports/export/{vehicle_id}",
                desc: "Xuất báo cáo dữ liệu hành trình lịch sử của một xe chỉ định ra tệp Excel CSV để phục vụ phân tích báo cáo tuần/tháng.",
                hasBody: false,
                pathParams: ["vehicle_id"],
                exampleParams: { "vehicle_id": "Transport-1" }
            }
        ];

        // --- GLOBAL STATE ---
        let selectedApi = null;

        // --- DOM ELEMENTS ---
        const endpointsList = document.getElementById("endpoints-list");
        const searchInput = document.getElementById("search-input");
        const endpointTitleContainer = document.getElementById("endpoint-title-container");
        const endpointDesc = document.getElementById("endpoint-desc");
        const noApiSelected = document.getElementById("no-api-selected");
        const apiWorkspaceForm = document.getElementById("api-workspace-form");
        const pathParamsSection = document.getElementById("path-params-section");
        const pathInputsContainer = document.getElementById("path-inputs-container");
        const simulatorSection = document.getElementById("simulator-section");
        const jsonBodySection = document.getElementById("json-body-section");
        const jsonTextareaInput = document.getElementById("json-textarea-input");
        const btnResetJson = document.getElementById("btn-reset-json");
        const btnSendRequest = document.getElementById("btn-send-request");
        const responseStatusInfo = document.getElementById("response-status-info");
        const respStatusBadge = document.getElementById("resp-status-badge");
        const respTimeVal = document.getElementById("resp-time-val");
        const noResponseYet = document.getElementById("no-response-yet");
        const responseSuccessContainer = document.getElementById("response-success-container");
        const responseOutputCode = document.getElementById("response-output-code");
        const btnCopyResponse = document.getElementById("btn-copy-response");
        
        // --- SIMULATOR INPUTS ---
        const simLat = document.getElementById("sim-lat");
        const simLng = document.getElementById("sim-lng");
        const simTemp = document.getElementById("sim-temp");
        const simHum = document.getElementById("sim-hum");
        const simAccel = document.getElementById("sim-accel");
        const simLight = document.getElementById("sim-light");
        const simRssi = document.getElementById("sim-rssi");
        const simSnr = document.getElementById("sim-snr");
        const simTamper = document.getElementById("sim-tamper");
        const simAnomaly = document.getElementById("sim-anomaly");

        // --- LOAD SIDEBAR ---
        function renderSidebar(filterText = "") {
            endpointsList.innerHTML = "";
            
            // Group by category
            const categories = {};
            apis.forEach(api => {
                if (filterText && !api.path.toLowerCase().includes(filterText.toLowerCase()) && !api.desc.toLowerCase().includes(filterText.toLowerCase())) {
                    return;
                }
                if (!categories[api.category]) {
                    categories[api.category] = [];
                }
                categories[api.category].push(api);
            });

            for (const [catName, catApis] of Object.entries(categories)) {
                if (catApis.length === 0) continue;
                
                const groupDiv = document.createElement("div");
                groupDiv.className = "category-group";
                
                const groupTitle = document.createElement("div");
                groupTitle.className = "category-title";
                groupTitle.textContent = catName;
                groupDiv.appendChild(groupTitle);
                
                catApis.forEach(api => {
                    const item = document.createElement("div");
                    item.className = `endpoint-item ${selectedApi && selectedApi.id === api.id ? 'active' : ''}`;
                    item.onclick = () => selectApiEndpoint(api);
                    
                    const badge = document.createElement("span");
                    badge.className = `badge ${api.method.toLowerCase()}`;
                    badge.textContent = api.method;
                    
                    const path = document.createElement("span");
                    path.className = "endpoint-path";
                    path.textContent = api.path;
                    
                    item.appendChild(badge);
                    item.appendChild(path);
                    groupDiv.appendChild(item);
                });
                
                endpointsList.appendChild(groupDiv);
            }
        }

        // --- SELECT ENDPOINT ---
        function selectApiEndpoint(api) {
            selectedApi = api;
            
            // Update active states in UI
            document.querySelectorAll(".endpoint-item").forEach(item => {
                item.classList.remove("active");
            });
            renderSidebar(searchInput.value);
            
            // Show Workspace
            noApiSelected.style.display = "none";
            apiWorkspaceForm.style.display = "flex";
            
            // Header Info
            endpointTitleContainer.innerHTML = `
                <span class="badge ${api.method.toLowerCase()}" style="font-size:12px; padding:4px 8px; width:auto;">${api.method}</span>
                <h2>${api.path}</h2>
            `;
            endpointDesc.textContent = api.desc;
            
            // Render Path parameters
            if (api.pathParams && api.pathParams.length > 0) {
                pathParamsSection.style.display = "block";
                pathInputsContainer.innerHTML = "";
                api.pathParams.forEach(param => {
                    const val = api.exampleParams[param] || "";
                    const group = document.createElement("div");
                    group.className = "form-group";
                    group.innerHTML = `
                        <label for="param-${param}">${param}</label>
                        <input type="text" id="param-${param}" value="${val}" oninput="updateUrlPreview()">
                    `;
                    pathInputsContainer.appendChild(group);
                });
            } else {
                pathParamsSection.style.display = "none";
            }

            // Render Query parameters (like limit)
            if (api.queryParams && api.queryParams.length > 0) {
                pathParamsSection.style.display = "block";
                api.queryParams.forEach(qParam => {
                    const val = api.exampleQueryParams[qParam] || "";
                    const group = document.createElement("div");
                    group.className = "form-group";
                    group.innerHTML = `
                        <label for="query-${qParam}">?${qParam} (Query parameter)</label>
                        <input type="text" id="query-${qParam}" value="${val}" oninput="updateUrlPreview()">
                    `;
                    pathInputsContainer.appendChild(group);
                });
            }
            
            // Check for simulator section
            if (api.id === "update_telemetry") {
                simulatorSection.style.display = "block";
                // Reset simulator slider values to default
                simLat.value = 21.0285;
                simLng.value = 105.8542;
                simTemp.value = 24.5;
                simHum.value = 65.0;
                simAccel.value = 1.02;
                simLight.value = 120;
                simRssi.value = -85;
                simSnr.value = 8;
                simTamper.checked = false;
                simAnomaly.checked = false;
                updateSimulatorLabels();
                syncSimulatorToJson();
            } else {
                simulatorSection.style.display = "none";
            }
            
            // Render JSON Body section
            if (api.hasBody) {
                jsonBodySection.style.display = "flex";
                if (api.id !== "update_telemetry") {
                    jsonTextareaInput.value = JSON.stringify(api.exampleBody, null, 2);
                }
            } else {
                jsonBodySection.style.display = "none";
            }
        }

        // --- UPDATE SIMULATOR LABELS & JSON ---
        function updateSimulatorLabels() {
            document.getElementById("val-lat").textContent = parseFloat(simLat.value).toFixed(4);
            document.getElementById("val-lng").textContent = parseFloat(simLng.value).toFixed(4);
            document.getElementById("val-temp").textContent = parseFloat(simTemp.value).toFixed(1);
            document.getElementById("val-hum").textContent = parseFloat(simHum.value).toFixed(1);
            document.getElementById("val-accel").textContent = parseFloat(simAccel.value).toFixed(2);
            document.getElementById("val-light").textContent = parseInt(simLight.value);
            document.getElementById("val-rssi").textContent = parseInt(simRssi.value);
            document.getElementById("val-snr").textContent = parseInt(simSnr.value);
        }

        function syncSimulatorToJson() {
            if (!selectedApi || selectedApi.id !== "update_telemetry") return;
            const body = {
                "online": true,
                "latitude": parseFloat(simLat.value),
                "longitude": parseFloat(simLng.value),
                "temperature": parseFloat(simTemp.value),
                "humidity": parseFloat(simHum.value),
                "accel_magnitude": parseFloat(simAccel.value),
                "light_level": parseInt(simLight.value),
                "tamper": simTamper.checked ? 1 : 0,
                "anomaly_flag": simAnomaly.checked ? 1 : 0,
                "rf_anomaly_state": "NORMAL",
                "knn_prediction": "NORMAL",
                "gateway_rssi": parseInt(simRssi.value),
                "gateway_snr": parseInt(simSnr.value)
            };
            jsonTextareaInput.value = JSON.stringify(body, null, 2);
        }

        // Attach simulator input listeners
        [simLat, simLng, simTemp, simHum, simAccel, simLight, simRssi, simSnr].forEach(input => {
            input.addEventListener("input", () => {
                updateSimulatorLabels();
                syncSimulatorToJson();
            });
        });
        [simTamper, simAnomaly].forEach(input => {
            input.addEventListener("change", syncSimulatorToJson);
        });

        // --- HELPERS ---
        function updateUrlPreview() {
            // Nothing complex needed, just reactive input
        }

        btnResetJson.addEventListener("click", () => {
            if (selectedApi && selectedApi.hasBody) {
                if (selectedApi.id === "update_telemetry") {
                    simLat.value = 21.0285;
                    simLng.value = 105.8542;
                    simTemp.value = 24.5;
                    simHum.value = 65.0;
                    simAccel.value = 1.02;
                    simLight.value = 120;
                    simRssi.value = -85;
                    simSnr.value = 8;
                    simTamper.checked = false;
                    simAnomaly.checked = false;
                    updateSimulatorLabels();
                    syncSimulatorToJson();
                } else {
                    jsonTextareaInput.value = JSON.stringify(selectedApi.exampleBody, null, 2);
                }
            }
        });

        // --- SEND API REQUEST ---
        btnSendRequest.addEventListener("click", async () => {
            if (!selectedApi) return;
            
            // Construct path with params
            let finalPath = selectedApi.path;
            if (selectedApi.pathParams) {
                for (const param of selectedApi.pathParams) {
                    const inputEl = document.getElementById(`param-${param}`);
                    const val = inputEl ? inputEl.value.trim() : "";
                    if (!val) {
                        alert(`Vui lòng nhập tham số path: ${param}`);
                        inputEl.focus();
                        return;
                    }
                    finalPath = finalPath.replace(`{${param}}`, encodeURIComponent(val));
                }
            }

            // Construct Query parameters
            if (selectedApi.queryParams) {
                let first = true;
                for (const qParam of selectedApi.queryParams) {
                    const inputEl = document.getElementById(`query-${qParam}`);
                    const val = inputEl ? inputEl.value.trim() : "";
                    if (val) {
                        finalPath += `${first ? '?' : '&'}${qParam}=${encodeURIComponent(val)}`;
                        first = false;
                    }
                }
            }

            // Setup Options
            const options = {
                method: selectedApi.method,
                headers: {}
            };

            if (selectedApi.hasBody) {
                const rawJson = jsonTextareaInput.value;
                try {
                    // Check if JSON is valid
                    JSON.parse(rawJson);
                } catch (e) {
                    alert("Dữ liệu JSON Payload không hợp lệ. Vui lòng kiểm tra dấu phẩy hoặc cú pháp!");
                    return;
                }
                options.headers["Content-Type"] = "application/json";
                options.body = rawJson;
            }

            // Loading state
            btnSendRequest.disabled = true;
            btnSendRequest.style.opacity = "0.7";
            btnSendRequest.querySelector("span").textContent = "Đang gửi...";
            
            const startTime = performance.now();
            
            try {
                const response = await fetch(finalPath, options);
                const duration = Math.round(performance.now() - startTime);
                
                // Show status and duration
                responseStatusInfo.style.display = "flex";
                respTimeVal.textContent = duration;
                
                const classCode = Math.floor(response.status / 100);
                respStatusBadge.className = `meta-item status-${classCode}xx`;
                respStatusBadge.querySelector("span").textContent = `${response.status} ${response.statusText || ''}`;
                
                noResponseYet.style.display = "none";
                responseSuccessContainer.style.display = "block";

                // Check if response is CSV file
                const contentType = response.headers.get("content-type") || "";
                if (contentType.includes("text/csv") || finalPath.includes("/export/")) {
                    const blob = await response.blob();
                    const url = window.URL.createObjectURL(blob);
                    const a = document.createElement("a");
                    a.href = url;
                    // Get filename from header or path
                    const disp = response.headers.get("content-disposition") || "";
                    let filename = "export_report.csv";
                    const matches = disp.match(/filename=(["']?)(.*?)\\1/);
                    if (matches != null && matches[2]) filename = matches[2];
                    a.download = filename;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                    window.URL.revokeObjectURL(url);
                    
                    responseOutputCode.innerHTML = `<span style="color:#10b981;">[FILE DOWNLOADED SUCCESSFULLY]</span>\n\nTập tin: ${filename}\nKích thước: ${blob.size} bytes\nMimetype: text/csv\n\nTệp tin báo cáo CSV đã được trình duyệt tự động tải về thư mục Downloads của bạn.`;
                } else {
                    const data = await response.json();
                    responseOutputCode.innerHTML = syntaxHighlight(data);
                }
            } catch (error) {
                const duration = Math.round(performance.now() - startTime);
                responseStatusInfo.style.display = "flex";
                respTimeVal.textContent = duration;
                respStatusBadge.className = "meta-item status-5xx";
                respStatusBadge.querySelector("span").textContent = "FAILED";
                
                noResponseYet.style.display = "none";
                responseSuccessContainer.style.display = "block";
                
                responseOutputCode.innerHTML = `<span style="color:#ef4444;">Lỗi kết nối Local Server (Network Error):</span>\n\n${error.message}\n\nHướng dẫn khắc phục:\n1. Đảm bảo rằng Local Flask Server đang chạy thành công trên cổng 5001.\n2. Kiểm tra log của CMD terminal xem server có báo lỗi runtime nào không.`;
            } finally {
                btnSendRequest.disabled = false;
                btnSendRequest.style.opacity = "1";
                btnSendRequest.querySelector("span").textContent = "Gửi Yêu Cầu (Send Request)";
            }
        });

        // --- JSON SYNTAX HIGHLIGHT ---
        function syntaxHighlight(json) {
            if (typeof json !== 'string') {
                json = JSON.stringify(json, undefined, 2);
            }
            json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            return json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+-]?\d+)?)/g, function (match) {
                let cls = 'number';
                if (/^"/.test(match)) {
                    if (/:$/.test(match)) {
                        cls = 'key';
                    } else {
                        cls = 'string';
                    }
                } else if (/true|false/.test(match)) {
                    cls = 'boolean';
                } else if (/null/.test(match)) {
                    cls = 'null';
                }
                return '<span class="' + cls + '">' + match + '</span>';
            });
        }

        // --- COPY RESPONSE ---
        btnCopyResponse.addEventListener("click", () => {
            const rawText = responseOutputCode.innerText;
            if (!rawText) return;
            
            navigator.clipboard.writeText(rawText).then(() => {
                const origText = btnCopyResponse.querySelector("span").textContent;
                btnCopyResponse.querySelector("span").textContent = "Đã Copy!";
                setTimeout(() => {
                    btnCopyResponse.querySelector("span").textContent = origText;
                }, 2000);
            }).catch(err => {
                console.error("Không thể copy: ", err);
            });
        });

        // --- CHECK SERVER HEALTH ---
        async function checkServerHealth() {
            const dot = document.getElementById("server-status-dot");
            const text = document.getElementById("server-status-text");
            
            try {
                const response = await fetch("/health");
                if (response.ok) {
                    dot.className = "status-dot";
                    text.textContent = "ONLINE";
                    text.style.color = "#10b981";
                } else {
                    dot.className = "status-dot loading";
                    text.textContent = "ABNORMAL";
                    text.style.color = "#f59e0b";
                }
            } catch (e) {
                dot.className = "status-dot error";
                text.textContent = "OFFLINE";
                text.style.color = "#ef4444";
            }
        }

        // Poll server health every 5 seconds
        setInterval(checkServerHealth, 5000);
        checkServerHealth();

        // --- SEARCH FILTER ---
        searchInput.addEventListener("input", (e) => {
            renderSidebar(e.target.value);
        });

        // --- INIT ---
        renderSidebar();
    </script>
</body>
</html>
"""

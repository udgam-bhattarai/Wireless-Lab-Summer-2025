# WiFi & 5G NR Channel Estimation Project

This project implements a dual-standard processing chain for WiFi and 5G signals, focusing on real-time Channel State Information (CSI) extraction.

---

## Project Files

### Transmitters (TX)
* **WiFi TX:** [WiFi_Transmit.m](Wifi_Transmit.m) — Generates the WiFi signal.
* **5G TX:** [NR_Transmit.m](NR_Transmit.m) — Generates the 5G NR signal.

### Receivers (RX)
* **Unified RX:** [WiFi_5G_CSI.m](WiFi_5G_CSI.m) — The main processing hub for both WiFi and 5G signals.
* **5G Processor:** [processNR.m](processNR.m) — Handles NR carrier configurations and H-matrix estimation.
* **WiFi Processor:** [processWiFi.m](processWiFi.m) — Handles non-HT WiFi configurations and H-matrix estimation.

---

## System Workflow

<image src="Capstone_MultiRAT.drawio.png" ></image>

Based on the system architecture, the data flows as follows:

### 1. Signal Input
The system accepts a combined or individual buffer containing:
- **WiFi signal** (from `WiFi_Transmit.m`)
- **5G signal** (from `NR_Transmit.m`)

### 2. Processing Hub (`WiFi_5G_CSI.m`)
The input buffer (`rxBuffer`) is routed to the specific processing script:

| Standard | Processor | Input Requirements | Outputs |
| :--- | :--- | :--- | :--- |
| **5G NR** | `processNR.m` | `rxBuffer`, `carrier` | Channel Estimation ($H$), Validity (`valid`) |
| **WiFi** | `processWiFi.m` | `rxBuffer`, `cfgnonHT` | Channel Estimation ($H$), Validity (`valid`) |

### 3. Data Visualization & Output
The final stage of the receiver provides:
* **Real-time Channel Estimation Graph:** Visual representation of the channel response.
* **Channel Estimation Values:** Raw numerical data for further analysis.

---

##  How to Run
1. Run the desired Transmitter script to generate signal data.
2. Execute `WiFi_5G_CSI.m` to begin the reception and estimation process.

#!/usr/bin/env python3
import serial
import csv
from datetime import datetime
import sys

PORT = '/dev/ttyUSB0'  # or 'COM3' on Windows
BAUD = 115200
FILENAME = f'encoder_log_{datetime.now().strftime("%Y%m%d_%H%M%S")}.csv'

ser = serial.Serial(PORT, BAUD)

with open(FILENAME, 'w', newline='') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=['timestamp', 'position', 'status', 'error', 'warning'])
    writer.writeheader()
    
    print(f"Logging to {FILENAME}")
    print("Press Ctrl+C to stop\n")
    
    try:
        while True:
            if ser.in_waiting:
                line = ser.readline().decode('ascii', errors='ignore').strip()
                if line.startswith('POS:'):
                    # Parse your existing format
                    # POS:XXXXX STS:XXXX ERR:X WRN:X
                    parts = line.split()
                    pos = parts[0].split(':')[1]
                    sts = parts[1].split(':')[1]
                    err = parts[2].split(':')[1]
                    wrn = parts[3].split(':')[1]
                    
                    row = {
                        'timestamp': datetime.now().isoformat(),
                        'position': pos,
                        'status': sts,
                        'error': err,
                        'warning': wrn
                    }
                    writer.writerow(row)
                    print(f"{row['timestamp']} | POS:{pos} | ERR:{err} WRN:{wrn}")
    
    except KeyboardInterrupt:
        print(f"\n\nLogging stopped. Data saved to {FILENAME}")
        ser.close()
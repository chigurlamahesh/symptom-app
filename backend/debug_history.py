import sqlite3
import json
import traceback

DB_NAME = "history.db"

try:
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute('SELECT * FROM predictions ORDER BY timestamp DESC LIMIT 50')
    rows = cursor.fetchall()
    conn.close()
    
    print(f"Successfully fetched {len(rows)} records.")
    
    history_list = []
    for idx, row in enumerate(rows):
        try:
            item = {
                'id': row['id'],
                'timestamp': row['timestamp'],
                'symptoms': json.loads(row['symptoms']),
                'predicted_disease': row['predicted_disease'],
                'confidence': row['confidence'],
                'precautions': json.loads(row['precautions']),
                'age': row['age'] if 'age' in row.keys() else None,
                'sex': row['sex'] if 'sex' in row.keys() else None,
                'smoker': row['smoker'] if 'smoker' in row.keys() else None,
                'weight': row['weight'] if 'weight' in row.keys() else None,
                'height': row['height'] if 'height' in row.keys() else None,
                'existing_conditions': json.loads(row['existing_conditions']) if 'existing_conditions' in row.keys() and row['existing_conditions'] else [],
                'duration': row['duration'] if 'duration' in row.keys() else None,
                'severity': row['severity'] if 'severity' in row.keys() else None,
                'recommendation': row['recommendation'] if 'recommendation' in row.keys() else None
            }
            history_list.append(item)
        except Exception as row_err:
            print(f"Error parsing row {idx} (ID: {row['id']}): {row_err}")
            traceback.print_exc()
            
    print("Parsed history items count:", len(history_list))
except Exception as e:
    print("Global error during fetch:")
    traceback.print_exc()

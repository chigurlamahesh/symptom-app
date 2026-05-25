import sqlite3
import os

DB_NAME = "history.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()
    
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS predictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        symptoms TEXT NOT NULL,
        predicted_disease TEXT NOT NULL,
        confidence REAL NOT NULL,
        precautions TEXT NOT NULL
    )
    ''')
    
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicine_name TEXT NOT NULL,
        alarm_time TEXT NOT NULL,
        dosage TEXT NOT NULL,
        repeat_days TEXT NOT NULL,
        label_color TEXT NOT NULL
    )
    ''')
    
    conn.commit()
    conn.close()
    print("Database tables initialized.")

if __name__ == '__main__':
    init_db()

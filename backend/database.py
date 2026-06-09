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
        precautions TEXT NOT NULL,
        age INTEGER,
        sex TEXT,
        smoker TEXT,
        weight REAL,
        height REAL,
        existing_conditions TEXT,
        duration TEXT,
        severity TEXT,
        recommendation TEXT
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
    
    # Run automatic schema migration if columns are missing
    cursor.execute("PRAGMA table_info(predictions)")
    columns = [col[1] for col in cursor.fetchall()]
    
    migrations = [
        ('age', 'INTEGER'),
        ('sex', 'TEXT'),
        ('smoker', 'TEXT'),
        ('weight', 'REAL'),
        ('height', 'REAL'),
        ('existing_conditions', 'TEXT'),
        ('duration', 'TEXT'),
        ('severity', 'TEXT'),
        ('recommendation', 'TEXT')
    ]
    
    migration_applied = False
    for col_name, col_type in migrations:
        if col_name not in columns:
            cursor.execute(f"ALTER TABLE predictions ADD COLUMN {col_name} {col_type}")
            print(f"Migration: Added column '{col_name}' to predictions table.")
            migration_applied = True
            
    if migration_applied:
        conn.commit()
    
    conn.commit()
    conn.close()
    print("Database tables initialized.")

if __name__ == '__main__':
    init_db()

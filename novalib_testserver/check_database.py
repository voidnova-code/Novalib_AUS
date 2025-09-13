import os
import mysql.connector
from mysql.connector import Error

KOHA_DB_CONFIG = {
    "host": "localhost",
    "user": "root",
    "password": "Sayan@kumar1234",
    "database": "koha_db"
}


def connect_koha_db():
    try:
        connection = mysql.connector.connect(**KOHA_DB_CONFIG)
        if connection.is_connected():
            return connection
    except Error as e:
        print(f"Error connecting to database: {e}")
        return None


def create_tables():
    conn = connect_koha_db()
    if not conn:
        return
    cursor = conn.cursor()
    # Create borrowers table without totp_secret column
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS borrowers (
            cardnumber VARCHAR(50) PRIMARY KEY,
            firstname VARCHAR(100),
            surname VARCHAR(100),
            phone VARCHAR(20)
        )
    """)
    # Create biblio table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS biblio (
            biblionumber INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(255),
            author VARCHAR(255)
        )
    """)
    # Create items table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS items (
            itemnumber INT AUTO_INCREMENT PRIMARY KEY,
            biblionumber INT,
            barcode VARCHAR(100) UNIQUE,
            FOREIGN KEY (biblionumber) REFERENCES biblio(biblionumber)
        )
    """)
    conn.commit()
    cursor.close()
    conn.close()
    print("Tables ensured.")
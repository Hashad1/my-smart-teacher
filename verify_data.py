
import psycopg2
from psycopg2 import sql

db_params = {
    "dbname": "postgres",
    "user": "postgres",
    "password": "Abaad@123411",
    "host": "db.trontorjwdxgdomkcfgk.supabase.co",
    "port": "5432"
}

def fetch_data(cur, table):
    query = sql.SQL("SELECT * FROM {}").format(sql.Identifier(table))
    cur.execute(query)
    return cur.fetchall()

def verify_data():
    conn = None
    try:
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**db_params)
        cur = conn.cursor()
        
        tables = ['educational_stages', 'countries', 'subjects', 'stage_country_subject']
        
        for table in tables:
            print("Data in " + table + ":")
            data = fetch_data(cur, table)
            for row in data:
                print(row)
            
            if table == 'stage_country_subject':
                print("Total entries in " + table + ": " + str(len(data)))
        
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
            print('Database connection closed.')

if __name__ == '__main__':
    verify_data()

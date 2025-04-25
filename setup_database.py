
import psycopg2
from psycopg2 import sql

db_params = {
    "dbname": "postgres",
    "user": "postgres",
    "password": "Abaad@123411",
    "host": "db.trontorjwdxgdomkcfgk.supabase.co",
    "port": "5432"
}

create_tables = [
    """
    CREATE TABLE IF NOT EXISTS educational_stages (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE,
        description TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS countries (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        code VARCHAR(3) NOT NULL UNIQUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS subjects (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL UNIQUE,
        description TEXT,
        educational_objectives TEXT,
        required_skills TEXT,
        learning_resources TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS stage_country_subject (
        id SERIAL PRIMARY KEY,
        stage_id INTEGER REFERENCES educational_stages(id),
        country_id INTEGER REFERENCES countries(id),
        subject_id INTEGER REFERENCES subjects(id),
        weekly_classes INTEGER,
        importance_order INTEGER,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(stage_id, country_id, subject_id)
    )
    """,
    """
    CREATE TABLE IF NOT EXISTS resources (
        id SERIAL PRIMARY KEY,
        stage_country_subject_id INTEGER REFERENCES stage_country_subject(id),
        title VARCHAR(200) NOT NULL,
        description TEXT,
        semester VARCHAR(50),
        resource_type VARCHAR(50),
        url TEXT NOT NULL,
        file_type VARCHAR(50),
        source VARCHAR(100),
        is_official BOOLEAN,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(stage_country_subject_id, title)
    )
    """
]

def setup_database():
    conn = None
    try:
        print('Connecting to the PostgreSQL database...')
        conn = psycopg2.connect(**db_params)
        cur = conn.cursor()
        
        # Drop existing tables if they exist
        cur.execute("DROP TABLE IF EXISTS resources, stage_country_subject, subjects, countries, educational_stages CASCADE")
        
        # Create tables
        for create_table_sql in create_tables:
            cur.execute(create_table_sql)
        
        cur.close()
        conn.commit()
        print("Tables created successfully!")
        
    except (Exception, psycopg2.DatabaseError) as error:
        print(error)
    finally:
        if conn is not None:
            conn.close()
            print('Database connection closed.')

if __name__ == '__main__':
    setup_database()

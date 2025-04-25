
import psycopg2
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
from urllib.parse import quote_plus

# Database connection
db_params = {
    "dbname": "postgres",
    "user": "postgres",
    "password": "Abaad@123411",
    "host": "db.trontorjwdxgdomkcfgk.supabase.co",
    "port": "5432"
}

print("Connecting to database...")
password = quote_plus(db_params['password'])
engine = create_engine(f"postgresql://{db_params['user']}:{password}@{db_params['host']}:{db_params['port']}/{db_params['dbname']}")
Session = sessionmaker(bind=engine)

def search_resources(country=None, stage=None, subject=None, semester=None, resource_type=None, query=None):
    print("Searching resources...")
    session = Session()
    
    base_query = """
    SELECT r.id, r.title, r.description, r.semester, r.resource_type, r.url, r.file_type, r.source, r.is_official,
           e.name as stage_name, c.name as country_name, s.name as subject_name
    FROM resources r
    JOIN stage_country_subject scs ON r.stage_country_subject_id = scs.id
    JOIN educational_stages e ON scs.stage_id = e.id
    JOIN countries c ON scs.country_id = c.id
    JOIN subjects s ON scs.subject_id = s.id
    WHERE 1=1
    """
    
    params = {}
    
    if country:
        base_query += " AND c.name = :country"
        params['country'] = country
    
    if stage:
        base_query += " AND e.name = :stage"
        params['stage'] = stage
    
    if subject:
        base_query += " AND s.name = :subject"
        params['subject'] = subject
    
    if semester:
        base_query += " AND r.semester = :semester"
        params['semester'] = semester
    
    if resource_type:
        base_query += " AND r.resource_type = :resource_type"
        params['resource_type'] = resource_type
    
    if query:
        base_query += " AND (r.title ILIKE :query OR r.description ILIKE :query)"
        params['query'] = f"%{query}%"
    
    print(f"Executing query: {base_query}")
    print(f"With params: {params}")
    result = session.execute(text(base_query), params)
    resources = result.fetchall()
    
    session.close()
    return resources

def get_auto_suggestions(partial_query, limit=5):
    print("Getting auto-suggestions...")
    session = Session()
    
    query = """
    SELECT DISTINCT title
    FROM resources
    WHERE title ILIKE :partial_query
    LIMIT :limit
    """
    
    result = session.execute(text(query), {'partial_query': f"%{partial_query}%", 'limit': limit})
    suggestions = [row[0] for row in result]
    
    session.close()
    return suggestions

def analyze_keywords(query):
    print("Analyzing keywords...")
    session = Session()
    
    # Fetch all resource titles and descriptions
    result = session.execute(text("SELECT title, description FROM resources"))
    documents = [f"{row.title} {row.description}" for row in result]
    
    # Create TF-IDF vectorizer
    vectorizer = TfidfVectorizer(stop_words='english')
    tfidf_matrix = vectorizer.fit_transform(documents)
    
    # Transform the query
    query_vector = vectorizer.transform([query])
    
    # Calculate cosine similarity
    cosine_similarities = cosine_similarity(query_vector, tfidf_matrix).flatten()
    
    # Get top 5 most similar documents
    related_docs_indices = cosine_similarities.argsort()[:-6:-1]
    
    # Fetch the actual resources
    related_resources = []
    for idx in related_docs_indices:
        result = session.execute(text("SELECT id, title, description FROM resources LIMIT 1 OFFSET :offset"), {'offset': int(idx)})
        resource = result.fetchone()
        related_resources.append(resource)
    
    session.close()
    return related_resources

# Example usage
if __name__ == "__main__":
    print("Starting search system...")
    
    print("Search results:")
    results = search_resources(country="مصر", stage="المرحلة الابتدائية", subject="اللغة العربية", resource_type="كتاب")
    for result in results:
        print(f"Title: {result.title}, Type: {result.resource_type}, Country: {result.country_name}, Stage: {result.stage_name}, Subject: {result.subject_name}")
    
    print("Auto-suggestions:")
    suggestions = get_auto_suggestions("كتاب")
    print(suggestions)
    
    print("Keyword analysis:")
    related_resources = analyze_keywords("تعلم اللغة العربية")
    for resource in related_resources:
        print(f"ID: {resource.id}, Title: {resource.title}")

    print("Search system execution completed.")

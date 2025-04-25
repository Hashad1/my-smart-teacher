
import re
import sqlite3
import random
import string

def create_database():
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("""CREATE TABLE IF NOT EXISTS users
                 (id INTEGER PRIMARY KEY,
                  whatsapp_number TEXT UNIQUE NOT NULL,
                  email TEXT,
                  verification_code TEXT)""")
    conn.commit()
    conn.close()

def validate_whatsapp_number(number):
    pattern = r'^\+\d{1,3}\d{9,15}$'
    return re.match(pattern, number) is not None

def validate_email(email):
    pattern = r'^[\w\.-]+@[\w\.-]+\.\w+$'
    return re.match(pattern, email) is not None

def generate_verification_code():
    return ''.join(random.choices(string.digits, k=6))

def register_user(whatsapp_number, email=None):
    if not validate_whatsapp_number(whatsapp_number):
        return "رقم واتساب غير صالح. يرجى إدخال الرقم بالصيغة الدولية (مثال: +966123456789)"

    if email and not validate_email(email):
        return "عنوان البريد الإلكتروني غير صالح"

    conn = sqlite3.connect('users.db')
    c = conn.cursor()

    try:
        verification_code = generate_verification_code()
        c.execute("INSERT INTO users (whatsapp_number, email, verification_code) VALUES (?, ?, ?)",
                  (whatsapp_number, email, verification_code))
        conn.commit()
        print(f"تم إرسال رمز التحقق إلى رقم الواتساب الخاص بك: {verification_code}")
        return "تم التسجيل بنجاح. يرجى التحقق من رسائل الواتساب الخاصة بك للحصول على رمز التحقق."
    except sqlite3.IntegrityError:
        return "رقم الواتساب مسجل بالفعل"
    finally:
        conn.close()

def verify_user(whatsapp_number, verification_code):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT verification_code FROM users WHERE whatsapp_number = ?", (whatsapp_number,))
    result = c.fetchone()
    
    if result and result[0] == verification_code:
        c.execute("UPDATE users SET verification_code = NULL WHERE whatsapp_number = ?", (whatsapp_number,))
        conn.commit()
        conn.close()
        return "تم التحقق بنجاح. مرحبًا بك في النظام!"
    else:
        conn.close()
        return "فشل التحقق. يرجى المحاولة مرة أخرى."

def simulated_registration_system():
    create_database()
    
    print("\n--- محاكاة نظام التسجيل ---")
    
    # Simulate user registration
    print("\n1. تسجيل مستخدم جديد")
    whatsapp_number = "+966123456789"
    email = "user@example.com"
    print(f"إدخال رقم الواتساب: {whatsapp_number}")
    print(f"إدخال البريد الإلكتروني: {email}")
    result = register_user(whatsapp_number, email)
    print(result)
    
    # Simulate user verification
    print("\n2. التحقق من الحساب")
    verification_code = generate_verification_code()  # Simulating the code sent to WhatsApp
    print(f"إدخال رقم الواتساب: {whatsapp_number}")
    print(f"إدخال رمز التحقق: {verification_code}")
    result = verify_user(whatsapp_number, verification_code)
    print(result)
    
    print("\n3. الخروج")
    print("انتهت المحاكاة. شكرًا لاستخدامك نظام التسجيل.")

if __name__ == "__main__":
    simulated_registration_system()

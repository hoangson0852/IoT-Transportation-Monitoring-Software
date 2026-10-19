import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# Tu dong tao thu muc app_data neu chua co
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
APP_DATA_DIR = os.path.join(BASE_DIR, "app_data")
if not os.path.exists(APP_DATA_DIR):
    os.makedirs(APP_DATA_DIR)

DATABASE_URL = f"sqlite:///{os.path.join(APP_DATA_DIR, 'iot_transport.db')}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        return db
    except Exception as e:
        db.close()
        raise e

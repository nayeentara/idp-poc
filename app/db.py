import os

from sqlalchemy import create_engine
from sqlalchemy import inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

DB_URL = os.getenv(
    "DB_URL",
    "postgresql+psycopg2://idp:idp@localhost:5432/idp",
)

engine = create_engine(DB_URL, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autocommit=False, autoflush=False)
Base = declarative_base()


def ensure_runtime_schema() -> None:
    inspector = inspect(engine)
    if "services" not in inspector.get_table_names():
        return
    column_names = {col["name"] for col in inspector.get_columns("services")}
    if "observability_enabled" not in column_names:
        with engine.begin() as conn:
            conn.execute(text("ALTER TABLE services ADD COLUMN observability_enabled BOOLEAN NOT NULL DEFAULT false"))

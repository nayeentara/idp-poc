from sqlalchemy import Boolean, Column, DateTime, Integer, String, func
from sqlalchemy.dialects.postgresql import JSONB

from app.db import Base


class ServiceModel(Base):
    __tablename__ = "services"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    repo_url = Column(String, nullable=False)
    owner_team = Column(String, nullable=False)
    runtime = Column(String, nullable=False)
    tier = Column(String, nullable=False)
    environments = Column(JSONB, nullable=False, default=list)
    tenant = Column(String, nullable=False, index=True)
    observability_enabled = Column(Boolean, nullable=False, default=False)
    provision_status = Column(String, nullable=False, default="not_requested")
    provision_detail = Column(String, nullable=False, default="")
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

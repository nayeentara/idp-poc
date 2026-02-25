from sqlalchemy import Column, DateTime, Integer, String, func

from app.db import Base


class TenantModel(Base):
    __tablename__ = "tenants"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False, unique=True, index=True)
    status = Column(String, nullable=False, default="not_requested")
    detail = Column(String, nullable=False, default="")
    namespace = Column(String, nullable=True)
    rds_schema = Column(String, nullable=True)
    s3_bucket = Column(String, nullable=True)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())


class ProvisionRequestModel(Base):
    __tablename__ = "provision_requests"

    id = Column(Integer, primary_key=True, index=True)
    service_id = Column(Integer, nullable=False, index=True)
    tenant = Column(String, nullable=False, index=True)
    action = Column(String, nullable=False)
    status = Column(String, nullable=False, default="queued")
    detail = Column(String, nullable=False, default="")
    execution_arn = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

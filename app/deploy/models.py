from sqlalchemy import Column, DateTime, Integer, String, func

from app.db import Base


class DeploymentModel(Base):
    __tablename__ = "deployments"

    id = Column(Integer, primary_key=True, index=True)
    service_id = Column(Integer, nullable=False, index=True)
    environment = Column(String, nullable=False, default="dev")
    status = Column(String, nullable=False, default="queued")
    detail = Column(String, nullable=False, default="")
    execution_arn = Column(String, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

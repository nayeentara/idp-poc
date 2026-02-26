from typing import Optional

from pydantic import BaseModel


class DeployRequest(BaseModel):
    environment: Optional[str] = None


class DeployResponse(BaseModel):
    deployment_id: int
    service_id: int
    environment: str
    action: str
    status: str
    detail: str
    execution_arn: Optional[str] = None


class DeployStatusResponse(BaseModel):
    deployment_id: int
    service_id: int
    environment: str
    status: str
    detail: str
    execution_arn: Optional[str] = None


class DeployCallback(BaseModel):
    deployment_id: int
    status: str
    detail: str = ""
    execution_arn: Optional[str] = None

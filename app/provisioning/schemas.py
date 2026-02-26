from typing import Optional

from pydantic import BaseModel


class ActionResponse(BaseModel):
    service_id: int
    action: str
    status: str
    detail: str


class StatusResponse(BaseModel):
    service_id: int
    environment: Optional[str] = None
    status: str
    detail: str


class ProvisionCallback(BaseModel):
    service_id: int
    tenant: str
    action: str = "provision"
    status: str
    detail: str = ""
    execution_arn: Optional[str] = None

from pydantic import BaseModel


class DeployResponse(BaseModel):
    service_id: int
    action: str
    status: str
    detail: str

from typing import List, Optional

from pydantic import BaseModel, Field


class ServiceInput(BaseModel):
    name: str = Field(..., min_length=1)
    repo_url: str = Field(..., min_length=1)
    owner_team: str = Field(..., min_length=1)
    runtime: str = Field(..., min_length=1, description="go|python")
    tier: str = Field(..., min_length=1)
    environments: List[str] = Field(default_factory=list)
    tenant: str = Field(..., min_length=1, description="Team/tenant slug")
    observability_enabled: bool = False


class Service(ServiceInput):
    id: int
    provision_status: str
    provision_detail: str
    observability_dashboard_url: Optional[str] = None

from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    cached: bool = False
    visit_duration_minutes: int = 60 

class TripInfo(BaseModel):
    trip_id: str
    user_id: str
    title: str
    total_available_time: int 
    created_at: datetime

class RouteRequest(BaseModel):
    trip_info: TripInfo
    places_to_visit: List[Place]

class RouteResponse(BaseModel):
    route_id: str
    status: str
    total_distance_km: float
    total_time_minutes: int
    optimized_order: List[str]
    dropped_places: List[str]
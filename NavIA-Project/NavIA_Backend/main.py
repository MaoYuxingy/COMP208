from fastapi import FastAPI
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import time, date, datetime

# --- 1. 初始化 FastAPI 应用 ---
app = FastAPI(
    title="NavIA Backend API",
    description="This is the core API for the NavIA multi-stop travel planning system.",
    version="1.0.0"
)

# --- 2. 核心数据模型 (严格根据 Data Dictionary 生成) ---

class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    opening_time: Optional[time] = None
    closing_time: Optional[time] = None
    estimated_visit_duration: Optional[int] = Field(None, description="Suggested stay duration in minutes")
    interest_score: Optional[float] = Field(None, ge=0.0, le=10.0, description="Value used in optimisation scoring")
    category: Optional[str] = None
    cached: bool

class Trip(BaseModel):
    trip_id: str
    user_id: str
    title: str
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    total_available_time: int = Field(..., description="Time budget for optimisation (minutes)")
    created_at: datetime

# --- 3. 接口请求与响应模型 ---

class RouteRequest(BaseModel):
    trip_info: Trip
    places_to_visit: List[Place]

class RouteResponse(BaseModel):
    route_id: str
    status: str
    total_distance_km: float
    total_time_minutes: int
    optimized_order: List[str]

# --- 4. API 路由端点 (Endpoints) ---

@app.get("/")
async def root():
    return {"message": "Welcome to NavIA API. Go to /docs for documentation."}

@app.post("/api/v1/optimize-route", response_model=RouteResponse, tags=["Routing"])
async def optimize_route(request: RouteRequest):
    # 这里以后会替换成你们队友写的真实的 TSP 算法
    # 现在先返回一个假的测试响应，保证前后端能通
    return RouteResponse(
        route_id="route_test_001",
        status="FEASIBLE",
        total_distance_km=12.5,
        total_time_minutes=210,
        optimized_order=[place.place_id for place in request.places_to_visit]
    )
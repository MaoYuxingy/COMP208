from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import googlemaps
import os
from dotenv import load_dotenv

# 1. 加载环境变量并初始化 Google Maps 客户端
load_dotenv()
gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAPS_API_KEY"))

app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务",
    version="1.0.0"
)

# --- 数据模型 (Data Models) ---

class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    cached: bool = False

class TripInfo(BaseModel):
    trip_id: str
    user_id: str
    title: str
    total_available_time: int  # 单位：分钟
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

# --- 核心接口 (API Endpoints) ---

@app.get("/")
async def root():
    return {"message": "Welcome to NavIA API - Real-time Routing Enabled"}

@app.post("/api/v1/optimize-route", response_model=RouteResponse, tags=["Routing"])
async def optimize_route(request: RouteRequest):
    locations = [f"{p.latitude},{p.longitude}" for p in request.places_to_visit]
    
    if len(locations) < 2:
        return RouteResponse(
            route_id="err_insufficient_data",
            status="NEED_MORE_PLACES",
            total_distance_km=0.0,
            total_time_minutes=0,
            optimized_order=[p.place_id for p in request.places_to_visit]
        )

    try:
        matrix = gmaps.distance_matrix(
            origins=locations, 
            destinations=locations, 
            mode='driving'
        )

        total_dist_meters = 0
        total_time_seconds = 0
        
        for i in range(len(locations) - 1):
            element = matrix['rows'][i]['elements'][i+1]
            if element['status'] == 'OK':
                total_dist_meters += element['distance']['value']
                total_time_seconds += element['duration']['value']
            else:
                raise HTTPException(status_code=400, detail=f"无法获取点 {i} 到点 {i+1} 的路况")

        return RouteResponse(
            route_id="route_multilevel_v1",
            status="SUCCESS",
            total_distance_km=round(total_dist_meters / 1000.0, 2),
            total_time_minutes=total_time_seconds // 60,
            optimized_order=[p.place_id for p in request.places_to_visit]
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# 必须保留这一段，否则 Uvicorn 有时会找不到入口
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
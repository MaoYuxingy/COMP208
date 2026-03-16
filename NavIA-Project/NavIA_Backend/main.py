from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import googlemaps
import os
from dotenv import load_dotenv
from auth_routes import router as auth_router

# 1. 加载环境变量并初始化 Google Maps 客户端
load_dotenv()
gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAPS_API_KEY"), timeout=10)

app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务",
    version="1.0.0"
)
app.include_router(auth_router)

# --- 数据模型 (Data Models) ---

class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    cached: bool = False
    visit_duration_minutes: int = 60  # 【V3 新增】默认每个景点逛 1 小时

class TripInfo(BaseModel):
    trip_id: str
    user_id: str
    title: str
    total_available_time: int  # 【V3 核心】用户总可用时间（分钟）
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
    dropped_places: List[str]  # 【V3 新增】告诉前端哪些景点因为时间不够被砍掉了

# --- 核心接口 (API Endpoints) ---

@app.get("/")
async def root():
    return {"message": "Welcome to NavIA API - Real-time Routing Enabled"}

@app.post("/api/v1/optimize-route", response_model=RouteResponse, tags=["Routing"])
async def optimize_route(request: RouteRequest):
    if len(request.places_to_visit) < 2:
        return RouteResponse(
            route_id="err_insufficient_data",
            status="NEED_MORE_PLACES",
            total_distance_km=0.0,
            total_time_minutes=0,
            optimized_order=[p.place_id for p in request.places_to_visit],
            dropped_places=[]
        )

    try:
        # 1. 获取所有点之间的距离矩阵
        locations = [f"{p.latitude},{p.longitude}" for p in request.places_to_visit]
        matrix = gmaps.distance_matrix(origins=locations, destinations=locations, mode='driving')

        if not matrix or not matrix.get('rows'):
            raise ValueError("Google Maps 返回了空数据或无法计算路况")

        # 2. 贪心算法 + 时间背包 (V3)
        unvisited = list(range(len(request.places_to_visit)))
        optimized_indices = []
        
        # 强制起点（比如酒店），起点通常不算游玩时间
        current_idx = unvisited.pop(0)
        optimized_indices.append(current_idx)

        total_dist_meters = 0
        total_time_seconds = 0
        
        # 获取用户的总时间预算 (转换为秒)
        time_budget_seconds = request.trip_info.total_available_time * 60

        while unvisited:
            nearest_neighbor = -1
            min_dist = float('inf')
            temp_time = 0

            # 找最近的邻居
            for next_idx in unvisited:
                element = matrix['rows'][current_idx]['elements'][next_idx]
                if element['status'] == 'OK':
                    dist = element['distance']['value']
                    if dist < min_dist:
                        min_dist = dist
                        nearest_neighbor = next_idx
                        temp_time = element['duration']['value']

            if nearest_neighbor == -1:
                break
            
            # 【核心校验】如果去下一个点，时间够不够？
            visit_time_seconds = request.places_to_visit[nearest_neighbor].visit_duration_minutes * 60
            predicted_time = total_time_seconds + temp_time + visit_time_seconds
            
            if predicted_time > time_budget_seconds:
                # 时间不够了！停止规划，剩下的点全部放弃
                break 
            
            # 时间充足，加入行程
            total_dist_meters += min_dist
            total_time_seconds += (temp_time + visit_time_seconds)
            current_idx = nearest_neighbor
            unvisited.remove(nearest_neighbor)
            optimized_indices.append(nearest_neighbor)

        # 3. 构造返回结果
        optimized_place_ids = [request.places_to_visit[i].place_id for i in optimized_indices]
        dropped_place_ids = [request.places_to_visit[i].place_id for i in unvisited] # 没被访问的点就是被砍掉的

        return RouteResponse(
            route_id="route_optimized_v3",
            status="SUCCESS_WITH_TIME_LIMIT",
            total_distance_km=round(total_dist_meters / 1000.0, 2),
            total_time_minutes=total_time_seconds // 60,
            optimized_order=optimized_place_ids,
            dropped_places=dropped_place_ids # 返回被砍掉的景点
        )

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=403, detail=f"地图服务授权失败: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"路径规划暂时不可用: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
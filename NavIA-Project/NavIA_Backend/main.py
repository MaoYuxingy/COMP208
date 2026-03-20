from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import googlemaps
import os
from dotenv import load_dotenv

from database import engine, SessionLocal
import models
from auth_routes import router as auth_router

# 1. 加载环境变量并初始化 Google Maps 客户端
load_dotenv()
gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAPS_API_KEY"), timeout=10)

# 2. 初始化 FastAPI 应用
app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务 (V5 Time Windows)",
    version="1.0.0"
)

# 3. 挂载跨域中间件 (CORS) 与 Auth 路由
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth_router)

# 4. 初始化数据库表结构
models.Base.metadata.create_all(bind=engine)

# ==========================================
# 数据模型 (Pydantic Schemas - V5 升级版)
# ==========================================

class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    cached: bool = False
    visit_duration_minutes: int = 60
    # V5 新增：营业时间（绝对分钟数，默认 0 即 00:00，1440 即 24:00）
    open_time: int = 0
    close_time: int = 1440

class TripInfo(BaseModel):
    trip_id: str
    user_id: str
    title: str
    # V5 新增：早上从酒店出发的时间（绝对分钟数，比如 8:00 AM 就是 480）
    start_time: int = 480 
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

# ==========================================
# 核心业务接口：V5 路线规划与闭环优化
# ==========================================

@app.post("/api/v1/optimize-route", response_model=RouteResponse)
def optimize_route(request: RouteRequest):
    if not request.places_to_visit or len(request.places_to_visit) < 2:
        raise HTTPException(status_code=400, detail="至少需要提供两个地点（包括起点）")

    # 提取经纬度用于调用 Google Maps API
    locations = [(p.latitude, p.longitude) for p in request.places_to_visit]
    
    try:
        # 调用 Google Maps 距离矩阵 API
        matrix = gmaps.distance_matrix(locations, locations, mode="driving")
        
        # --- V5 初始化绝对时间轴 (全转为秒，方便计算) ---
        start_time_sec = request.trip_info.start_time * 60
        current_time_sec = start_time_sec
        end_time_sec = current_time_sec + (request.trip_info.total_available_time * 60)
        
        start_idx = 0  # 默认列表第一个元素为起点（酒店）
        current_idx = start_idx
        unvisited = list(range(1, len(request.places_to_visit)))
        
        optimized_indices = [start_idx]
        total_dist_meters = 0
        
        # --- V5 贪心推演与剪枝逻辑 ---
        while unvisited:
            nearest_neighbor = -1
            min_cost = float('inf') 
            
            temp_time_to_next = 0
            temp_wait_time = 0
            temp_dist_to_next = 0
            
            for next_idx in unvisited:
                element_to = matrix['rows'][current_idx]['elements'][next_idx]
                element_return = matrix['rows'][next_idx]['elements'][start_idx]
                
                if element_to['status'] == 'OK' and element_return['status'] == 'OK':
                    dist_to = element_to['distance']['value']
                    time_to = element_to['duration']['value']
                    time_return = element_return['duration']['value']
                    
                    visit_time = request.places_to_visit[next_idx].visit_duration_minutes * 60
                    open_time_sec = request.places_to_visit[next_idx].open_time * 60
                    close_time_sec = request.places_to_visit[next_idx].close_time * 60
                    
                    # 1. 推算到达时间
                    arrival_time = current_time_sec + time_to
                    
                    # 2. 计算在门外的等待时间
                    wait_time = max(0, open_time_sec - arrival_time)
                    
                    # 3. 实际开始游玩时间
                    actual_start_time = arrival_time + wait_time
                    
                    # 【硬约束 1】：关门剪枝
                    if actual_start_time + visit_time > close_time_sec:
                        continue
                        
                    # 【硬约束 2】：闭环超时剪枝
                    if actual_start_time + visit_time + time_return > end_time_sec:
                        continue
                        
                    # 综合代价计算: 距离 + 等待时间的双重惩罚
                    cost = dist_to + (wait_time * 2) 
                    
                    if cost < min_cost:
                        min_cost = cost
                        nearest_neighbor = next_idx
                        temp_time_to_next = time_to
                        temp_wait_time = wait_time
                        temp_dist_to_next = dist_to

            # 如果没有符合条件的景点，结束今天的行程
            if nearest_neighbor == -1:
                break
            
            # 正式将该景点加入行程
            visit_time = request.places_to_visit[nearest_neighbor].visit_duration_minutes * 60
            current_time_sec += (temp_time_to_next + temp_wait_time + visit_time)
            total_dist_meters += temp_dist_to_next
            
            current_idx = nearest_neighbor
            unvisited.remove(nearest_neighbor)
            optimized_indices.append(nearest_neighbor)

        # 闭环：计算返回起点的距离和时间
        element_return_final = matrix['rows'][current_idx]['elements'][start_idx]
        if element_return_final['status'] == 'OK':
            total_dist_meters += element_return_final['distance']['value']
            current_time_sec += element_return_final['duration']['value']
            optimized_indices.append(start_idx)

        # 统计舍弃的景点
        dropped_indices = unvisited
        optimized_place_ids = [request.places_to_visit[i].place_id for i in optimized_indices]
        dropped_place_ids = [request.places_to_visit[i].place_id for i in dropped_indices]

        # ==========================================
        # 将生成的路线持久化到数据库
        # ==========================================
        db = SessionLocal()
        try:
            # 1. 创建 Trip 记录
            new_trip = models.DBTrip(
                trip_id=request.trip_info.trip_id,
                user_id=request.trip_info.user_id,
                title=request.trip_info.title,
                total_available_time=request.trip_info.total_available_time,
                created_at=request.trip_info.created_at
            )
            db.add(new_trip)
            
            # 2. 创建关联的 Place 记录 (仅保存去成的景点)
            for place_id in optimized_place_ids:
                p = next((item for item in request.places_to_visit if item.place_id == place_id), None)
                if p:
                    new_place = models.DBPlace(
                        place_id=p.place_id,
                        name=p.name,
                        latitude=p.latitude,
                        longitude=p.longitude,
                        visit_duration_minutes=p.visit_duration_minutes,
                        trip_id=request.trip_info.trip_id
                    )
                    db.add(new_place)
            
            db.commit()
        except Exception as db_err:
            db.rollback()
            print(f"Database Error: {db_err}")
        finally:
            db.close()

        # 计算总耗时 (修复了缺少 60 的语法错误)
        total_time_minutes = (current_time_sec - start_time_sec) // 60

        # 返回最终结果 (修复了之前缩进不对导致被判定在 try 外面的错误)
        return RouteResponse(
            route_id="route_optimized_v5_time_windows",
            status="SUCCESS_ROUND_TRIP_WITH_TIME_WINDOWS",
            total_distance_km=round(total_dist_meters / 1000.0, 2),
            total_time_minutes=total_time_minutes,
            optimized_order=optimized_place_ids,
            dropped_places=dropped_place_ids
        )

    # 捕获 Google Maps API 异常 (修复了之前的缩进丢失问题)
    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=500, detail=f"Google Maps API 错误: {str(e)}")
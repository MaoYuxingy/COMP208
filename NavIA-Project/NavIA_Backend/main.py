from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime
import googlemaps
import os
from dotenv import load_dotenv
from database import engine, SessionLocal
import models
from auth_routes import router as auth_router

# 1. 加载环境变量并初始化
load_dotenv()
gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAPS_API_KEY"), timeout=10)

app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务",
    version="1.0.0"
)
app.include_router(auth_router)

# --- 关键：在这里插入数据库初始化代码 ---
models.Base.metadata.create_all(bind=engine)

# --- 数据模型 ---

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

# --- 核心接口 ---

@app.get("/")
async def root():
    return {"message": "Welcome to NavIA API - V4 Round-Trip Routing Enabled"}

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
        # 1. 获取距离矩阵
        locations = [f"{p.latitude},{p.longitude}" for p in request.places_to_visit]
        matrix = gmaps.distance_matrix(origins=locations, destinations=locations, mode='driving')

        if not matrix or not matrix.get('rows'):
            raise ValueError("Google Maps 返回了空数据")

        # 2. V4 闭环贪心算法
        unvisited = list(range(len(request.places_to_visit)))
        optimized_indices = []
        
        # 记录起点 (如：酒店)，并移出未访问列表
        start_idx = unvisited.pop(0)
        current_idx = start_idx
        optimized_indices.append(start_idx)

        total_dist_meters = 0
        total_time_seconds = 0
        time_budget_seconds = request.trip_info.total_available_time * 60

        while unvisited:
            nearest_neighbor = -1
            min_dist = float('inf')
            temp_time_to_next = 0
            
            for next_idx in unvisited:
                # 获取从当前点去下一站的数据
                element_to = matrix['rows'][current_idx]['elements'][next_idx]
                # 获取从下一站直接回酒店的数据
                element_return = matrix['rows'][next_idx]['elements'][start_idx]
                
                if element_to['status'] == 'OK' and element_return['status'] == 'OK':
                    dist_to = element_to['distance']['value']
                    time_to = element_to['duration']['value']
                    time_return = element_return['duration']['value']
                    
                    visit_time = request.places_to_visit[next_idx].visit_duration_minutes * 60
                    
                    # 【V4 核心】：预测总耗时 = 已用时间 + 去下一站车程 + 下一站游玩 + 从下一站回酒店的车程
                    predicted_time = total_time_seconds + time_to + visit_time + time_return
                    
                    # 只有在总预算范围内，且距离最短的，才是我们的目标
                    if predicted_time <= time_budget_seconds and dist_to < min_dist:
                        min_dist = dist_to
                        nearest_neighbor = next_idx
                        temp_time_to_next = time_to

            # 如果找不到符合条件的点（时间不够了，或者路不通），必须结束寻找
            if nearest_neighbor == -1:
                break
            
            # 正式加入行程
            visit_time = request.places_to_visit[nearest_neighbor].visit_duration_minutes * 60
            total_dist_meters += min_dist
            total_time_seconds += (temp_time_to_next + visit_time)
            current_idx = nearest_neighbor
            unvisited.remove(nearest_neighbor)
            optimized_indices.append(nearest_neighbor)

        # 3. 闭环：添加最后一段回酒店的行程
        if current_idx != start_idx:
            final_leg = matrix['rows'][current_idx]['elements'][start_idx]
            if final_leg['status'] == 'OK':
                total_dist_meters += final_leg['distance']['value']
                total_time_seconds += final_leg['duration']['value']
            
            # 将起点再次追加到路线末尾，形成完美闭环
            optimized_indices.append(start_idx)

        # 构造结果
        optimized_place_ids = [request.places_to_visit[i].place_id for i in optimized_indices]
        dropped_place_ids = [request.places_to_visit[i].place_id for i in unvisited] # 没被访问的点就是被砍掉的\

        # ... 前面的计算逻辑保持不变 ...

        # --- 【新增：保存到数据库】 ---
        db = SessionLocal()
        try:
            # 1. 创建行程记录
            new_trip = models.DBTrip(
                trip_id=request.trip_info.trip_id,
                user_id=request.trip_info.user_id,
                title=request.trip_info.title,
                total_available_time=request.trip_info.total_available_time,
                created_at=request.trip_info.created_at
            )
            db.add(new_trip)
            
            # 2. 创建关联的地点记录
            for p in request.places_to_visit:
                new_place = models.DBPlace(
                    place_id=p.place_id,
                    name=p.name,
                    latitude=p.latitude,
                    longitude=p.longitude,
                    visit_duration_minutes=p.visit_duration_minutes,
                    trip_id=request.trip_info.trip_id # 建立外键关联
                )
                db.add(new_place)
            
            db.commit() # 真正写入 navia.db 文件
        except Exception as db_err:
            db.rollback() # 出错就回滚，保证数据不乱
            print(f"Database Error: {db_err}")
        finally:
            db.close() # 必须关闭连接，否则数据库会被锁死

        return RouteResponse(
            route_id="route_optimized_v4_closed_loop",
            status="SUCCESS_ROUND_TRIP",
            total_distance_km=round(total_dist_meters / 1000.0, 2),
            total_time_minutes=total_time_seconds // 60,
            optimized_order=optimized_place_ids,
            dropped_places=dropped_place_ids
        )

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=403, detail=f"地图服务授权失败: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"路径规划暂时不可用: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime
import googlemaps
import os
from dotenv import load_dotenv

from database import engine, SessionLocal
import models
from auth_routes import router as auth_router
from schemas import Place, TripInfo, RouteRequest, RouteResponse # 导入最新的 schemas

# 1. 加载环境变量并初始化 Google Maps 客户端
load_dotenv()
gmaps = googlemaps.Client(key=os.getenv("GOOGLE_MAPS_API_KEY"), timeout=10)

# 2. 初始化 FastAPI 应用
app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务 (V5 Time Windows + Polyline 轨迹)",
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
# 数据库依赖注入 (水管工函数)
# ==========================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ==========================================
# 核心业务接口：V5 路线规划与闭环优化
# ==========================================
@app.post("/api/v1/optimize-route", response_model=RouteResponse)
def optimize_route(request: RouteRequest):
    if not request.places_to_visit or len(request.places_to_visit) < 2:
        raise HTTPException(status_code=400, detail="至少需要提供两个地点（包括起点）")

    locations = [(p.latitude, p.longitude) for p in request.places_to_visit]
    
    try:
        # 调用 Google Maps 距离矩阵 API
        matrix = gmaps.distance_matrix(locations, locations, mode="driving")
        
        # ==========================================
        # 【核心修复：时间单位换算对齐】
        # ==========================================
        # 前端约定: start_time 为分钟 (如 540 表示 9:00 AM) -> 需乘 60 转为秒
        start_time_sec = request.trip_info.start_time * 60
        current_time_sec = start_time_sec
        
        # 前端约定: total_available_time 为小时 (如 4 表示 4小时) -> 需乘 3600 转为秒
        end_time_sec = current_time_sec + (request.trip_info.total_available_time * 3600)
        
        start_idx = 0 
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
                    
                    # 这里的 visit_duration_minutes, open_time, close_time 前端约定均为分钟 -> 乘 60 转为秒
                    visit_time = request.places_to_visit[next_idx].visit_duration_minutes * 60
                    open_time_sec = request.places_to_visit[next_idx].open_time * 60
                    close_time_sec = request.places_to_visit[next_idx].close_time * 60
                    
                    arrival_time = current_time_sec + time_to
                    wait_time = max(0, open_time_sec - arrival_time)
                    actual_start_time = arrival_time + wait_time
                    
                    if actual_start_time + visit_time > close_time_sec:
                        continue
                        
                    if actual_start_time + visit_time + time_return > end_time_sec:
                        continue
                        
                    cost = dist_to + (wait_time * 2) 
                    
                    if cost < min_cost:
                        min_cost = cost
                        nearest_neighbor = next_idx
                        temp_time_to_next = time_to
                        temp_wait_time = wait_time
                        temp_dist_to_next = dist_to

            if nearest_neighbor == -1:
                break
            
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

        dropped_indices = unvisited
        optimized_place_ids = [request.places_to_visit[i].place_id for i in optimized_indices]
        dropped_place_ids = [request.places_to_visit[i].place_id for i in dropped_indices]

        # ==========================================
        # 数据库持久化逻辑
        # ==========================================
        db = SessionLocal()
        try:
            new_trip = models.DBTrip(
                trip_id=request.trip_info.trip_id,
                user_id=request.trip_info.user_id,
                title=request.trip_info.title,
                total_available_time=request.trip_info.total_available_time,
                created_at=request.trip_info.created_at
            )
            db.add(new_trip)
            
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

        # ==========================================
        # 视觉优化：获取真实街道 Polyline 轨迹
        # ==========================================
        polylines = []
        try:
            # 获取已排序地点的经纬度
            ordered_locations = []
            for pid in optimized_place_ids:
                p = next(item for item in request.places_to_visit if item.place_id == pid)
                ordered_locations.append((p.latitude, p.longitude))
            
            # 依次请求 A->B, B->C 的详细轨迹
            for i in range(len(ordered_locations) - 1):
                origin = ordered_locations[i]
                destination = ordered_locations[i+1]
                directions_result = gmaps.directions(origin, destination, mode="driving")
                if directions_result:
                    encoded_polyline = directions_result[0]['overview_polyline']['points']
                    polylines.append(encoded_polyline)
        except Exception as poly_err:
            print(f"获取 Polyline 失败，已降级: {poly_err}")

        total_time_minutes = (current_time_sec - start_time_sec) // 60

        return RouteResponse(
            route_id="route_optimized_v5_time_windows",
            status="SUCCESS_ROUND_TRIP_WITH_TIME_WINDOWS",
            total_distance_km=round(total_dist_meters / 1000.0, 2),
            total_time_minutes=total_time_minutes,
            optimized_order=optimized_place_ids,
            dropped_places=dropped_place_ids,
            polylines=polylines  # 返回给前端画线
        )

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=403, detail=f"地图服务授权失败: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"路径规划暂时不可用: {str(e)}")


# ==========================================
# 历史行程查询接口 (已移至正确位置)
# ==========================================
@app.get("/api/v1/trips/{trip_id}")
def get_trip_history(trip_id: str, db: Session = Depends(get_db)):
    # 去数据库里查对应的行程
    trip = db.query(models.DBTrip).filter(models.DBTrip.trip_id == trip_id).first()
    
    # 如果查不到，返回 404 报错
    if not trip:
        raise HTTPException(status_code=404, detail="找不到该行程数据")
        
    # 查到了直接返回
    return trip


# ==========================================
# 程序启动入口 (必须在最底部)
# ==========================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
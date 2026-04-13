from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime

# ==========================================
# 1. 景点模型 (带有 V5 时间窗约束)
# ==========================================
class Place(BaseModel):
    place_id: str
    name: str
    latitude: float
    longitude: float
    cached: bool = False
    
    # 时间约束 (单位：分钟)
    visit_duration_minutes: int = Field(default=60, description="预计游玩时长")
    open_time: int = Field(default=0, description="景点开门时间，从 0:00 开始的分钟数")
    close_time: int = Field(default=1440, description="景点关门时间，从 0:00 开始的分钟数")

# ==========================================
# 2. 行程基础信息模型
# ==========================================
class TripInfo(BaseModel):
    trip_id: str
    user_id: str
    title: str
    
    # 核心预算参数
    total_available_time: int = Field(..., description="总预算时间，单位：小时")
    start_time: int = Field(default=480, description="出发时刻，从 0:00 开始的分钟数，默认 8:00")
    
    created_at: datetime = Field(default_factory=datetime.utcnow)

# ==========================================
# 3. 路径请求模型 (API 入参)
# ==========================================
class RouteRequest(BaseModel):
    trip_info: TripInfo
    places_to_visit: List[Place]

# ==========================================
# 4. 路径响应模型 (API 出参)
# ==========================================
class RouteResponse(BaseModel):
    route_id: str
    status: str
    
    # 统计数据
    total_distance_km: float
    total_time_minutes: int
    
    # 结果详情
    optimized_order: List[str] = Field(..., description="优化后的景点 ID 排序列表")
    dropped_places: List[str] = Field(..., description="因时间预算不足被剔除的景点 ID 列表")
    
    # 地图轨迹数据
    polylines: List[str] = Field(default_factory=list, description="Google Maps 轨迹解码字符串，用于前端绘图")

# ==========================================
# 5. 额外辅助模型 (如需要)
# ==========================================
class UserProfile(BaseModel):
    user_id: str
    email: str
    name: str
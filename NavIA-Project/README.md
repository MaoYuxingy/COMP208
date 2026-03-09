# NavIA 

NavIA 是一款原生的 iOS 旅行规划与导航 App。它由 Python FastAPI 后端支持，并包含一个专门处理多重约束（如营业时间、距离）的路线规划引擎。

## 🛠 技术栈
* **前端 (Frontend):** iOS 原生开发 (Swift, SwiftUI, ARKit)
* **后端 (Backend):** Python (FastAPI)
* **数据库 (Database):** MySQL (云端) & Core Data (本地离线缓存)
* **外部接口 (External APIs):** Google Maps SDK (用于距离计算和地点搜索)

## 🚀 快速启动 (本地环境搭建)

请按照以下步骤，把后端的本地服务器跑起来：

1. 克隆代码到本地电脑：
git clone [https://github.com/MaoYuxingy/COMP208.git](https://github.com/MaoYuxingy/COMP208.git)
cd NavIA_Backend

2. 安装所需的 Python 依赖包：
pip install -r requirements.txt

3. 启动本地服务器：
uvicorn main:app --reload

启动成功后，在浏览器打开 API 接口文档进行测试：http://127.0.0.1:8000/docs

NavIA V4 核心算法 API 对接速查表
接口基础信息
接口路径 (Endpoint): POST /api/v1/optimize-route

功能描述: 接收用户选择的景点，根据总时间预算进行智能排序、剔除超时景点，并自动生成闭环（回到起点）的最优路线。

1.前端传给后端的 JSON (Request Body)

前端同学请严格按照以下格式构造请求体。特别注意注释中的要求：

JSON
{
  "trip_info": {
    "trip_id": "trip_888",
    "user_id": "user_123",
    "title": "巴黎一日游",
    "total_available_time": 300, 
    "created_at": "2026-03-09T09:00:00Z"
  },
  "places_to_visit": [
    {
      "place_id": "hotel_01", 
      "name": "巴黎中心酒店",
      "latitude": 48.8566,
      "longitude": 2.3522,
      "visit_duration_minutes": 0 
    },
    {
      "place_id": "louvre_01",
      "name": "卢浮宫",
      "latitude": 48.8606,
      "longitude": 2.3376,
      "visit_duration_minutes": 120
    }
  ]
}

前端开发必看（防报错指南）：

起点锁定原则：places_to_visit 数组里的第 1 个元素（Index 0）必须是用户的出发地/酒店。算法会自动将它作为路线的起点和终点。

总时间预算：total_available_time 代表今天总共能玩多久（单位：分钟）。

游玩时间：每个景点必须传 visit_duration_minutes（单位：分钟）。如果没传，后端会默认按 60 分钟算。

2.后端返回给前端的 JSON (Response Body)
调用成功后，前端会收到如下结果，直接拿去渲染 UI：

JSON
{
  "route_id": "route_optimized_v4_closed_loop",
  "status": "SUCCESS_ROUND_TRIP",
  "total_distance_km": 12.5,
  "total_time_minutes": 260, 
  "optimized_order": [
    "hotel_01",
    "louvre_01",
    "hotel_01" 
  ],
  "dropped_places": [
    "eiffel_01" 
  ]
}

UI/前端渲染必看：
如何画线：拿到 optimized_order 后，直接按这个数组里的 ID 顺序在 MapKit 上打点连线，它已经是一个完美的闭环路线。

总耗时/里程：total_distance_km 和 total_time_minutes 已经包含了所有车程 + 所有景点的游玩时间。直接显示在界面顶部即可。

被砍掉的景点：dropped_places 里的 ID 是因为“时间不够”被算法智能舍弃的。请在行程结果页底部加一个类似 “时间不足，已为您省略以下景点” 的提示 UI。

3.数据库建表必对齐 (Database Schema)
负责数据库的同学请注意，在用 SQLAlchemy 建表时：

Trip 表必须有 total_available_time (Integer) 字段。

Place 表必须有 visit_duration_minutes (Integer) 字段。

经纬度统一使用 Float，不要用 String 存。




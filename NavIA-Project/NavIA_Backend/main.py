from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from datetime import timedelta
import googlemaps
import os
from dotenv import load_dotenv

from database import engine, SessionLocal
import models
from auth_routes import router as auth_router
from auth_store import ensure_demo_user_in_db
from schemas import (
    Place,
    TripInfo,
    RouteRequest,
    RouteResponse,
    TripHistoryResponse,
    TripDetailResponse,
)

# ==========================================
# 1. Load environment variables and initialise Google Maps client
# ==========================================
load_dotenv()
GOOGLE_MAPS_API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")
gmaps = googlemaps.Client(key=GOOGLE_MAPS_API_KEY, timeout=10) if GOOGLE_MAPS_API_KEY else None

# ==========================================
# 2. Initialise FastAPI app
# ==========================================
app = FastAPI(
    title="NavIA Backend API",
    description="旅游路线规划与优化后端服务 (V5 Time Windows + Polyline 轨迹)",
    version="1.0.0"
)

# ==========================================
# 3. Configure CORS and mount auth routes
# ==========================================
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth_router)

# ==========================================
# 4. Initialise database tables
# ==========================================
models.Base.metadata.create_all(bind=engine)


def ensure_sqlite_column(table_name: str, column_name: str, column_definition: str):
    with engine.begin() as connection:
        columns = {
            row[1]
            for row in connection.exec_driver_sql(f"PRAGMA table_info({table_name})").fetchall()
        }
        if column_name not in columns:
            connection.exec_driver_sql(
                f"ALTER TABLE {table_name} ADD COLUMN {column_definition}"
            )


def migrate_legacy_sqlite_schema():
    ensure_sqlite_column("users", "is_active", "is_active BOOLEAN DEFAULT 1")
    ensure_sqlite_column("trips", "start_time", "start_time INTEGER DEFAULT 480")
    ensure_sqlite_column("places", "open_time", "open_time INTEGER DEFAULT 0")
    ensure_sqlite_column("places", "close_time", "close_time INTEGER DEFAULT 1440")
    ensure_sqlite_column("places", "visit_order", "visit_order INTEGER")
    ensure_sqlite_column("places", "arrival_time", "arrival_time TEXT")
    ensure_sqlite_column("places", "wait_time", "wait_time INTEGER DEFAULT 0")
    ensure_sqlite_column("places", "departure_time", "departure_time TEXT")
    ensure_sqlite_column("places", "dropped", "dropped BOOLEAN DEFAULT 0")


migrate_legacy_sqlite_schema()
ensure_demo_user_in_db()

# ==========================================
# Database session dependency
# Creates and closes one DB session per request
# ==========================================
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def root():
    return {
        "status": "ok",
        "message": "NavIA backend is running.",
        "docs_url": "/docs",
    }


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "NavIA Backend API",
    }


# ==========================================
# Core business API: V5 route optimisation with time windows and round trip
# ==========================================
@app.post("/api/v1/optimize-route", response_model=RouteResponse)
def optimize_route(request: RouteRequest):
    if not request.places_to_visit or len(request.places_to_visit) < 2:
        raise HTTPException(status_code=400, detail="至少需要提供两个地点（包括起点）")

    if gmaps is None:
        raise HTTPException(status_code=503, detail="Google Maps API Key 尚未配置")

    locations = [(p.latitude, p.longitude) for p in request.places_to_visit]

    try:
        # Call Google Maps Distance Matrix API
        matrix = gmaps.distance_matrix(locations, locations, mode="driving")

        start_time_sec = request.trip_info.start_time * 60
        current_time_sec = start_time_sec
        # total_available_time is provided in hours, so convert to seconds here.
        end_time_sec = current_time_sec + (request.trip_info.total_available_time * 3600)

        start_idx = 0
        current_idx = start_idx
        unvisited = list(range(1, len(request.places_to_visit)))

        optimized_indices = [start_idx]
        total_dist_meters = 0

        # Store per-place schedule state for DB persistence
        place_schedule = {
            request.places_to_visit[start_idx].place_id: {
                "visit_order": 0,
                "arrival_time": str(timedelta(seconds=start_time_sec)),
                "wait_time": 0,
                "departure_time": str(timedelta(seconds=start_time_sec)),
                "dropped": False,
            }
        }

        # Greedy search with time-window pruning
        while unvisited:
            nearest_neighbor = -1
            min_cost = float("inf")

            temp_time_to_next = 0
            temp_wait_time = 0
            temp_dist_to_next = 0

            for next_idx in unvisited:
                element_to = matrix["rows"][current_idx]["elements"][next_idx]
                element_return = matrix["rows"][next_idx]["elements"][start_idx]

                if element_to["status"] == "OK" and element_return["status"] == "OK":
                    dist_to = element_to["distance"]["value"]
                    time_to = element_to["duration"]["value"]
                    time_return = element_return["duration"]["value"]

                    visit_time = request.places_to_visit[next_idx].visit_duration_minutes * 60
                    open_time_sec = request.places_to_visit[next_idx].open_time * 60
                    close_time_sec = request.places_to_visit[next_idx].close_time * 60

                    arrival_time = current_time_sec + time_to
                    wait_time = max(0, open_time_sec - arrival_time)
                    actual_start_time = arrival_time + wait_time

                    # Skip if cannot arrive and finish before closing
                    if actual_start_time + visit_time > close_time_sec:
                        continue

                    # Skip if cannot finish visit and return to origin within budget
                    if actual_start_time + visit_time + time_return > end_time_sec:
                        continue

                    # Combined cost: distance + weighted waiting penalty
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
            arrival_time_sec = current_time_sec + temp_time_to_next
            actual_start_time_sec = arrival_time_sec + temp_wait_time
            departure_time_sec = actual_start_time_sec + visit_time

            selected_place = request.places_to_visit[nearest_neighbor]

            # Persist route-state data for this selected place
            place_schedule[selected_place.place_id] = {
                "visit_order": len(optimized_indices),
                "arrival_time": str(timedelta(seconds=arrival_time_sec)),
                "wait_time": temp_wait_time // 60,
                "departure_time": str(timedelta(seconds=departure_time_sec)),
                "dropped": False,
            }

            current_time_sec = departure_time_sec
            total_dist_meters += temp_dist_to_next

            current_idx = nearest_neighbor
            unvisited.remove(nearest_neighbor)
            optimized_indices.append(nearest_neighbor)

        # Round trip: return to start
        element_return_final = matrix["rows"][current_idx]["elements"][start_idx]
        if element_return_final["status"] == "OK":
            total_dist_meters += element_return_final["distance"]["value"]
            current_time_sec += element_return_final["duration"]["value"]
            optimized_indices.append(start_idx)

        dropped_indices = unvisited
        optimized_place_ids = [request.places_to_visit[i].place_id for i in optimized_indices]
        dropped_place_ids = [request.places_to_visit[i].place_id for i in dropped_indices]

        # Mark dropped places for persistence
        for dropped_idx in dropped_indices:
            dropped_place = request.places_to_visit[dropped_idx]
            place_schedule[dropped_place.place_id] = {
                "visit_order": -1,
                "arrival_time": None,
                "wait_time": 0,
                "departure_time": None,
                "dropped": True,
            }

        # ==========================================
        # Persist trip and all place states to DB
        # ==========================================
        db = SessionLocal()
        try:
            db.query(models.DBPlace).filter(models.DBPlace.trip_id == request.trip_info.trip_id).delete()
            db.query(models.DBTrip).filter(models.DBTrip.trip_id == request.trip_info.trip_id).delete()

            new_trip = models.DBTrip(
                trip_id=request.trip_info.trip_id,
                user_id=request.trip_info.user_id,
                title=request.trip_info.title,
                start_time=request.trip_info.start_time,
                total_available_time=request.trip_info.total_available_time,
                created_at=request.trip_info.created_at,
            )
            db.add(new_trip)

            # Save all places from the original request
            # so dropped places can also be restored later
            for p in request.places_to_visit:
                schedule = place_schedule.get(
                    p.place_id,
                    {
                        "visit_order": -1,
                        "arrival_time": None,
                        "wait_time": 0,
                        "departure_time": None,
                        "dropped": False,
                    },
                )

                new_place = models.DBPlace(
                    place_id=p.place_id,
                    name=p.name,
                    latitude=p.latitude,
                    longitude=p.longitude,
                    visit_duration_minutes=p.visit_duration_minutes,
                    open_time=p.open_time,
                    close_time=p.close_time,
                    visit_order=schedule["visit_order"],
                    arrival_time=schedule["arrival_time"],
                    wait_time=schedule["wait_time"],
                    departure_time=schedule["departure_time"],
                    dropped=schedule["dropped"],
                    trip_id=request.trip_info.trip_id,
                )
                db.add(new_place)

            db.commit()
        except Exception as db_err:
            db.rollback()
            print(f"Database Error: {db_err}")
            raise HTTPException(status_code=500, detail="路线已生成，但保存行程失败")
        finally:
            db.close()

        # ==========================================
        # Polyline generation for frontend route rendering
        # ==========================================
        polylines = []
        try:
            ordered_locations = []
            for pid in optimized_place_ids:
                p = next(item for item in request.places_to_visit if item.place_id == pid)
                ordered_locations.append((p.latitude, p.longitude))

            for i in range(len(ordered_locations) - 1):
                origin = ordered_locations[i]
                destination = ordered_locations[i + 1]
                directions_result = gmaps.directions(origin, destination, mode="driving")
                if directions_result:
                    encoded_polyline = directions_result[0]["overview_polyline"]["points"]
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
            polylines=polylines,
        )

    except googlemaps.exceptions.ApiError as e:
        raise HTTPException(status_code=403, detail=f"地图服务授权失败: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"路径规划暂时不可用: {str(e)}")


# ==========================================
# Trip detail API
# Returns one saved trip with all persisted places and route-state fields
# ==========================================
@app.get("/api/v1/trips/{trip_id}", response_model=TripDetailResponse)
def get_trip_detail(trip_id: str, db: Session = Depends(get_db)):
    trip = db.query(models.DBTrip).filter(models.DBTrip.trip_id == trip_id).first()

    if not trip:
        raise HTTPException(status_code=404, detail="找不到该行程数据")

    places = sorted(
        trip.places,
        key=lambda p: (
            p.visit_order is None or p.visit_order < 0,
            p.visit_order if p.visit_order is not None and p.visit_order >= 0 else 9999,
        ),
    )

    return {
        "trip_info": {
            "trip_id": trip.trip_id,
            "user_id": trip.user_id,
            "title": trip.title,
            "start_time": trip.start_time,
            "total_available_time": trip.total_available_time,
            "created_at": trip.created_at,
        },
        "places": [
            {
                "place_id": p.place_id,
                "name": p.name,
                "latitude": p.latitude,
                "longitude": p.longitude,
                "cached": False,
                "visit_duration_minutes": p.visit_duration_minutes,
                "open_time": p.open_time,
                "close_time": p.close_time,
                "visit_order": p.visit_order if p.visit_order is not None and p.visit_order >= 0 else None,
                "arrival_time": p.arrival_time,
                "wait_time": p.wait_time,
                "departure_time": p.departure_time,
                "dropped": p.dropped,
            }
            for p in places
        ],
    }


# ==========================================
# User trip history list API
# Returns all saved trips for a given user, newest first
# ==========================================
@app.get("/api/v1/users/{user_id}/trips", response_model=TripHistoryResponse)
def get_user_trip_history(user_id: str, db: Session = Depends(get_db)):
    trips = (
        db.query(models.DBTrip)
        .filter(models.DBTrip.user_id == user_id)
        .order_by(models.DBTrip.created_at.desc())
        .all()
    )

    return {
        "trips": [
            {
                "trip_id": trip.trip_id,
                "user_id": trip.user_id,
                "title": trip.title,
                "total_available_time": trip.total_available_time,
                "created_at": trip.created_at,
            }
            for trip in trips
        ]
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

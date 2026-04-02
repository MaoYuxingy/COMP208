from database import SessionLocal, engine
import models
import uuid

# 确保数据库的表都已经建好了
models.Base.metadata.create_all(bind=engine)

# 拧开数据库的水龙头
db = SessionLocal()

# 1. 捏造一个假行程 (Trip)
fake_trip_id = str(uuid.uuid4()) # 随机生成一个行程ID
fake_trip = models.DBTrip(
    trip_id=fake_trip_id,
    user_id="test_user_001"
)

# 2. 给这个行程塞两个假景点 (Places)
fake_place1 = models.DBPlace(
    place_id="p001", 
    name="大英博物馆", 
    latitude=51.5194, 
    longitude=-0.1269, 
    visit_duration_minutes=120,
    trip_id=fake_trip_id
)

fake_place2 = models.DBPlace(
    place_id="p002", 
    name="伦敦眼", 
    latitude=51.5033, 
    longitude=-0.1195, 
    visit_duration_minutes=60,
    trip_id=fake_trip_id
)

# 3. 把假数据扔进数据库并保存
db.add(fake_trip)
db.add(fake_place1)
db.add(fake_place2)
db.commit()

print(f"✅ 假数据造好了！请让前端请求这个 trip_id: {fake_trip_id}")

# 关紧水龙头
db.close()
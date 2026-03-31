from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship
from database import Base
import datetime


class DBUser(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, unique=True, index=True, nullable=False)
    email = Column(String, unique=True, index=True, nullable=False)
    display_name = Column(String, nullable=False)
    password_hash = Column(String, nullable=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class DBTrip(Base):
    __tablename__ = "trips"

    id = Column(Integer, primary_key=True, index=True)
    trip_id = Column(String, unique=True, index=True)
    user_id = Column(String)
    title = Column(String)
    total_available_time = Column(Integer)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    # 一对多关系：一个行程有多个地点
    places = relationship("DBPlace", back_populates="trip")


class DBPlace(Base):
    __tablename__ = "places"

    id = Column(Integer, primary_key=True, index=True)
    place_id = Column(String)
    name = Column(String)
    latitude = Column(Float)
    longitude = Column(Float)
    visit_duration_minutes = Column(Integer)

    # 外键：关联到 trips 表的 trip_id
    trip_id = Column(String, ForeignKey("trips.trip_id"))
    trip = relationship("DBTrip", back_populates="places")
import os
import requests
from dotenv import load_dotenv

# 1. 打开“保险箱”，加载 .env 文件中的环境变量
load_dotenv()

# 2. 安全地获取你的 API Key
API_KEY = os.getenv("GOOGLE_MAPS_API_KEY")

def test_google_maps_api():
    # 我们拿伦敦的两个著名景点做测试
    origin = "British Museum, London"
    destination = "London Eye, London"

    # 这是 Google Maps 计算距离和时间的专属接口 (Distance Matrix API)
    url = "https://maps.googleapis.com/maps/api/distancematrix/json"

    # 告诉 Google 我们要查什么
    params = {
        "origins": origin,
        "destinations": destination,
        "mode": "walking",  # 我们假设用户步行
        "key": API_KEY      # 亮出你的通行证
    }

    print(f"正在向 Google 请求从 '{origin}' 到 '{destination}' 的数据...\n")

    # 发送请求并接收数据
    response = requests.get(url, params=params)
    data = response.json()

    # 解析 Google 返回的结果
    if data.get("status") == "OK":
        element = data["rows"][0]["elements"][0]
        if element.get("status") == "OK":
            distance = element["distance"]["text"]
            duration = element["duration"]["text"]
            print("✅ 恭喜！API 连通成功！")
            print(f"🚶 步行距离: {distance}")
            print(f"⏱️ 预计时间: {duration}")
            print("\n这就是我们接下来算 TSP 算法需要的基础数据！")
        else:
            print(f"❌ 路线计算失败，可能是不支持步行，状态码: {element.get('status')}")
    else:
        print(f"❌ API 调用失败！状态码: {data.get('status')}")
        if "error_message" in data:
            print(f"详情: {data['error_message']}")

if __name__ == "__main__":
    if not API_KEY:
        print("⚠️ 找不到 API Key，请检查你的 .env 文件！")
    else:
        test_google_maps_api()
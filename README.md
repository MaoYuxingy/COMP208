# NavIA - 多重约束的旅行规划与导航应用

NavIA 是一款原生的 iOS 旅行规划与导航 App。它由 Python FastAPI 后端支持，并包含一个专门处理多重约束（如营业时间、距离）的路线规划引擎。

## 🛠 技术栈
* **前端 (Frontend):** iOS 原生开发 (Swift, SwiftUI, ARKit)
* **后端 (Backend):** Python (FastAPI)
* **数据库 (Database):** MySQL (云端) & Core Data (本地离线缓存)
* **外部接口 (External APIs):** Google Maps SDK (用于距离计算和地点搜索)

## 🚀 快速启动 (本地环境搭建)

请前端和后端的同学都按照以下步骤，把后端的本地服务器跑起来：

**1. 克隆代码到本地电脑：**
```bash
git clone [https://github.com/MaoYuxingy/COMP208.git](https://github.com/MaoYuxingy/COMP208.git)
cd NavIA_Backend
2. 安装所需的 Python 依赖包：

Bash
pip install -r requirements.txt
3. 配置安全密钥 (⚠️非常重要！)：

在项目文件夹下，手动新建一个名叫 .env 的文件。(警告：绝对不要把这个文件提交到 GitHub！)

打开文件，把我在微信群里发的那串 Google Maps API Key 贴进去，格式严格如下：

Plaintext
GOOGLE_MAPS_API_KEY=群里发的这串密钥
4. 启动本地服务器：

Bash
uvicorn main:app --reload
启动成功后，在浏览器打开 API 接口文档进行测试：http://127.0.0.1:8000/docs
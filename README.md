# COMP208

# NavIA - 多重约束的旅行规划与导航应用

[cite_start]NavIA 是一款原生的 iOS 旅行规划与导航 App。它由 Python FastAPI 后端支持，并包含一个专门处理多重约束（如营业时间、距离）的路线规划引擎 [cite: 202-205, 213]。

## 🛠 技术栈
* [cite_start]**前端 (Frontend):** iOS 原生开发 (Swift, SwiftUI, ARKit) [cite: 233]
* [cite_start]**后端 (Backend):** Python (FastAPI) [cite: 234]
* [cite_start]**数据库 (Database):** MySQL (云端) & Core Data (本地离线缓存) [cite: 235]
* [cite_start]**外部接口 (External APIs):** Google Maps SDK (用于距离计算和地点搜索) [cite: 240]

## 🚀 快速启动 (后端跑通指南)

请前端和后端的同学都按照以下步骤，把后端的本地服务器跑起来：

**1. 克隆代码到本地电脑：**
```bash
git clone <这里填你们的GitHub仓库链接>
cd NavIA-Project/Backend

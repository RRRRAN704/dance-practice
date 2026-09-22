# Tech Stack

## 项目定位

Dance Practice Platform（扒舞练习平台）

目标：

* 解决舞蹈练习与扒舞场景中的痛点
* 提供专业的视频练习工具
* 支持未来商业化扩展
* 支持 App Store 发布
* 作为个人作品集项目展示

---

# Architecture

采用：

```text
SwiftUI
    ↓
Spring Boot REST API
    ↓
PostgreSQL
```

整体架构：

```text
┌─────────────────┐
│   iOS App       │
│    SwiftUI      │
└────────┬────────┘
         │
         │ HTTPS
         │ REST API
         ▼
┌─────────────────┐
│  Spring Boot    │
│   Backend       │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  PostgreSQL     │
└─────────────────┘
```

---

# Frontend

## Framework

SwiftUI

原因：

* 原生 iOS 开发
* 支持 iPhone
* 支持 iPad
* 与苹果视频框架集成度高
* 适合实现高级视频功能

---

## Video Framework

AVFoundation

主要负责：

* 视频播放
* 倍速控制
* 视频镜面
* A-B循环
* 视频缩略图生成
* 双视频同步播放

---

## Local Storage

本地存储：

* 视频文件
* 视频缩略图缓存
* 游客模式数据
* 用户缓存数据

设计原则：

```text
Local First
```

优先保证视频播放性能。

---

# Backend

## Framework

Spring Boot

原因：

* 当前最熟悉技术栈
* 与求职方向一致
* 便于展示后端能力
* 便于后期扩展

---

## API Style

RESTful API

主要模块：

* Authentication
* User
* Practice Room
* Statistics
* Sync

---

## Authentication

JWT

功能：

* 登录
* 注册
* Token认证
* 用户身份管理

---

# Database

## Database

PostgreSQL

原因：

* 英国企业使用广泛
* SaaS / FinTech / LegalTech 常见
* 简历价值较高
* 适合长期扩展

---

## 存储内容

云端存储：

* 用户信息
* 练习室信息
* A-B循环片段
* 播放器设置
* 练习记录
* 统计数据

不存储：

* 原始视频文件

---

# Deployment

## Container

Docker

目标：

* 本地开发环境统一
* 后续部署方便
* 增加项目工程化程度

---

# MVP Version

第一阶段目标：

## User

* 注册
* 登录
* 游客模式

---

## Practice Room

* 创建练习室
* 编辑练习室
* 删除练习室

---

## Video Player

* 视频播放
* 视频暂停
* 速度控制（Slider）
* 镜面模式
* A-B循环

---

## Timeline

核心特色功能：

Frame-based Thumbnail Timeline

功能：

* 自动生成视频缩略图
* 进度条显示视频关键帧
* 快速定位动作位置
* 支持拖动跳转

灵感来源：

Apple Photos 视频编辑时间轴

---

# Future Features

## Statistics

* 每日练习时长
* 每周练习时长
* 连续练习天数
* 舞种统计

---

## Video Comparison

双屏对比模式：

```text
原视频 | 用户视频
```

支持同步播放。

---

## Cloud Sync

支持多设备同步：

* 用户数据
* 练习记录
* 播放器设置

---

## Community

后续版本考虑：

* 发帖
* 评论
* 点赞
* 收藏
* 关注
* 分享

不属于 MVP 范围。

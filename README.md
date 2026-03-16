## Project Overview

**NETRA** is an AI-powered navigation and vision assistant built for visually impaired individuals. It combines real-time **obstacle detection**, **monocular depth estimation**, and **voice-guided navigation**.

A custom-trained **YOLOv11s** model detects critical objects — pedestrians, vehicles, crosswalks, stairs, guide blocks, and traffic signals while **Depth Anything V2** estimates their distance from the user. A **FastAPI** inference server processes detections and communicates with a **Flutter** mobileapp, delivering real-time audio alerts and turn-by-turn directions via **OpenStreetMap**.

The app is built with accessibility at its core, leveraging Android's built-in**TalkBack** feature to deliver audio feedback.Unlike existing tools that handle either navigation or detection isolation, NETRA unifies both into one accessible platform.

---

## System Architecture

NETRA follows a **client–server architecture**. The Flutter mobile app captures
camera frames and sends them to a FastAPI inference server, which runs object
detection and depth estimation and returns results as audio guidance to the user.

**Core Components:**

| Component | Role |
|-----------|------|
| **Mobile App** (Flutter) | Captures camera frames, handles user input, delivers audio feedback via TalkBack |
| **Inference Server** (FastAPI) | Receives frames and runs AI inference |
| **Object Detection** (YOLOv11s) | Detects obstacles, crosswalks, signals, and other navigation-critical objects |
| **Depth Estimation** (Depth Anything V2) | Estimates distance of detected objects from the user |

![System Architecture](docs/images/system_block_diagram.png)

---

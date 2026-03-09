# Nub-Bill

> **Real-time Visual Bill-Splitting Tool for Groups**
> *Simplify group travel expenses with automated debt clearing and slip verification.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Supabase](https://img.shields.io/badge/Supabase-Realtime-green?logo=supabase)](https://supabase.com)
[![ElysiaJS](https://img.shields.io/badge/ElysiaJS-Bun-purple?logo=bun)](https://elysiajs.com)
[![License](https://img.shields.io/badge/License-MIT-green)](./LICENSE)
[![Status](https://img.shields.io/badge/Status-In%20Development-orange)]()

## 🎥 Demo Video

[![Demo Video](https://img.youtube.com/vi/X9-zET5074U/maxresdefault.jpg)](https://youtu.be/X9-zET5074U)

> คลิกที่รูปด้านบนเพื่อดูวิดีโอสาธิตการใช้งานบน YouTube

---

## Introduction

**Nub-Bill** (หรือ "นับบิล") เกิดขึ้นเพื่อแก้ปัญหาความซับซ้อนทางการเงินเมื่อออกทริปเป็นกลุ่ม (Group Travel) ซึ่งมักมีผู้สำรองจ่ายหลายคน และตัวหารในแต่ละรายการไม่เท่ากัน (เช่น ค่าเดินทางหารเฉพาะคนนั่งรถ, ค่าอาหารหารเฉพาะคนกิน) การใช้ Spreadsheet แบบเดิมมีความยุ่งยากในการกรอกข้อมูล และเมื่อจบทริปมักเกิดความสับสนในการเคลียร์หนี้ อีกทั้งยังขาดระบบตรวจสอบสลิปการโอนเงินที่น่าเชื่อถือ

แอปพลิเคชันนี้มุ่งเน้นกลุ่มเป้าหมายคือ **กลุ่มเพื่อนที่ไปเที่ยวต่างจังหวัด** ที่มีการแชร์ค่าใช้จ่ายซับซ้อน (มีคนขับรถ, มีคนจองที่พัก, มีคนซื้อของกองกลาง) โดยเน้นประสบการณ์การใช้งานแบบ Real-time ร่วมกัน

## Features

### MVP Features (Core Functionality)
- [ ] **Smart Expense Recording:** บันทึกรายการจ่ายเงินระบุ "คนจ่าย" และ "คนหาร" ได้อย่างอิสระ
- [ ] **Sub-Group Management:** แก้ปัญหาค่าเดินทาง/น้ำมัน โดยการตั้ง Group ย่อย (เช่น กลุ่มรถคันที่ 1, กลุ่มรถคันที่ 2) เลือกหารเฉพาะกลุ่มได้ในคลิกเดียว
- [ ] **Auto Debt Simplification:** คำนวณยอดสุทธิอัตโนมัติ หักลบกลบหนี้ระหว่างกันเพื่อลดจำนวน Transaction การโอนให้เหลือน้อยที่สุด
- [ ] **PromptPay QR & Slip Verification:** (Highlight Feature) ระบบสร้าง QR Code รับเงินและตรวจสอบสลิป
- [ ] **Negative Balance Support:** รองรับยอดเงินติดลบสำหรับกรณีได้รับเงินคืน (Cashback/Refund) เพื่อหักลบกับค่าใช้จ่ายรวมได้อย่างถูกต้อง
- [ ] **Quick Invite:** เชิญเพื่อนเข้าทริปผ่าน QR Code หรือ Deep Link โดยไม่ต้องค้นหา Username
- [ ] **Visual Summary:** สร้างรูปภาพสรุปยอดหนี้สินของแต่ละคน เพื่อส่งเข้า LINE/Messenger ได้ทันที

### Nice-to-have Features (Future Roadmap)

---

## 📱 Screenshots

### Core Features in Action

| | |
|:---:|:---:|
| ![Smart Expense Recording](docs/screenshots/1000014700.jpg) | ![Sub-Group Management](docs/screenshots/1000014702.jpg) |
| **Smart Expense Recording** — บันทึกรายการ ระบุผู้จ่ายและผู้หาร | **Sub-Group Management** — จัดการกลุ่มย่อย หารเฉพาะกลุ่มได้ |
| ![Auto Debt Simplification](docs/screenshots/1000014704.jpg) | ![PromptPay QR Generation](docs/screenshots/1000014706.jpg) |
| **Auto Debt Simplification** — คำนวณยอดสุทธิ หักลบกลบหนี้อัตโนมัติ | **Trip & Member Overview** — ภาพรวมทริปและสมาชิก |
| ![Slip Verification](docs/screenshots/1000014708.jpg) | ![Sub-Group Management](docs/screenshots/Screenshot%202026-03-10%20001238.png) |
| **Deep Link / QR Trip Invitation** — ชวนเพื่อนด้วย QR หรือ Deep Link | **PromptPay QR Generation** — สร้าง QR Code รับเงิน + **Slip Verification** — ตรวจสอบสลิปโอนเงินผ่าน Thunder Solution |

---

### Nice-to-have Features (Future Roadmap)
- [ ] **AI Receipt Scanning (OCR):** ใช้ Google ML Kit สแกนใบเสร็จยาวๆ แปลงเป็นรายการ Digital
- [ ] **Real-time Activity Log:** Audit Log แสดงความเคลื่อนไหวทันทีที่มีการเพิ่ม/ลบ/แก้ไข รายการ
- [ ] **Ghost Member Support:** สร้างสมาชิกสมมติสำหรับเพื่อนที่ไม่ได้โหลดแอปฯ
- [ ] **Spending Analytics:** Dashboard กราฟสรุปพฤติกรรมการใช้จ่ายของทริป (Pie Chart/Ranking)
- [ ] **Smart Debt Visualization:** Node Graph แสดงเส้นทางการไหลของเงิน

---

## Technical Architecture & Implementation

สถาปัตยกรรมของระบบถูกออกแบบให้รองรับการทำงานแบบ **Real-time Synchronization** และมีความปลอดภัยสูงในการตรวจสอบธุรกรรมการเงิน โดยแบ่งส่วนการทำงานดังนี้:

### 1. Backend-as-a-Service (Supabase)
ทำหน้าที่เป็นศูนย์กลางข้อมูลของระบบ (Centralized Data Store) เพื่อให้สมาชิกในทริปเห็นข้อมูลตรงกันทันที
* **Database:** ใช้ PostgreSQL ในการจัดเก็บความสัมพันธ์ระหว่าง Users, Trips, Expenses และ Settlements พร้อม Row Level Security (RLS) ทุก Table
* **Real-time Engine:** ใช้ Supabase Realtime (Postgres Changes) เพื่อ Sync รายการค่าใช้จ่าย, สถานะการชำระเงิน และ Notifications ผ่าน Websocket ไปยังสมาชิกทุกคนทันที
* **Object Storage:** จัดเก็บรูปภาพสลิปโอนเงินอย่างปลอดภัยด้วย Storage Policies
* **Auth:** Supabase Auth (OTP ผ่าน Email)

### 2. Secure Custom API (ElysiaJS on Bun)
ทำหน้าที่เป็น **Secure Gateway** สำหรับ Business Logic ที่ต้องติดต่อกับ Third-party Services
* **Slip Verification Proxy:** ระบบใช้ ElysiaJS เป็นตัวกลางรับ Transaction Reference จากแอปพลิเคชัน และตรวจสอบกับ **Thunder Solution API**
    * *เหตุผลทางเทคนิค:* ซ่อน API Key (Server-to-Server) ไม่ให้รั่วไหลสู่ฝั่ง Client
    * Settlement Token ถูกสร้างและตรวจสอบด้วย HMAC-SHA256 พร้อม TTL 30 นาที เพื่อป้องกัน Replay Attack
* **Debt Simplification:** คำนวณยอดหนี้สุทธิและลด Transaction ให้น้อยที่สุดด้วย `debtService` (Greedy Algorithm)
* **PromptPay QR Generation:** สร้าง QR Payload ตามมาตรฐาน EMVCo (Tag 30) บน Server โดยคำนวณ CRC16-CCITT และแปลง Proxy ID (เบอร์โทร/บัตรประชาชน)
* **Rate Limiting:** ป้องกัน Abuse ด้วย Upstash Redis (Sliding Window: 100 req/60s)
* **API Documentation:** มี Swagger UI (`/swagger`) สำหรับ API Explorer
* **Deployment:** Railway (primary worker) / Vercel (serverless fallback)

### 3. Push Notifications (FCM)
* **Firebase Admin SDK** (Backend) ส่ง Push Notification ผ่าน FCM ไปยังอุปกรณ์ของสมาชิกเมื่อมีกิจกรรมสำคัญ (เช่น เพื่อนเพิ่มค่าใช้จ่าย, สลิปได้รับการยืนยัน)
* **Firebase Cloud Messaging** (Flutter) รับ notification ขณะแอปอยู่ Background/Foreground ผ่าน `firebase_messaging`
* **Notification Push Listener** ทำงานเป็น Background Worker บน Railway เพื่อ poll และส่ง FCM ได้ตลอดเวลา

### 4. Client-side Processing (Flutter)
* **PromptPay QR Parsing:** `promptpay_parser.dart` แยก Proxy ID และยอดเงินจาก QR Payload ฝั่ง Client เพื่อแสดง Confirmation UI ก่อนโอน
* **Realtime Subscriptions:** `realtime_service.dart` จัดการ Supabase Channel subscriptions สำหรับ Expenses, Splits, Settlements และ Notifications
* **Deep Linking:** รองรับ App Link (`app_links`) สำหรับ Quick Invite เข้าทริป

---

## Tech Stack

### Frontend (Mobile Application)
| Category | Library / Tool |
|---|---|
| Framework | Flutter (Dart SDK ^3.10.1) |
| State Management | [Riverpod](https://riverpod.dev) (`flutter_riverpod ^2.5.1`) + `flutter_hooks` |
| Navigation | [go_router](https://pub.dev/packages/go_router) `^13.2.0` |
| Backend Client | `supabase_flutter ^2.8.3` (Auth + Realtime + DB + Storage) |
| Push Notifications | `firebase_messaging ^15.1.3` + `flutter_local_notifications ^18.0.1` |
| QR Code | `qr_flutter ^4.1.0` (generate) + `mobile_scanner ^7.0.0` (scan) |
| Barcode / ML | `google_mlkit_barcode_scanning ^0.12.0` |
| Deep Linking | `app_links ^6.3.3` |
| Sharing / Gallery | `share_plus ^10.0.0` + `gal ^2.3.2` |
| HTTP Client | `http ^1.6.0` |
| Code Generation | `freezed ^2.4.7` + `json_serializable ^6.7.1` |
| Local Storage | `shared_preferences ^2.2.2` |
| Fonts | LINESeedSansTH + `google_fonts ^6.1.0` |

### Backend & Infrastructure
* **Core Backend (BaaS):** [Supabase](https://supabase.com)
    * PostgreSQL (Database) with Row Level Security (RLS)
    * Supabase Realtime (Websocket — Postgres Changes)
    * Supabase Storage (Object Storage)
    * Supabase Auth (Email OTP)
* **Custom API Service:** [ElysiaJS](https://elysiajs.com) `^1.4.22` (Running on [Bun](https://bun.sh))
    * TypeScript `^5.9.3`
    * CORS (`@elysiajs/cors`) + Swagger (`@elysiajs/swagger`)
    * Rate Limiting: Upstash Redis (`@upstash/ratelimit ^2.0.8`) — Sliding Window
    * Push Notifications: Firebase Admin SDK (`firebase-admin ^13.7.0`)
    * Deployed on: **Railway** (primary always-on worker) / **Vercel** (serverless)

### External Services
* **Slip Verification:** Thunder Solution API (Server-to-Server, key hidden in backend)
* **Push Notifications:** Firebase Cloud Messaging (FCM)

---

## Non-functional Requirements
* **Data Consistency:** ข้อมูลยอดเงินต้องตรงกันทุกเครื่องแบบ Real-time (Eventual Consistency via Websocket).
* **Precision:** การคำนวณทศนิยม 2 ตำแหน่งมีความแม่นยำสูง (Double-entry principle).
* **Security:** API Keys ของ Third-party ต้องไม่ถูกฝังใน Source Code ของแอปพลิเคชัน

# Raonson Backend Architecture

## Overview
Raonson is a full Instagram-like social network backend built with Node.js
and deployed on Render.

The system follows:
- Layered architecture
- Service-driven logic
- Stateless REST API
- Forward-only development

## Layers

### 1. Routes
HTTP endpoints.
Responsible only for:
- URL structure
- Middleware chaining
- Calling controllers

### 2. Controllers
Request/response orchestration.
Responsibilities:
- Input extraction
- Permission validation
- Calling services
- Returning formatted responses

### 3. Services
Business logic layer.
Responsibilities:
- Core rules (follow, like, feed)
- Transactions
- Notifications triggers
- Data aggregation

### 4. Models
MongoDB schemas via Mongoose.
Each domain has its own model.

### 5. Middlewares
Cross-cutting concerns:
- Auth (JWT)
- Rate limiting
- Validation
- File uploads

### 6. Sockets
Real-time features:
- Chat messages
- Presence
- Notifications

### 7. Queues & Jobs
Background processing:
- Notifications
- Media processing
- Story expiration
- Stats calculation

### 8. Security
Protection layer:
- Anti-spam
- Anti-abuse
- IP blocking

## Data Flow Example (Post Like)

Client → Route → Auth Middleware → Controller  
→ Service → Model → Notification Queue  
→ Socket emit → Client update

## Scalability
- Stateless API
- Ready for Redis cache
- Horizontal scaling on Render
- Future microservice split possible

## Compliance
- Instagram-style UX logic
- Feed ranking ready
- Story 24h expiration
- Private accounts support

## Status
This backend is **NOT MVP**.
It is a **full production-grade social network backend**
designed for national-scale usage.

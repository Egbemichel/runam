# RunAm – On-Demand Errand & Runner Platform

RunAm is a location-based, on-demand errand platform that connects buyers who need tasks done with nearby runners in real time. The system focuses on speed, trust, and seamless payments, delivering a premium experience through smart backend orchestration and a smooth mobile UI.

---

## 🚀 Features

### Core Functionality
- Create errands with **multiple tasks**, each having its own price
- Support for **one-way** and **round-trip** errands
- Real-time **runner discovery** based on proximity and trust score
- Sequential runner request flow (15s per runner)
- Dynamic pricing based on **distance + task value**
- Escrow-based payment handling for cash and online payments
- Image uploads for errands (optional)
- Persistent errand drafts (recoverable on app restart)

### User Roles
- **Buyer**: creates and tracks errands
- **Runner**: receives and accepts nearby errands

---

## 🧱 Architecture Overview

RunAm follows a **client–server architecture** with a clear separation of concerns:

### Frontend
- **Flutter**
- State management with **GetX**
- Modular feature-based folder structure
- GraphQL for all network communication

### Backend
- **Django**
- **Graphene (GraphQL)**
- PostgreSQL database
- Token-based authentication
- Business logic enforced server-side

### Communication
- GraphQL queries & mutations
- File uploads handled via multipart GraphQL requests

---

## 🔁 Errand Request Flow

1. Buyer submits a new errand
2. System fetches nearby runners and ranks them by:
   - Distance
   - Trust score
3. Runners are notified **one at a time** (15 seconds each)
4. On acceptance:
   - Distance is calculated
   - Final price is computed
5. Payment handling:
   - **Cash + Round-trip** → Service fee paid to escrow
   - **Online payment** → Full amount paid to escrow
6. Both buyer and runner transition to the **errand ongoing** screen

---

## 💰 Pricing & Service Fees

- Task prices are defined by the buyer
- Distance-based cost is added dynamically
- Service fee formula:
  ```python
  service_fee = int(errand_value * 0.2)

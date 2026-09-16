# Backend API Requirement Document

**Project:** de luxex ERP Platform  
**Client / Company:** Deluxex Lighting & Living Ltd.  
**Document Version:** 1.0.0  
**Target Audience:** Backend Developers, API Engineers, Database Architects  

---

## Table of Contents
1. [Project Overview](#1-project-overview)
   - [1.1 Project Purpose](#11-project-purpose)
   - [1.2 Main Modules & Features](#12-main-modules--features)
   - [1.3 User Types & System Roles](#13-user-types--system-roles)
2. [Global Architecture & API Conventions](#2-global-architecture--api-conventions)
   - [2.1 Base URLs & Protocols](#21-base-urls--protocols)
   - [2.2 Standard Request & Response Structure](#22-standard-request--response-structure)
   - [2.3 Error Handling & Status Codes](#23-error-handling--status-codes)
   - [2.4 Role-Based Access Control (RBAC) Specification](#24-role-based-access-control-rbac-specification)
   - [2.5 Pragmatic Schema & API Design Principles](#25-pragmatic-schema--api-design-principles)
3. [Authentication & Security APIs](#3-authentication--security-apis)
   - [3.1 Login & Token Generation](#31-login--token-generation)
   - [3.2 Refresh JWT Token](#32-refresh-jwt-token)
   - [3.3 Get Current User Profile](#33-get-current-user-profile)
   - [3.4 Supervisor Password Verification & Temporary Access Override](#34-supervisor-password-verification--temporary-access-override)
   - [3.5 Security Audit Trail Logs](#35-security-audit-trail-logs)
   - [3.6 Revoke Temporary Access Override](#36-revoke-temporary-access-override)
4. [User & Role Management (RBAC) Module](#4-user--role-management-rbac-module)
   - [4.1 List Users](#41-list-users)
   - [4.2 Create User](#42-create-user)
   - [4.3 Update User](#43-update-user)
   - [4.4 Toggle User Active Status](#44-toggle-user-active-status)
   - [4.5 Reset User Password](#45-reset-user-password)
   - [4.6 List Roles & Permission Matrix](#46-list-roles--permission-matrix)
   - [4.7 Create Role](#47-create-role)
   - [4.8 Update Role](#48-update-role)
5. [Dashboard & Analytics Module](#5-dashboard--analytics-module)
   - [5.1 Executive Unified Dashboard Overview](#51-executive-unified-dashboard-overview)
   - [5.2 Role-Specific Dashboard Metrics](#52-role-specific-dashboard-metrics)
6. [Inventory & Warehouse Management Module](#6-inventory--warehouse-management-module)
   - [6.1 Get Raw Materials Stock](#61-get-raw-materials-stock)
   - [6.2 Get Finished Products Stock](#62-get-finished-products-stock)
   - [6.3 Stock Movement Ledger (Audit Log)](#63-stock-movement-ledger-audit-log)
   - [6.4 Perform Stock Adjustment](#64-perform-stock-adjustment)
   - [6.5 Trigger Low Stock WhatsApp Alert](#65-trigger-low-stock-whatsapp-alert)
   - [6.6 Get Low Stock Alert History](#66-get-low-stock-alert-history)
   - [6.7 Resolve Low Stock Alert](#67-resolve-low-stock-alert)
7. [Purchase & Procurement Management Module](#7-purchase--procurement-management-module)
   - [7.1 List Purchase Orders / Inward Bills](#71-list-purchase-orders--inward-bills)
   - [7.2 Create Purchase Order / Inward Bill](#72-create-purchase-order--inward-bill)
   - [7.3 Get Purchase Details](#73-get-purchase-details)
   - [7.4 Update Purchase Status](#74-update-purchase-status)
8. [Production & Manufacturing Module](#8-production--manufacturing-module)
   - [8.1 List Production Work Orders](#81-list-production-work-orders)
   - [8.2 Create Production Work Order](#82-create-production-work-order)
   - [8.3 Complete Work Order (BOM Consumption & Stock Inward)](#83-complete-work-order-bom-consumption--stock-inward)
   - [8.4 Cancel / Soft Delete Work Order](#84-cancel--soft-delete-work-order)
9. [Sales & Commercial Lifecycle Module](#9-sales--commercial-lifecycle-module)
   - [9.1 Quotations (Create, List, Update, Status, Revisions)](#91-quotations-lifecycle)
   - [9.2 Proforma Invoices (Create from Quotation, Advance Receipts)](#92-proforma-invoices)
   - [9.3 Sales Orders (Create with Auto-Stock Reservation & Shortage Detection)](#93-sales-orders)
   - [9.4 Delivery Challans & Dispatch (Physical Stock Deduction)](#94-delivery-challans--dispatch)
   - [9.5 Tax Invoices & Direct Counter Sales](#95-tax-invoices--direct-counter-sales)
   - [9.6 Sales Returns & RMA (Inspection, Restock/Damaged, Refund/Credit)](#96-sales-returns--refunds)
10. [Architectural Projects & Portfolio Module](#10-architectural-projects--portfolio-module)
    - [10.1 List Projects](#101-list-projects)
    - [10.2 Create Project](#102-create-project)
    - [10.3 Update Project](#103-update-project)
    - [10.4 Get Project Financials & Material Consumption](#104-get-project-financials--material-consumption)
11. [Payments, Ledgers & Expenses Module](#11-payments-ledgers--expenses-module)
    - [11.1 List Payments & Receipts](#111-list-payments--receipts)
    - [11.2 Record Payment Voucher](#112-record-payment-voucher)
    - [11.3 List Architect Commissions](#113-list-architect-commissions)
    - [11.4 Approve Commission](#114-approve-commission)
    - [11.5 Disburse / Pay Commission](#115-disburse--pay-commission)
    - [11.6 Reject Commission](#116-reject-commission)
    - [11.7 Expense Vouchers (CRUD)](#117-expense-vouchers-crud)
12. [Master Data Registry Module](#12-master-data-registry-module)
    - [12.1 Customers Master (CRUD)](#121-customers-master)
    - [12.2 Vendors Master (CRUD + Soft Delete)](#122-vendors-master)
    - [12.3 Dealers Master (CRUD)](#123-dealers-master)
    - [12.4 Architects Master (CRUD)](#124-architects-master)
    - [12.5 Raw Material Catalog (CRUD)](#125-raw-material-catalog)
    - [12.6 Finished Products SKUs (CRUD)](#126-finished-products-skus)
    - [12.7 Categories & Measurement Units (CRUD)](#127-categories--measurement-units)
    - [12.8 Link Architect and Customer Dual Identity](#128-link-architect-and-customer-dual-identity)
13. [Reports & Business Intelligence Module](#13-reports--business-intelligence-module)
    - [13.1 Query Report Registers (8 Core Statements)](#131-query-report-registers)
14. [Document OCR, WhatsApp & System Settings Module](#14-document-ocr-whatsapp--system-settings-module)
    - [14.1 Vision OCR Multi-format Document Data Extraction](#141-vision-ocr-multi-format-document-data-extraction)
    - [14.2 WhatsApp Message Dispatch & Communication Log](#142-whatsapp-message-dispatch--communication-log)
    - [14.3 WhatsApp Alert Recipients (CRUD)](#143-whatsapp-alert-recipients-crud)
    - [14.4 System Company Preferences](#144-system-company-preferences)

---

## 1. Project Overview

### 1.1 Project Purpose
**de luxex ERP** is an enterprise-grade ERP system tailored for **Deluxex Lighting & Living Ltd.**, a high-end architectural and luxury lighting manufacturing company. The system manages the operational and financial lifecycles of customized and batch lighting production:
- Multi-tier supply chain and raw material procurement
- Factory shopfloor assembly, BOM consumption, and batch unit costing
- Real-time stock tracking for raw materials and finished goods with immutable stock ledgers
- Sales lifecycle: Quotations (revisions), Proforma Invoices, Sales Orders (auto-reservation and shortage production triggers), Delivery Challans (dispatch with stock deduction), Tax Invoices (GST-compliant), Direct Counter Sales, and Sales Returns (QA inspection, restock/damage classification, and refund processing)
- Commercial architectural projects portfolio and architect commission payout lifecycle
- Accounts receivables, vendor payables, multi-mode payment vouchers, and operational expense logs
- AI-powered document OCR data extraction and WhatsApp communication/alert automation
- Granular Role-Based Access Control (RBAC) supporting 10 modules $\times$ 9 actions, supervisor password overrides, and security audit trails

---

### 1.2 Main Modules & Features

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                   DE LUXEX ERP PLATFORM                                 │
├────────────────────────────────┬────────────────────────────────────────────────────────┤
│ 1. Authentication & RBAC       │ Login, JWT tokens, Role Matrices, Supervisor Overrides │
│ 2. Dashboards & Analytics      │ Unified Executive Dashboard & 8 Role-Specific Hubs     │
│ 3. Inventory Management        │ Raw Materials, Finished Goods, Ledgers, Adjustments    │
│ 4. Purchase & Procurement      │ POs, Inward Receipts, Vendor Invoices, Payment Status  │
│ 5. Production & Manufacturing  │ Work Orders, BOM Consumption, Yields, Unit Costing     │
│ 6. Sales & Commercial Flow     │ Quotations -> Proforma -> Orders -> Dispatch -> Invoices│
│ 7. Sales Returns & Refunds     │ Inspections, Restock vs Damaged, Credit Notes, Refunds │
│ 8. Project Portfolio           │ Architectural Sites, Milestones, Budget Consumption    │
│ 9. Payments & Finance          │ Receipts, Disbursements, Commissions, Expense Vouchers │
│ 10. Master Data Registry       │ Clients, Dealers, Architects, Vendors, SKUs, Units     │
│ 11. Reports & Intelligence     │ 8 Detailed Financial, Tax (GST), and Operational Audits│
│ 12. OCR & Integrations         │ Vision Document Parser, WhatsApp Alert Dispatcher      │
└────────────────────────────────┴────────────────────────────────────────────────────────┘
```

---

### 1.3 User Types & System Roles

| Role Key | Role Name | Primary Scope & Default Landing |
| :--- | :--- | :--- |
| `admin` | **System Administrator** | Universal unrestricted access across all modules, configuration, and security matrices. Default: `/dashboard` |
| `inventory_manager` | **Inventory Manager** | Warehouse stock tracking, raw materials, finished products, stock ledger, stock adjustments. Default: `/inventory` |
| `purchase_manager` | **Purchase Manager** | Vendor management, raw material & finished goods procurement, PO creation, inward goods. Default: `/purchase` |
| `production_manager`| **Production Manager** | Factory shopfloor work orders, raw material consumption tracking, assembly costing. Default: `/production` |
| `sales_manager` | **Sales Manager** | Quotations, proforma invoices, sales orders, deliveries, tax invoices, sales returns. Default: `/sales` |
| `accounts_manager` | **Accounts / Finance** | Customer receivables, dealer ledgers, vendor settlements, expense vouchers, commission payouts. Default: `/payments` |
| `project_manager` | **Project Manager** | Architectural projects portfolio, site delivery tracking, material budget consumption. Default: `/projects` |
| `masters_manager` | **Master Data Manager** | Centralized management of Customers, Vendors, Dealers, Architects, SKUs, Categories, and Units. Default: `/masters` |
| `report_viewer` | **Auditor / Report Viewer**| Read-only access across analytical registers, GST reports, audit trails, and financial statements. Default: `/reports` |
| `data_entry` | **Data Entry Operator** | Fast voucher creation (Quotations, Orders, Invoices, Masters) without delete or supervisor approval rights. Default: `/sales` |

---

## 2. Global Architecture & API Conventions

### 2.1 Base URLs & Protocols
- **Protocol:** HTTPS only
- **Base URL:** `https://api.deluxex.com/api/v1`
- **Data Format:** `application/json` (UTF-8) except for file uploads (`multipart/form-data`)
- **Date/Time Standard:** ISO 8601 extended format with UTC offset (e.g. `2026-09-11T14:30:00.000Z`)
- **Currency Standard:** Indian Rupee (`₹` / `INR`) with precision of 2 decimal places.

---

### 2.2 Standard Request & Response Structure

#### Standard Success Response
```json
{
  "success": true,
  "message": "Operation completed successfully",
  "data": {},
  "timestamp": "2026-09-11T14:30:00.000Z"
}
```

#### Standard Paginated Response
```json
{
  "success": true,
  "data": {
    "items": [],
    "pagination": {
      "totalItems": 150,
      "totalPages": 6,
      "currentPage": 1,
      "limit": 25,
      "hasNextPage": true,
      "hasPrevPage": false
    }
  },
  "timestamp": "2026-09-11T14:30:00.000Z"
}
```

#### Standard Error Response
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_FAILED",
    "message": "The return quantity cannot exceed available invoiced balance.",
    "details": [
      {
        "field": "returnItems[0].quantity",
        "issue": "Requested quantity 5.0 exceeds max returnable 2.0"
      }
    ]
  },
  "timestamp": "2026-09-11T14:30:00.000Z"
}
```

---

### 2.3 Error Handling & Status Codes

| HTTP Status | Meaning | Typical Usage in ERP |
| :--- | :--- | :--- |
| `200 OK` | Request succeeded | Standard GET, PUT, PATCH responses |
| `201 Created` | Resource created | Successful creation of PO, SO, Quotation, Master, Invoice |
| `400 Bad Request` | Validation failure | Malformed JSON, missing required fields, quantity exceeds limit |
| `401 Unauthorized` | Auth failed | Missing token, expired JWT, invalid login credentials |
| `403 Forbidden` | Access denied | User lacks permission in RBAC matrix and no supervisor override exists |
| `404 Not Found` | Entity not found | Invalid document ID or SKU ID |
| `409 Conflict` | State conflict | Duplicate invoice number, already processed return, superseded doc |
| `422 Unprocessable`| Business logic fail | Insufficient raw materials for work order completion |
| `500 Server Error` | Backend failure | Unhandled exceptions, database connection failures |

---

### 2.4 Role-Based Access Control (RBAC) Specification

The system specifies a strict modular permission matrix evaluated for every incoming request:

**Supported Modules (`ErpModule`):**
1. `dashboard`
2. `inventory`
3. `purchase`
4. `production`
5. `sales`
6. `payments`
7. `masters`
8. `reports`
9. `settings`
10. `userManagement`

**Supported Actions (`ErpAction`):**
`view`, `create`, `edit`, `delete`, `approve`, `cancel`, `export`, `print`, `share`.

**Resolution Hierarchy:**
1. If `user.primaryRoleId == 'admin'`, allow immediately.
2. Check if an active unexpired **TemporaryAccessGrant** exists for `(user.id, targetModule, targetAction)`.
3. Check `user.customPermissionOverrides`.
4. Check `user.primaryRole.permissions`.
5. Check `user.assignedRoleIds` (secondary roles).
6. If no match is found, reject with `403 Forbidden` and log the denial in `AuditLog`.

---

### 2.5 Pragmatic Schema & API Design Principles (Anti-Overkill & Anti-Bloat)

To maintain an optimal balance between architectural purity, query performance, and codebase simplicity, all database schemas and APIs must strictly adhere to the following principles:

1. **Anti-Overkill Normalization (Avoid Micro-Table Explosion)**:
   - **Do NOT decompose natural entity attributes into separate 1-to-1 or trivial lookup tables.** For example, vendor contacts, addresses, payment terms, and credit limits must reside directly as typed columns within the `vendors` table rather than spanning across 4 micro-tables (`vendor_addresses`, `vendor_contacts`, `vendor_payment_terms`, `vendor_credit_limits`).
   - Only create separate relational child tables when true 1-to-many business collections exist (such as line items in `purchase_items`, `quotation_items`, or audit transactions in `stock_transactions`).
   - Use structured, validated JSONB columns where flexible, document-style structures are natural (e.g. `before_snapshot`, `after_snapshot` in `audit_logs`, custom document metadata) instead of creating endless generic EAV (Entity-Attribute-Value) tables.

2. **Anti-Bloat Architecture (Avoid Monolithic God-Tables)**:
   - Do NOT merge unrelated operational domains into a generic "all-in-one" transaction table. Keep distinct domain entities in their own dedicated tables (`purchases`, `quotations`, `sales_orders`, `tax_invoices`, `stock_adjustments`).
   - Keep parent header data and child line item data cleanly separated into standard parent-child relational pairs (e.g., `sales_orders` and `sales_order_items`).

3. **Continuous Prefixed Document Sequences (Q-07 & Q-08 Closed)**:
   - All operational document sequences (`PUR-2026-0046`, `INV-2026-0089`, `QT-2026-0105`, `SO-2026-0072`, `DC-2026-0034`, `WO-2026-0018`, `PAY-2026-0091`) must maintain a continuous sequential number format.
   - **Sequences do NOT reset every Financial Year (1 April – 31 March).** The numbering continues indefinitely, incrementing monotonically to avoid broken audit trails and document collisions.

4. **Item Code Reuse on Soft Delete (Q-06 Closed)**:
   - When master entities (such as raw materials with item code `RM-1001` or vendors with code `VND-005`) are soft-deleted (`is_deleted = true`), the code may be reassigned to a new future entity.
   - All unique code constraints in PostgreSQL must be defined as partial unique indexes:
     ```sql
     CREATE UNIQUE INDEX uq_raw_materials__item_code ON raw_materials(item_code) WHERE is_deleted = false;
     CREATE UNIQUE INDEX uq_finished_products__item_code ON finished_products(item_code) WHERE is_deleted = false;
     ```

5. **Soft Warning on Credit Limit Exceedance (Q-13 Closed)**:
   - In commercial sales and purchase operations, exceeding a customer or vendor credit limit must **NOT** result in a hard blocking error (such as HTTP 422).
   - Instead, the backend must emit an advisory warning in the response envelope (`meta.warning: "Credit limit exceeded for this party"`) and record the warning in the audit log, allowing authorized personnel to proceed without halting manufacturing operations.

6. **Nullable HSN/SAC Codes (Q-23 Closed)**:
   - All inventory items (`raw_materials` and `finished_products`) support a nullable `hsn_sac_code TEXT NULL` column to accommodate non-standardized or locally sourced materials before tax filing.

7. **Fixed-Precision Decimal Transport (ADR-011)**:
   - Monetary figures and tax amounts must never be transmitted or processed as IEEE floating-point numbers (`double`). Currency must be fixed at 2 decimal places (`numeric(18,2)` / string format `"12500.50"`), and stock quantities must be fixed at 4 decimal places (`numeric(18,4)` / string format `"45.1250"`).

8. **Scope Boundary Enforcement (ADR-013 & ADR-014)**:
   - Single dedicated client instance for Blazon Creative LLP, Gujarat (`state_code: 24`).
   - Every stock transaction is anchored to a valid `stock_location_id`.

---

## 3. Authentication & Security APIs

### 3.1 Login & Token Generation

### API: User Login

**Method:** `POST`

**Endpoint:**
`/api/v1/auth/login`

**Purpose:**
Authenticates an ERP user using their Work Email, Username, or 10-digit Mobile Number and password. Returns access and refresh JWT tokens, user metadata, and effective permission matrix.

**Headers:**
```text
Content-Type: application/json
```

**Request Body:**
```json
{
  "identifier": "admin@deluxex.com",
  "password": "admin123",
  "roleId": "admin"
}
```

**Required Fields:**
- `identifier` (String: Email, Username, or 10-digit Mobile)
- `password` (String: Min 6 characters)

**Optional Fields:**
- `roleId` (String: Optional role verification guard)

**Validation:**
- `identifier` cannot be empty.
- `password` cannot be empty.
- User status must be active (`isActive: true`).

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Authentication successful",
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "refreshToken": "dGhpcy1pcy1hLXJlZnJlc2gtdG9rZW4...",
    "expiresIn": 86400,
    "user": {
      "id": "USR-001",
      "name": "Alex Sterling",
      "email": "admin@deluxex.com",
      "mobile": "+91 98765 00001",
      "primaryRoleId": "admin",
      "primaryRoleName": "System Administrator",
      "assignedRoleIds": [],
      "defaultDashboardSection": "dashboard",
      "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
      "lastLoginAt": "2026-09-11T19:12:00.000Z"
    },
    "effectivePermissions": {
      "dashboard": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "inventory": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "purchase": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "production": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "sales": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "payments": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "masters": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "reports": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "settings": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"],
      "userManagement": ["view", "create", "edit", "delete", "approve", "cancel", "export", "print", "share"]
    }
  }
}
```

**Error Responses:**
- `400 Bad Request`: Missing identifier or password.
- `401 Unauthorized`: Invalid credentials or password mismatch.
- `403 Forbidden`: User account is deactivated.

---

### 3.2 Refresh JWT Token

### API: Refresh Access Token

**Method:** `POST`

**Endpoint:**
`/api/v1/auth/refresh-token`

**Purpose:**
Provides a refreshed JWT access token before expiration without forcing user re-authentication.

**Headers:**
```text
Content-Type: application/json
```

**Request Body:**
```json
{
  "refreshToken": "dGhpcy1pcy1hLXJlZnJlc2gtdG9rZW4..."
}
```

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiresIn": 86400
  }
}
```

---

### 3.3 Get Current User Profile

### API: Get Logged-in User Profile

**Method:** `GET`

**Endpoint:**
`/api/v1/auth/me`

**Purpose:**
Returns the currently authenticated user's session, assigned roles, overrides, and active temporary grants.

**Headers:**
```text
Authorization: Bearer <token>
```

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "USR-002",
      "name": "Rohan Varma",
      "email": "inventory@deluxex.com",
      "mobile": "+91 98765 00002",
      "primaryRoleId": "inventory_manager",
      "assignedRoleIds": ["purchase_manager"],
      "isActive": true,
      "avatarUrl": "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150"
    },
    "activeTemporaryGrants": []
  }
}
```

---

### 3.4 Supervisor Password Verification & Temporary Access Override

### API: Request Supervisor Override Grant

**Method:** `POST`

**Endpoint:**
`/api/v1/auth/supervisor-override`

**Purpose:**
Validates a supervisor/manager password on the server to dynamically grant temporary elevated permission for a restricted module or action. Creates an audit trail log entry.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "supervisorPassword": "admin123",
  "targetModule": "sales",
  "targetAction": "approve",
  "durationMinutes": 30,
  "isSessionOnly": false,
  "reason": "Emergency customer price approval"
}
```

**Required Fields:**
- `supervisorPassword` (String)
- `targetModule` (String: `dashboard`, `inventory`, `purchase`, `production`, `sales`, `payments`, `masters`, `reports`, `settings`, `userManagement`)

**Optional Fields:**
- `targetAction` (String: `view`, `create`, `edit`, `delete`, `approve`, `cancel`, `export`, `print`, `share`)
- `durationMinutes` (Integer: Default `30`, Range: `5` to `480`)
- `isSessionOnly` (Boolean: Default `false`)
- `reason` (String)

**Validation:**
- Password must belong to an active user holding `admin` role or having valid authorization rights for `(targetModule, targetAction)`.

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Temporary access override authorized by Alex Sterling (System Administrator)",
  "data": {
    "grantId": "TAG-8942110",
    "module": "sales",
    "action": "approve",
    "grantedToUserId": "USR-009",
    "grantedByUserId": "USR-001",
    "grantedByName": "Alex Sterling (System Administrator)",
    "grantedAt": "2026-09-11T19:30:00.000Z",
    "expiresAt": "2026-09-11T20:00:00.000Z",
    "isSessionOnly": false
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid supervisor password.
- `403 Forbidden`: Authenticated supervisor lacks authorization privileges for this action.

---

### 3.5 Security Audit Trail Logs

### API: Get Security Audit Logs

**Method:** `GET`

**Endpoint:**
`/api/v1/auth/audit-logs`

**Purpose:**
Retrieves security audit entries documenting system access attempts, rejections, and supervisor overrides.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `page` (Integer: Default `1`)
- `limit` (Integer: Default `25`)
- `search` (String: Filter by user name, role, authorizer, notes)
- `status` (String: `ALL`, `ALLOWED`, `DENIED`, `OVERRIDE`)
- `module` (String: Module filter)
- `startDate` (ISO8601 Date)
- `endDate` (ISO8601 Date)

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "AUD-9948210",
        "userId": "USR-009",
        "userName": "Karan Singhania",
        "userRole": "Data Entry Operator",
        "module": "sales",
        "action": "approve",
        "sectionName": "Sales Order Approval",
        "timestamp": "2026-09-11T19:30:00.000Z",
        "status": "temporaryGranted",
        "authorizingUserId": "USR-001",
        "authorizingUserName": "Alex Sterling",
        "durationMinutes": 30,
        "notes": "Temporary 30-minute access authorized by Alex Sterling"
      }
    ],
    "pagination": {
      "totalItems": 142,
      "totalPages": 6,
      "currentPage": 1,
      "limit": 25
    }
  }
}
```

---

### 3.6 Revoke Temporary Access Override

### API: Revoke Temporary Access Grant

**Method:** `DELETE`

**Endpoint:**
`/api/v1/auth/temporary-grants/:grantId`

**Purpose:**
Instantly invalidates an active temporary supervisor override. Pass `:grantId` as `all` to revoke all active overrides system-wide.

**Headers:**
```text
Authorization: Bearer <token>
```

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "message": "Temporary access override grant revoked successfully"
}
```

---

## 4. User & Role Management (RBAC) Module

### 4.1 List Users

### API: List Users Directory

**Method:** `GET`

**Endpoint:**
`/api/v1/users`

**Purpose:**
Fetches all ERP user accounts, assigned primary and secondary roles, account statuses, and activity metrics.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `search` (String: Search by name, email, or mobile)
- `roleId` (String)
- `isActive` (Boolean)
- `page` (Integer), `limit` (Integer)

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "USR-001",
        "name": "Alex Sterling",
        "email": "admin@deluxex.com",
        "mobile": "+91 98765 00001",
        "primaryRoleId": "admin",
        "primaryRoleName": "System Administrator",
        "assignedRoleIds": [],
        "isActive": true,
        "avatarUrl": "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150",
        "lastLoginAt": "2026-09-11T19:12:00.000Z",
        "createdAt": "2026-05-14T10:00:00.000Z"
      }
    ],
    "pagination": { "totalItems": 10, "currentPage": 1, "totalPages": 1, "limit": 50 }
  }
}
```

---

### 4.2 Create User

### API: Create New User

**Method:** `POST`

**Endpoint:**
`/api/v1/users`

**Purpose:**
Registers a new user account in the ERP system, hashing password securely with salt and setting role permissions.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Karan Singhania",
  "email": "karan@deluxex.com",
  "mobile": "+91 98200 11223",
  "password": "SecurePassword123!",
  "primaryRoleId": "sales_manager",
  "assignedRoleIds": ["inventory_manager"],
  "isActive": true,
  "customPermissionOverrides": {
    "reports": ["view", "export"]
  }
}
```

**Required Fields:** `name`, `email`, `mobile`, `password`, `primaryRoleId`

**Validation:**
- `email` must be valid and unique in the database.
- `mobile` must be valid 10 digits with country code.
- `password` must be minimum 6 characters.

**Success Response (`201 Created`):**
```json
{
  "success": true,
  "message": "User account created successfully",
  "data": {
    "id": "USR-011",
    "name": "Karan Singhania",
    "email": "karan@deluxex.com",
    "primaryRoleId": "sales_manager",
    "isActive": true,
    "createdAt": "2026-09-11T19:35:00.000Z"
  }
}
```

---

### 4.3 Update User

### API: Update User Profile & Roles

**Method:** `PUT`

**Endpoint:**
`/api/v1/users/:userId`

**Purpose:**
Updates user personal details, primary role, secondary roles, and custom permission overrides.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Karan Singhania",
  "email": "karan@deluxex.com",
  "mobile": "+91 98200 11223",
  "primaryRoleId": "sales_manager",
  "assignedRoleIds": ["inventory_manager", "purchase_manager"],
  "isActive": true
}
```

---

### 4.4 Toggle User Active Status

### API: Toggle User Active Status

**Method:** `PATCH`

**Endpoint:**
`/api/v1/users/:userId/status`

**Purpose:**
Deactivates or reactivates a user account. Deactivated users are blocked from logging in.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "isActive": false
}
```

---

### 4.5 Reset User Password

### API: Reset User Password (Admin / Manager)

**Method:** `POST`

**Endpoint:**
`/api/v1/users/:userId/reset-password`

**Purpose:**
Resets a user's password directly from the User Management console.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "newPassword": "NewSecurePass2026#"
}
```

---

### 4.6 List Roles & Permission Matrix

### API: Get All Roles & Permission Matrices

**Method:** `GET`

**Endpoint:**
`/api/v1/roles`

**Purpose:**
Returns all default system roles and custom-created roles along with their complete granular permission matrices.

**Headers:**
```text
Authorization: Bearer <token>
```

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": [
    {
      "id": "sales_manager",
      "name": "Sales Manager",
      "description": "Sales lifecycle: Quotations, Sales Orders, Tax Invoices, Deliveries",
      "isSystemRole": true,
      "isActive": true,
      "defaultDashboardSection": "salesDashboard",
      "assignedUserCount": 2,
      "permissions": {
        "dashboard": ["view"],
        "sales": ["view", "create", "edit", "approve", "cancel", "print", "share", "export"],
        "masters": ["view", "create", "edit", "print", "export"],
        "payments": ["view"],
        "reports": ["view", "export", "print"]
      }
    }
  ]
}
```

---

### 4.7 Create Role

### API: Create Custom Role

**Method:** `POST`

**Endpoint:**
`/api/v1/roles`

**Purpose:**
Creates a custom ERP role with a tailored $10 \times 9$ permission matrix and default landing dashboard.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "name": "Regional Sales Executive",
  "description": "Quotation creation and delivery inspection for western zone",
  "defaultDashboardSection": "salesDashboard",
  "isActive": true,
  "permissions": {
    "dashboard": ["view"],
    "sales": ["view", "create", "edit", "print", "share"],
    "masters": ["view"],
    "reports": ["view"]
  }
}
```

---

### 4.8 Update Role

### API: Update Role & Permissions

**Method:** `PUT`

**Endpoint:**
`/api/v1/roles/:roleId`

**Purpose:**
Updates title, description, landing section, active status, or permission matrix of an existing role.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:** Same schema as Create Role.

---

## 5. Dashboard & Analytics Module

### 5.1 Executive Unified Dashboard Overview

### API: Get Main Dashboard Overview

**Method:** `GET`

**Endpoint:**
`/api/v1/dashboard/overview`

**Purpose:**
Calculates and returns all high-level operational KPIs, stock valuation metrics, chart series datasets, and the recent activity ledger for the executive dashboard.

**Headers:**
```text
Authorization: Bearer <token>
```

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "kpis": {
      "totalSales": 1248750.00,
      "totalPurchases": 324800.00,
      "rawMaterialStockValuation": 842500.00,
      "finishedProductStockValuation": 1575200.00,
      "totalStockValuation": 2417700.00,
      "todaySales": 124500.00,
      "todaySalesGrowthPercent": 14.2,
      "customerReceivablesDue": 245000.00,
      "vendorPayablesDue": 120000.00,
      "pendingArchitectCommissions": 35000.00,
      "lowStockItemCount": 18
    },
    "charts": {
      "stockValuationTrend": {
        "labels": ["May", "Jun", "Jul", "Aug", "Sep", "Oct"],
        "valuesInLakhs": [14.2, 15.8, 18.4, 17.6, 21.2, 24.1]
      },
      "stockInVsStockOut": {
        "labels": ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"],
        "stockIn": [24, 32, 18, 42, 28, 15],
        "stockOut": [16, 22, 14, 30, 20, 10]
      },
      "stockByWarehouse": [
        { "name": "Main Central Warehouse", "percentage": 45, "valuation": 1080000.00 },
        { "name": "Finished Goods Showroom", "percentage": 30, "valuation": 720000.00 },
        { "name": "Raw Assembly Floor", "percentage": 15, "valuation": 360000.00 },
        { "name": "Transit / Staging Yard", "percentage": 10, "valuation": 240000.00 }
      ]
    },
    "recentActivityLedger": [
      {
        "id": "MOV-001",
        "date": "2026-09-11T14:30:00.000Z",
        "activity": "STOCK IN (PURCHASE)",
        "reference": "PO-2026-0104",
        "type": "Raw Material",
        "itemName": "6063 Aluminum Extrusion Profile 2.5m",
        "quantity": 150.0,
        "unit": "MTR",
        "user": "Vikram Mehta"
      }
    ]
  }
}
```

---

### 5.2 Role-Specific Dashboard Metrics

### API: Get Role Dashboard Metrics

**Method:** `GET`

**Endpoint:**
`/api/v1/dashboard/role-metrics`

**Purpose:**
Returns specific dashboard summaries for specialized roles (`inventory`, `purchase`, `production`, `sales`, `accounts`, `project`, `masters`, `report_viewer`, `data_entry`).

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `role` (String: `inventory_manager`, `purchase_manager`, `production_manager`, `sales_manager`, `accounts_manager`, `project_manager`, `masters_manager`)

**Success Response (`200 OK`):** Returns role-targeted metrics, quick actions, and filtered tables.

---

## 6. Inventory & Warehouse Management Module

### 6.1 Get Raw Materials Stock

### API: Get Raw Materials Inventory

**Method:** `GET`

**Endpoint:**
`/api/v1/inventory/raw-materials`

**Purpose:**
Retrieves all raw material inventory records, current on-hand balances, minimum buffers, reorder thresholds, and valuations.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `search` (String: Name, item code)
- `categoryId` (String)
- `isLowStock` (Boolean)
- `page` (Integer), `limit` (Integer)

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalItems": 42,
      "totalValuation": 842500.00,
      "lowStockCount": 5
    },
    "items": [
      {
        "id": "RM-001",
        "name": "6063 Architectural Aluminum Extrusion Profile 2.5m",
        "itemCode": "RAW-ALU-001",
        "categoryId": "CAT-001",
        "categoryName": "Profiles & Extrusions",
        "unit": "MTR",
        "openingStock": 300.0,
        "currentStock": 420.0,
        "minimumStock": 100.0,
        "reorderLevel": 150.0,
        "defaultPurchasePrice": 480.00,
        "gstPercent": 18.0,
        "totalValuation": 201600.00,
        "isLowStock": false,
        "preferredVendorNames": ["Apex Aluminum Extrusions Ltd"]
      }
    ],
    "pagination": { "totalItems": 42, "currentPage": 1, "totalPages": 1, "limit": 50 }
  }
}
```

---

### 6.2 Get Finished Products Stock

### API: Get Finished Goods Inventory

**Method:** `GET`

**Endpoint:**
`/api/v1/inventory/finished-products`

**Purpose:**
Retrieves stock levels for finished lighting products, including manufactured and purchased items, reserved stock for active Sales Orders, and unallocated available stock.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `search` (String)
- `categoryId` (String)
- `isLowStock` (Boolean)
- `page` (Integer), `limit` (Integer)

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "summary": {
      "totalSkus": 38,
      "totalStockValuation": 1575200.00,
      "totalReservedStock": 45.0,
      "lowStockCount": 3
    },
    "items": [
      {
        "id": "FP-001",
        "name": "Aarix Axis Architectural Wall Light (Matte Black)",
        "itemCode": "DLX-WL-001",
        "categoryId": "CAT-002",
        "categoryName": "Wall Fixtures",
        "unit": "PCS",
        "currentStock": 28.0,
        "reservedStock": 10.0,
        "availableStock": 18.0,
        "purchasedStock": 0.0,
        "producedStock": 28.0,
        "openingStock": 15.0,
        "minimumStock": 10.0,
        "costPrice": 2450.00,
        "dealerSellingPrice": 4200.00,
        "customerSellingPrice": 4800.00,
        "gstPercent": 18.0,
        "totalValuation": 68600.00,
        "isLowStock": false
      }
    ]
  }
}
```

---

### 6.3 Stock Movement Ledger (Audit Log)

### API: Get Immutable Stock Ledger

**Method:** `GET`

**Endpoint:**
`/api/v1/inventory/stock-movements`

**Purpose:**
Provides an immutable ledger record of all inward/outward inventory movements. **Core Rule:** Physical inventory is never altered without generating an entry in this ledger.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `itemId` (String)
- `itemType` (`rawMaterial` | `finishedProduct`)
- `transactionType` (`purchase`, `productionConsumption`, `productionOutput`, `sale`, `saleReturn`, `purchaseReturn`, `damage`, `adjustment`)
- `startDate`, `endDate` (ISO8601)
- `search` (Reference document, SKU, user)
- `page` (Integer), `limit` (Integer)

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "MOV-001",
        "date": "2026-09-11T14:30:00.000Z",
        "itemId": "FP-001",
        "itemName": "Aarix Axis Architectural Wall Light",
        "itemCode": "DLX-WL-001",
        "itemType": "finishedProduct",
        "transactionType": "sale",
        "referenceNumber": "DLZ/DLV/2026/0042",
        "stockIn": 0.0,
        "stockOut": 4.0,
        "currentBalance": 28.0,
        "unit": "PCS",
        "notes": "Dispatched for Sales Order DLZ/SO/2026/0074 (Vehicle: MH-04-AZ-8812)",
        "performedBy": "Alex Sterling"
      }
    ],
    "pagination": { "totalItems": 350, "currentPage": 1, "totalPages": 14, "limit": 25 }
  }
}
```

---

### 6.4 Perform Stock Adjustment

### API: Create Stock Adjustment

**Method:** `POST`

**Endpoint:**
`/api/v1/inventory/stock-adjustments`

**Purpose:**
Reconciles physical inventory variances (damages, count mismatch, loss, theft), updating the item's current stock and creating an immutable ledger transaction.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "itemId": "RM-001",
  "itemType": "rawMaterial",
  "adjustedStockAfter": 415.0,
  "reason": "damagedGoods",
  "remarks": "5 meters damaged during forklift relocation in Bay 3"
}
```

**Required Fields:** `itemId`, `itemType`, `adjustedStockAfter`, `reason`

**Enum `reason` Values:**
`physicalCountMismatch`, `damagedGoods`, `expiry`, `theftOrLoss`, `internalConsumption`, `revaluation`, `other`.

**Backend Business Logic:**
1. Fetch item current balance ($420.0$).
2. Compute `adjustmentQuantity = adjustedStockAfter - currentBalance` ($415.0 - 420.0 = -5.0$).
3. Update item `currentStock = 415.0`.
4. Insert into `StockMovement` ledger with type `adjustment`.
5. Return generated `StockAdjustment` record.

---

### 6.5 Trigger Low Stock WhatsApp Alert

### API: Trigger WhatsApp Low Stock Alert

**Method:** `POST`

**Endpoint:**
`/api/v1/inventory/trigger-low-stock-alert`

**Purpose:**
Broadcasts a critical low stock notification via WhatsApp Business API to registered warehouse recipients.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "itemId": "RM-003",
  "recipientId": "REC-001",
  "customMessage": "Raw Material Tridonic Constant Current LED Driver 40W is critically low (45 PCS). Reorder level: 80 PCS."
}
```

---

### 6.6 Get Low Stock Alert History

### API: Get Low Stock Alert Logs

**Method:** `GET`

**Endpoint:**
`/api/v1/inventory/low-stock-alerts`

**Purpose:**
Returns the log of all low stock alerts triggered, delivery statuses, recipients, and resolution timestamps.

**Headers:**
```text
Authorization: Bearer <token>
```

---

### 6.7 Resolve Low Stock Alert

### API: Mark Alert as Resolved

**Method:** `PATCH`

**Endpoint:**
`/api/v1/inventory/low-stock-alerts/:alertId/resolve`

**Purpose:**
Marks a low stock alert record as resolved after procurement has replenished stock.

**Headers:**
```text
Authorization: Bearer <token>
```

---

## 7. Purchase & Procurement Management Module

### 7.1 List Purchase Orders / Inward Bills

### API: List Purchases

**Method:** `GET`

**Endpoint:**
`/api/v1/purchases`

**Purpose:**
Lists all procurement orders, vendor bills, tax breakdowns, and settlement statuses.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `status` (`draft`, `saved`, `partialPaid`, `paid`, `cancelled`)
- `purchaseType` (`rawMaterial`, `finishedProduct`)
- `vendorId` (String)
- `startDate`, `endDate` (ISO8601)
- `search` (PO number, vendor invoice number)

---

### 7.2 Create Purchase Order / Inward Bill

### API: Create Purchase Inward Bill

**Method:** `POST`

**Endpoint:**
`/api/v1/purchases`

**Purpose:**
Generates a new purchase order or inward bill. Increases inventory stock, posts ledger transactions, updates vendor outstanding balance, and optionally records initial payment.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "vendorId": "VEN-001",
  "vendorName": "Apex Aluminum Extrusions Ltd",
  "vendorInvoiceNumber": "APEX/2026/912",
  "purchaseDate": "2026-09-11T00:00:00.000Z",
  "invoiceDate": "2026-09-10T00:00:00.000Z",
  "purchaseType": "rawMaterial",
  "projectId": "PRJ-001",
  "projectName": "Sky City Tower C Luxury Penthouses",
  "items": [
    {
      "itemType": "rawMaterial",
      "rawMaterialId": "RM-001",
      "rawMaterialName": "6063 Architectural Aluminum Extrusion Profile 2.5m",
      "rawMaterialCode": "RAW-ALU-001",
      "quantity": 100.0,
      "unit": "MTR",
      "rate": 480.00,
      "discountAmount": 1000.00,
      "gstPercent": 18.0,
      "taxableAmount": 47000.00,
      "cgstAmount": 4230.00,
      "sgstAmount": 4230.00,
      "igstAmount": 0.00,
      "lineTotal": 55460.00
    }
  ],
  "subtotalAmount": 48000.00,
  "discountAmount": 1000.00,
  "taxableAmount": 47000.00,
  "cgstAmount": 4230.00,
  "sgstAmount": 4230.00,
  "igstAmount": 0.00,
  "gstAmount": 8460.00,
  "totalAmount": 55460.00,
  "paidAmount": 20000.00,
  "pendingAmount": 35460.00,
  "paymentMode": "bankTransfer",
  "status": "partialPaid",
  "notes": "Delivered to Unit 2 Assembly Floor",
  "attachmentUrl": "https://storage.deluxex.com/bills/apex_inv_912.pdf"
}
```

**Backend Business Logic:**
1. Generate sequence document number (e.g. `PO-2026-0105`).
2. If `status != 'draft'`:
   - If `purchaseType == 'rawMaterial'`, update each `rawMaterial.currentStock += quantity` and insert `StockMovement` (`purchase`).
   - If `purchaseType == 'finishedProduct'`, update `finishedProduct.currentStock += quantity`, `finishedProduct.purchasedStock += quantity`, and insert `StockMovement`.
3. Increase `vendor.outstandingBalance += pendingAmount`.
4. If `paidAmount > 0`, insert receipt into `ErpPayment` ledger (`vendorPayment`).

---

### 7.3 Get Purchase Details

### API: Get Purchase Details by ID

**Method:** `GET`

**Endpoint:**
`/api/v1/purchases/:purchaseId`

**Purpose:**
Returns the complete purchase record, items, linked payment vouchers, and document attachment.

**Headers:**
```text
Authorization: Bearer <token>
```

---

### 7.4 Update Purchase Status

### API: Update Purchase Order Status

**Method:** `PATCH`

**Endpoint:**
`/api/v1/purchases/:purchaseId/status`

**Purpose:**
Updates PO workflow status (`draft` $\rightarrow$ `saved` $\rightarrow$ `cancelled`).

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "status": "cancelled",
  "reason": "Supplier unable to meet delivery lead time"
}
```

---

## 8. Production & Manufacturing Module

### 8.1 List Production Work Orders

### API: List Production Orders

**Method:** `GET`

**Endpoint:**
`/api/v1/production/orders`

**Purpose:**
Retrieves factory work orders, target output quantities, Bill of Materials consumption, batch costs, and schedule status.

**Headers:**
```text
Authorization: Bearer <token>
```

**Query Parameters:**
- `status` (`planned`, `inProgress`, `completed`, `cancelled`)
- `salesOrderId` (String)
- `finishedProductId` (String)
- `page` (Integer), `limit` (Integer)

---

### 8.2 Create Production Work Order

### API: Create Production Order

**Method:** `POST`

**Endpoint:**
`/api/v1/production/orders`

**Purpose:**
Creates a shopfloor production work order for a batch of finished products.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "finishedProductId": "FP-001",
  "finishedProductName": "Aarix Axis Architectural Wall Light",
  "finishedProductCode": "DLX-WL-001",
  "unit": "PCS",
  "plannedQuantity": 20.0,
  "productionDate": "2026-09-15T00:00:00.000Z",
  "status": "planned",
  "salesOrderId": "SALE-003",
  "salesOrderNumber": "DLZ/SO/2026/0075",
  "projectId": "PRJ-001",
  "projectName": "Sky City Tower C Luxury Penthouses",
  "notes": "Custom matte black powder coating specification"
}
```

---

### 8.3 Complete Work Order (BOM Consumption & Stock Inward)

### API: Complete Production Work Order

**Method:** `POST`

**Endpoint:**
`/api/v1/production/orders/:orderId/complete`

**Purpose:**
Finalizes a manufacturing batch:
1. Consumes and deducts raw materials from inventory.
2. Inwards finished products into available inventory.
3. Allocates produced goods to any linked Sales Order reservation shortage.
4. Calculates total batch cost and unit cost.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "actualQuantityProduced": 20.0,
  "rawMaterialsUsed": [
    {
      "rawMaterialId": "RM-001",
      "rawMaterialName": "6063 Architectural Aluminum Extrusion Profile 2.5m",
      "rawMaterialCode": "RAW-ALU-001",
      "quantityUsed": 30.0,
      "unit": "MTR",
      "unitCost": 480.00,
      "totalCost": 14400.00
    },
    {
      "rawMaterialId": "RM-003",
      "rawMaterialName": "Tridonic Constant Current LED Driver 40W",
      "rawMaterialCode": "RAW-DRV-40W",
      "quantityUsed": 20.0,
      "unit": "PCS",
      "unitCost": 850.00,
      "totalCost": 17000.00
    }
  ],
  "rawMaterialCost": 31400.00,
  "labourCost": 6000.00,
  "otherExpenses": 2600.00,
  "totalProductionCost": 40000.00,
  "costPerUnit": 2000.00,
  "notes": "Batch QA passed: 100% luminous flux compliance"
}
```

**Backend Business Logic:**
1. Deduct each `rawMaterial.currentStock -= quantityUsed` and log `StockMovement` (`productionConsumption`).
2. Add `finishedProduct.currentStock += actualQuantityProduced`, `finishedProduct.producedStock += actualQuantityProduced` and log `StockMovement` (`productionOutput`).
3. If linked to `salesOrderId`:
   - Update `soItem.producedQuantity` and `soItem.reservedQuantity`.
   - Update `finishedProduct.reservedStock += actualQuantityProduced`.
   - If all order items are reserved, advance Sales Order status to `readyForDispatch`.
4. Update Production Order status to `completed`.

---

### 8.4 Cancel / Soft Delete Work Order

### API: Cancel Work Order

**Method:** `DELETE`

**Endpoint:**
`/api/v1/production/orders/:orderId`

**Purpose:**
Cancels or soft-deletes a planned work order.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "reason": "Customer cancelled custom pendant order"
}
```

---

## 9. Sales & Commercial Lifecycle Module

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           SALES LIFECYCLE WORKFLOW                              │
│                                                                                 │
│   [Quotation]  ───────>  [Proforma Invoice]  ───────>  [Sales Order]            │
│   (Zero Stock)           (Advance Payment)             (Stock Auto-Reservation) │
│                                                               │                 │
│                                                               ▼                 │
│   [Tax Invoice] <───────  [Direct Sale]     <───────  [Delivery Challan]        │
│   (GST Ledger)           (Counter Sale)               (Physical Stock Deducted) │
│         │                                                                       │
│         ▼                                                                       │
│   [Sales Return] ───> [QA: Restock vs Damaged] ───> [Refund / Store Credit]     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

### 9.1 Quotations Lifecycle

#### API: Create Quotation
**Method:** `POST`
**Endpoint:** `/api/v1/sales/quotations`
**Purpose:** Creates a formal price estimate. **Crucial Rule:** Quotations have **zero** impact on inventory stock or customer ledgers.
**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```
**Request Body:**
```json
{
  "partyType": "customer",
  "partyId": "CUST-001",
  "partyName": "Oberoi Sky City Residences",
  "customerContactPerson": "Mr. Rahul Oberoi",
  "customerMobile": "+91 98210 11223",
  "customerEmail": "procurement@oberoiskycity.com",
  "customerGstNumber": "27AABCO8892K1Z9",
  "billingAddress": "Oberoi Sky City, Western Express Hwy, Borivali East, Mumbai",
  "shippingAddress": "Tower C Site Stores, Oberoi Sky City, Mumbai",
  "projectId": "PRJ-001",
  "projectName": "Sky City Tower C Luxury Penthouses",
  "architectId": "ARCH-001",
  "architectName": "Ar. Sanjay Puri",
  "salesExecutive": "Alex Sterling",
  "saleDate": "2026-09-11T00:00:00.000Z",
  "validUntil": "2026-10-11T00:00:00.000Z",
  "isInterStateTax": false,
  "items": [
    {
      "finishedProductId": "FP-001",
      "finishedProductName": "Aarix Axis Architectural Wall Light (Matte Black)",
      "finishedProductCode": "DLX-WL-001",
      "productDescription": "IP65 Architectural Grade 3000K Warm White",
      "quantity": 20.0,
      "unit": "PCS",
      "rate": 4800.00,
      "discountAmount": 4000.00,
      "gstPercent": 18.0,
      "taxableAmount": 92000.00,
      "cgstAmount": 8280.00,
      "sgstAmount": 8280.00,
      "igstAmount": 0.00,
      "lineTotal": 108560.00
    }
  ],
  "subtotalAmount": 96000.00,
  "discountAmount": 4000.00,
  "taxableAmount": 92000.00,
  "cgstAmount": 8280.00,
  "sgstAmount": 8280.00,
  "igstAmount": 0.00,
  "gstAmount": 16560.00,
  "totalAmount": 108560.00,
  "termsAndConditions": "50% advance along with PO, balance prior to dispatch.",
  "notes": "Finish RAL 9005 Fine Texture"
}
```

#### API: Create Quotation Revision
**Method:** `POST`
**Endpoint:** `/api/v1/sales/quotations/:quotationId/revisions`
**Purpose:** Creates a new revision (e.g. `DLZ/QT/2026/0103-R2`), marking the parent quotation as `superseded`.

#### API: Update Quotation Status
**Method:** `PATCH`
**Endpoint:** `/api/v1/sales/quotations/:quotationId/status`
**Purpose:** Updates status (`sent`, `accepted`, `approved`, `rejected`, `cancelled`).

---

### 9.2 Proforma Invoices

#### API: Convert Quotation to Proforma Invoice
**Method:** `POST`
**Endpoint:** `/api/v1/sales/quotations/:quotationId/convert-to-proforma`
**Purpose:** Generates a Proforma Invoice from an accepted quotation, setting `proformaStatus = 'issued'`.

#### API: Record Proforma Advance Payment
**Method:** `POST`
**Endpoint:** `/api/v1/sales/proforma/:proformaId/advance-payment`
**Purpose:** Records milestone advance payment against a Proforma Invoice before production/dispatch.

---

### 9.3 Sales Orders

#### API: Create Sales Order (Auto-Reservation & Shortage Handling)
**Method:** `POST`
**Endpoint:** `/api/v1/sales/orders`
**Purpose:** Creates a confirmed Sales Order. Inspects inventory:
1. Reserves available finished product stock (`reservedStock += reservedQty`).
2. If stock is insufficient, calculates `shortage = ordered - available` and automatically generates a linked `ProductionOrder` with status `planned`.
3. Sets order status to `readyForDispatch` (if fully available) or `productionPending` (if shortage exists).

---

### 9.4 Delivery Challans & Dispatch

#### API: Create Delivery Challan (Physical Stock Deduction)
**Method:** `POST`
**Endpoint:** `/api/v1/sales/deliveries`
**Purpose:** Dispatches goods against a Sales Order.
**Crucial Rule:**
1. Deducts physical stock: `finishedProduct.currentStock -= quantity`.
2. Releases reserved stock: `finishedProduct.reservedStock -= quantity`.
3. Inserts official outward `StockMovement` (type `sale`, ref `DLZ/DLV/2026/0043`).
4. Updates Sales Order delivered quantities and status (`partiallyDelivered` / `delivered`).

**Request Body:**
```json
{
  "salesOrderId": "SALE-003",
  "vehicleNumber": "MH-04-AZ-8812",
  "driverContact": "+91 98330 11992",
  "courierName": "Deluzex Dedicated Fleet",
  "trackingNumber": "DLZ-TRK-9902",
  "expectedDeliveryDate": "2026-09-12T00:00:00.000Z",
  "dispatchNotes": "Fragile crystal chandeliers secured with foam braces",
  "deliveryItems": [
    {
      "finishedProductId": "FP-001",
      "quantity": 20.0
    }
  ]
}
```

---

### 9.5 Tax Invoices & Direct Counter Sales

#### API: Generate Tax Invoice from Delivery
**Method:** `POST`
**Endpoint:** `/api/v1/sales/invoices/from-delivery`
**Purpose:** Creates a legal Tax Invoice against delivered quantities:
1. Calculates GST (CGST/SGST or IGST).
2. Posts receivable balance to Customer / Dealer ledger (`outstandingAmount += pendingAmount`).
3. Auto-calculates Architect referral commission (`commission = taxableAmount * architect.defaultCommissionRate / 100`) and registers into `ArchitectCommission` registry.
4. Records payment if initial receipt is provided.

#### API: Create Direct Counter Sale
**Method:** `POST`
**Endpoint:** `/api/v1/sales/direct-sale`
**Purpose:** Point-of-Sale counter transaction executing invoice creation, physical stock deduction, and immediate payment recording in a single atomic transaction.

---

### 9.6 Sales Returns & Refunds

#### API: Create Sales Return (RMA)
**Method:** `POST`
**Endpoint:** `/api/v1/sales/returns`
**Purpose:** Submits a return request against an original Tax Invoice.

#### API: Approve & Process Sales Return
**Method:** `POST`
**Endpoint:** `/api/v1/sales/returns/:returnId/approve`
**Purpose:**
1. **Inventory:** If condition is `resalable` / `goodCondition`, increments `currentStock` and logs `StockMovement` (`saleReturn`). If `damaged` / `scrap`, creates `StockAdjustment` with `damagedGoods` reason without adding to salable stock.
2. **Ledger:** Reduces invoice `pendingAmount` and customer `outstandingAmount`.
3. **Commission:** Reverses previously generated architect commission proportionately.
4. **Project:** Adjusts project total sales turnover.
5. **Refund Status:** If original invoice was paid, sets `refundStatus = 'pending'` with calculated refund amount.

#### API: Disburse Sales Return Refund / Store Credit
**Method:** `POST`
**Endpoint:** `/api/v1/sales/returns/:returnId/refund`
**Purpose:** Disburses refund via Bank/UPI/Cash or issues Customer Store Credit note.

---

## 10. Architectural Projects & Portfolio Module

### 10.1 List Projects
**Method:** `GET` | **Endpoint:** `/api/v1/projects`
**Query Parameters:** `status`, `architectId`, `customerId`, `dealerId`, `page`, `limit`

### 10.2 Create Project
**Method:** `POST` | **Endpoint:** `/api/v1/projects`
**Request Body:**
```json
{
  "name": "Sky City Tower C Luxury Penthouses",
  "customerId": "CUST-001",
  "customerName": "Oberoi Sky City Residences",
  "dealerId": null,
  "architectId": "ARCH-001",
  "architectName": "Ar. Sanjay Puri",
  "startDate": "2026-06-01T00:00:00.000Z",
  "expectedCompletionDate": "2026-12-31T00:00:00.000Z",
  "status": "active",
  "notes": "Custom brushed brass finishes across 4 duplex penthouses"
}
```

### 10.3 Update Project
**Method:** `PUT` | **Endpoint:** `/api/v1/projects/:projectId`

### 10.4 Get Project Financials & Material Consumption
**Method:** `GET` | **Endpoint:** `/api/v1/projects/:projectId/financials`
**Purpose:** Returns project turnover, raw material usage, work order costs, deliveries, and profit margin.

---

## 11. Payments, Ledgers & Expenses Module

### 11.1 List Payments & Receipts
**Method:** `GET` | **Endpoint:** `/api/v1/payments`
**Query Parameters:** `paymentType`, `partyId`, `paymentMode`, `startDate`, `endDate`

### 11.2 Record Payment Voucher
**Method:** `POST` | **Endpoint:** `/api/v1/payments`
**Request Body:**
```json
{
  "paymentType": "customerPayment",
  "partyId": "CUST-001",
  "partyName": "Oberoi Sky City Residences",
  "referenceDocumentId": "SALE-001",
  "referenceDocumentNumber": "INV-2026-0214",
  "amount": 50000.00,
  "paymentMode": "bankTransfer",
  "paymentDate": "2026-09-11T12:00:00.000Z",
  "transactionReference": "NEFT-HDFC-994821",
  "notes": "Milestone 2 payment received",
  "isFullPayment": false
}
```

### 11.3 List Architect Commissions
**Method:** `GET` | **Endpoint:** `/api/v1/payments/commissions`
**Query Parameters:** `architectId`, `status` (`generated`, `approved`, `paid`, `rejected`)

### 11.4 Approve Commission
**Method:** `POST` | **Endpoint:** `/api/v1/payments/commissions/:commissionId/approve`
**Purpose:** Moves status from `generated` to `approved` and transfers architect `pendingCommission` to `approvedCommission`.

### 11.5 Disburse / Pay Commission
**Method:** `POST` | **Endpoint:** `/api/v1/payments/commissions/:commissionId/pay`
**Purpose:** Disburses payout, inserts `commissionPayment` into `ErpPayment`, and updates architect `paidCommission`.

### 11.6 Reject Commission
**Method:** `POST` | **Endpoint:** `/api/v1/payments/commissions/:commissionId/reject`

### 11.7 Expense Vouchers (CRUD)
**Method:** `GET` / `POST` / `PUT` / `DELETE` | **Endpoint:** `/api/v1/expenses`
**Request Body (POST):**
```json
{
  "expenseName": "Site Freight & Dedicated Crane Delivery",
  "category": "transportation",
  "amount": 14500.00,
  "expenseDate": "2026-09-08T00:00:00.000Z",
  "paidBy": "Alex Sterling",
  "paymentMethod": "Bank Transfer",
  "vendorPayee": "QuickMove Logistics LLP",
  "projectId": "PRJ-001",
  "projectName": "Sky City Tower C Luxury Penthouses",
  "expenseReference": "QM/LR/9924",
  "description": "Chandelier hoisting crane & specialized freight",
  "paymentStatus": "paid"
}
```

---

## 12. Master Data Registry Module

| Entity | Base Endpoint | Key Attributes & Unique Constraints |
| :--- | :--- | :--- |
| **Customers** | `/api/v1/masters/customers` | `name`, `mobile`, `email`, `gstNumber`, `outstandingAmount`, `creditBalance`, `linkedArchitectId` |
| **Vendors** | `/api/v1/masters/vendors` | `name`, `contactPerson`, `mobile`, `email`, `gstNumber`, `panNumber`, `creditLimit`, `outstandingBalance`, Soft-delete `isDeleted` |
| **Dealers** | `/api/v1/masters/dealers` | `name`, `companyName`, `mobile`, `email`, `gstNumber`, `outstandingAmount` |
| **Architects** | `/api/v1/masters/architects` | `name`, `companyName`, `mobile`, `email`, `defaultCommissionRate` (default 5.0%), `linkedCustomerId` |
| **Raw Materials** | `/api/v1/masters/raw-materials` | `name`, `itemCode`, `categoryId`, `unit`, `openingStock`, `minimumStock`, `reorderLevel`, `defaultPurchasePrice`, `gstPercent`, `hsnSacCode` |
| **Finished Products** | `/api/v1/masters/finished-products`| `name`, `itemCode`, `categoryId`, `unit`, `costPrice`, `dealerSellingPrice`, `customerSellingPrice`, `minimumStock`, `gstPercent`, `hsnSacCode` |
| **Categories** | `/api/v1/masters/categories` | `name`, `description` |
| **Units** | `/api/v1/masters/units` | `name`, `symbol` (`PCS`, `MTR`, `KG`, `BOX`, `SET`, `ROL`) |

---

### 12.1 Customers Master (CRUD)
- **GET** `/api/v1/masters/customers` — Query params: `search`, `page`, `limit`, `isAlsoArchitect`. Returns paginated customer entities with `outstandingAmount` and `creditBalance`.
- **GET** `/api/v1/masters/customers/:id` — Returns full customer detail, linked project IDs, and purchase history.
- **POST** `/api/v1/masters/customers` — Creates a customer.
  - Required: `name`, `mobile`, `email`, `address`. Optional: `gstNumber`, `linkedArchitectId`, `isAlsoArchitect`.
- **PUT** `/api/v1/masters/customers/:id` — Updates customer profile details.
- **DELETE** `/api/v1/masters/customers/:id` — Soft-deletes customer record.

---

### 12.2 Vendors Master (CRUD + Soft Delete)
- **GET** `/api/v1/masters/vendors` — Query params: `search`, `includeDeleted`, `page`, `limit`. Returns vendor records with `outstandingBalance` and `creditLimit`.
- **GET** `/api/v1/masters/vendors/:id` — Returns single vendor details, active purchase orders, and payment history.
- **POST** `/api/v1/masters/vendors` — Creates a vendor.
  - Required: `name`, `contactPerson`, `mobile`, `email`, `gstNumber`, `panNumber`, `address`, `paymentTerms`, `creditLimit`.
- **PUT** `/api/v1/masters/vendors/:id` — Updates vendor terms or contact details.
- **DELETE** `/api/v1/masters/vendors/:id` — Soft-deletes vendor (`is_deleted = true`, `delete_reason`, `deleted_at = NOW()`).

---

### 12.3 Dealers Master (CRUD)
- **GET** `/api/v1/masters/dealers` — Query params: `search`, `page`, `limit`. Returns dealer network records with `outstandingAmount`.
- **GET** `/api/v1/masters/dealers/:id` — Returns single dealer profile and sales order history.
- **POST** `/api/v1/masters/dealers` — Creates a dealer.
  - Required: `name`, `companyName`, `contactPerson`, `mobile`, `email`, `gstNumber`, `address`.
- **PUT** `/api/v1/masters/dealers/:id` — Updates dealer profile.
- **DELETE** `/api/v1/masters/dealers/:id` — Soft-deletes dealer record.

---

### 12.4 Architects Master (CRUD)
- **GET** `/api/v1/masters/architects` — Query params: `search`, `page`, `limit`. Returns architects with `defaultCommissionRate`, `totalCommissionEarned`, `pendingCommission`, `approvedCommission`, and `paidCommission`.
- **GET** `/api/v1/masters/architects/:id` — Returns architect profile, affiliated projects, and commission ledger.
- **POST** `/api/v1/masters/architects` — Creates an architect.
  - Required: `name`, `companyName`, `mobile`, `email`, `gstNumber`, `address`, `defaultCommissionRate`. Optional: `linkedCustomerId`, `isAlsoCustomer`.
- **PUT** `/api/v1/masters/architects/:id` — Updates architect profile or commission rate.
- **DELETE** `/api/v1/masters/architects/:id` — Soft-deletes architect record.

---

### 12.5 Raw Materials Catalog (CRUD + Soft Delete & Item Code Reuse)
- **GET** `/api/v1/masters/raw-materials` — Query params: `search`, `categoryId`, `lowStockOnly`, `page`, `limit`. Returns raw material SKUs with `currentStock`, `minimumStock`, `defaultPurchasePrice`, `gstPercent`, `hsnSacCode`.
- **GET** `/api/v1/masters/raw-materials/:id` — Returns single raw material details, preferred vendors, and stock valuation.
- **POST** `/api/v1/masters/raw-materials` — Creates a raw material.
  - Required: `name`, `itemCode`, `categoryId`, `unit`, `openingStock`, `minimumStock`, `reorderLevel`, `defaultPurchasePrice`, `gstPercent`. Optional: `hsnSacCode`, `preferredVendorIds`.
  - Enforces partial unique constraint `uq_raw_materials__item_code ON raw_materials(item_code) WHERE is_deleted = false`.
- **PUT** `/api/v1/masters/raw-materials/:id` — Updates item properties.
- **DELETE** `/api/v1/masters/raw-materials/:id` — Soft-deletes raw material (`is_deleted = true`). The `itemCode` becomes immediately reusable for future items (Q-06).

---

### 12.6 Finished Products SKUs (CRUD)
- **GET** `/api/v1/masters/finished-products` — Query params: `search`, `categoryId`, `page`, `limit`. Returns manufactured and assembled lighting products with `currentStock`, `reservedStock`, `costPrice`, `dealerSellingPrice`, `customerSellingPrice`, `gstPercent`, `hsnSacCode`.
- **GET** `/api/v1/masters/finished-products/:id` — Returns single SKU details and stock availability across locations.
- **POST** `/api/v1/masters/finished-products` — Creates a finished product SKU.
  - Required: `name`, `itemCode`, `categoryId`, `unit`, `openingStock`, `minimumStock`, `costPrice`, `dealerSellingPrice`, `customerSellingPrice`, `gstPercent`. Optional: `hsnSacCode`.
- **PUT** `/api/v1/masters/finished-products/:id` — Updates product pricing or specifications.
- **DELETE** `/api/v1/masters/finished-products/:id` — Soft-deletes finished product SKU.

---

### 12.7 Categories & Measurement Units (CRUD)
- **Categories**:
  - `GET /api/v1/masters/categories` — List item categories.
  - `POST /api/v1/masters/categories` — Create category (`name`, `description`).
  - `PUT /api/v1/masters/categories/:id` — Update category.
  - `DELETE /api/v1/masters/categories/:id` — Remove category (restricted if items exist).
- **Units**:
  - `GET /api/v1/masters/units` — List measurement units (`PCS`, `MTR`, `KG`, `BOX`, `SET`, `ROL`).
  - `POST /api/v1/masters/units` — Create custom measurement unit (`name`, `symbol`).
  - `DELETE /api/v1/masters/units/:id` — Remove measurement unit.

---

### 12.8 Link Architect and Customer Dual Identity
**Method:** `POST` | **Endpoint:** `/api/v1/masters/link-architect-customer`
**Request Body:**
```json
{
  "architectId": "ARCH-001",
  "customerId": "CUST-001"
}
```

---

## 13. Reports & Business Intelligence Module

### 13.1 Query Report Registers
**Method:** `GET`

**Endpoint:**
`/api/v1/reports/:reportType`

**Available `:reportType` Parameters:**
1. `inventory`: Stock Flow, Valuation, and Inward/Outward Audit
2. `purchase`: Purchases Register, Tax Modes, and Vendor Balances
3. `production`: Manufacturing Costing, BOM Usage, and Yield Margins
4. `sales`: Sales Revenue, Taxable Turnover, and GST Register (CGST/SGST/IGST breakdown)
5. `project-costing`: Project Material Consumption, Invoiced Turnover, and Margins
6. `expenses`: Operating & Site Overhead Ledger
7. `commissions`: Architect Referrals and Payout Statement
8. `financial-balance`: Balance Sheet, Working Capital, Receivables & Payables

**Query Parameters:**
- `startDate` (ISO8601)
- `endDate` (ISO8601)
- `exportFormat` (`json`, `pdf`, `excel`, `csv`)
- `filterPartyId` (String)
- `filterProjectId` (String)

---

## 14. Document OCR, WhatsApp & System Settings Module

### 14.1 Vision OCR Multi-format Document Data Extraction

**Method:** `POST`

**Endpoint:**
`/api/v1/integrations/ocr-extract`

**Purpose:**
Accepts uploaded multi-format files (PDF, PNG, JPG, WEBP) and parses document key-value pairs, line items, and field confidence levels using Vision OCR.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Form Data:**
- `file`: Binary document (PDF, PNG, JPG)
- `docType`: `purchaseInvoice`, `customerPo`, `quotation`, `vendorDoc`, `customerDoc`, `architectDoc`

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "fileName": "vendor_apex_invoice_912.pdf",
    "extractedData": {
      "Vendor Name": "Apex Aluminum Extrusions Ltd",
      "Invoice Number": "INV-912",
      "Invoice Date": "2026-09-10",
      "Material Name": "6063 Architectural Aluminum Extrusion Profile 2.5m",
      "Item Code": "RAW-ALU-001",
      "Quantity": "100.0",
      "Unit": "MTR",
      "Rate": "480.0",
      "Tax": "8460.0",
      "Total Amount": "55460.0"
    },
    "confidenceScores": {
      "Vendor Name": "High",
      "Invoice Number": "High",
      "Invoice Date": "High",
      "Material Name": "High",
      "Item Code": "Medium",
      "Quantity": "High",
      "Unit": "High",
      "Rate": "High",
      "Tax": "Medium",
      "Total Amount": "High"
    }
  }
}
```

---

### 14.2 WhatsApp Message Dispatch & Communication Log

**Method:** `POST`

**Endpoint:**
`/api/v1/integrations/whatsapp/send-message`

**Purpose:**
Dispatches automated customer notifications (Quotations, Tax Invoices, Delivery Tracking, Payment Reminders, Low Stock Alerts) via WhatsApp Business API and stores the record in `messageLogs`.

**Headers:**
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "messageType": "Quotation",
  "recipientName": "Rahul Oberoi",
  "recipientNumber": "+919821011223",
  "relatedEntityType": "Quotation",
  "relatedEntityId": "QT-002",
  "relatedEntityNumber": "DLZ/QT/2026/0103-R2",
  "messageText": "Dear Rahul Oberoi, please find the revised quotation DLZ/QT/2026/0103-R2 for Sky City Tower C project (Amount: Rs. 3,28,040). Download PDF: https://erp.deluzex.com/docs/QT-002.pdf"
}
```

---

### 14.3 WhatsApp Alert Recipients (CRUD)

**Method:** `GET` / `POST` / `PUT` / `DELETE`

**Endpoint:**
`/api/v1/integrations/whatsapp/alert-recipients`

**Request Body (POST):**
```json
{
  "recipientName": "Vikram Joshi (Production Head)",
  "mobileNumber": "+91 98200 44551",
  "whatsappNumber": "+919820044551",
  "roleOrDepartment": "Production & Manufacturing",
  "alertType": "allLowStock",
  "isActive": true
}
```

---

### 14.4 System Company Preferences

**Method:** `GET` / `PUT`

**Endpoint:**
`/api/v1/settings/company-profile`

**Purpose:**
Fetches and updates legal company details, GSTIN, billing emails, support phone numbers, and WhatsApp Desk configurations.

**Request Body (PUT):**
```json
{
  "companyName": "Deluxex Lighting & Living Ltd.",
  "gstin": "27AABCD1234F1Z8",
  "officialBillingEmail": "accounting@deluxex.com",
  "supportPhone": "+91 (022) 2899-4400",
  "globalSupportWhatsapp": "+919820012345",
  "currencySymbol": "₹"
}
```

---

## 15. Summary & Verification Checklist for Backend Developers

| Module | Endpoints Count | Key Non-Negotiable Rules & Database Triggers |
| :--- | :---: | :--- |
| **Auth & RBAC** | 7 | JWT auth, $10 \times 9$ matrix validation, password-verified supervisor override grants with automatic expiry, security audit trail. |
| **Dashboards** | 2 | Real-time computed aggregations, historical 6-month line charts, warehouse donut distribution, role-specific landing views. |
| **Inventory** | 7 | Immutable stock movement ledger (never update stock without a transaction), stock adjustment reasons, low stock triggers. |
| **Purchase** | 4 | Inward receipts increase stock, auto-update vendor ledger, link payments to PO numbers. |
| **Production** | 4 | Deduct consumed raw materials, add finished output to warehouse, allocate output to pending sales order reservations, calculate unit cost. |
| **Sales Lifecycle** | 12 | Quotations (zero stock impact), Revisions (superseded linking), Orders (auto stock reservation & shortage production triggers), Deliveries (deduct physical & release reserved), Invoices (GST & Architect Commission generation), Returns (QA condition check, restock/damage handling, refunds). |
| **Projects** | 4 | Project budgets, commercial milestone billing, architect & dealer linkages. |
| **Accounts & Payments** | 7 | Multi-mode payment reconciliation, 3-step architect commission lifecycle (`generated` $\rightarrow$ `approved` $\rightarrow$ `paid`), expense categorization. |
| **Masters** | 9 | Full CRUD for 8 entities with duplicate checks on GSTIN/email/SKU, soft deletion for vendors, dual Architect-as-Customer links. |
| **Reports** | 1 | Standardized queryable registers for 8 core reports supporting multi-format exports. |
| **OCR & WhatsApp** | 4 | Vision OCR multipart extraction with confidence metrics, WhatsApp webhook logging, company legal settings. |

---
*Document prepared for backend engineering team based on codebase analysis of de luxex ERP Platform.*

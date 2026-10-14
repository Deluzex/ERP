# Backend API Requirement Document — Addendum & Master Enhancements

**Project:** de luxex ERP Platform  
**Client / Company:** Deluxex Lighting & Living Ltd.  
**Version:** v2.5.0-prod  
**Document Version:** 2.0.0  
**Target Audience:** Backend Developers, API Engineers, Database Architects, System Mentors  
**Scope:** Bill of Materials (BOM) Master Module, Expense & Payment Mode Categories, Geographic Localization (`state` & `pincode` across Customer, Vendor, Dealer, Architect entities), and Interstate Tax Determination Engine.

---

## Table of Contents
1. [Executive Summary & Scope of Enhancements](#1-executive-summary--scope-of-enhancements)
2. [Global Architecture & Precision Standards](#2-global-architecture--precision-standards)
   - [2.1 Monetary & Quantity Precision (ADR-011)](#21-monetary--quantity-precision-adr-011)
   - [2.2 State-Based Tax Engine Rules (Intra-State vs Inter-State)](#22-state-based-tax-engine-rules-intra-state-vs-inter-state)
3. [Bill of Materials (BOM) Master Module](#3-bill-of-materials-bom-master-module)
   - [3.1 BOM Data Model & Database Schema](#31-bom-data-model--database-schema)
   - [3.2 List BOMs (with Pagination & Filter)](#32-list-boms-with-pagination--filter)
   - [3.3 Create New BOM](#33-create-new-bom)
   - [3.4 Get BOM Details by ID](#34-get-bom-details-by-id)
   - [3.5 Update BOM](#35-update-bom)
   - [3.6 Duplicate / Clone BOM Version](#36-duplicate--clone-bom-version)
   - [3.7 Update BOM Lifecycle Status](#37-update-bom-lifecycle-status)
   - [3.8 Dynamic Cost Rollup API](#38-dynamic-cost-rollup-api)
   - [3.9 Get Active BOM by Finished Product ID](#39-get-active-bom-by-finished-product-id)
4. [Master Categories & Financial Modes Module](#4-master-categories--financial-modes-module)
   - [4.1 Expense Categories Sub-Module (CRUD)](#41-expense-categories-sub-module-crud)
   - [4.2 Payment Modes Sub-Module (CRUD)](#42-payment-modes-sub-module-crud)
   - [4.3 Product Categories & Measurement Units Integration](#43-product-categories--measurement-units-integration)
5. [Geographic Localization in Master Entities (State & Pincode)](#5-geographic-localization-in-master-entities-state--pincode)
   - [5.1 Customer Master API Updates](#51-customer-master-api-updates)
   - [5.2 Vendor Master API Updates](#52-vendor-master-api-updates)
   - [5.3 Dealer Master API Updates](#53-dealer-master-api-updates)
   - [5.4 Architect Master API Updates](#54-architect-master-api-updates)
   - [5.5 Pincode Validation & State Determination Rules](#55-pincode-validation--state-determination-rules)
6. [Database Schema DDL & Migration Scripts](#6-database-schema-ddl--migration-scripts)
   - [6.1 Migration Script: BOM Master & Items](#61-migration-script-bom-master--items)
   - [6.2 Migration Script: Expense Categories & Payment Modes](#62-migration-script-expense-categories--payment-modes)
   - [6.3 Migration Script: State and Pincode Columns](#63-migration-script-state-and-pincode-columns)
7. [AI-TDD Verification & Backend Acceptance Criteria](#7-ai-tdd-verification--backend-acceptance-criteria)

---

## 1. Executive Summary & Scope of Enhancements

This document supplements the core de luxex ERP v2.4.0 specification. It defines the exact backend database schemas, NestJS DTOs, controller endpoints, validation pipelines, and business rules required to support recent frontend enhancements across:

1. **Bill of Materials (BOM) Master**:
   - Complete manufacturing recipe definition linking Finished Products to Raw Materials and sub-assemblies.
   - Multi-version lifecycle tracking (`DRAFT` $\rightarrow$ `ACTIVE` $\rightarrow$ `OBSOLETE`), output yield quantities, scrap tolerances, and recursive dynamic unit cost rollups.
2. **Master Categories Expansion**:
   - Dedicated master management for **Expense Categories** (`transportation`, `factory_maintenance`, `site_travel`, `marketing`, `utilities`, etc.).
   - Configurable **Payment Modes** (`bank_transfer`, `upi`, `cash`, `cheque`, `rtgs_neft`, `credit_card`) with reference enforcement flags.
3. **Geographic Localization (State & Pincode)**:
   - Persistence of `state` and `pincode` across **Customers**, **Vendors**, **Dealers**, and **Architects**.
   - Strict 6-digit Indian Postal PIN code regex validation (`/^[1-9][0-9]{5}$/`).
   - Automatic GST place-of-supply resolution: Comparing party state against company home state (Maharashtra - `27`) to automate `CGST + SGST` vs `IGST` calculation.

---

## 2. Global Architecture & Precision Standards

### 2.1 Monetary & Quantity Precision (ADR-011)
Per enterprise architecture directive **ADR-011**, all backend entities, PostgreSQL tables, and API responses must adhere to exact fixed-point numerical representations:
- **Currency & Monetary Amounts:** `NUMERIC(18, 2)` (e.g. unit prices, line totals, taxes, commissions, rolled-up costs). Never use `FLOAT` or `DOUBLE PRECISION`.
- **Physical Stock Quantities & Yields:** `NUMERIC(18, 4)` (e.g. raw material quantities, scrap percentages, batch yields).

### 2.2 State-Based Tax Engine Rules (Intra-State vs Inter-State)
Company Origin: **Maharashtra (State Code: 27)**.
When invoicing or purchasing:
- If `party.state == 'Maharashtra'` (or GST starts with `27`):
  $$\text{Tax Rate} = \text{CGST } \left(\frac{\text{GST}\%}{2}\right) + \text{SGST } \left(\frac{\text{GST}\%}{2}\right), \quad \text{IGST} = 0$$
- If `party.state != 'Maharashtra'` (or GST starts with other state code):
  $$\text{Tax Rate} = \text{IGST } (\text{GST}\%), \quad \text{CGST} = 0, \quad \text{SGST} = 0$$

---

## 3. Bill of Materials (BOM) Master Module

The BOM Master establishes standard product recipes used by the Production & Manufacturing module to reserve raw materials, calculate batch costs, and verify shopfloor yields.

### 3.1 BOM Data Model & Database Schema

```
┌─────────────────────────────────┐        1:N        ┌─────────────────────────────────┐
│              boms               │ ───────────────── │           bom_items             │
├─────────────────────────────────┤                   ├─────────────────────────────────┤
│ id: UUID (PK)                   │                   │ id: UUID (PK)                   │
│ bom_number: VARCHAR(50) (UNIQUE)│                   │ bom_id: UUID (FK -> boms.id)    │
│ finished_product_id: UUID (FK)  │                   │ raw_material_id: UUID (FK)      │
│ version: INT (DEFAULT 1)        │                   │ quantity: NUMERIC(18, 4)        │
│ status: bom_status_enum         │                   │ unit: VARCHAR(20)               │
│ yield_quantity: NUMERIC(18, 4)  │                   │ unit_cost: NUMERIC(18, 2)       │
│ total_cost: NUMERIC(18, 2)      │                   │ scrap_percentage: NUMERIC(5, 2) │
│ notes: TEXT                     │                   │ item_notes: TEXT                │
│ created_at / updated_at         │                   │ created_at / updated_at         │
└─────────────────────────────────┘                   └─────────────────────────────────┘
```

**Enum `bom_status_enum`:** `'DRAFT'`, `'ACTIVE'`, `'OBSOLETE'`.

---

### 3.2 List BOMs (with Pagination & Filter)

**Method:** `GET`  
**Endpoint:** `/api/v1/boms`  
**Purpose:** Fetches a paginated list of Bill of Materials with optional product, status, and text search filters.  
**Headers:** `Authorization: Bearer <token>`  

**Query Parameters:**
| Parameter | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `page` | Integer | `1` | Page number |
| `limit` | Integer | `25` | Records per page |
| `search` | String | - | Searches BOM number, product name, or product code |
| `productId`| UUID | - | Filter by specific finished product |
| `status` | String | - | Filter by status (`DRAFT`, `ACTIVE`, `OBSOLETE`) |

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "e3b0c442-98fc-1c14-9afe-436b78f30001",
        "bomNumber": "BOM-FP001-V1",
        "finishedProductId": "7d9b4c12-3456-42bc-910a-8192a01f1234",
        "finishedProductName": "Aarix Axis Architectural Wall Light (Matte Black)",
        "finishedProductCode": "DLX-WL-001",
        "version": 1,
        "status": "ACTIVE",
        "yieldQuantity": 1.0000,
        "unit": "PCS",
        "itemCount": 4,
        "totalCost": 2000.00,
        "notes": "Standard production recipe for 2026 Architectural series",
        "createdAt": "2026-09-10T10:00:00.000Z",
        "updatedAt": "2026-09-11T14:30:00.000Z"
      }
    ],
    "pagination": {
      "totalItems": 18,
      "totalPages": 1,
      "currentPage": 1,
      "limit": 25,
      "hasNextPage": false,
      "hasPrevPage": false
    }
  },
  "timestamp": "2026-09-11T14:30:00.000Z"
}
```

---

### 3.3 Create New BOM

**Method:** `POST`  
**Endpoint:** `/api/v1/boms`  
**Purpose:** Creates a new Bill of Materials recipe for a finished product with itemized raw materials, scrap allowances, and calculated yield cost.  
**Headers:**  
```text
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "finishedProductId": "7d9b4c12-3456-42bc-910a-8192a01f1234",
  "yieldQuantity": 1.0,
  "status": "DRAFT",
  "notes": "Custom high-lumen commercial variant with thermal heatsink",
  "items": [
    {
      "rawMaterialId": "3b29c512-1089-4bc2-990a-112233445566",
      "quantity": 1.5000,
      "unit": "MTR",
      "scrapPercentage": 2.50,
      "itemNotes": "6063-T6 architectural grade cut to 1.5m length"
    },
    {
      "rawMaterialId": "4c38d623-2190-4cd3-aa1b-223344556677",
      "quantity": 1.0000,
      "unit": "PCS",
      "scrapPercentage": 0.00,
      "itemNotes": "Tridonic 40W Constant Current Driver"
    },
    {
      "rawMaterialId": "5d49e734-3201-4de4-bb2c-334455667788",
      "quantity": 1.0000,
      "unit": "PCS",
      "scrapPercentage": 1.00,
      "itemNotes": "Bridgelux COB LED Array 3000K"
    }
  ]
}
```

**Backend Business Logic & Validation:**
1. Check that `finishedProductId` exists in `finished_products`.
2. Determine `version`: Query max existing version for `finishedProductId`. If none, `version = 1`, else `version = max + 1`.
3. Auto-generate `bomNumber`: `BOM-<ProductCode>-V<version>` (e.g. `BOM-DLX-WL-001-V1`).
4. For each item:
   - Verify `rawMaterialId` exists and fetch current `default_purchase_price`.
   - Calculate item effective cost:
     $$\text{Effective Quantity} = \text{quantity} \times \left(1 + \frac{\text{scrapPercentage}}{100}\right)$$
     $$\text{Line Cost} = \text{Effective Quantity} \times \text{unitCost}$$
5. Sum all line costs into `total_cost`.
6. Insert BOM record and all BOM items inside a database transaction (`BEGIN ... COMMIT`).
7. If `status == 'ACTIVE'`, mark any previous `ACTIVE` BOM for this product as `OBSOLETE`.

**Success Response (`201 Created`):**
```json
{
  "success": true,
  "message": "Bill of Materials created successfully",
  "data": {
    "id": "e3b0c442-98fc-1c14-9afe-436b78f30002",
    "bomNumber": "BOM-DLX-WL-001-V2",
    "finishedProductId": "7d9b4c12-3456-42bc-910a-8192a01f1234",
    "version": 2,
    "status": "DRAFT",
    "yieldQuantity": 1.0000,
    "totalCost": 2045.50,
    "itemCount": 3,
    "createdAt": "2026-09-11T15:00:00.000Z"
  }
}
```

---

### 3.4 Get BOM Details by ID

**Method:** `GET`  
**Endpoint:** `/api/v1/boms/:id`  
**Purpose:** Fetches full details of a specific BOM, including all component line items, scrap rates, and current raw material market prices.  
**Headers:** `Authorization: Bearer <token>`  

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "id": "e3b0c442-98fc-1c14-9afe-436b78f30001",
    "bomNumber": "BOM-DLX-WL-001-V1",
    "finishedProductId": "7d9b4c12-3456-42bc-910a-8192a01f1234",
    "finishedProductName": "Aarix Axis Architectural Wall Light (Matte Black)",
    "finishedProductCode": "DLX-WL-001",
    "version": 1,
    "status": "ACTIVE",
    "yieldQuantity": 1.0000,
    "unit": "PCS",
    "totalCost": 2000.00,
    "notes": "Standard production recipe",
    "items": [
      {
        "id": "b1a2c3d4-0001-4444-9999-111122223333",
        "rawMaterialId": "3b29c512-1089-4bc2-990a-112233445566",
        "rawMaterialName": "6063 Architectural Aluminum Extrusion Profile 2.5m",
        "rawMaterialCode": "RAW-ALU-001",
        "quantity": 1.5000,
        "unit": "MTR",
        "unitCost": 480.00,
        "scrapPercentage": 2.50,
        "lineTotalCost": 738.00,
        "itemNotes": "Extrusion body casing"
      },
      {
        "id": "b1a2c3d4-0002-4444-9999-111122223333",
        "rawMaterialId": "4c38d623-2190-4cd3-aa1b-223344556677",
        "rawMaterialName": "Tridonic Constant Current LED Driver 40W",
        "rawMaterialCode": "RAW-DRV-40W",
        "quantity": 1.0000,
        "unit": "PCS",
        "unitCost": 850.00,
        "scrapPercentage": 0.00,
        "lineTotalCost": 850.00,
        "itemNotes": "Internal power supply"
      }
    ]
  }
}
```

---

### 3.5 Update BOM

**Method:** `PUT`  
**Endpoint:** `/api/v1/boms/:id`  
**Purpose:** Modifies an existing BOM if its status is `DRAFT`.  
**Constraint:** Active or Obsolete BOMs cannot have items edited directly (must clone to a new version via `/duplicate`).  

---

### 3.6 Duplicate / Clone BOM Version

**Method:** `POST`  
**Endpoint:** `/api/v1/boms/:id/duplicate`  
**Purpose:** Clones an existing BOM into a new `DRAFT` version with an auto-incremented version number (e.g. Version 1 $\rightarrow$ Version 2).  
**Headers:** `Authorization: Bearer <token>`  

**Success Response (`201 Created`):**
```json
{
  "success": true,
  "message": "BOM version cloned successfully as DRAFT",
  "data": {
    "newBomId": "e3b0c442-98fc-1c14-9afe-436b78f30003",
    "bomNumber": "BOM-DLX-WL-001-V3",
    "version": 3,
    "status": "DRAFT",
    "parentBomId": "e3b0c442-98fc-1c14-9afe-436b78f30001"
  }
}
```

---

### 3.7 Update BOM Lifecycle Status

**Method:** `PATCH`  
**Endpoint:** `/api/v1/boms/:id/status`  
**Purpose:** Transitions a BOM between lifecycle states (`DRAFT` $\rightarrow$ `ACTIVE` $\rightarrow$ `OBSOLETE`).  
**Headers:** `Authorization: Bearer <token>`  

**Request Body:**
```json
{
  "status": "ACTIVE"
}
```

**Business Logic:**
- When setting a BOM to `ACTIVE`, any other BOM for the same `finished_product_id` is automatically set to `OBSOLETE`.
- Updates `cost_price` of the linked Finished Product based on the active BOM's rolled-up cost.

---

### 3.8 Dynamic Cost Rollup API

**Method:** `GET`  
**Endpoint:** `/api/v1/boms/:id/cost-rollup`  
**Purpose:** Re-evaluates component costs against live raw material purchase prices to calculate updated batch costs, variance from historical BOM cost, and gross profit margin.  
**Headers:** `Authorization: Bearer <token>`  

**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "bomId": "e3b0c442-98fc-1c14-9afe-436b78f30001",
    "storedBomCost": 2000.00,
    "currentMarketCost": 2085.00,
    "costVariance": 85.00,
    "costVariancePercent": 4.25,
    "sellingPriceCustomer": 4800.00,
    "currentGrossMarginPercent": 56.56,
    "costBreakdown": [
      {
        "rawMaterialId": "3b29c512-1089-4bc2-990a-112233445566",
        "rawMaterialName": "6063 Architectural Aluminum Extrusion Profile 2.5m",
        "bomUnitCost": 480.00,
        "latestPurchaseRate": 510.00,
        "lineDifference": 45.00
      }
    ]
  }
}
```

---

### 3.9 Get Active BOM by Finished Product ID

**Method:** `GET`  
**Endpoint:** `/api/v1/boms/by-product/:productId`  
**Purpose:** Returns the currently active recipe for shopfloor work order auto-population.  
**Headers:** `Authorization: Bearer <token>`  

---

## 4. Master Categories & Financial Modes Module

### 4.1 Expense Categories Sub-Module (CRUD)

Manages operational and site expense classifications (e.g. Freight, Generator Fuel, Packaging, Site Travel).

#### 4.1.1 List Expense Categories
**Method:** `GET` | **Endpoint:** `/api/v1/expense-categories`  
**Query Parameters:** `search`, `isActive`, `page`, `limit`  
**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": {
    "items": [
      {
        "id": "exp-cat-001",
        "name": "Transportation & Logistics",
        "code": "EXP-TRANS",
        "description": "Site delivery trucks, dedicated cranes, and shipping freight",
        "isActive": true,
        "createdAt": "2026-08-01T00:00:00.000Z"
      },
      {
        "id": "exp-cat-002",
        "name": "Factory Tooling & Maintenance",
        "code": "EXP-MAINT",
        "description": "CNC tooling, powder coat nozzle replacements, machine servicing",
        "isActive": true,
        "createdAt": "2026-08-01T00:00:00.000Z"
      }
    ],
    "pagination": { "totalItems": 6, "totalPages": 1, "currentPage": 1, "limit": 50 }
  }
}
```

#### 4.1.2 Create Expense Category
**Method:** `POST` | **Endpoint:** `/api/v1/expense-categories`  
**Request Body:**
```json
{
  "name": "Architectural Site Travel",
  "code": "EXP-TRAVEL",
  "description": "Outstation travel and lodging for lighting consultants",
  "isActive": true
}
```
**Validation:** `name` must be unique; `code` must be uppercase alphanumeric without spaces.

#### 4.1.3 Update Expense Category
**Method:** `PUT` | **Endpoint:** `/api/v1/expense-categories/:id`  

#### 4.1.4 Delete / Toggle Expense Category Status
**Method:** `PATCH` | **Endpoint:** `/api/v1/expense-categories/:id/status`  
**Request Body:** `{"isActive": false}`  

---

### 4.2 Payment Modes Sub-Module (CRUD)

Configures accepted financial transaction channels (e.g. NEFT, UPI, Cheque, Cash).

#### 4.2.1 List Payment Modes
**Method:** `GET` | **Endpoint:** `/api/v1/payment-modes`  
**Success Response (`200 OK`):**
```json
{
  "success": true,
  "data": [
    {
      "id": "pm-001",
      "name": "Bank Transfer (NEFT / RTGS)",
      "code": "BANK_TRANSFER",
      "requiresReference": true,
      "description": "Direct bank settlement via UTR / Transaction reference",
      "isActive": true
    },
    {
      "id": "pm-002",
      "name": "UPI / QR Code",
      "code": "UPI",
      "requiresReference": true,
      "description": "Unified Payments Interface instant transfer",
      "isActive": true
    },
    {
      "id": "pm-003",
      "name": "Company Cheque",
      "code": "CHEQUE",
      "requiresReference": true,
      "description": "Subject to bank clearance",
      "isActive": true
    },
    {
      "id": "pm-004",
      "name": "Cash",
      "code": "CASH",
      "requiresReference": false,
      "description": "Direct counter petty cash receipt",
      "isActive": true
    }
  ]
}
```

#### 4.2.2 Create Payment Mode
**Method:** `POST` | **Endpoint:** `/api/v1/payment-modes`  
**Request Body:**
```json
{
  "name": "Letter of Credit (LC)",
  "code": "LC",
  "requiresReference": true,
  "description": "Commercial bank verified trade credit document",
  "isActive": true
}
```

#### 4.2.3 Update Payment Mode
**Method:** `PUT` | **Endpoint:** `/api/v1/payment-modes/:id`  

---

### 4.3 Product Categories & Measurement Units Integration

- **Product Categories (`/api/v1/masters/categories`):** Group finished products and raw materials into catalog trees (e.g., *Profiles & Extrusions*, *Wall Fixtures*, *Pendant Chandeliers*, *LED Drivers*).
- **Measurement Units (`/api/v1/masters/units`):** Standard units of measure (`PCS`, `MTR`, `KG`, `BOX`, `SET`, `ROL`, `SQFT`).

---

## 5. Geographic Localization in Master Entities (State & Pincode)

All four trading party entities (**Customers**, **Vendors**, **Dealers**, and **Architects**) must persist geographic localization attributes (`state` and `pincode`) to support physical dispatch delivery and automated GST tax calculation.

### 5.1 Customer Master API Updates

**Endpoint:** `/api/v1/masters/customers`  
**Updated Fields Added:**
- `state`: String (e.g. `"Maharashtra"`, `"Gujarat"`, `"Karnataka"`)
- `pincode`: String (Exact 6 digits: `"400066"`)

**Create / Update Customer Request Body:**
```json
{
  "name": "Oberoi Sky City Residences",
  "contactPerson": "Mr. Rahul Oberoi",
  "mobile": "+91 98210 11223",
  "email": "procurement@oberoiskycity.com",
  "gstNumber": "27AABCO8892K1Z9",
  "panNumber": "AABCO8892K",
  "billingAddress": "Oberoi Sky City, Western Express Hwy, Borivali East",
  "shippingAddress": "Tower C Site Stores, Oberoi Sky City",
  "city": "Mumbai",
  "state": "Maharashtra",
  "pincode": "400066",
  "creditLimit": 500000.00,
  "linkedArchitectId": "ARCH-001"
}
```

---

### 5.2 Vendor Master API Updates

**Endpoint:** `/api/v1/masters/vendors`  
**Create / Update Vendor Request Body:**
```json
{
  "name": "Apex Aluminum Extrusions Ltd",
  "contactPerson": "Suresh Patel",
  "mobile": "+91 98250 44332",
  "email": "sales@apexaluminum.in",
  "gstNumber": "24AAACA9012J1Z5",
  "panNumber": "AAACA9012J",
  "address": "Plot 104, GIDC Industrial Estate, Makarpura",
  "city": "Vadodara",
  "state": "Gujarat",
  "pincode": "390010",
  "creditLimit": 1000000.00
}
```
*(Notice: State is Gujarat (24) $\rightarrow$ Backend will automatically apply Interstate IGST on all Purchase Invoices from this vendor).*

---

### 5.3 Dealer Master API Updates

**Endpoint:** `/api/v1/masters/dealers`  
**Create / Update Dealer Request Body:**
```json
{
  "name": "Lumina Lifestyle Studios",
  "companyName": "Lumina Luxury Retail LLP",
  "contactPerson": "Pooja Hegde",
  "mobile": "+91 98450 66778",
  "email": "orders@luminalifestyle.com",
  "gstNumber": "29AABCL7743M1Z2",
  "address": "12 Richmond Road, Ashok Nagar",
  "city": "Bengaluru",
  "state": "Karnataka",
  "pincode": "560025",
  "discountTier": "PLATINUM"
}
```

---

### 5.4 Architect Master API Updates

**Endpoint:** `/api/v1/masters/architects`  
**Create / Update Architect Request Body:**
```json
{
  "name": "Ar. Sanjay Puri",
  "companyName": "Sanjay Puri Architects",
  "mobile": "+91 98201 55667",
  "email": "projects@sanjaypuriarchitects.com",
  "gstNumber": "27AAACS1123P1Z1",
  "panNumber": "AAACS1123P",
  "address": "20 Ground Floor, Famous Studios Lane, Mahalaxmi",
  "city": "Mumbai",
  "state": "Maharashtra",
  "pincode": "400011",
  "defaultCommissionRate": 5.00,
  "linkedCustomerId": "CUST-001"
}
```

---

### 5.5 Pincode Validation & State Determination Rules

1. **Validation Rule (Class-Validator DTO):**
   ```typescript
   @IsOptional()
   @IsString()
   @Matches(/^[1-9][0-9]{5}$/, {
     message: 'Pincode must be a valid 6-digit Indian Postal PIN code (e.g. 400001)',
   })
   pincode?: string;

   @IsOptional()
   @IsString()
   @MaxLength(100)
   state?: string;
   ```

2. **Automated State Consistency Check:**
   When a `gstNumber` is provided, the first two numeric digits correspond to the Indian State Code per GST rules (e.g. `27` = Maharashtra, `24` = Gujarat, `29` = Karnataka, `07` = Delhi). The backend verifies that the selected `state` corresponds with the GST state code prefix.

---

## 6. Database Schema DDL & Migration Scripts

The following SQL migrations must be executed in order on PostgreSQL / Supabase:

### 6.1 Migration Script: BOM Master & Items
```sql
-- 1. Create BOM Status Enum
CREATE TYPE bom_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'OBSOLETE');

-- 2. Create boms Table
CREATE TABLE IF NOT EXISTS boms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    bom_number VARCHAR(50) NOT NULL UNIQUE,
    finished_product_id UUID NOT NULL REFERENCES finished_products(id) ON DELETE RESTRICT,
    version INT NOT NULL DEFAULT 1,
    status bom_status_enum NOT NULL DEFAULT 'DRAFT',
    yield_quantity NUMERIC(18, 4) NOT NULL DEFAULT 1.0000,
    total_cost NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_product_version UNIQUE(tenant_id, finished_product_id, version)
);

-- 3. Create bom_items Table
CREATE TABLE IF NOT EXISTS bom_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    bom_id UUID NOT NULL REFERENCES boms(id) ON DELETE CASCADE,
    raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE RESTRICT,
    quantity NUMERIC(18, 4) NOT NULL,
    unit VARCHAR(20) NOT NULL,
    unit_cost NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    scrap_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    item_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Indexes for high-speed queries
CREATE INDEX IF NOT EXISTS idx_boms_product_status ON boms(finished_product_id, status);
CREATE INDEX IF NOT EXISTS idx_bom_items_bom_id ON bom_items(bom_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_raw_material ON bom_items(raw_material_id);
```

---

### 6.2 Migration Script: Expense Categories & Payment Modes
```sql
-- 1. Create expense_categories Table
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_expense_cat_code UNIQUE(tenant_id, code)
);

-- 2. Create payment_modes Table
CREATE TABLE IF NOT EXISTS payment_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL,
    requires_reference BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_payment_mode_code UNIQUE(tenant_id, code)
);
```

---

### 6.3 Migration Script: State and Pincode Columns
```sql
-- Alter Customers
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Alter Vendors
ALTER TABLE vendors 
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Alter Dealers
ALTER TABLE dealers 
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Alter Architects
ALTER TABLE architects 
ADD COLUMN IF NOT EXISTS state VARCHAR(100),
ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);
```

---

## 7. AI-TDD Verification & Backend Acceptance Criteria

To comply with the project's **AI-TDD (Test-Driven Development)** directives, every backend feature must have Supertest integration tests written before implementation.

| Feature Area | Positive Test Case | Negative / Error Test Case | Edge / Boundary Test Case |
| :--- | :--- | :--- | :--- |
| **BOM Lifecycle** | Create BOM with 3 items; verify `total_cost` equals sum of `(qty * (1 + scrap/100) * price)`. | Attempt to edit items on an `ACTIVE` BOM $\rightarrow$ `400 Bad Request`. | Setting a BOM to `ACTIVE` automatically marks any previous active BOM for that SKU as `OBSOLETE`. |
| **BOM Rollup** | Call `/cost-rollup` after updating a raw material's purchase price; verify correct variance returned. | Call `/cost-rollup` with non-existent BOM ID $\rightarrow$ `404 Not Found`. | BOM containing zero raw material cost returns 0 variance without divide-by-zero exception. |
| **Pincode & State** | Create Customer with valid 6-digit pincode (`400066`) and state (`Maharashtra`). | Send invalid pincode `01234` or `40006A` $\rightarrow$ `400 Validation Error`. | Pincode string with leading whitespace is trimmed cleanly before regex validation. |
| **Interstate Tax** | Invoice customer with state `Gujarat` $\rightarrow$ CGST/SGST zero, IGST applied at 18%. | Customer with invalid GSTIN state prefix mismatching state $\rightarrow$ flagged with warning. | Intra-state customer with state `Maharashtra` splits 18% into 9% CGST and 9% SGST. |
| **Expense Categories** | Create expense voucher referencing valid `expense_category_id`. | Create category with duplicate `code` $\rightarrow$ `409 Conflict`. | Deactivating category prevents new vouchers while preserving historical reports. |
| **Payment Modes** | Record payment with mode `BANK_TRANSFER` providing mandatory `transactionReference`. | Record payment with `BANK_TRANSFER` omitting reference $\rightarrow$ `400 Bad Request`. | `CASH` payment mode succeeds without reference parameter. |

---
*Document prepared for backend engineering team and mentor review on de luxex ERP Platform.*


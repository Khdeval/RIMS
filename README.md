# RIMS - Restaurant Inventory Management System

A full-stack restaurant inventory management system with a **Node.js + TypeScript** backend API, **Prisma ORM**, and a **Flutter web dashboard**. Track ingredients, manage recipes, monitor stock levels, record sales, log waste, and handle stock-in with receipt scanning.

## 🚀 Features

- **Ingredient Management**: Track stock levels, par levels, and unit costs
- **Menu Items**: Define menu items with base prices
- **Recipe Management**: Link ingredients to menu items with quantity requirements
- **Waste Tracking**: Log waste by ingredient with reasons; account for prep waste with yield factors
- **Sales Tracking**: Record and analyze sales transactions with automatic stock deductions
- **Stock Deduction**: Automatic calculation: `ActualDeduction = quantityRequired / yieldFactor`
- **Stock-In & Stock Taking**: Record received stock, adjust physical counts, and scan receipts/invoices to bulk-add inventory
- **Receipt Parsing**: Paste receipt text to auto-match ingredients, extract quantities and costs
- **Real-time Updates**: Socket.IO pushes inventory changes to connected clients
- **Flutter Web Dashboard**: Full management UI with overview, menus, recipes, ingredients, sales, waste, deductions, and stock-in screens

## 📋 Schema Overview

### Ingredient
- `id`: Unique identifier
- `name`: Ingredient name
- `unit`: Unit of measurement (grams, ml, pieces, etc.)
- `currentStock`: Current stock quantity
- `parLevel`: Minimum stock threshold
- `unitCost`: Cost per unit

### MenuItem
- `id`: Unique identifier
- `name`: Menu item name
- `basePrice`: Menu item price

### RecipeItem (Junction Table)
- `id`: Unique identifier
- `menuItemId`: Reference to MenuItem
- `ingredientId`: Reference to Ingredient
- `quantityRequired`: Amount of ingredient needed
- `yieldFactor`: Waste multiplier (default: 1.0)
	- Example: yieldFactor of 1.1 = 10% waste
	- Actual deduction = quantityRequired / yieldFactor

### Sale
- `id`: Unique identifier
- `menuItemId`: Reference to MenuItem
- `quantitySold`: Quantity sold in transaction
- `createdAt`: Transaction timestamp

### WasteLog
- `id`: Unique identifier
- `ingredientId`: Reference to Ingredient
- `quantity`: Amount wasted
- `reason`: Reason for waste (expired, spilled, prep waste, damaged)
- `createdAt`: Timestamp

### StockIn
- `id`: Unique identifier
- `ingredientId`: Reference to Ingredient
- `quantity`: Amount stocked in
- `unitCost`: Cost per unit at time of purchase
- `totalCost`: Total cost for this stock-in
- `source`: Origin — `manual`, `receipt_scan`, `stock_count`, `purchase_order`
- `invoiceRef`: Invoice/receipt reference number
- `supplier`: Supplier name
- `notes`: Additional notes
- `createdAt`: Timestamp

## 🛠️ Setup Instructions

### Prerequisites
- Node.js 18+
- npm or yarn
- Flutter 3.19+ (for the dashboard)

### Installation

1. **Install backend dependencies**:
	 ```bash
	 npm install
	 ```

2. **Generate Prisma Client**:
	 ```bash
	 npx prisma generate
	 ```

3. **Create and apply database migrations**:
	 ```bash
	 npx prisma migrate dev
	 ```

4. **Seed the database with sample data**:
	 ```bash
	 npm run db:seed
	 ```

5. **Start the backend API**:
	 ```bash
	 npm run dev
	 ```

6. **Install Flutter dependencies & run the dashboard**:
	 ```bash
	 cd dashboard_flutter
	 flutter pub get
	 flutter run -d web-server --web-port=8080 --web-hostname=0.0.0.0
	 ```

## 📚 Available Scripts

```bash
# Backend
npm run dev              # Run API server in development mode (ts-node)
npm run build            # Compile TypeScript to JavaScript
npm start                # Run compiled application

# Database & Prisma
npm run db:generate      # Generate Prisma Client
npm run db:migrate       # Apply migrations (production)
npm run db:migrate:dev   # Create and apply migrations (development)
npm run db:seed          # Seed database with sample data
npm run db:studio        # Open Prisma Studio GUI

# Docker
npm run docker:up        # Start services with Docker Compose
npm run docker:down      # Stop Docker services
npm run docker:logs      # Tail Docker logs
```

## 📊 Sample Data

The seed script creates:
- **3 Ingredients**: Beef, Bun, Lettuce
- **1 Menu Item**: Burger ($12.99)
- **3 Recipe Items** with different yield factors:
	- Beef: 200g per burger (1.1 yield factor = 10% waste)
	- Bun: 1 piece per burger (1.0 yield factor = no waste)
	- Lettuce: 50g per burger (1.2 yield factor = 20% waste)
- **1 Sample Sale**: 5 burgers sold

### Deduction Calculation Example
If 5 burgers are sold:
- Beef actual deduction: 200g × 5 ÷ 1.1 = 909.09g
- Bun actual deduction: 1 × 5 ÷ 1.0 = 5 pieces
- Lettuce actual deduction: 50g × 5 ÷ 1.2 = 208.33g

## 📁 Project Structure

```
RIMS/
├── src/
│   ├── server.ts             # Express API server with all endpoints
│   ├── business-logic.ts     # Core business logic (sales, inventory, costs)
│   └── index.ts              # Entry point
├── prisma/
│   ├── schema.prisma         # Prisma schema (Ingredient, MenuItem, RecipeItem, Sale, WasteLog, StockIn)
│   ├── seed.ts               # Database seed script
│   └── migrations/           # Database migrations
├── dashboard_flutter/
│   ├── lib/
│   │   └── main.dart         # Flutter web dashboard (all screens)
│   ├── pubspec.yaml          # Flutter dependencies
│   └── web/                  # Web build assets
├── docker-compose.yml        # Docker Compose (development)
├── docker-compose.prod.yml   # Docker Compose (production)
├── Dockerfile                # Backend Docker image
├── Dockerfile.flutter        # Flutter web Docker image
├── package.json              # Backend dependencies & scripts
├── tsconfig.json             # TypeScript configuration
└── README.md                 # This file
```

## 🌐 API Endpoints

### Health & Info
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API info & endpoint listing |
| GET | `/health` | Health check with DB status |

### Ingredients
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/ingredients` | List all ingredients |
| POST | `/ingredients` | Create ingredient |
| PUT | `/ingredients/:id` | Update ingredient |
| DELETE | `/ingredients/:id` | Delete ingredient |
| GET | `/inventory` | Inventory summary with stock status |

### Menu Items
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/menu-items` | List all menu items with recipes |
| GET | `/menu-items/:id` | Get menu item details with costs |
| POST | `/menu-items` | Create menu item |
| PUT | `/menu-items/:id` | Update menu item |
| DELETE | `/menu-items/:id` | Delete menu item |

### Recipes
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/recipe-items` | List all recipe items |
| GET | `/menu-items/:id/recipes` | Get recipes for a menu item |
| POST | `/recipe-items` | Create recipe item |
| PUT | `/recipe-items/:id` | Update recipe item |
| DELETE | `/recipe-items/:id` | Delete recipe item |

### Sales
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/sales` | List sales (query: `?days=30`) |
| GET | `/sales/report` | Sales summary report (query: `?days=7`) |
| POST | `/sales` | Record a sale (auto-deducts stock) |
| GET | `/stock-deductions/:menuItemId` | Preview deductions for a menu item |

### Waste
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/waste-logs` | List waste logs (query: `?days=30`) |
| GET | `/waste-logs/summary` | Waste summary by ingredient & reason |
| POST | `/waste-logs` | Log waste (auto-deducts stock) |
| DELETE | `/waste-logs/:id` | Delete waste log |

### Stock-In & Stock Taking
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/stock-ins` | List stock-in history (query: `?days=90&ingredientId=1`) |
| POST | `/stock-ins` | Add stock for a single ingredient |
| POST | `/stock-ins/bulk` | Bulk stock-in (multiple ingredients) |
| POST | `/stock-ins/parse-receipt` | Parse receipt text & match to ingredients |
| DELETE | `/stock-ins/:id` | Delete stock-in record |
| POST | `/ingredients/:id/adjust-stock` | Adjust stock to physical count |

## 🔧 Environment Variables

Create a `.env` file (or copy from `.env.example`):

```env
DATABASE_URL="file:./dev.db"
```

For production, use a different database:
```env
DATABASE_URL="postgresql://user:password@localhost:5432/rims"
DATABASE_URL="mysql://user:password@localhost:3306/rims"
```

## 💡 Usage Example

```typescript
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

// Fetch menu item with all recipe ingredients
const burger = await prisma.menuItem.findUnique({
	where: { id: 1 },
	include: {
		recipeItems: {
			include: { ingredient: true }
		}
	}
});

// Calculate total ingredient cost for a menu item
const totalCost = burger.recipeItems.reduce((sum, recipe) => {
	const actualQuantity = recipe.quantityRequired / recipe.yieldFactor;
	return sum + (actualQuantity * recipe.ingredient.unitCost);
}, 0);

console.log(`Burger cost: $${totalCost.toFixed(2)}`);
```

## 🔍 Prisma Studio

View and edit your database via GUI:

```bash
npx prisma studio
```

## 🛡️ Type Safety

This project uses TypeScript with strict mode enabled for:
- Type-safe database queries with auto-generated Prisma types
- Compile-time error detection
- Better IDE autocomplete and documentation

## 📈 Flutter Dashboard

The Flutter web dashboard provides a complete management interface with these screens:

| Screen | Description |
|--------|-------------|
| **Overview** | Dashboard with inventory status, low-stock alerts, and quick stats |
| **Menu** | Create, edit, and delete menu items |
| **Recipes** | Link ingredients to menu items with quantities and yield factors |
| **Ingredients** | Manage ingredients with stock levels, par levels, and costs |
| **Sales** | Record sales, view transaction history, and generate reports |
| **Waste** | Log waste events with reasons, view waste summary |
| **Deductions** | Preview ingredient deductions per menu item sale |
| **Stock In** | Add received stock, scan receipts, adjust physical counts, view history |

The dashboard auto-detects the API URL in Codespaces/Gitpod environments via browser origin.

## 📝 License

MIT

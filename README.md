# RIMS - Restaurant Inventory Management System

A Node.js + TypeScript backend service with Prisma ORM for restaurant inventory and recipe management. Track ingredients, manage recipes, monitor stock levels, and calculate ingredient deductions based on sales.

## 🚀 Features

- **Ingredient Management**: Track stock levels, par levels, and unit costs
- **Menu Items**: Define menu items with base prices
- **Recipe Management**: Link ingredients to menu items with quantity requirements
- **Waste Tracking**: Account for prep waste with yield factors
- **Sales Tracking**: Record and analyze sales transactions
- **Stock Deduction**: Automatic calculation: `ActualDeduction = quantityRequired / yieldFactor`

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

## 🛠️ Setup Instructions

### Prerequisites
- Node.js 18+ 
- npm or yarn

### Installation

1. **Install dependencies**:
	 ```bash
	 npm install
	 ```

2. **Generate Prisma Client** (if not auto-generated):
	 ```bash
	 npm run prisma:generate
	 ```

3. **Create and apply database migrations**:
	 ```bash
	 npm run prisma:migrate
	 ```

4. **Seed the database with sample data**:
	 ```bash
	 npm run seed
	 ```

## 📚 Available Scripts

```bash
# Development
npm run dev              # Run the application in development mode
npm run build            # Compile TypeScript to JavaScript
npm start                # Run compiled application

# Database & Prisma
npm run prisma:generate  # Generate Prisma Client
npm run prisma:migrate   # Create and apply migrations
npm run seed             # Run seed script with sample data
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
│   └── index.ts              # Demo application
├── prisma/
│   ├── schema.prisma         # Prisma schema definition
│   ├── seed.ts               # Database seed script
│   └── migrations/           # Database migrations
├── .env                       # Environment variables
├── .env.example              # Environment template
├── .gitignore               # Git ignore rules
├── package.json             # Dependencies & scripts
├── tsconfig.json            # TypeScript configuration
└── README.md                # This file
```

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

## 📈 Next Steps

- Add API endpoints (Express, Fastify, etc.)
- Implement stock deduction logic on sales
- Add authentication and role-based access control
- Create dashboard for inventory analytics
- Set up automated alerts for low stock levels

## 📝 License

MIT

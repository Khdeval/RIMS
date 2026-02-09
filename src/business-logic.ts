// This file demonstrates how to implement key business logic with the RIMS schema

import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

/**
 * Calculate the actual deduction for a single unit of a recipe item
 * Formula: ActualDeduction = quantityRequired / yieldFactor
 */
export function calculateActualDeduction(
  quantityRequired: number,
  yieldFactor: number
): number {
  return quantityRequired / yieldFactor;
}

/**
 * Calculate the total ingredient cost for a menu item
 */
export async function calculateMenuItemCost(menuItemId: number): Promise<number> {
  const recipeItems = await prisma.recipeItem.findMany({
    where: { menuItemId },
    include: { ingredient: true },
  });

  return recipeItems.reduce((total, recipe) => {
    const actualQuantity = calculateActualDeduction(
      recipe.quantityRequired,
      recipe.yieldFactor
    );
    return total + actualQuantity * recipe.ingredient.unitCost;
  }, 0);
}

/**
 * Process a sale and deduct ingredients from stock
 */
export async function processSale(
  menuItemId: number,
  quantitySold: number
): Promise<{ success: boolean; message: string; insufficientStock?: string[] }> {
  const menuItem = await prisma.menuItem.findUnique({
    where: { id: menuItemId },
    include: {
      recipeItems: {
        include: { ingredient: true },
      },
    },
  });

  if (!menuItem) {
    return { success: false, message: "Menu item not found" };
  }

  const insufficientStock: string[] = [];

  // Check if we have enough stock for all ingredients
  for (const recipe of menuItem.recipeItems) {
    const actualDeductionPerUnit = calculateActualDeduction(
      recipe.quantityRequired,
      recipe.yieldFactor
    );
    const totalDeduction = actualDeductionPerUnit * quantitySold;

    if (recipe.ingredient.currentStock < totalDeduction) {
      insufficientStock.push(
        `${recipe.ingredient.name}: needs ${totalDeduction.toFixed(2)}, have ${recipe.ingredient.currentStock}`
      );
    }
  }

  if (insufficientStock.length > 0) {
    return {
      success: false,
      message: "Insufficient stock for some ingredients",
      insufficientStock,
    };
  }

  // Deduct ingredients from stock
  for (const recipe of menuItem.recipeItems) {
    const actualDeductionPerUnit = calculateActualDeduction(
      recipe.quantityRequired,
      recipe.yieldFactor
    );
    const totalDeduction = actualDeductionPerUnit * quantitySold;

    await prisma.ingredient.update({
      where: { id: recipe.ingredientId },
      data: {
        currentStock: {
          decrement: totalDeduction,
        },
      },
    });
  }

  // Record the sale
  await prisma.sale.create({
    data: {
      menuItemId,
      quantitySold,
    },
  });

  return {
    success: true,
    message: `Sale processed: ${quantitySold} ${menuItem.name}(s)`,
  };
}

/**
 * Get all ingredients with stock status
 */
export async function getInventorySummary(): Promise<
  Array<{
    name: string;
    currentStock: number;
    parLevel: number;
    unit: string;
    status: "OK" | "LOW" | "CRITICAL";
  }>
> {
  const ingredients = await prisma.ingredient.findMany();

  return ingredients.map((ing) => {
    let status: "OK" | "LOW" | "CRITICAL";
    if (ing.currentStock === 0) {
      status = "CRITICAL";
    } else if (ing.currentStock < ing.parLevel) {
      status = "LOW";
    } else {
      status = "OK";
    }

    return {
      name: ing.name,
      currentStock: ing.currentStock,
      parLevel: ing.parLevel,
      unit: ing.unit,
      status,
    };
  });
}

/**
 * Get menu item details with ingredient costs
 */
export async function getMenuItemDetails(menuItemId: number) {
  const menuItem = await prisma.menuItem.findUnique({
    where: { id: menuItemId },
    include: {
      recipeItems: {
        include: { ingredient: true },
      },
    },
  });

  if (!menuItem) {
    return null;
  }

  const ingredientCost = menuItem.recipeItems.reduce((total, recipe) => {
    const actualQuantity = calculateActualDeduction(
      recipe.quantityRequired,
      recipe.yieldFactor
    );
    return total + actualQuantity * recipe.ingredient.unitCost;
  }, 0);

  const profitMargin =
    ((menuItem.basePrice - ingredientCost) / menuItem.basePrice) * 100;

  return {
    id: menuItem.id,
    name: menuItem.name,
    basePrice: menuItem.basePrice,
    ingredientCost: ingredientCost.toFixed(2),
    profitMargin: profitMargin.toFixed(2),
    recipes: menuItem.recipeItems.map((recipe) => ({
      ingredient: recipe.ingredient.name,
      quantityRequired: recipe.quantityRequired,
      unit: recipe.ingredient.unit,
      yieldFactor: recipe.yieldFactor,
      actualDeduction: calculateActualDeduction(
        recipe.quantityRequired,
        recipe.yieldFactor
      ).toFixed(2),
      unitCost: recipe.ingredient.unitCost,
    })),
  };
}

/**
 * Get sales statistics
 */
export async function getSalesReport(days: number = 7) {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - days);

  const sales = await prisma.sale.findMany({
    where: {
      createdAt: {
        gte: cutoffDate,
      },
    },
    include: {
      menuItem: true,
    },
    orderBy: {
      createdAt: "desc",
    },
  });

  const summary = sales.reduce(
    (acc, sale) => {
      const itemName = sale.menuItem.name;
      if (!acc[itemName]) {
        acc[itemName] = {
          name: itemName,
          quantity: 0,
          revenue: 0,
        };
      }
      acc[itemName].quantity += sale.quantitySold;
      acc[itemName].revenue += sale.quantitySold * sale.menuItem.basePrice;
      return acc;
    },
    {} as Record<string, { name: string; quantity: number; revenue: number }>
  );

  return {
    period: `Last ${days} days`,
    totalSales: sales.length,
    dateRange: {
      from: cutoffDate,
      to: new Date(),
    },
    summary: Object.values(summary),
  };
}

/**
 * Generate purchase orders for low stock items
 */
export async function generatePurchaseOrders() {
  const lowStockItems = await prisma.ingredient.findMany({
    where: {
      currentStock: {
        lte: 0,
      },
    },
  });

  return lowStockItems.map((item) => ({
    ingredientId: item.id,
    name: item.name,
    currentStock: item.currentStock,
    parLevel: item.parLevel,
    orderQuantity: item.parLevel * 2, // Order to 2x par level
    unit: item.unit,
    estimatedCost: (item.parLevel * 2 - item.currentStock) * item.unitCost,
  }));
}

// Example usage
async function demo() {
  console.log("🍔 RIMS Business Logic Demo\n");

  // Get inventory summary
  console.log("📦 Inventory Summary:");
  const inventory = await getInventorySummary();
  console.table(inventory);

  // Get menu item details
  console.log("\n🍽️ Menu Item Details:");
  const menuItem = await getMenuItemDetails(1);
  console.table(menuItem?.recipes);
  console.log(`Menu Item: ${menuItem?.name}`);
  console.log(`Base Price: $${menuItem?.basePrice}`);
  console.log(`Ingredient Cost: $${menuItem?.ingredientCost}`);
  console.log(`Profit Margin: ${menuItem?.profitMargin}%`);

  // Get sales report
  console.log("\n📊 Sales Report:");
  const report = await getSalesReport(7);
  console.log(`${report.period}`);
  console.table(report.summary);

  // Generate purchase orders
  console.log("\n📋 Purchase Orders for Low Stock:");
  const orders = await generatePurchaseOrders();
  console.table(orders.length > 0 ? orders : "No low stock items");
}

// Run demo if executed directly
if (require.main === module) {
  demo()
    .then(async () => {
      await prisma.$disconnect();
    })
    .catch(async (e) => {
      console.error(e);
      await prisma.$disconnect();
      process.exit(1);
    });
}

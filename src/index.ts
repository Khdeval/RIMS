import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🍔 RIMS Backend - Restaurant Inventory Management System");
  console.log("========================================================\n");

  // Example: Get all menu items with their recipes
  const menuItems = await prisma.menuItem.findMany({
    include: {
      recipeItems: {
        include: {
          ingredient: true,
        },
      },
    },
  });

  console.log("📋 Menu Items:");
  for (const item of menuItems) {
    console.log(`\n${item.name} - $${item.basePrice}`);
    console.log("  Ingredients:");
    for (const recipe of item.recipeItems) {
      const actualDeduction = recipe.quantityRequired / recipe.yieldFactor;
      console.log(
        `    - ${recipe.ingredient.name}: ${recipe.quantityRequired} ${recipe.ingredient.unit}` +
        ` (yield factor: ${recipe.yieldFactor}, actual deduction: ${actualDeduction.toFixed(2)} ${recipe.ingredient.unit})`
      );
    }
  }

  // Example: Get all ingredients with stock levels
  const ingredients = await prisma.ingredient.findMany();

  console.log("\n📦 Inventory Levels:");
  for (const ingredient of ingredients) {
    const status =
      ingredient.currentStock < ingredient.parLevel ? "⚠️ LOW" : "✅ OK";
    console.log(
      `  ${status} ${ingredient.name}: ${ingredient.currentStock} ${ingredient.unit} (Par level: ${ingredient.parLevel})`
    );
  }

  // Example: Get sales history
  const sales = await prisma.sale.findMany({
    include: {
      menuItem: true,
    },
    orderBy: {
      createdAt: "desc",
    },
    take: 5,
  });

  console.log("\n💳 Recent Sales:");
  for (const sale of sales) {
    console.log(
      `  ${sale.menuItem.name} × ${sale.quantitySold} (${sale.createdAt.toISOString()})`
    );
  }
}

main()
  .then(async () => {
    console.log("\n✨ Ready to serve!");
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });

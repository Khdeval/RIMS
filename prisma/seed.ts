import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

async function main() {
  console.log("🌱 Starting seed...");

  // Delete existing data
  await prisma.sale.deleteMany({});
  await prisma.recipeItem.deleteMany({});
  await prisma.menuItem.deleteMany({});
  await prisma.ingredient.deleteMany({});

  // Create ingredients
  const beef = await prisma.ingredient.create({
    data: {
      name: "Beef",
      unit: "grams",
      currentStock: 5000,
      parLevel: 1000,
      unitCost: 0.08, // $0.08 per gram
    },
  });

  const bun = await prisma.ingredient.create({
    data: {
      name: "Bun",
      unit: "pieces",
      currentStock: 200,
      parLevel: 50,
      unitCost: 0.50, // $0.50 per bun
    },
  });

  const lettuce = await prisma.ingredient.create({
    data: {
      name: "Lettuce",
      unit: "grams",
      currentStock: 1500,
      parLevel: 300,
      unitCost: 0.02, // $0.02 per gram
    },
  });

  console.log("✅ Ingredients created:", { beef, bun, lettuce });

  // Create menu item
  const burger = await prisma.menuItem.create({
    data: {
      name: "Burger",
      basePrice: 12.99,
    },
  });

  console.log("✅ Menu item created:", burger);

  // Create recipe items linking burger to ingredients
  // Burger recipe:
  // - 200 grams of beef with 10% prep waste (yieldFactor = 1.1)
  // - 1 bun with no waste (yieldFactor = 1.0)
  // - 50 grams of lettuce with 20% waste (yieldFactor = 1.2)

  const beefRecipe = await prisma.recipeItem.create({
    data: {
      menuItemId: burger.id,
      ingredientId: beef.id,
      quantityRequired: 200,
      yieldFactor: 1.1, // 10% prep waste
    },
  });

  const bunRecipe = await prisma.recipeItem.create({
    data: {
      menuItemId: burger.id,
      ingredientId: bun.id,
      quantityRequired: 1,
      yieldFactor: 1.0, // No waste
    },
  });

  const lettuceRecipe = await prisma.recipeItem.create({
    data: {
      menuItemId: burger.id,
      ingredientId: lettuce.id,
      quantityRequired: 50,
      yieldFactor: 1.2, // 20% prep waste
    },
  });

  console.log("✅ Recipe items created:", {
    beefRecipe,
    bunRecipe,
    lettuceRecipe,
  });

  // Create sample sale
  const sale = await prisma.sale.create({
    data: {
      menuItemId: burger.id,
      quantitySold: 5,
    },
  });

  console.log("✅ Sample sale created:", sale);

  console.log("\n📊 Seed Summary:");
  console.log("-------------------");
  console.log(`Ingredients: ${await prisma.ingredient.count()}`);
  console.log(`Menu Items: ${await prisma.menuItem.count()}`);
  console.log(`Recipe Items: ${await prisma.recipeItem.count()}`);
  console.log(`Sales: ${await prisma.sale.count()}`);
  console.log("\n💡 Ingredient Deduction Calculation Example:");
  console.log("For Burger (5 sold):");
  console.log(`  Beef: 200g × 5 / 1.1 = ${(200 * 5) / 1.1} grams`);
  console.log(`  Bun: 1 × 5 / 1.0 = ${(1 * 5) / 1.0} pieces`);
  console.log(`  Lettuce: 50g × 5 / 1.2 = ${(50 * 5) / 1.2} grams`);

  console.log("\n✨ Seed completed successfully!");
}

main()
  .then(async () => {
    await prisma.$disconnect();
  })
  .catch(async (e) => {
    console.error(e);
    await prisma.$disconnect();
    process.exit(1);
  });

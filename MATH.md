# RIMS - Deduction Math & Calculations Guide

## Stock Deduction Formula

The core formula for calculating ingredient deductions when items are sold:

$$\text{ActualDeduction} = \frac{\text{quantityRequired}}{\text{yieldFactor}}$$

### Understanding Each Component

- **quantityRequired**: The base amount of ingredient used in the recipe (e.g., 200g of beef per burger)
- **yieldFactor**: A multiplier accounting for preparation waste (default: 1.0)
- **ActualDeduction**: The amount to subtract from current stock

### Yield Factor Explanation

The `yieldFactor` accounts for waste during food preparation:

| Yield Factor | Waste % | Interpretation |
|---|---|---|
| 1.0 | 0% | No waste (e.g., pre-portioned items) |
| 1.1 | 10% | 10% waste during prep |
| 1.2 | 20% | 20% waste during prep |
| 1.25 | 25% | 25% waste during prep |
| 1.5 | 50% | 50% waste during prep (significant trimming) |

**Formula for waste percentage**: Waste % = (yieldFactor - 1) × 100

## Examples

### Example 1: Burger with 5 Units Sold

**Recipe for 1 Burger:**
- Beef: 200g (yield factor: 1.1)
- Bun: 1 piece (yield factor: 1.0)
- Lettuce: 50g (yield factor: 1.2)

**When 5 burgers are sold:**

Beef deduction:
$$\text{Beef} = \frac{200 \text{ g}}{1.1} = 181.82 \text{ g}$$

Bun deduction:
$$\text{Bun} = \frac{1 \text{ piece}}{1.0} = 1.00 \text{ piece}$$

Lettuce deduction:
$$\text{Lettuce} = \frac{50 \text{ g}}{1.2} = 41.67 \text{ g}$$

**Total per burger**: 181.82g beef + 1 bun + 41.67g lettuce

**For 5 burgers**:
- Beef: 181.82 × 5 = **909.09g**
- Bun: 1 × 5 = **5 pieces**  
- Lettuce: 41.67 × 5 = **208.33g**

### Example 2: Item with No Waste

**Recipe for 1 Salad:**
- Lettuce: 150g (yield factor: 1.0)
- Tomato: 100g (yield factor: 1.0)
- Dressing: 30ml (yield factor: 1.0)

When 10 salads are sold:
- Lettuce: 150g ÷ 1.0 = 150g per salad × 10 = **1500g**
- Tomato: 100g ÷ 1.0 = 100g per salad × 10 = **1000g**
- Dressing: 30ml ÷ 1.0 = 30ml per salad × 10 = **300ml**

### Example 3: Item with High Waste (Trimming)

**Recipe for 1 Steak:**
- Meat (rib roast): 250g (yield factor: 1.4 = 40% waste from trimming)
- Potatoes: 200g (yield factor: 1.15 = 15% waste from peeling)

When 3 steaks are sold:
- Meat: 250g ÷ 1.4 = 178.57g per steak × 3 = **535.71g** (must order 250g per steak)
- Potatoes: 200g ÷ 1.15 = 173.91g per steak × 3 = **521.74g** (must order 200g per steak)

## Implementation Pattern

When recording a sale, deduct ingredients as follows:

```typescript
// Pseudo-code for processing a sale
async function processSale(menuItemId: number, quantitySold: number) {
  // Get the menu item with recipe details
  const menuItem = await prisma.menuItem.findUnique({
    where: { id: menuItemId },
    include: {
      recipeItems: {
        include: { ingredient: true }
      }
    }
  });

  // Deduct each ingredient
  for (const recipe of menuItem.recipeItems) {
    const actualDeductionPerUnit = recipe.quantityRequired / recipe.yieldFactor;
    const totalDeduction = actualDeductionPerUnit * quantitySold;

    // Update inventory
    await prisma.ingredient.update({
      where: { id: recipe.ingredientId },
      data: {
        currentStock: {
          decrement: totalDeduction
        }
      }
    });
  }

  // Record the sale
  await prisma.sale.create({
    data: {
      menuItemId,
      quantitySold
    }
  });
}
```

## Cost Calculation

To calculate ingredient cost for a menu item:

```typescript
const recipeItems = await prisma.recipeItem.findMany({
  where: { menuItemId: 1 },
  include: { ingredient: true }
});

const ingredientCost = recipeItems.reduce((total, recipe) => {
  const actualQuantity = recipe.quantityRequired / recipe.yieldFactor;
  return total + (actualQuantity * recipe.ingredient.unitCost);
}, 0);

console.log(`Ingredient cost per burger: $${ingredientCost.toFixed(2)}`);
```

## Common Yields by Ingredient

| Ingredient Type | Typical Yield Factor | Common Use |
|---|---|---|
| Pre-portioned (burgers) | 1.0 | Patties, buns |
| Vegetables (light prep) | 1.05-1.15 | Lettuce, tomato |
| Vegetables (moderate trim) | 1.15-1.25 | Onion, pepper |
| Vegetables (heavy trim) | 1.25-1.50 | Artichoke, broccoli |
| Meat (light trim) | 1.10-1.15 | Ground meat |
| Meat (heavy trim) | 1.30-1.50 | Steaks, roasts |
| Protein (fish) | 1.20-1.30 | Whole fish |
| Dairy products | 1.0-1.05 | Cheese, butter |

## Validation Rules

Consider implementing these validations:

1. **yieldFactor must be ≥ 1.0**: A yield factor less than 1 would mean gaining material, which is impossible
2. **quantityRequired must be > 0**: Can't require zero or negative amounts
3. **Prevent over-deduction**: Check that current stock ≥ totalDeduction before processing
4. **Track low stock**: Alert when ingredient falls below par level

## Database Queries

### Find all recipes with high waste
```typescript
const wasteItems = await prisma.recipeItem.findMany({
  where: {
    yieldFactor: {
      gt: 1.25  // Greater than 25% waste
    }
  },
  include: {
    menuItem: true,
    ingredient: true
  }
});
```

### Calculate total ingredient cost for all menu items
```typescript
const items = await prisma.menuItem.findMany({
  include: { recipeItems: { include: { ingredient: true } } }
});

items.forEach(item => {
  const cost = item.recipeItems.reduce((sum, recipe) => {
    return sum + (recipe.quantityRequired / recipe.yieldFactor) * recipe.ingredient.unitCost;
  }, 0);
  console.log(`${item.name}: $${cost.toFixed(2)}`);
});
```

## Related Formula: Profit Margin

Once you have ingredient costs, you can calculate profit margin:

$$\text{Profit Margin \%} = \frac{\text{basePrice} - \text{ingredientCost}}{\text{basePrice}} \times 100$$

Example:
- Burger base price: $12.99
- Ingredient cost: $3.50
- Profit margin: (12.99 - 3.50) / 12.99 × 100 = **73.06%**

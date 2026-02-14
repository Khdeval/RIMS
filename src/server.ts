import express, { Request, Response, NextFunction } from "express";
import { PrismaClient } from "@prisma/client";
import cors from "cors";
import helmet from "helmet";
import compression from "compression";
import morgan from "morgan";
import dotenv from "dotenv";
import {
  processSale,
  getInventorySummary,
  getMenuItemDetails,
  getSalesReport,
  fetchCloverInventory,
  upsertCloverInventory,
} from "./business-logic";
import http from "http";
import { Server as SocketIOServer } from "socket.io";

// ── Config ────────────────────────────────────────────────────────────────────
dotenv.config();

const NODE_ENV = process.env.NODE_ENV || "development";
const PORT = parseInt(process.env.PORT || "3000", 10);
const CORS_ORIGINS = process.env.CORS_ORIGINS
  ? process.env.CORS_ORIGINS.split(",").map((o) => o.trim())
  : ["*"];
const LOG_FORMAT = NODE_ENV === "production" ? "combined" : "dev";

// ── App & Server ──────────────────────────────────────────────────────────────
const app = express();
const server = http.createServer(app);

const prisma = new PrismaClient({
  log: NODE_ENV === "production" ? ["error"] : ["info", "warn", "error"],
});

const io = new SocketIOServer(server, {
  cors: {
    origin: CORS_ORIGINS.includes("*") ? true : CORS_ORIGINS,
    methods: ["GET", "POST"],
  },
});

// ── Middleware ─────────────────────────────────────────────────────────────────
app.use(helmet({ contentSecurityPolicy: false }));
app.use(compression());
app.use(express.json({ limit: "1mb" }));

if (CORS_ORIGINS.includes("*")) {
  app.use(cors());
} else {
  app.use(cors({ origin: CORS_ORIGINS, credentials: true }));
}

app.use(morgan(LOG_FORMAT));
app.set("trust proxy", 1);

// ── Health & Info ─────────────────────────────────────────────────────────────
app.get("/", (_req, res) =>
  res.json({
    name: "RIMS API",
    version: "1.0.0",
    environment: NODE_ENV,
    uptime: `${Math.floor(process.uptime())}s`,
    endpoints: [
      "GET  /health",
      "GET  /inventory",
      "GET  /ingredients",
      "POST /ingredients",
      "PUT  /ingredients/:id",
      "DELETE /ingredients/:id",
      "GET  /menu-items",
      "GET  /menu-items/:id",
      "POST /menu-items",
      "PUT  /menu-items/:id",
      "DELETE /menu-items/:id",
      "GET  /menu-items/:id/recipes",
      "GET  /recipe-items",
      "POST /recipe-items",
      "PUT  /recipe-items/:id",
      "DELETE /recipe-items/:id",
      "GET  /sales",
      "GET  /sales/report",
      "POST /sales",
      "GET  /waste-logs",
      "GET  /waste-logs/summary",
      "POST /waste-logs",
      "DELETE /waste-logs/:id",
      "GET  /stock-deductions/:menuItemId",
    ],
  })
);

app.get("/health", async (_req, res) => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    res.json({
      status: "ok",
      environment: NODE_ENV,
      uptime: `${Math.floor(process.uptime())}s`,
      database: "connected",
      timestamp: new Date().toISOString(),
    });
  } catch {
    res.status(503).json({ status: "error", database: "disconnected" });
  }
});

app.get("/inventory", async (_req, res) => {
  try {
    const data = await getInventorySummary();
    res.json(data);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch inventory";
    res.status(500).json({ error: message });
  }
});

app.get("/menu-items", async (_req, res) => {
  try {
    const items = await prisma.menuItem.findMany({
      include: {
        recipeItems: { include: { ingredient: true } },
      },
    });
    res.json(items);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch menu items";
    res.status(500).json({ error: message });
  }
});

app.get("/menu-items/:id", async (req, res) => {
  const id = Number(req.params.id);
  try {
    const details = await getMenuItemDetails(id);
    if (!details) return res.status(404).json({ error: "Not found" });
    res.json(details);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch menu item" });
  }
});

app.post("/menu-items", async (req, res) => {
  const { name, basePrice } = req.body;
  if (!name || typeof basePrice !== "number") {
    return res.status(400).json({ error: "name and basePrice required" });
  }
  try {
    const menuItem = await prisma.menuItem.create({
      data: { name, basePrice },
    });
    res.status(201).json(menuItem);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to create menu item";
    res.status(500).json({ error: message });
  }
});

app.put("/menu-items/:id", async (req, res) => {
  const id = Number(req.params.id);
  const { name, basePrice } = req.body;
  if (!name || typeof basePrice !== "number") {
    return res.status(400).json({ error: "name and basePrice required" });
  }
  try {
    const menuItem = await prisma.menuItem.update({
      where: { id },
      data: { name, basePrice },
    });
    res.json(menuItem);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to update menu item";
    res.status(500).json({ error: message });
  }
});

app.delete("/menu-items/:id", async (req, res) => {
  const id = Number(req.params.id);
  try {
    await prisma.menuItem.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to delete menu item";
    res.status(500).json({ error: message });
  }
});

app.get("/ingredients", async (_req, res) => {
  try {
    const ingredients = await prisma.ingredient.findMany({ orderBy: { name: 'asc' } });
    res.json(ingredients);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch ingredients";
    res.status(500).json({ error: message });
  }
});

app.post("/ingredients", async (req, res) => {
  const { name, unit, currentStock, parLevel, unitCost } = req.body;
  if (!name || !unit) {
    return res.status(400).json({ error: "name and unit are required" });
  }
  try {
    const ingredient = await prisma.ingredient.create({
      data: {
        name,
        unit,
        currentStock: currentStock ?? 0,
        parLevel: parLevel ?? 0,
        unitCost: unitCost ?? 0,
      },
    });
    res.status(201).json(ingredient);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to create ingredient";
    res.status(500).json({ error: message });
  }
});

app.put("/ingredients/:id", async (req, res) => {
  const id = Number(req.params.id);
  const { name, unit, currentStock, parLevel, unitCost } = req.body;
  try {
    const ingredient = await prisma.ingredient.update({
      where: { id },
      data: {
        ...(name !== undefined ? { name } : {}),
        ...(unit !== undefined ? { unit } : {}),
        ...(currentStock !== undefined ? { currentStock } : {}),
        ...(parLevel !== undefined ? { parLevel } : {}),
        ...(unitCost !== undefined ? { unitCost } : {}),
      },
    });
    res.json(ingredient);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to update ingredient";
    res.status(500).json({ error: message });
  }
});

app.delete("/ingredients/:id", async (req, res) => {
  const id = Number(req.params.id);
  try {
    await prisma.ingredient.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to delete ingredient";
    res.status(500).json({ error: message });
  }
});

app.get("/menu-items/:id/recipes", async (req, res) => {
  const menuItemId = Number(req.params.id);
  try {
    const recipes = await prisma.recipeItem.findMany({
      where: { menuItemId },
      include: { ingredient: true },
    });
    res.json(recipes);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch recipes";
    res.status(500).json({ error: message });
  }
});

app.post("/recipe-items", async (req, res) => {
  const { menuItemId, ingredientId, quantityRequired, yieldFactor } = req.body;
  if (!menuItemId || !ingredientId || typeof quantityRequired !== "number") {
    return res.status(400).json({ error: "menuItemId, ingredientId, and quantityRequired required" });
  }
  try {
    const recipeItem = await prisma.recipeItem.create({
      data: {
        menuItemId,
        ingredientId,
        quantityRequired,
        yieldFactor: yieldFactor || 1.0,
      },
      include: { ingredient: true },
    });
    res.status(201).json(recipeItem);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to create recipe item";
    res.status(500).json({ error: message });
  }
});

app.get("/recipe-items", async (_req, res) => {
  try {
    const recipes = await prisma.recipeItem.findMany({
      include: { ingredient: true, menuItem: true },
    });
    res.json(recipes);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch recipe items";
    res.status(500).json({ error: message });
  }
});

app.put("/recipe-items/:id", async (req, res) => {
  const id = Number(req.params.id);
  const { quantityRequired, yieldFactor } = req.body;
  try {
    const recipeItem = await prisma.recipeItem.update({
      where: { id },
      data: {
        ...(typeof quantityRequired === "number" ? { quantityRequired } : {}),
        ...(typeof yieldFactor === "number" ? { yieldFactor } : {}),
      },
      include: { ingredient: true },
    });
    res.json(recipeItem);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to update recipe item";
    res.status(500).json({ error: message });
  }
});

app.delete("/recipe-items/:id", async (req, res) => {
  const id = Number(req.params.id);
  try {
    await prisma.recipeItem.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to delete recipe item";
    res.status(500).json({ error: message });
  }
});

app.post("/sales", async (req, res) => {
  const { menuItemId, quantitySold } = req.body;
  if (typeof menuItemId !== "number" || typeof quantitySold !== "number") {
    return res.status(400).json({ error: "menuItemId and quantitySold required" });
  }

  try {
    const result = await processSale(menuItemId, quantitySold);
    if (!result.success) return res.status(400).json(result);
    // Emit inventory update via socket
    io.emit('inventory_update', { message: 'Sale processed', menuItemId, quantitySold });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to process sale" });
  }
});

// Sales listing
app.get("/sales", async (req, res) => {
  const days = Number(req.query.days) || 30;
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    const sales = await prisma.sale.findMany({
      where: { createdAt: { gte: cutoffDate } },
      include: { menuItem: true },
      orderBy: { createdAt: "desc" },
    });
    res.json(sales);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch sales";
    res.status(500).json({ error: message });
  }
});

// Sales report/summary
app.get("/sales/report", async (req, res) => {
  const days = Number(req.query.days) || 7;
  try {
    const report = await getSalesReport(days);
    res.json(report);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to generate sales report";
    res.status(500).json({ error: message });
  }
});

// Waste tracking
app.get("/waste-logs", async (req, res) => {
  const days = Number(req.query.days) || 30;
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    const logs = await prisma.wasteLog.findMany({
      where: { createdAt: { gte: cutoffDate } },
      include: { ingredient: true },
      orderBy: { createdAt: "desc" },
    });
    res.json(logs);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to fetch waste logs";
    res.status(500).json({ error: message });
  }
});

app.post("/waste-logs", async (req, res) => {
  const { ingredientId, quantity, reason } = req.body;
  if (!ingredientId || typeof quantity !== "number" || !reason) {
    return res.status(400).json({ error: "ingredientId, quantity, and reason required" });
  }
  try {
    // Record waste log
    const wasteLog = await prisma.wasteLog.create({
      data: { ingredientId, quantity, reason },
      include: { ingredient: true },
    });
    // Deduct from stock
    await prisma.ingredient.update({
      where: { id: ingredientId },
      data: { currentStock: { decrement: quantity } },
    });
    io.emit('inventory_update', { message: 'Waste logged', ingredientId, quantity });
    res.status(201).json(wasteLog);
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to log waste";
    res.status(500).json({ error: message });
  }
});

app.delete("/waste-logs/:id", async (req, res) => {
  const id = Number(req.params.id);
  try {
    await prisma.wasteLog.delete({ where: { id } });
    res.status(204).send();
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to delete waste log";
    res.status(500).json({ error: message });
  }
});

// Stock deduction report — shows what would be deducted per sale
app.get("/stock-deductions/:menuItemId", async (req, res) => {
  const menuItemId = Number(req.params.menuItemId);
  try {
    const menuItem = await prisma.menuItem.findUnique({
      where: { id: menuItemId },
      include: { recipeItems: { include: { ingredient: true } } },
    });
    if (!menuItem) return res.status(404).json({ error: "Menu item not found" });

    const deductions = menuItem.recipeItems.map((recipe) => {
      const actualDeduction = recipe.quantityRequired / recipe.yieldFactor;
      return {
        ingredient: recipe.ingredient.name,
        ingredientId: recipe.ingredientId,
        unit: recipe.ingredient.unit,
        quantityRequired: recipe.quantityRequired,
        yieldFactor: recipe.yieldFactor,
        actualDeduction: parseFloat(actualDeduction.toFixed(4)),
        currentStock: recipe.ingredient.currentStock,
        canMake: Math.floor(recipe.ingredient.currentStock / actualDeduction),
        costPerUnit: parseFloat((actualDeduction * recipe.ingredient.unitCost).toFixed(4)),
      };
    });

    const maxServings = deductions.length > 0 ? Math.min(...deductions.map(d => d.canMake)) : 0;

    res.json({
      menuItem: menuItem.name,
      menuItemId: menuItem.id,
      basePrice: menuItem.basePrice,
      deductions,
      maxServings,
      totalIngredientCost: parseFloat(deductions.reduce((sum, d) => sum + d.costPerUnit, 0).toFixed(2)),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to calculate deductions";
    res.status(500).json({ error: message });
  }
});

// Waste summary report
app.get("/waste-logs/summary", async (req, res) => {
  const days = Number(req.query.days) || 30;
  try {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - days);
    const logs = await prisma.wasteLog.findMany({
      where: { createdAt: { gte: cutoffDate } },
      include: { ingredient: true },
    });

    const byIngredient: Record<string, { name: string; unit: string; totalWasted: number; totalCost: number; count: number }> = {};
    const byReason: Record<string, { reason: string; totalEntries: number; totalQuantity: number }> = {};

    for (const log of logs) {
      const name = log.ingredient.name;
      if (!byIngredient[name]) {
        byIngredient[name] = { name, unit: log.ingredient.unit, totalWasted: 0, totalCost: 0, count: 0 };
      }
      byIngredient[name].totalWasted += log.quantity;
      byIngredient[name].totalCost += log.quantity * log.ingredient.unitCost;
      byIngredient[name].count++;

      if (!byReason[log.reason]) {
        byReason[log.reason] = { reason: log.reason, totalEntries: 0, totalQuantity: 0 };
      }
      byReason[log.reason].totalEntries++;
      byReason[log.reason].totalQuantity += log.quantity;
    }

    res.json({
      period: `Last ${days} days`,
      totalEntries: logs.length,
      byIngredient: Object.values(byIngredient),
      byReason: Object.values(byReason),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to generate waste summary";
    res.status(500).json({ error: message });
  }
});

app.post('/webhook/clover', async (req, res) => {
  io.emit('inventory_update', { message: 'Inventory updated from Clover webhook' });
  res.status(200).send('OK');
});

app.post('/sync/clover', async (req, res) => {
  const { merchantId, accessToken } = req.body;
  if (!merchantId || !accessToken) {
    return res.status(400).json({ error: "merchantId and accessToken required" });
  }
  try {
    const items = await fetchCloverInventory(merchantId, accessToken);
    await upsertCloverInventory(items);
    io.emit('inventory_update', { items });
    res.json({ success: true, count: items.length });
  } catch (err) {
    const message = err instanceof Error ? err.message : "Failed to sync Clover inventory";
    res.status(500).json({ error: message });
  }
});

// ── Socket.io ─────────────────────────────────────────────────────────────────
io.on('connection', (socket) => {
  console.log(`[socket] Client connected: ${socket.id}`);
  socket.on('disconnect', () => {
    console.log(`[socket] Client disconnected: ${socket.id}`);
  });
});

// ── Global error handler ──────────────────────────────────────────────────────
app.use((err: Error, _req: Request, res: Response, _next: NextFunction) => {
  console.error("[error]", err.stack);
  res.status(500).json({
    error: NODE_ENV === "production" ? "Internal Server Error" : err.message,
  });
});

// ── Graceful shutdown ─────────────────────────────────────────────────────────
async function shutdown(signal: string) {
  console.log(`\n[${signal}] Shutting down gracefully…`);
  server.close(() => console.log("[server] HTTP server closed"));
  await prisma.$disconnect();
  console.log("[prisma] Database connection closed");
  process.exit(0);
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

// ── Start ─────────────────────────────────────────────────────────────────────
server.listen(PORT, () => {
  console.log(`\n  ╔══════════════════════════════════════╗`);
  console.log(`  ║  RIMS API Server                     ║`);
  console.log(`  ║  Port: ${String(PORT).padEnd(29)}║`);
  console.log(`  ║  Env:  ${NODE_ENV.padEnd(29)}║`);
  console.log(`  ╚══════════════════════════════════════╝\n`);
});

export { app, server };

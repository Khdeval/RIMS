import express from "express";
import { PrismaClient } from "@prisma/client";
import {
  processSale,
  getInventorySummary,
  getMenuItemDetails,
} from "./business-logic";

const app = express();
const prisma = new PrismaClient();
app.use(express.json());

app.get("/health", (_req, res) => res.json({ status: "ok" }));

app.get("/inventory", async (_req, res) => {
  try {
    const data = await getInventorySummary();
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: "Failed to fetch inventory" });
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
    res.status(500).json({ error: "Failed to fetch menu items" });
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

app.post("/sales", async (req, res) => {
  const { menuItemId, quantitySold } = req.body;
  if (typeof menuItemId !== "number" || typeof quantitySold !== "number") {
    return res.status(400).json({ error: "menuItemId and quantitySold required" });
  }

  try {
    const result = await processSale(menuItemId, quantitySold);
    if (!result.success) return res.status(400).json(result);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: "Failed to process sale" });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`API server listening on http://localhost:${port}`);
});

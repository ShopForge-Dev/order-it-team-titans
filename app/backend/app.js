const express = require("express");
const app = express();
const path = require("path");
const cookieParser = require("cookie-parser");
const bodyParser = require("body-parser");
const fileUpload = require("express-fileupload");
const errorMiddleware = require("./middlewares/errors");

// Middleware
app.use(express.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(fileUpload());

// Routes
const foodRouter = require("./routes/foodItem");
const restaurantRouter = require("./routes/restaurant");
const menuRouter = require("./routes/menu");
const couponRouter = require("./routes/couponRoutes");
const reviewRouter = require("./routes/reviewsRoutes");
const orderRouter = require("./routes/order");
const authRouter = require("./routes/auth");
const paymentRouter = require("./routes/payment");

// Body size limits
app.use(express.json({ limit: "30kb" }));
app.use(express.urlencoded({ extended: true, limit: "30kb" }));

// Mount routes
app.use("/api/v1/eats/fooditems", foodRouter);
app.use("/api/v1/eats/menus", menuRouter);
app.use("/api/v1/eats/stores", restaurantRouter);
app.use("/api/v1/eats/orders", orderRouter);
app.use("/api/v1/reviews", reviewRouter);
app.use("/api/v1/users", authRouter);
app.use("/api/v1/payment", paymentRouter);
app.use("/api/v1/coupon", couponRouter);

// Health check endpoints (K8s probes)
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "ok",
    service: "orderit-backend",
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
  });
});

app.get("/ready", (req, res) => {
  const mongoose = require("mongoose");
  const isReady = mongoose.connection.readyState === 1;

  if (isReady) {
    return res.status(200).json({
      ready: true,
      checks: { database: true },
      timestamp: new Date().toISOString(),
    });
  }

  res.status(503).json({
    ready: false,
    checks: { database: false },
    timestamp: new Date().toISOString(),
  });
});

app.get("/metrics", (req, res) => {
  res.type("text/plain");
  res.send(`
# HELP process_uptime_seconds Process uptime in seconds
# TYPE process_uptime_seconds gauge
process_uptime_seconds ${process.uptime()}

# HELP nodejs_memory_usage_bytes Memory usage in bytes
# TYPE nodejs_memory_usage_bytes gauge
nodejs_memory_usage_bytes{type="heapUsed"} ${
    process.memoryUsage().heapUsed
  }
nodejs_memory_usage_bytes{type="heapTotal"} ${
    process.memoryUsage().heapTotal
  }
  `);
});

// View engine setup
app.set("view engine", "pug");
app.set("views", path.join(__dirname, "./routes"));

// Stripe test mode endpoint
app.get("/api/v1/stripeapi", (req, res) => {
  res.status(200).json({
    stripeApiKey: process.env.STRIPE_API_KEY,
  });
});

// 404 handler
app.all("*", (req, res, next) => {
  res.status(404).json({
    status: "fail",
    message: `Can't find ${req.originalUrl} on this server!`,
  });
});

// Error handling middleware
app.use(errorMiddleware);

module.exports = app;

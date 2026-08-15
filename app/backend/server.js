const app = require("./app");
const connectDatabase = require("./config/database");
const dotenv = require("dotenv");
const mongoose = require("mongoose");

// Load environment variables
dotenv.config({ path: "./config/config.env" });

// Connect to database
connectDatabase();

// Handle uncaught exceptions
process.on("uncaughtException", (err) => {
  console.log("ERROR: " + err.stack);
  console.log("Shutting down server due to uncaught exception");
  process.exit(1);
});

// Start server
const server = app.listen(process.env.PORT, () => {
  console.log(
    "Server started on PORT: " +
      process.env.PORT +
      " in " +
      process.env.NODE_ENV +
      " mode."
  );
});

// Handle unhandled promise rejection
process.on("unhandledRejection", (err) => {
  console.log("ERROR: " + err.message);
  console.log("Shutting down the server due to Unhandled Promise rejection");
  server.close(() => {
    process.exit(1);
  });
});

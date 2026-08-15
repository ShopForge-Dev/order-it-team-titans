const app = require("./app");
const connectDatabase = require("./config/database");
const dotenv = require("dotenv");
const cloudinary = require("cloudinary");
const { setDriver } = require("mongoose");

// Load environment variables
dotenv.config({ path: "./config/config.env" });

// Connect to database
connectDatabase();

// Configure cloudinary
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

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

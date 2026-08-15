const mongoose = require("mongoose");

const connectDatabase = () => {
  mongoose
    .connect(process.env.DB_LOCAL_URI, {})
    .then((instance) => {
      console.log(
        "MongoDB Database connected with HOST: " + instance.connection.host
      );
    })
    .catch((err) => {
      console.log("Database connection error:", err);
      process.exit(1);
    });
};

module.exports = connectDatabase;

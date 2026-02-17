// backend/test/setup/test_env.js
process.env.NODE_ENV = "test";

process.env.APP_NAME = "Raonson-Test";
process.env.BASE_URL = "https://raonson-v1.onrender.com";

process.env.JWT_SECRET = "test_jwt_secret_key";
process.env.JWT_EXPIRES_IN = "7d";

process.env.MONGO_URI = "mongodb://127.0.0.1:27017/raonson_test";

process.env.REDIS_URL = "redis://127.0.0.1:6379";

process.env.RATE_LIMIT_WINDOW = "15";
process.env.RATE_LIMIT_MAX = "1000";

export {};

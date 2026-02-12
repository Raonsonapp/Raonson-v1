const PORT = process.env.PORT || 3000;
import app from "./app.js";

dotenv.config();

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
  console.log("Raonson backend running on port", PORT);
});
app.get("/", (req, res) => {
  res.json({ status: "Raonson backend is running" });
});

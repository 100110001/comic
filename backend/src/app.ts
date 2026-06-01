import express from "express";
import path from "path";
import cors from "cors";
import morgan from "morgan";
import { router } from "./routes/index";
import { config } from "./config";

const app = express();

app.use(cors());
morgan.token("decoded-url", (req) => {
  try {
    return decodeURIComponent(req.url ?? "");
  } catch {
    return req.url ?? "";
  }
});
app.use(morgan("[:date[iso]] :method :decoded-url :status :response-time ms"));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

app.get("/", (_req, res) => {
  res.sendFile(path.join(process.cwd(), "public", "index.html"));
});

app.use(express.static(path.join(process.cwd(), "public")));
app.use("/static", express.static(config.comicRoot));
app.use("/api", router);

export default app;

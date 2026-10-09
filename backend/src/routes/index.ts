import { Router } from "express";
import type { Request, Response } from "express";
import { comicsRouter } from "./comics";
import { chaptersRouter } from "./chapters";
import { favoriteAuthorsRouter } from "./favorite-authors";
import { mineRouter } from "./mine";
import { ok } from "../utils/response";

import { superResolutionRouter } from "./super-resolution";
import { imagesRouter } from "./images";

export const router: Router = Router();

router.get("/health", (_req: Request, res: Response) => {
  ok(res, { status: "ok" });
});

router.use("/comics", comicsRouter);
router.use("/chapters", chaptersRouter);
router.use("/favorite-authors", favoriteAuthorsRouter);
router.use("/mine", mineRouter);

router.use("/super-resolution", superResolutionRouter);

router.use("/images", imagesRouter);

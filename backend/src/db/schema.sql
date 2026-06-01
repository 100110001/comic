-- Comic App Database Schema
-- MySQL / MariaDB

CREATE DATABASE IF NOT EXISTS comic CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE comic;

-- 漫画
CREATE TABLE IF NOT EXISTS comics (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  title       VARCHAR(255)  NOT NULL,
  author      VARCHAR(100)  DEFAULT NULL,
  description TEXT          DEFAULT NULL,
  cover_path  VARCHAR(500)  DEFAULT NULL,         -- 封面图片相对路径
  created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  INDEX idx_title (title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 章节
CREATE TABLE IF NOT EXISTS chapters (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  comic_id     INT UNSIGNED  NOT NULL,
  title        VARCHAR(255)  NOT NULL,
  sort_order   INT UNSIGNED  NOT NULL DEFAULT 0,  -- 排序序号，允许自定义顺序
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_chapters_comic FOREIGN KEY (comic_id) REFERENCES comics(id) ON DELETE CASCADE,
  INDEX idx_comic_sort (comic_id, sort_order)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 图片
CREATE TABLE IF NOT EXISTS images (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  chapter_id   INT UNSIGNED  NOT NULL,
  filename     VARCHAR(255)  NOT NULL,            -- 原始文件名
  path         VARCHAR(500)  NOT NULL,            -- 存储相对路径
  page_number  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  width        SMALLINT UNSIGNED DEFAULT NULL,
  height       SMALLINT UNSIGNED DEFAULT NULL,
  created_at   DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_images_chapter FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE,
  INDEX idx_chapter_page (chapter_id, page_number)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

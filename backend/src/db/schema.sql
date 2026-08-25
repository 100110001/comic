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

  INDEX idx_title (title),
  UNIQUE KEY uq_comics_title_author (title, author)
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
  INDEX idx_comic_sort (comic_id, sort_order),
  UNIQUE KEY uq_chapters_comic_title (comic_id, title)
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
  INDEX idx_chapter_page (chapter_id, page_number),
  UNIQUE KEY uq_images_chapter_filename (chapter_id, filename)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 收藏（漫画级别，每本漫画最多一条）
CREATE TABLE IF NOT EXISTS favorites (
  comic_id   INT UNSIGNED NOT NULL PRIMARY KEY,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT fk_favorites_comic FOREIGN KEY (comic_id) REFERENCES comics(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 阅读进度（每本漫画只保留一条最新记录）
CREATE TABLE IF NOT EXISTS reading_progress (
  comic_id    INT UNSIGNED NOT NULL PRIMARY KEY,
  chapter_id  INT UNSIGNED NOT NULL,
  page_number SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  updated_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

  CONSTRAINT fk_progress_comic FOREIGN KEY (comic_id) REFERENCES comics(id) ON DELETE CASCADE,
  CONSTRAINT fk_progress_chapter FOREIGN KEY (chapter_id) REFERENCES chapters(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 收藏作者（作者按名字去重）
CREATE TABLE IF NOT EXISTS favorite_authors (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  author     VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

  UNIQUE KEY uq_favorite_authors_author (author)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

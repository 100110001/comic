"use strict";
(() => {
  const $ = (id) => document.getElementById(id),
    page = document.body.dataset.page,
    params = new URLSearchParams(location.search);
  let category = ["all", "api", "image", "upscale"].includes(
      params.get("category"),
    )
      ? params.get("category")
      : "api",
    data = null,
    busy = false;
  const names = {
      all: "全部链路",
      api: "普通接口",
      image: "原图",
      upscale: "超分 HTTP",
    },
    cacheNames = {
      hit: "命中",
      miss: "未命中",
      unavailable: "不可用",
      unused: "未使用",
    };
  const num = (n) => (n == null ? "—" : Number(n).toLocaleString("zh-CN")),
    pct = (n, d) => (d ? ((100 * n) / d).toFixed(1) + "%" : "—"),
    ms = (n) =>
      n == null
        ? "—"
        : n >= 1000
          ? (n / 1000).toFixed(2) + " 秒"
          : Math.round(n) + " ms",
    clock = (s) => new Date(s).toLocaleTimeString("zh-CN", { hour12: false });
  const bytes = (n) =>
    n == null
      ? "未采集"
      : n >= 1073741824
        ? (n / 1073741824).toFixed(2) + " GiB"
        : n >= 1048576
          ? (n / 1048576).toFixed(1) + " MiB"
          : n >= 1024
            ? (n / 1024).toFixed(1) + " KiB"
            : n + " B";
  function el(tag, text, cls) {
    const n = document.createElement(tag);
    if (text != null) n.textContent = text;
    if (cls) n.className = cls;
    return n;
  }
  function metric(label, value, note, href, featured = false) {
    const n = el(
      href ? "a" : "div",
      null,
      "metric" + (featured ? " featured" : ""),
    );
    if (href) n.href = href;
    n.append(
      el("div", label + (href ? " ↗" : ""), "label"),
      el("div", value, "value"),
      el("div", note, "note"),
    );
    return n;
  }
  function row(label, value, note, fraction, href) {
    const n = el("div", null, "cache-row"),
      title = el("div", null, "cache-title"),
      a = el(href ? "a" : "span", label);
    if (href) a.href = href;
    title.append(a, el("span", value));
    n.append(title);
    if (Number.isFinite(fraction)) {
      const track = el("div", null, "track"),
        fill = el("span");
      fill.style.width = Math.min(100, Math.max(0, fraction * 100)) + "%";
      track.append(fill);
      n.append(track);
    }
    if (note) n.append(el("p", note));
    return n;
  }
  function summary(sr) {
    const ended = sr.requests.filter(
        (r) => r.status === "ready" || r.status === "failed",
      ),
      known = sr.requests.filter((r) =>
        ["cache", "shared", "inference"].includes(r.kind),
      );
    return {
      ended,
      known,
      hits: known.filter((r) => r.kind === "cache").length,
      shared: known.filter((r) => r.kind === "shared").length,
      success: ended.filter((r) => r.status === "ready").length,
    };
  }
  function empty(body, count, message) {
    const tr = el("tr"),
      td = el("td", message, "empty-cell");
    td.colSpan = count;
    tr.append(td);
    body.append(tr);
  }
  function chart(records, overview, target = "request-chart") {
    const root = $(target);
    root.replaceChildren();
    if (!records.length) {
      root.append(
        el("p", "暂无请求，开始阅读后将在这里显示趋势。", "empty-cell"),
      );
      return;
    }
    const now = Math.floor(new Date(data.timestamp).getTime() / 60000),
      buckets = Array.from({ length: 15 }, (_, i) => ({
        minute: now - 14 + i,
        api: 0,
        image: 0,
        upscale: 0,
        count: 0,
        elapsed: 0,
      }));
    for (const r of records) {
      const b = buckets.find(
        (b) =>
          b.minute === Math.floor(new Date(r.requestedAt).getTime() / 60000),
      );
      if (b) {
        b[r.category]++;
        b.count++;
        b.elapsed += r.elapsedMs;
      }
    }
    const max = Math.max(1, ...buckets.map((b) => b.count)),
      maxMs = Math.max(
        1,
        ...buckets.map((b) => (b.count ? b.elapsed / b.count : 0)),
      ),
      ns = "http://www.w3.org/2000/svg",
      svg = document.createElementNS(ns, "svg");
    svg.setAttribute("viewBox", "0 0 640 190");
    svg.setAttribute("role", "img");
    svg.setAttribute(
      "aria-label",
      "最近十五分钟请求量" + (overview ? "，按类型分布" : "和平均耗时"),
    );
    svg.classList.add("chart");
    function shape(tag, attrs, text) {
      const n = document.createElementNS(ns, tag);
      for (const [k, v] of Object.entries(attrs)) n.setAttribute(k, v);
      if (text != null) n.textContent = text;
      svg.append(n);
      return n;
    }
    for (let i = 0; i <= 3; i++) {
      const y = 160 - i * 46;
      shape("line", { x1: 30, y1: y, x2: 595, y2: y });
      shape("text", { x: 2, y: y + 4 }, String(Math.round((max * i) / 3)));
      if (!overview)
        shape(
          "text",
          { x: 600, y: y + 4 },
          String(Math.round((maxMs * i) / 3)),
        );
    }
    let segment = [];
    const flush = () => {
      if (segment.length > 1)
        shape("polyline", {
          points: segment.map((p) => p.join(",")).join(" "),
          fill: "none",
          stroke: "#85b9e8",
          "stroke-width": 2,
        });
      segment = [];
    };
    buckets.forEach((b, i) => {
      const x = 38 + i * 37;
      let bottom = 160;
      for (const key of overview ? ["api", "image", "upscale"] : ["count"]) {
        const h = (b[key] / max) * 138,
          bar = shape("rect", {
            x,
            y: bottom - h,
            width: 22,
            height: h,
            rx: 2,
            fill: {
              api: "#b8ed8c",
              image: "#85b9e8",
              upscale: "#d5ade9",
              count: "#b8ed8c",
            }[key],
          });
        const title = document.createElementNS(ns, "title");
        title.textContent = clock(b.minute * 60000) + " · " + b[key] + " 次";
        bar.append(title);
        bottom -= h;
      }
      if (!overview) {
        if (b.count) {
          const y = 160 - (b.elapsed / b.count / maxMs) * 138;
          segment.push([x + 11, y]);
          shape("circle", { cx: x + 11, cy: y, r: 3, fill: "#85b9e8" });
        } else flush();
      }
      if (i % 4 === 0 || i === 14)
        shape("text", { x, y: 184 }, clock(b.minute * 60000).slice(0, 5));
    });
    flush();
    root.append(svg);
  }
  function overview() {
    const { infrastructure: i, traffic: t, superResolution: sr } = data,
      s = summary(sr),
      tot = t.totals;
    $("library-cards").replaceChildren(
      metric("漫画总数", num(i.library.comics), "已入库漫画", null, true),
      metric("章节总数", num(i.library.chapters), "所有漫画章节"),
      metric("图片总数", num(i.library.images), "已索引的原图"),
      metric(
        "超分缓存",
        bytes(i.cache.bytes),
        i.cache.status === "unavailable"
          ? "缓存目录不可读"
          : num(i.cache.count) + " 个文件 · 上限 " + bytes(i.cache.maxBytes),
      ),
    );
    const services = $("services");
    services.replaceChildren();
    for (const [name, value, ok] of [
      ["后台服务", "在线", true],
      [
        "数据库",
        i.library.status === "ready" ? "可用" : "不可用",
        i.library.status === "ready",
      ],
      [
        "Redis 连接",
        i.redis === "ready" ? "已连接" : "不可用",
        i.redis === "ready",
      ],
      ["超分配置", sr.enabled ? "已启用" : "已关闭", sr.enabled],
    ]) {
      const n = el("div", null, "status-item");
      n.append(
        el("span", name),
        el("span", value, "pill" + (ok ? "" : " bad")),
      );
      services.append(n);
    }
    services.append(
      el("span", "配置启用不代表引擎可用 · 基础信息每 15 秒更新", "muted"),
    );
    const failed = Object.values(tot).reduce((n, v) => n + v.failed, 0);
    $("traffic-cards").replaceChildren(
      metric(
        "普通接口",
        num(tot.api.requests),
        "本次运行请求数",
        "/requests.html?category=api",
      ),
      metric(
        "图片请求",
        num(tot.image.requests),
        "到达后端的原图请求",
        "/requests.html?category=image",
      ),
      metric(
        "超分提交",
        num(sr.total),
        sr.queued + " 排队 · " + sr.running + " 处理中",
        "/super-resolution-monitor.html",
        true,
      ),
      metric(
        "HTTP 异常",
        num(failed),
        "各链路失败状态或连接中断",
        "/requests.html?category=all&status=failed",
      ),
    );
    chart(t.records, true);
    $("cache-overview").replaceChildren(
      row(
        "接口 Redis 命中",
        pct(tot.api.hit, tot.api.hit + tot.api.miss),
        "仅包括实际查询缓存且可用的请求",
        tot.api.hit / (tot.api.hit + tot.api.miss),
        "/requests.html?category=api&cache=hit",
      ),
      row(
        "原图 304 协商缓存",
        num(tot.image.notModified) + " 次",
        "浏览器本地命中不经过后端",
        undefined,
        "/requests.html?category=image&status=304",
      ),
      row(
        "超分缓存命中",
        pct(s.hits, s.known.length),
        "近期已知处理类型 · 共享任务单列",
        s.hits / s.known.length,
        "/super-resolution-monitor.html?kind=cache",
      ),
    );
    $("upscale-overview").replaceChildren(
      row(
        "任务队列",
        sr.queued + " 排队 / " + sr.running + " 运行",
        "推理串行执行；请求可能共享任务",
      ),
      row(
        "近期成功率",
        pct(s.success, s.ended.length),
        "仅统计已结束的保留请求",
        s.success / s.ended.length,
      ),
      row(
        "共享任务",
        num(s.shared),
        "复用在途任务，不计入缓存命中",
        undefined,
        "/super-resolution-monitor.html?kind=shared",
      ),
    );
    const errors = [
        ...t.records
          .filter((r) => r.aborted || r.status >= 400)
          .map((r) => ({
            type: names[r.category],
            name: r.path,
            result: r.aborted ? "连接中断" : String(r.status),
            at: r.requestedAt,
            href: "/requests.html?category=" + r.category + "&status=failed",
          })),
        ...sr.requests
          .filter((r) => r.status === "failed")
          .map((r) => ({
            type: "超分处理",
            name: r.filename,
            result: r.error || "处理失败",
            at: r.requestedAt,
            href:
              "/super-resolution-monitor.html?status=failed&request=" + r.id,
          })),
      ]
        .sort((a, b) => b.at.localeCompare(a.at))
        .slice(0, 6),
      body = $("recent-errors");
    body.replaceChildren();
    for (const r of errors) {
      const tr = el("tr"),
        td = el("td"),
        a = el("a", r.name);
      a.href = r.href;
      td.append(a);
      const result = el("td", r.result);
      result.title = r.result;
      tr.append(el("td", r.type), td, result, el("td", clock(r.at)));
      body.append(tr);
    }
    if (!errors.length) empty(body, 4, "目前没有异常记录");
  }
  function requests() {
    const { traffic: t, superResolution: sr, infrastructure: i } = data,
      total =
        category === "all"
          ? Object.values(t.totals).reduce((a, v) => {
              for (const k of Object.keys(v)) a[k] = (a[k] || 0) + v[k];
              return a;
            }, {})
          : t.totals[category],
      s = summary(sr);
    document
      .querySelectorAll("[data-category]")
      .forEach((b) =>
        b.setAttribute("aria-pressed", String(b.dataset.category === category)),
      );
    $("category-cards").replaceChildren(
      metric(
        "HTTP 请求",
        num(total.requests),
        "本次运行 · " + names[category],
        null,
        true,
      ),
      metric("失败 / 中断", num(total.failed), "包含 4xx、5xx 与连接中断"),
      metric(
        "平均响应耗时",
        ms(total.requests ? total.elapsedMs / total.requests : null),
        "本次运行 · 含排队等待",
      ),
      metric(
        "已知响应体大小",
        bytes(total.bytes),
        total.unknownBytes + " 次大小未知 · 不含响应头",
      ),
    );
    chart(
      t.records.filter((r) => category === "all" || r.category === category),
      false,
    );
    const cache = $("cache-detail");
    cache.replaceChildren();
    if (category === "all")
      cache.append(
        row(
          "按链路观察",
          "普通接口 / 原图 / 超分",
          "选择上方分类查看对应缓存；三类缓存不能合成统一命中率",
        ),
        row(
          "监视范围",
          "当前后端进程",
          "不包含浏览器本地缓存命中；监视轮询不计入业务请求",
        ),
      );
    else if (category === "api")
      cache.append(
        row(
          "Redis 命中率",
          pct(total.hit, total.hit + total.miss),
          "只统计缓存查询成功的请求",
          total.hit / (total.hit + total.miss),
        ),
        row(
          "命中 / 未命中",
          total.hit + " / " + total.miss,
          "目前章节图片列表使用 Redis，缓存有效期 24 小时",
        ),
        row(
          "不可用 / 未使用",
          total.unavailable + " / " + total.unused,
          "不可用时回退查询；未使用缓存不算未命中",
        ),
      );
    else if (category === "image")
      cache.append(
        row(
          "304 协商缓存",
          num(total.notModified) + " 次",
          "原图 HTTP 缓存有效期 1 小时",
        ),
        row(
          "客户端本地命中",
          "不可观测",
          "浏览器或客户端直接使用本地缓存，不会请求后端",
        ),
        row(
          "统计范围",
          "到达后端的请求",
          "响应体大小依据完成响应的 Content-Length；304 和 HEAD 为零",
        ),
      );
    else
      cache.append(
        row(
          "超分磁盘命中",
          pct(s.hits, s.known.length),
          "最近保留的提交记录；与 HTTP 请求数独立",
          s.hits / s.known.length,
          "/super-resolution-monitor.html?kind=cache",
        ),
        row(
          "新推理 / 共享",
          s.known.filter((r) => r.kind === "inference").length +
            " / " +
            s.shared,
          "共享的是在途任务，非磁盘缓存命中",
        ),
        row(
          "已发布文件",
          bytes(i.cache.bytes) + " / " + bytes(i.cache.maxBytes),
          i.cache.status === "unavailable"
            ? "缓存目录不可读"
            : num(i.cache.count) + " 个文件 · 容量每 15 秒更新",
          i.cache.bytes == null ? undefined : i.cache.bytes / i.cache.maxBytes,
        ),
        row(
          "增强图 304",
          num(total.notModified) + " 次",
          "增强文件 HTTP 缓存 1 天；下方统计超分专用接口及文件传输，统一图片解析归普通接口",
        ),
      );
    $("upscale-trend-panel").hidden = category !== "upscale";
    if (category === "upscale")
      chart(
        s.ended.map((r) => ({ ...r, category: "upscale" })),
        false,
        "upscale-chart",
      );
    $("cache-filter").hidden = category !== "api";
    rows();
  }
  function rows() {
    if (!data) return;
    const term = $("search").value.trim().toLowerCase(),
      status = $("status-filter").value,
      cache = $("cache-filter").value;
    const visible = data.traffic.records.filter(
      (r) =>
        (category === "all" || r.category === category) &&
        (r.path + " " + r.method).toLowerCase().includes(term) &&
        (status === "all" ||
          (status === "failed" && (r.aborted || r.status >= 400)) ||
          (status === "success" &&
            !r.aborted &&
            r.status >= 200 &&
            r.status < 400) ||
          (status === "304" && r.status === 304)) &&
        (category !== "api" || cache === "all" || r.cache === cache),
    );
    const body = $("request-rows");
    body.replaceChildren();
    for (const r of visible) {
      const tr = el("tr"),
        statusCell = el("td"),
        pathCell = el("td");
      statusCell.append(
        el(
          "span",
          r.aborted ? "中断" : String(r.status),
          "pill" + (r.aborted || r.status >= 400 ? " bad" : ""),
        ),
      );
      pathCell.title = r.path;
      let readable = r.path;
      try {
        readable = decodeURIComponent(r.path);
      } catch {}
      pathCell.append(el("code", readable));
      tr.append(
        el("td", clock(r.requestedAt)),
        el("td", r.method),
        pathCell,
        statusCell,
        el(
          "td",
          category === "api" || (category === "all" && r.category === "api")
            ? cacheNames[r.cache]
            : r.status === 304
              ? "协商缓存"
              : "—",
        ),
        el("td", ms(r.elapsedMs)),
        el("td", bytes(r.bytes)),
      );
      body.append(tr);
    }
    if (!visible.length)
      empty(
        body,
        7,
        data.traffic.records.some(
          (r) => category === "all" || r.category === category,
        )
          ? "没有符合筛选条件的请求"
          : "暂无此类请求；开始阅读或调用接口后可在此查看。",
      );
    $("visible-count").textContent =
      visible.length + " 条 · 全类别合计保留最多 500 条";
  }
  async function refresh() {
    if (busy) return;
    busy = true;
    $("refresh").disabled = true;
    $("refresh").textContent = "刷新中…";
    const controller = new AbortController(),
      timer = setTimeout(() => controller.abort(), 10000);
    try {
      const response = await fetch("/api/admin/dashboard", {
        cache: "no-store",
        signal: controller.signal,
      });
      if (!response.ok) throw Error("HTTP " + response.status);
      const json = await response.json();
      if (
        json.code !== 0 ||
        !Array.isArray(json.data?.traffic?.records) ||
        !Array.isArray(json.data?.superResolution?.requests) ||
        !json.data?.infrastructure?.library
      )
        throw Error("后台响应无效");
      data = json.data;
      $("connection").classList.remove("stale");
      $("connection-text").textContent =
        "已连接 · " +
        ($("auto-refresh").checked ? "每 5 秒更新请求数据" : "自动刷新已暂停");
      $("updated").textContent = "更新于 " + clock(data.timestamp);
      $("scope-note").textContent =
        "统计始于 " +
        new Date(data.traffic.startedAt).toLocaleString("zh-CN") +
        "。本进程累计与近期明细分别计算，重启清空；HTTP 和超分提交明细各保留最多 500 条。监视轮询不计入业务请求。";
      const focused = document.activeElement;
      const scope = focused?.closest(
        "#library-cards, #traffic-cards, #cache-overview, #upscale-overview, #recent-errors, #cache-detail",
      );
      const href =
        focused?.tagName === "A" ? focused.getAttribute("href") : null;
      if (page === "overview") overview();
      else requests();
      if (scope && href)
        Array.from(scope.querySelectorAll("a"))
          .find((a) => a.getAttribute("href") === href)
          ?.focus({ preventScroll: true });
    } catch (error) {
      $("connection").classList.add("stale");
      $("connection-text").textContent =
        (error.name === "AbortError" ? "刷新超时" : "连接失败") +
        " · " +
        (data
          ? "上次数据已过时，请稍后重试"
          : "尚未获取数据，请检查后台连接后重试");
    } finally {
      clearTimeout(timer);
      busy = false;
      $("refresh").disabled = false;
      $("refresh").textContent = "刷新数据 ↻";
    }
  }
  if (page === "requests") {
    document
      .querySelectorAll("[data-category]")
      .forEach((b) =>
        b.setAttribute("aria-pressed", String(b.dataset.category === category)),
      );
    if (["failed", "success", "304"].includes(params.get("status")))
      $("status-filter").value = params.get("status");
    if (["hit", "miss", "unavailable", "unused"].includes(params.get("cache")))
      $("cache-filter").value = params.get("cache");
    $("search").oninput = rows;
    $("status-filter").onchange = rows;
    $("cache-filter").onchange = rows;
    document.querySelectorAll("[data-category]").forEach(
      (button) =>
        (button.onclick = () => {
          category = button.dataset.category;
          $("cache-filter").value = "all";
          if (data) requests();
          else
            document
              .querySelectorAll("[data-category]")
              .forEach((b) =>
                b.setAttribute("aria-pressed", String(b === button)),
              );
        }),
    );
  }
  $("refresh").onclick = refresh;
  $("auto-refresh").onchange = () => {
    if ($("auto-refresh").checked) refresh();
    else if (data && !$("connection").classList.contains("stale"))
      $("connection-text").textContent = "已连接 · 自动刷新已暂停";
  };
  if (page === "overview") {
    $("library-cards").replaceChildren(
      ...["漫画总数", "章节总数", "图片总数", "超分缓存"].map((t) =>
        metric(t, "—", "等待数据"),
      ),
    );
    $("traffic-cards").replaceChildren(
      ...["普通接口", "图片请求", "超分提交", "HTTP 异常"].map((t) =>
        metric(t, "—", "等待数据"),
      ),
    );
  } else
    $("category-cards").replaceChildren(
      ...["HTTP 请求", "失败 / 中断", "平均响应耗时", "已知响应体大小"].map(
        (t) => metric(t, "—", "等待数据"),
      ),
    );
  setInterval(() => {
    if ($("auto-refresh").checked && !document.hidden) refresh();
  }, 5000);
  refresh();
})();

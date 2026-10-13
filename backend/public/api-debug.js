"use strict";
const ENDPOINTS = [
  { method: "GET", url: "/api/admin/dashboard", label: "后台看板快照" },
  { method: "GET", url: "/api/health", label: "健康检查" },
  {
    method: "GET",
    url: "/api/comics?pageOffset=1&pageSize=20",
    label: "漫画列表",
    hint: "pageOffset 从 1 开始，pageSize 最多 100。",
  },
  {
    method: "GET",
    url: "/api/comics?keyword=关键词&pageOffset=1&pageSize=20",
    label: "搜索漫画与作者",
    hint: "将 keyword 改为漫画名或作者名。",
  },
  {
    method: "GET",
    url: "/api/comics?random=1&seed=123&pageOffset=1&pageSize=20",
    label: "固定种子随机列表",
    hint: "同一种子保持随机顺序，可分页并使用缓存；不传种子则每次重新随机。",
  },
  { method: "GET", url: "/api/comics/random", label: "随机漫画" },
  { method: "GET", url: "/api/comics/1", label: "漫画详情" },
  { method: "GET", url: "/api/chapters/1/images", label: "章节图片" },
  {
    method: "GET",
    url: "/api/super-resolution/monitor",
    label: "超分监视状态",
  },
  { method: "GET", url: "/api/mine/recent", label: "最近阅读" },
  { method: "GET", url: "/api/mine/favorites", label: "收藏漫画" },
  { method: "GET", url: "/api/favorite-authors", label: "收藏作者" },
  {
    method: "PUT",
    url: "/api/comics/1/progress",
    label: "更新阅读进度",
    body: { chapterId: 1, pageNumber: 0 },
    hint: "会覆盖阅读位置。章节必须属于该漫画，pageNumber 从 0 开始。",
  },
  {
    method: "POST",
    url: "/api/comics/1/favorite",
    label: "收藏漫画",
    hint: "会收藏地址中 ID 对应的漫画。",
  },
  {
    method: "DELETE",
    url: "/api/comics/1/favorite",
    label: "取消收藏漫画",
    hint: "会取消收藏，不删除漫画文件。",
  },
  {
    method: "POST",
    url: "/api/favorite-authors",
    label: "收藏作者",
    body: { author: "替换为作者名" },
    hint: "会收藏请求体中的作者。",
  },
  {
    method: "DELETE",
    url: "/api/favorite-authors",
    label: "取消收藏作者",
    body: { author: "替换为作者名" },
    hint: "会取消收藏请求体中的作者。",
  },
  {
    method: "POST",
    url: "/api/comics/1/open-directory",
    label: "打开漫画文件夹",
    hint: "会在后端所在电脑打开文件夹，请先替换漫画 ID。",
  },
  {
    method: "POST",
    url: "/api/images/resolve",
    label: "解析图片地址",
    body: {
      upscale: false,
      images: [{ id: 1, version: "替换为原图URL中的v参数", priority: 0 }],
    },
    hint: "先查章节图片，复制图片 ID 与 URL 的 v 参数。最多 11 张，priority 为 0–10；upscale 为 true 时可能启动超分。",
  },
  {
    method: "GET",
    url: "/api/super-resolution/policy",
    label: "超分策略与可用性",
    hint: "查询当前超分配置与运行可用性，可能探测 GPU。",
  },
  {
    method: "POST",
    url: "/api/super-resolution/jobs",
    label: "提交超分任务",
    body: { images: [{ id: 1, version: "替换为原图URL中的v参数" }] },
    hint: "最多 11 张；需要真实图片 ID 与版本。可能启动推理并占用 GPU。",
  },
  {
    method: "GET",
    url: "/api/super-resolution/jobs?keys=替换为任务key",
    label: "查询超分任务",
    hint: "填写提交或解析响应中的 64 位 key；多个 key 用逗号分隔，最多 11 个。",
  },
  {
    method: "GET",
    url: "/api/super-resolution/files/替换为任务key",
    label: "获取超分图片",
    hint: "填写已完成任务的 key；图片响应展示类型与大小。",
  },
  {
    method: "DELETE",
    url: "/api/super-resolution/cache",
    label: "清空超分缓存",
    hint: "会停止正在运行的超分任务、清空队列，并删除超分缓存文件。",
  },
];
const $ = (id) => document.getElementById(id);
let selected = 0,
  busy = false,
  confirming = false,
  responseText = "";
$("url-input").value = location.origin + ENDPOINTS[0].url;
function render() {
  const focused = document.activeElement?.closest(".endpoint")?.dataset.index;
  const query = $("search").value.trim().toLowerCase();
  const fragment = document.createDocumentFragment();
  ENDPOINTS.forEach((ep, index) => {
    if (!`${ep.label} ${ep.url} ${ep.method}`.toLowerCase().includes(query))
      return;
    const button = document.createElement("button");
    button.className = "endpoint" + (index === selected ? " active" : "");
    button.disabled = busy;
    button.dataset.index = String(index);
    button.setAttribute("aria-pressed", String(index === selected));
    const badge = document.createElement("span");
    badge.className = "method " + ep.method.toLowerCase();
    badge.textContent = ep.method;
    const description = document.createElement("span");
    description.className = "endpoint-copy";
    const title = document.createElement("strong");
    title.textContent = ep.label;
    const path = document.createElement("code");
    path.textContent = ep.url;
    description.append(title, path);
    button.append(badge, description);
    button.onclick = () => {
      selected = index;
      $("url-input").value = location.origin + ep.url;
      $("method").value = ep.method;
      $("request-body").value = ep.body ? JSON.stringify(ep.body, null, 2) : "";
      updateMethod();
      render();
    };
    fragment.append(button);
  });
  if (!fragment.childNodes.length) {
    const empty = document.createElement("p");
    empty.className = "empty";
    empty.textContent = "没有匹配的接口，试试其他关键词。";
    fragment.append(empty);
  }
  $("sidebar").replaceChildren(fragment);
  if (focused)
    Array.from($("sidebar").children)
      .find((button) => button.dataset.index === focused)
      ?.focus({ preventScroll: true });
}
function updateMethod() {
  const destructive = $("method").value === "DELETE";
  $("body-editor").hidden = $("method").value === "GET";
  $("body-error").textContent = "";
  $("send-btn").className = destructive ? "danger" : "primary";
  $("send-btn").textContent = busy
    ? "请求中…"
    : destructive
      ? "发送删除请求"
      : "发送请求";
  $("request-hint").textContent =
    ENDPOINTS[selected]?.hint ||
    ($("method").value === "GET"
      ? "默认连接当前后端，示例 ID 请替换为实际值；支持完整 URL 或相对路径。"
      : "此请求可能修改数据或触发操作，发送前需要确认。请检查地址与请求体。");
}
async function send(event) {
  event.preventDefault();
  if (busy || confirming) return;
  const url = $("url-input").value.trim();
  if (!url) return;
  const method = $("method").value;
  let body;
  if (method !== "GET" && $("request-body").value.trim()) {
    try {
      body = JSON.stringify(JSON.parse($("request-body").value));
    } catch {
      $("body-error").textContent =
        "JSON 格式不正确，请检查引号、逗号和括号；请求尚未发送。";
      $("request-body").focus();
      return;
    }
  }
  if (
    method !== "GET" &&
    !(await confirmRequest(
      `确认发送 ${method} 请求？\n${url}\n${$("request-hint").textContent}`,
    ))
  )
    return;
  busy = true;
  responseText = "";
  $("response-body").textContent = "正在等待后端响应…";
  $("meta-status").className = "";
  $("meta-status").textContent = "请求中";
  $("meta-time").textContent = "—";
  $("meta-size").textContent = "—";
  $("copy-feedback").textContent = "";
  $("copy-btn").disabled = true;
  for (const id of ["send-btn", "method", "url-input", "request-body"])
    $(id).disabled = true;
  for (const button of $("sidebar").querySelectorAll("button"))
    button.disabled = true;
  updateMethod();
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);
  const start = performance.now();
  try {
    const response = await fetch(url, {
      method,
      body,
      headers:
        body === undefined ? undefined : { "Content-Type": "application/json" },
      signal: controller.signal,
      cache: "no-store",
    });
    const blob = await response.blob();
    const type = response.headers.get("Content-Type") || "";
    if (
      type.startsWith("image/") ||
      type.includes("application/octet-stream")
    ) {
      responseText = `二进制响应 · ${type}\n大小：${formatBytes(blob.size)}\n可复制请求地址，在浏览器中查看图片。`;
    } else {
      const raw = await blob.text();
      try {
        responseText = JSON.stringify(JSON.parse(raw), null, 2);
      } catch {
        responseText = raw;
      }
    }
    $("response-body").textContent = responseText || "响应内容为空。";
    $("meta-status").textContent =
      `${response.status} ${response.statusText}`.trim();
    $("meta-status").className = response.ok ? "status-ok" : "status-err";
    $("meta-size").textContent = formatBytes(blob.size);
    $("copy-btn").disabled = !responseText;
  } catch (error) {
    $("meta-status").textContent =
      error.name === "AbortError" ? "请求超时" : "请求失败";
    $("meta-status").className = "status-err";
    $("response-body").textContent =
      error.name === "AbortError"
        ? "请求超过 30 秒，请检查后端后重试。"
        : `无法获取响应，请检查地址、后端连接和跨域设置。\n${error.message}`;
  } finally {
    clearTimeout(timeout);
    $("meta-time").textContent = `${Math.round(performance.now() - start)} ms`;
    busy = false;
    for (const id of ["send-btn", "method", "url-input", "request-body"])
      $(id).disabled = false;
    for (const button of $("sidebar").querySelectorAll("button"))
      button.disabled = false;
    updateMethod();
  }
}
$("request-form").onsubmit = send;
$("search").oninput = render;
$("method").onchange = () => {
  selected = -1;
  updateMethod();
  render();
};
$("url-input").oninput = () => {
  selected = -1;
  updateMethod();
  for (const button of $("sidebar").querySelectorAll("button")) {
    button.classList.remove("active");
    button.setAttribute("aria-pressed", "false");
  }
};
$("copy-btn").onclick = async () => {
  const snapshot = responseText;
  $("copy-btn").disabled = true;
  try {
    await navigator.clipboard.writeText(snapshot);
    $("copy-feedback").textContent = "已复制";
  } catch {
    $("copy-feedback").textContent = "复制不可用，请选中响应内容复制。";
  } finally {
    $("copy-btn").disabled = busy || !responseText;
  }
};
function formatBytes(bytes) {
  return bytes >= 1e9
    ? (bytes / 1e9).toFixed(2) + " GB"
    : bytes >= 1e6
      ? (bytes / 1e6).toFixed(1) + " MB"
      : bytes >= 1e3
        ? (bytes / 1e3).toFixed(1) + " KB"
        : bytes + " B";
}
function confirmRequest(message) {
  confirming = true;
  const dialog = $("confirm-request");
  $("confirm-details").textContent = message;
  dialog.returnValue = "cancel";
  return new Promise((resolve) => {
    dialog.addEventListener(
      "close",
      () => {
        confirming = false;
        resolve(dialog.returnValue === "send");
      },
      { once: true },
    );
    dialog.showModal();
  });
}
updateMethod();
render();

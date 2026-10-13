(() => {
  document.body.classList.add("workbench");
  const nav = document.createElement("nav");
  nav.className = "rail";
  nav.setAttribute("aria-label", "后台主导航");
  nav.innerHTML = `<a class="rail-brand" href="/"><span class="rail-mark">漫</span><span>漫画后台<small>COMIC WORKSPACE</small></span></a><div class="rail-label">工作空间</div>`;
  for (const [url, title, icon] of [
    ["/", "总览", "◫"],
    ["/requests.html", "请求与缓存", "⇄"],
    ["/super-resolution-monitor.html", "超分监视", "✧"],
    ["/api-debug.html", "API 调试", "⌘"],
  ]) {
    const link = document.createElement("a");
    link.href = url;
    link.className = "nav-item";
    const mark = document.createElement("span");
    mark.className = "nav-icon";
    mark.setAttribute("aria-hidden", "true");
    mark.textContent = icon;
    link.append(mark, title);
    if (
      location.pathname === url ||
      (url === "/" && location.pathname === "/index.html")
    )
      link.setAttribute("aria-current", "page");
    nav.append(link);
  }
  const foot = document.createElement("div");
  foot.className = "rail-foot";
  foot.innerHTML =
    "<strong>本地漫画 · 运行工作台</strong>观察请求，了解每一次处理。";
  nav.append(foot);
  document.body.prepend(nav);
})();

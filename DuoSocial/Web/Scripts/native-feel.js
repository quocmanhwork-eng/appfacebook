// DuoSocial — làm trang Facebook/Messenger trông và phản hồi giống ứng dụng hơn.
//
// Chạy ở đầu mỗi trang (main frame). Cấu hình do app đặt trước trong window.__duoSocialConfig:
//   hideWebTabBar: ẩn thanh tab của chính trang Facebook vì app đã có thanh tab riêng.
//
// Mọi thao tác ẩn đều thận trọng: chỉ ẩn khi dấu hiệu rất rõ, và không bao giờ làm hỏng trang nếu lỗi.
(() => {
  if (window.__duoSocialNativeFeel) return;

  const config = Object.assign({ hideWebTabBar: false }, window.__duoSocialConfig || {});
  const api = (window.__duoSocialNativeFeel = { config, hidden: [], tabRow: null });

  const STYLE_ID = 'duosocial-native-feel';
  const HIDDEN_ATTR = 'data-duosocial-hidden';
  const CSS = `
    html {
      -webkit-text-size-adjust: 100% !important;
      -webkit-tap-highlight-color: transparent;
      touch-action: manipulation; /* bỏ phóng to khi chạm đúp và độ trễ chạm */
    }
    * { -webkit-tap-highlight-color: transparent; }
    a, button, img, svg, [role="button"], [role="link"], [role="tab"], [role="tablist"],
    [role="menuitem"], [role="navigation"], [role="toolbar"] {
      -webkit-user-select: none;
      user-select: none;
    }
    a, [role="button"], [role="link"], [role="tab"] { -webkit-touch-callout: none; }
    input, textarea, [contenteditable="true"], [contenteditable=""], [contenteditable="plaintext-only"] {
      -webkit-user-select: text;
      user-select: text;
      -webkit-touch-callout: default;
    }
    [${HIDDEN_ATTR}] { display: none !important; }
  `;

  // Link/nút mời tải app chính thức (App Store, mở app Facebook/Messenger).
  const APP_LINK =
    /^(itms-apps?|itms-appss|fb|fb-messenger|fbapi|fb-messenger-api|fbauth2?):|apps\.apple\.com|itunes\.apple\.com|\/mobile\/messenger|messenger\.com\/(download|mobile)|\/(download|install|get)[_-]?app/i;

  // Nút mời mở/tải app chính thức, nhận ra qua chữ hiển thị (Facebook thường dùng nút JavaScript, không phải link).
  const APP_BUTTON_TEXT =
    /^(mở ứng dụng|mở trong ứng dụng|mở app|mở bằng ứng dụng|dùng ứng dụng|sử dụng ứng dụng|tải ứng dụng|tải xuống ứng dụng|cài đặt ứng dụng|tiếp tục trong ứng dụng|open app|open in app|open the app|use app|use the app|get app|get the app|install app|download app|continue in app|open facebook app|open messenger)$/i;

  // Các tab của Facebook: nhận ra qua đường dẫn hoặc nhãn (tiếng Anh/Việt).
  const TABS = [
    ['home', ['home', 'trang chủ', 'bảng feed', 'feed'], [/^\/(home\.php)?$/]],
    ['friends', ['friends', 'bạn bè'], [/^\/friends/]],
    ['video', ['video', 'videos', 'watch', 'reels', 'thước phim'], [/^\/(watch|video|reel)/]],
    ['marketplace', ['marketplace', 'chợ'], [/^\/marketplace/]],
    ['notifications', ['notifications', 'thông báo'], [/^\/notifications/]],
    ['menu', ['menu'], [/^\/(bookmarks|menu)/]],
  ];
  // Không ẩn vùng chứa ô tìm kiếm hay nút Messenger/tạo bài — đó không phải thanh tab.
  const KEEP_SELECTOR =
    'input, textarea, [aria-label*="search" i], [aria-label*="tìm" i], [aria-label*="messenger" i], [aria-label*="tin nhắn" i], [aria-label*="create" i], [aria-label*="tạo" i]';

  const addStyle = () => {
    if (document.getElementById(STYLE_ID)) return;
    const style = document.createElement('style');
    style.id = STYLE_ID;
    style.textContent = CSS;
    (document.head || document.documentElement).appendChild(style);
  };

  const mark = (element, reason) => {
    if (element.hasAttribute(HIDDEN_ATTR)) return;
    element.setAttribute(HIDDEN_ATTR, reason);
    api.hidden.push({ element, reason });
  };

  const labelMatches = (label, name) => {
    if (!label.startsWith(name)) return false;
    const next = label.charAt(name.length);
    return next === '' || /[\s,.:;(·|\-–—\d]/.test(next);
  };

  const tabKind = (element) => {
    let path = null;
    if (element.tagName === 'A') {
      try {
        const url = new URL(element.getAttribute('href') || '', location.href);
        if (/(^|\.)facebook\.com$/i.test(url.hostname)) path = url.pathname.toLowerCase();
      } catch (error) {
        path = null;
      }
    }
    const aria = (element.getAttribute('aria-label') || '').trim().toLowerCase();
    const text = aria || (element.textContent || '').trim().toLowerCase().slice(0, 40);
    for (const [kind, labels, paths] of TABS) {
      if (path !== null && paths.some((pattern) => pattern.test(path))) return kind;
      if (text && labels.some((name) => labelMatches(text, name))) return kind;
    }
    return null;
  };

  // Thanh tab của trang: vùng nhỏ ở đầu trang chứa ít nhất 4 loại tab khác nhau.
  const findWebTabRow = () => {
    const items = [];
    const nodes = document.querySelectorAll('a[href], [role="tab"], [role="button"][aria-label], [role="link"][aria-label]');
    for (let index = 0; index < nodes.length && index < 1200; index += 1) {
      const element = nodes[index];
      const kind = tabKind(element);
      if (!kind) continue;
      const rect = element.getBoundingClientRect();
      if (rect.height === 0 || rect.height > 90 || rect.top > 220 || rect.bottom < 0) continue;
      items.push({ element, kind });
    }
    if (new Set(items.map((item) => item.kind)).size < 4) return null;

    // Với mỗi tab, tìm vùng gần nhất chứa ≥4 loại tab; chọn vùng sâu nhất (chính là hàng tab,
    // không phải cả phần đầu trang chứa logo và ô tìm kiếm).
    const candidates = new Set();
    for (const { element } of items) {
      let node = element.parentElement;
      for (let depth = 0; node && node !== document.body && depth < 8; depth += 1, node = node.parentElement) {
        const container = node;
        const kinds = new Set(items.filter((item) => container.contains(item.element)).map((item) => item.kind));
        if (kinds.size >= 4) {
          candidates.add(container);
          break;
        }
      }
    }
    const deepest = [...candidates].filter((candidate) => ![...candidates].some((other) => other !== candidate && candidate.contains(other)));
    for (const container of deepest) {
      const rect = container.getBoundingClientRect();
      const looksLikeTabRow = rect.height > 0 && rect.height <= 110 && rect.top < 220;
      if (looksLikeTabRow && !container.querySelector(KEEP_SELECTOR)) return container;
    }
    return null;
  };

  // Ẩn thanh nổi (fixed/sticky) nhỏ chứa phần tử; không đụng nội dung bình thường hay lớp phủ toàn màn hình.
  const hideFloatingAncestor = (element, reason) => {
    let node = element;
    for (let depth = 0; node && node !== document.body && depth < 12; depth += 1, node = node.parentElement) {
      const position = getComputedStyle(node).position;
      if (position !== 'fixed' && position !== 'sticky') continue;
      const rect = node.getBoundingClientRect();
      if (rect.height > 0 && rect.height < 240 && !node.hasAttribute(HIDDEN_ATTR)) {
        mark(node, reason);
        return true;
      }
      return false;
    }
    return false;
  };

  // Banner/nút nổi mời mở hoặc tải app chính thức.
  const hideAppBanners = () => {
    let found = false;
    const links = document.querySelectorAll('a[href]');
    for (let index = 0; index < links.length; index += 1) {
      const link = links[index];
      if (APP_LINK.test(link.getAttribute('href') || '')) found = hideFloatingAncestor(link, 'app-banner') || found;
    }
    const buttons = document.querySelectorAll('a, button, [role="button"], [role="link"]');
    for (let index = 0; index < buttons.length; index += 1) {
      const button = buttons[index];
      if (button.childElementCount > 6) continue;
      const text = (button.textContent || '').trim().replace(/\s+/g, ' ');
      if (text.length === 0 || text.length > 40 || !APP_BUTTON_TEXT.test(text)) continue;
      found = hideFloatingAncestor(button, 'app-button') || found;
    }
    return found;
  };

  let scheduled = false;
  let misses = 0;

  const run = () => {
    scheduled = false;
    try {
      addStyle();
      let found = hideAppBanners();
      if (config.hideWebTabBar && !(api.tabRow && api.tabRow.isConnected)) {
        const row = findWebTabRow();
        if (row) {
          api.tabRow = row;
          mark(row, 'web-tab-bar');
          found = true;
        }
      }
      misses = found ? 0 : misses + 1;
    } catch (error) {
      // Không bao giờ làm hỏng trang vì phần trang trí này.
    }
  };

  const schedule = () => {
    if (scheduled) return;
    scheduled = true;
    // Facebook cập nhật DOM liên tục: gom lại và chậm dần nếu không có gì để ẩn.
    setTimeout(run, misses > 15 ? 4000 : 600);
  };

  api.restore = () => {
    for (const { element } of api.hidden) element.removeAttribute(HIDDEN_ATTR);
    api.hidden = [];
    api.tabRow = null;
  };

  // Facebook là ứng dụng một trang: khi chuyển trang thì quét lại ngay, không chờ nhịp chậm.
  const onRouteChange = () => {
    misses = 0;
    scheduled = false;
    schedule();
  };
  for (const method of ['pushState', 'replaceState']) {
    const original = history[method];
    if (typeof original !== 'function') continue;
    history[method] = function (...args) {
      const result = original.apply(this, args);
      onRouteChange();
      return result;
    };
  }
  window.addEventListener('popstate', onRouteChange);

  addStyle();
  const start = () => {
    run();
    new MutationObserver(schedule).observe(document.documentElement, { childList: true, subtree: true });
  };
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();

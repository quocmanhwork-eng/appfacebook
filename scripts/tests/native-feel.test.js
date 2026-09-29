// Kiểm tra native-feel.js trên các trang giả lập giống Facebook (jsdom không tính layout nên
// vị trí/kích thước được giả bằng thuộc tính data-top / data-h).
//
// Chạy: npm install --no-save jsdom@24 && node scripts/tests/native-feel.test.js
const { JSDOM } = require('jsdom');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const SCRIPT = fs.readFileSync(path.join(__dirname, '..', '..', 'DuoSocial', 'Web', 'Scripts', 'native-feel.js'), 'utf8');

// Layout giả: đọc data-top / data-h cho getBoundingClientRect (jsdom không tính layout).
async function page(html, config) {
  const dom = new JSDOM(`<!doctype html><html><head></head><body>${html}</body></html>`,
    { url: 'https://m.facebook.com/', runScripts: 'outside-only', pretendToBeVisual: true });
  const w = dom.window;
  w.Element.prototype.getBoundingClientRect = function () {
    let top = 0, h = 0;
    for (let n = this; n && n.getAttribute; n = n.parentElement) {
      if (n.hasAttribute('data-h') && h === 0) h = Number(n.getAttribute('data-h'));
      if (n.hasAttribute('data-top')) { top = Number(n.getAttribute('data-top')); break; }
    }
    if (this.hasAttribute('data-h')) h = Number(this.getAttribute('data-h'));
    return { top, bottom: top + h, height: h, width: 390, left: 0, right: 390 };
  };
  if (config) w.eval(`window.__duoSocialConfig = ${JSON.stringify(config)};`);
  w.eval(SCRIPT);
  if (w.document.readyState === 'loading') await new Promise((r) => w.document.addEventListener('DOMContentLoaded', r, { once: true }));
  await new Promise((r) => setTimeout(r, 20));
  return w;
}
const hidden = (w, sel) => w.document.querySelector(sel).hasAttribute('data-duosocial-hidden');
const tabs = (attrs) => attrs.map(([href, label]) => `<a href="${href}" aria-label="${label}" data-h="44">${label}</a>`).join('');
const VI_TABS = tabs([['/', 'Trang chủ'], ['/friends/', 'Bạn bè'], ['/watch/', 'Video'], ['/marketplace/', 'Marketplace'], ['/notifications/', 'Thông báo, 3 mới'], ['/bookmarks/', 'Menu']]);
const LOGO_ROW = `<div id="logo" data-top="0" data-h="48"><a href="/" aria-label="Facebook" data-h="40">facebook</a><div role="button" aria-label="Tìm kiếm" data-h="36"></div><div role="button" aria-label="Messenger" data-h="36"></div></div>`;
let passed = 0;
const test = async (name, fn) => { await fn(); passed += 1; console.log('  ✓', name); };

(async () => {
  await test('style được chèn và không chèn trùng', async () => {
    const w = await page('', { hideWebTabBar: true });
    w.eval(SCRIPT);
    assert.strictEqual(w.document.querySelectorAll('#duosocial-native-feel').length, 1);
    assert.match(w.document.getElementById('duosocial-native-feel').textContent, /touch-action: manipulation/);
  });

  await test('ẩn thanh tab (link) của m.facebook.com, giữ hàng logo + tìm kiếm', async () => {
    const w = await page(`<header>${LOGO_ROW}<div id="tabs" data-top="48" data-h="52">${VI_TABS}</div></header>
      <main data-top="400" data-h="600"><a href="/watch/?v=1" data-h="200">Video hay quá</a></main>`, { hideWebTabBar: true });
    assert.ok(hidden(w, '#tabs'), 'tab row should be hidden');
    assert.ok(!hidden(w, '#logo'), 'logo row must stay');
    assert.strictEqual(w.__duoSocialNativeFeel.hidden.length, 1);
  });

  await test('ẩn thanh tab dạng role="tab" không có href (nhãn tiếng Anh kèm số)', async () => {
    const t = ['Home, tab 1 of 6', 'Friends, tab 2 of 6', 'Video, tab 3 of 6', 'Marketplace, tab 4 of 6', 'Notifications, 12 new', 'Menu, tab 6 of 6']
      .map((l) => `<div role="tab" aria-label="${l}" data-h="44"></div>`).join('');
    const w = await page(`${LOGO_ROW}<div id="tabs" role="tablist" data-top="48" data-h="52">${t}</div>`, { hideWebTabBar: true });
    assert.ok(hidden(w, '#tabs'));
  });

  await test('KHÔNG ẩn khi tab nằm chung vùng với ô tìm kiếm', async () => {
    const w = await page(`<div id="bar" data-top="0" data-h="56">${VI_TABS}<div role="button" aria-label="Tìm kiếm" data-h="36"></div></div>`, { hideWebTabBar: true });
    assert.ok(!hidden(w, '#bar'));
  });

  await test('KHÔNG ẩn khi tắt tùy chọn hideWebTabBar', async () => {
    const w = await page(`${LOGO_ROW}<div id="tabs" data-top="48" data-h="52">${VI_TABS}</div>`, { hideWebTabBar: false });
    assert.ok(!hidden(w, '#tabs'));
  });

  await test('KHÔNG ẩn trang cá nhân chỉ có vài link Bạn bè/Video ở đầu trang', async () => {
    const w = await page(`<div id="profile" data-top="60" data-h="80">${tabs([['/profile.php?sk=friends', 'Bạn bè'], ['/profile.php?sk=videos', 'Video'], ['/profile.php?sk=photos', 'Ảnh']])}</div>`, { hideWebTabBar: true });
    assert.strictEqual(w.__duoSocialNativeFeel.hidden.length, 0);
  });

  await test('KHÔNG ẩn link giống tab nhưng nằm sâu trong bảng tin', async () => {
    const w = await page(`<div id="feed" data-top="500" data-h="80">${VI_TABS}</div>`, { hideWebTabBar: true });
    assert.ok(!hidden(w, '#feed'));
  });

  await test('KHÔNG ẩn vùng quá cao (không phải một hàng tab)', async () => {
    const w = await page(`<div id="big" data-top="40" data-h="400">${VI_TABS}</div>`, { hideWebTabBar: true });
    assert.ok(!hidden(w, '#big'));
  });

  await test('ẩn banner nổi mời tải app, không đụng link App Store trong bài viết', async () => {
    const w = await page(`<div id="banner" style="position:fixed" data-top="780" data-h="64"><span>Facebook tốt hơn trên ứng dụng</span><a href="https://apps.apple.com/app/facebook/id284882215">Mở ứng dụng</a></div>
      <article id="post" data-top="300" data-h="200"><a href="https://apps.apple.com/app/some-game/id1">Tải game này</a></article>
      <div id="msgr" style="position:sticky" data-top="0" data-h="50"><a href="fb-messenger://threads">Mở Messenger</a></div>`, { hideWebTabBar: false });
    assert.ok(hidden(w, '#banner'));
    assert.ok(hidden(w, '#msgr'));
    assert.ok(!hidden(w, '#post'));
  });

  await test('KHÔNG ẩn lớp phủ lớn toàn màn hình (người dùng tự bấm "Lúc khác")', async () => {
    const w = await page(`<div id="interstitial" style="position:fixed" data-top="0" data-h="800"><a href="https://apps.apple.com/app/id284882215">Mở ứng dụng</a><button>Lúc khác</button></div>`, {});
    assert.ok(!hidden(w, '#interstitial'));
  });

  await test('ẩn nút "Mở ứng dụng" (nút JavaScript) trong thanh nổi ở đáy — như ảnh chụp thật', async () => {
    const w = await page(`<main data-top="0" data-h="2000"><article id="post"><p>Bài viết</p></article></main>
      <div id="footer" style="position:fixed" data-top="700" data-h="96"><div><div role="button" tabindex="0"><span>Mở ứng dụng</span></div></div></div>`, { hideWebTabBar: true });
    assert.ok(hidden(w, '#footer'));
    assert.ok(!hidden(w, '#post'));
  });

  await test('ẩn nút "Open app" tiếng Anh', async () => {
    const w = await page(`<div id="footer" style="position:sticky" data-top="700" data-h="80"><button>  Open   app </button></div>`, {});
    assert.ok(hidden(w, '#footer'));
  });

  await test('KHÔNG ẩn nút "Mở ứng dụng" nằm trong nội dung bình thường', async () => {
    const w = await page(`<article id="post" data-top="300" data-h="300"><div role="button">Mở ứng dụng</div></article>`, {});
    assert.ok(!hidden(w, '#post'));
    assert.strictEqual(w.__duoSocialNativeFeel.hidden.length, 0);
  });

  await test('KHÔNG ẩn thanh nổi có chữ dài chỉ nhắc tới ứng dụng', async () => {
    const w = await page(`<div id="bar" style="position:fixed" data-top="0" data-h="60"><div role="button">Mở ứng dụng để xem thêm bình luận của bạn bè</div></div>`, {});
    assert.ok(!hidden(w, '#bar'));
  });

  await test('KHÔNG ẩn thanh điều hướng nổi chỉ vì có nút khác', async () => {
    const w = await page(`<div id="nav" style="position:fixed" data-top="0" data-h="56"><div role="button" aria-label="Tìm kiếm">Tìm kiếm</div><div role="button">Menu</div></div>`, {});
    assert.ok(!hidden(w, '#nav'));
  });

  await test('quét lại ngay khi Facebook chuyển trang bằng history.pushState', async () => {
    const w = await page(`<main data-top="0" data-h="2000"></main>`, {});
    const footer = w.document.createElement('div');
    footer.id = 'footer'; footer.style.position = 'fixed';
    footer.setAttribute('data-top', '700'); footer.setAttribute('data-h', '96');
    footer.innerHTML = '<div role="button">Mở ứng dụng</div>';
    w.document.body.appendChild(footer);
    w.history.pushState({}, '', '/watch/');
    await new Promise((r) => setTimeout(r, 800));
    assert.ok(hidden(w, '#footer'));
    assert.strictEqual(w.location.pathname, '/watch/', 'pushState vẫn hoạt động bình thường');
  });

  await test('nhận ra thanh tab được Facebook vẽ thêm sau khi trang tải (MutationObserver)', async () => {
    const w = await page(LOGO_ROW, { hideWebTabBar: true });
    const row = w.document.createElement('div');
    row.id = 'tabs'; row.setAttribute('data-top', '48'); row.setAttribute('data-h', '52'); row.innerHTML = VI_TABS;
    w.document.body.appendChild(row);
    await new Promise((r) => setTimeout(r, 800));
    assert.ok(hidden(w, '#tabs'));
  });

  await test('restore() hiện lại mọi thứ đã ẩn', async () => {
    const w = await page(`${LOGO_ROW}<div id="tabs" data-top="48" data-h="52">${VI_TABS}</div>`, { hideWebTabBar: true });
    w.__duoSocialNativeFeel.restore();
    assert.ok(!hidden(w, '#tabs'));
  });

  await test('chạy được khi được chèn lúc document còn đang tải (documentStart)', async () => {
    const dom = new JSDOM('', { url: 'https://m.facebook.com/', runScripts: 'outside-only' });
    const w = dom.window;
    Object.defineProperty(w.document, 'readyState', { value: 'loading', configurable: true });
    w.eval(SCRIPT);
    assert.ok(w.__duoSocialNativeFeel, 'api exposed');
    assert.ok(w.document.getElementById('duosocial-native-feel'), 'style added early');
    w.document.dispatchEvent(new w.Event('DOMContentLoaded'));
  });

  console.log(`\n${passed} test đều qua`);
  process.exit(0);
})().catch((error) => { console.error('✗ FAILED:', error.message); process.exit(1); });

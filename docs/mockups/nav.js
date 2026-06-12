// Gamepad-style navigation for the mockups.
//
// Keyboard: arrows = d-pad, Enter = A (select), Escape/Backspace = B (back).
// Real controller (Chrome Gamepad API): d-pad / left stick to move,
// A to select, B to back. Held directions auto-repeat like a real game menu.

(function () {
  // ---- stage scaling: fit the 1920x1080 stage to the window ----
  function fit() {
    const stage = document.querySelector('.stage');
    const s = Math.min(window.innerWidth / 1920, window.innerHeight / 1080);
    stage.style.transform = `translate(-50%, -50%) scale(${s})`;
  }
  window.addEventListener('resize', fit);

  // ---- focus model ----
  let items = [];
  let idx = 0;

  function refresh() {
    items = Array.from(document.querySelectorAll('[data-focusable]'));
    if (!items.length) return;
    idx = Math.max(0, items.findIndex(el => el.classList.contains('focused')));
    apply();
  }

  function apply() {
    items.forEach((el, i) => el.classList.toggle('focused', i === idx));
    document.dispatchEvent(new CustomEvent('navfocus', { detail: items[idx] }));
  }

  function move(dir) {
    if (!items.length) return;
    const horizontal = items[idx]?.closest('[data-nav="row"]') !== null;
    const axisOk = horizontal ? (dir === 'left' || dir === 'right')
                              : (dir === 'up' || dir === 'down');
    if (!axisOk) return;
    const fwd = dir === 'down' || dir === 'right';
    idx = (idx + (fwd ? 1 : -1) + items.length) % items.length;
    apply();
  }

  function select() {
    const href = items[idx]?.dataset.href;
    if (href) location.href = href;
  }

  function back() {
    const dest = document.body.dataset.back;
    if (dest) location.href = dest;
  }

  // ---- keyboard ----
  document.addEventListener('keydown', (e) => {
    const map = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' };
    if (map[e.key]) { move(map[e.key]); e.preventDefault(); }
    else if (e.key === 'Enter') select();
    else if (e.key === 'Escape' || e.key === 'Backspace') back();
  });

  // ---- gamepad (standard mapping: 0=A 1=B 12-15=dpad, axes 0/1=left stick) ----
  const DEADZONE = 0.5;
  const REPEAT_DELAY = 400;   // ms before a held direction repeats
  const REPEAT_RATE = 130;    // ms between repeats
  const dirState = { up: 0, down: 0, left: 0, right: 0 };  // 0 = released, else next-fire time
  let prevA = false, prevB = false;
  let toast = null, toastTimer = 0;

  function showToast(text) {
    if (!toast) {
      toast = document.createElement('div');
      toast.style.cssText =
        'position:fixed; right:24px; bottom:24px; z-index:99; padding:10px 18px;' +
        'background:rgba(20,23,29,0.92); border:1px solid rgba(255,163,26,0.5);' +
        'border-radius:8px; color:#e8e6e1; font:14px "Segoe UI",sans-serif;' +
        'letter-spacing:0.05em; transition:opacity 0.4s; pointer-events:none';
      document.body.appendChild(toast);
    }
    toast.textContent = text;
    toast.style.opacity = '1';
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { toast.style.opacity = '0'; }, 2500);
  }

  window.addEventListener('gamepadconnected', (e) =>
    showToast('\u{1F3AE} ' + e.gamepad.id.replace(/\s*\(.*\)$/, '')));

  function dirHeld(gp, dir) {
    const b = gp.buttons;
    switch (dir) {
      case 'up':    return b[12]?.pressed || gp.axes[1] < -DEADZONE;
      case 'down':  return b[13]?.pressed || gp.axes[1] >  DEADZONE;
      case 'left':  return b[14]?.pressed || gp.axes[0] < -DEADZONE;
      case 'right': return b[15]?.pressed || gp.axes[0] >  DEADZONE;
    }
  }

  function pollGamepad(now) {
    const gp = Array.from(navigator.getGamepads?.() || []).find(g => g && g.connected);
    if (gp) {
      for (const dir of Object.keys(dirState)) {
        if (dirHeld(gp, dir)) {
          if (dirState[dir] === 0) {            // fresh press
            move(dir);
            dirState[dir] = now + REPEAT_DELAY;
          } else if (now >= dirState[dir]) {    // held: auto-repeat
            move(dir);
            dirState[dir] = now + REPEAT_RATE;
          }
        } else {
          dirState[dir] = 0;
        }
      }
      const a = gp.buttons[0]?.pressed, b = gp.buttons[1]?.pressed;
      if (a && !prevA) select();
      if (b && !prevB) back();
      prevA = a; prevB = b;
    }
    requestAnimationFrame(pollGamepad);
  }

  document.addEventListener('DOMContentLoaded', () => {
    fit();
    refresh();
    requestAnimationFrame(pollGamepad);
  });
})();

// ==========================================================================
// ChomiamOS Installer - Tauri v2 Controller
// ==========================================================================

let currentStep = 1;
const totalSteps = 7;
let availableLayouts = [];
let detectedGpuDriver = "amd";
let availableDisks = [];
let availableDesktops = [];

// Reliable IPC Helper for Tauri v2
async function ensureTauri() {
  if (window.__TAURI__?.core?.invoke || window.__TAURI_INTERNALS__?.invoke) {
    return true;
  }
  for (let i = 0; i < 50; i++) {
    await new Promise(r => setTimeout(r, 20));
    if (window.__TAURI__?.core?.invoke || window.__TAURI_INTERNALS__?.invoke) {
      return true;
    }
  }
  return false;
}

async function invoke(cmd, args = {}) {
  await ensureTauri();
  if (window.__TAURI__?.core?.invoke) {
    return window.__TAURI__.core.invoke(cmd, args);
  }
  if (window.__TAURI_INTERNALS__?.invoke) {
    return window.__TAURI_INTERNALS__.invoke(cmd, args);
  }
  console.error("Tauri invoke non disponible pour:", cmd);
  throw new Error("Tauri IPC non disponible");
}

async function listen(event, cb) {
  await ensureTauri();
  if (window.__TAURI__?.event?.listen) {
    return window.__TAURI__.event.listen(event, cb);
  }
  if (window.__TAURI_INTERNALS__?.listen) {
    return window.__TAURI_INTERNALS__.listen(event, cb);
  }
  return () => {};
}

document.addEventListener('DOMContentLoaded', async () => {
  initNavigation();
  await loadPrerequisites();
  await loadDesktops();
  await loadKeyboardLayouts();
  await loadTimezones();
  await loadDisks();
  initSwapSlider();
  initPasswordSecurity();
  initSummaryTrigger();
  initConfirmationModal();
  await initUpdateManager();
});


function initPasswordSecurity() {
  const pwdInput = document.getElementById('input-password');
  const confirmInput = document.getElementById('input-password-confirm');
  const chkStrong = document.getElementById('chk-strong-password');
  const barFill = document.getElementById('password-strength-bar');
  const badge = document.getElementById('password-strength-badge');
  const matchFeedback = document.getElementById('password-match-feedback');

  const critLength = document.getElementById('crit-length');
  const critUpper = document.getElementById('crit-upper');
  const critDigit = document.getElementById('crit-digit');
  const critSpecial = document.getElementById('crit-special');

  function evaluatePassword() {
    const pwd = pwdInput ? pwdInput.value : '';
    const confirm = confirmInput ? confirmInput.value : '';

    if (!pwd) {
      if (barFill) {
        barFill.style.width = '0%';
        barFill.className = 'strength-bar-fill';
      }
      if (badge) {
        badge.textContent = 'Non renseigné';
        badge.className = 'strength-badge none';
      }
      [critLength, critUpper, critDigit, critSpecial].forEach(el => {
        if (el) {
          el.classList.remove('valid');
          const icon = el.querySelector('.crit-icon');
          if (icon) icon.textContent = '○';
        }
      });
    } else {
      const hasLength = pwd.length >= 8;
      const hasUpper = /[A-Z]/.test(pwd);
      const hasDigit = /[0-9]/.test(pwd);
      const hasSpecial = /[^A-Za-z0-9]/.test(pwd);

      updateCrit(critLength, hasLength);
      updateCrit(critUpper, hasUpper);
      updateCrit(critDigit, hasDigit);
      updateCrit(critSpecial, hasSpecial);

      let score = 0;
      if (hasLength) score++;
      if (hasUpper) score++;
      if (hasDigit) score++;
      if (hasSpecial) score++;

      if (barFill && badge) {
        barFill.className = 'strength-bar-fill';
        if (score <= 1) {
          barFill.style.width = '25%';
          barFill.classList.add('weak');
          badge.textContent = 'Très faible';
          badge.className = 'strength-badge weak';
        } else if (score === 2) {
          barFill.style.width = '50%';
          barFill.classList.add('medium');
          badge.textContent = 'Faible';
          badge.className = 'strength-badge medium';
        } else if (score === 3) {
          barFill.style.width = '75%';
          barFill.classList.add('good');
          badge.textContent = 'Moyen';
          badge.className = 'strength-badge good';
        } else {
          barFill.style.width = '100%';
          barFill.classList.add('strong');
          badge.textContent = 'Fort (Sécurisé)';
          badge.className = 'strength-badge strong';
        }
      }
    }

    // Concordance
    if (!confirm) {
      if (matchFeedback) {
        matchFeedback.textContent = '';
        matchFeedback.className = 'password-feedback';
      }
    } else if (pwd === confirm) {
      if (matchFeedback) {
        matchFeedback.textContent = '✓ Les mots de passe correspondent';
        matchFeedback.className = 'password-feedback match';
      }
    } else {
      if (matchFeedback) {
        matchFeedback.textContent = '✗ Les mots de passe ne correspondent pas';
        matchFeedback.className = 'password-feedback mismatch';
      }
    }
  }

  function updateCrit(el, isValid) {
    if (!el) return;
    const icon = el.querySelector('.crit-icon');
    if (isValid) {
      el.classList.add('valid');
      if (icon) icon.textContent = '✓';
    } else {
      el.classList.remove('valid');
      if (icon) icon.textContent = '○';
    }
  }

  if (pwdInput) pwdInput.addEventListener('input', evaluatePassword);
  if (confirmInput) confirmInput.addEventListener('input', evaluatePassword);
  if (chkStrong) chkStrong.addEventListener('change', evaluatePassword);
}

function validateStep(step) {
  if (step === 3) {
    const selectedDisk = document.querySelector('.disk-card.selected');
    if (!selectedDisk && availableDisks.length === 0) {
      alert("Aucun disque disponible sélectionné pour l'installation.");
      return false;
    }
  }
  if (step === 6) {
    const username = document.getElementById('input-username')?.value.trim();
    if (!username) {
      alert("Veuillez saisir un nom d'utilisateur (login).");
      return false;
    }
    const pwd = document.getElementById('input-password')?.value || '';
    const confirm = document.getElementById('input-password-confirm')?.value || '';

    if (!pwd) {
      alert("Veuillez définir un mot de passe pour le compte administrateur.");
      return false;
    }
    if (pwd !== confirm) {
      alert("Les mots de passe saisis ne correspondent pas.");
      return false;
    }
    const chkStrong = document.getElementById('chk-strong-password');
    if (chkStrong && chkStrong.checked) {
      const hasLength = pwd.length >= 8;
      const hasUpper = /[A-Z]/.test(pwd);
      const hasDigit = /[0-9]/.test(pwd);
      const hasSpecial = /[^A-Za-z0-9]/.test(pwd);

      if (!hasLength || !hasUpper || !hasDigit || !hasSpecial) {
        alert("Le mot de passe fort est exigé. Il doit comporter au moins 8 caractères, une majuscule, un chiffre et un caractère spécial.");
        return false;
      }
    }
  }
  return true;
}

function initNavigation() {
  const btnPrev = document.getElementById('btn-prev');
  const btnNext = document.getElementById('btn-next');
  const btnInstall = document.getElementById('btn-install');

  btnPrev.addEventListener('click', () => {
    if (currentStep > 1) goToStep(currentStep - 1);
  });

  btnNext.addEventListener('click', () => {
    if (!validateStep(currentStep)) return;
    if (currentStep < totalSteps) goToStep(currentStep + 1);
  });

  document.querySelectorAll('.step-item').forEach(item => {
    item.addEventListener('click', () => {
      const step = parseInt(item.dataset.step);
      if (step <= currentStep || item.classList.contains('completed')) {
        goToStep(step);
      }
    });
  });

  document.querySelectorAll('input[name="desktop_env"]').forEach(radio => {
    radio.addEventListener('change', () => {
      document.querySelectorAll('.selection-card').forEach(card => card.classList.remove('active'));
      radio.closest('.selection-card').classList.add('active');
    });
  });
}

function goToStep(step) {
  const curPanel = document.getElementById(`panel-step-${currentStep}`);
  const curNav = document.querySelector(`.step-item[data-step="${currentStep}"]`);
  if (curPanel) curPanel.classList.remove('active');
  if (curNav) {
    curNav.classList.remove('active');
    if (step > currentStep) curNav.classList.add('completed');
  }

  currentStep = step;

  const nextPanel = document.getElementById(`panel-step-${currentStep}`);
  const nextNav = document.querySelector(`.step-item[data-step="${currentStep}"]`);
  if (nextPanel) nextPanel.classList.add('active');
  if (nextNav) nextNav.classList.add('active');

  const btnPrev = document.getElementById('btn-prev');
  const btnNext = document.getElementById('btn-next');
  const btnInstall = document.getElementById('btn-install');

  if (btnPrev) btnPrev.disabled = currentStep === 1;

  if (currentStep === totalSteps) {
    if (btnNext) btnNext.classList.add('hidden');
    if (btnInstall) btnInstall.classList.remove('hidden');
    updateSummary();
  } else if (currentStep < totalSteps) {
    if (btnNext) btnNext.classList.remove('hidden');
    if (btnInstall) btnInstall.classList.add('hidden');
  }
}

function setPrereqStatus(id, level, statusText, detailText) {
  const card = document.getElementById(id);
  if (!card) return;
  card.classList.remove('loading', 'status-ok', 'status-warn', 'status-error');

  if (level === 'optimal' || level === 'ok' || level === true) {
    card.classList.add('status-ok');
  } else if (level === 'warning' || level === 'warn') {
    card.classList.add('status-warn');
  } else {
    card.classList.add('status-error');
  }

  const statusEl = card.querySelector('.prereq-status');
  const detailEl = card.querySelector('.prereq-detail');
  if (statusEl) statusEl.textContent = statusText;
  if (detailEl && detailText) detailEl.textContent = detailText;
}

async function loadPrerequisites() {
  try {
    const pre = await invoke('get_prerequisites');

    // 1. Espace disque : au moins un disque >= 80 Go pour pavé vert
    if (pre.has_80gb_disk) {
      setPrereqStatus('prereq-disk', 'optimal', '✓ Conforme (≥ 80 Go)', pre.disk_message);
    } else {
      setPrereqStatus('prereq-disk', 'error', '✗ Insuffisant (< 80 Go)', pre.disk_message);
    }

    // 2. RAM : > 8 Go vert, 4-8 Go orange, < 4 Go rouge
    if (pre.ram_level === 'optimal') {
      setPrereqStatus('prereq-ram', 'optimal', '✓ Optimal (> 8 Go)', pre.ram_message);
    } else if (pre.ram_level === 'warning') {
      setPrereqStatus('prereq-ram', 'warning', '⚠ Minimum atteint (4-8 Go)', pre.ram_message);
    } else {
      setPrereqStatus('prereq-ram', 'error', '✗ Insuffisant (< 4 Go)', pre.ram_message);
    }

    // 3. CPU : >= 8 cœurs conseillés vert, 4-7 orange, < 4 rouge
    if (pre.cpu_level === 'optimal') {
      setPrereqStatus('prereq-cpu', 'optimal', '✓ Recommandé (≥ 8 cœurs)', pre.cpu_message);
    } else if (pre.cpu_level === 'warning') {
      setPrereqStatus('prereq-cpu', 'warning', '⚠ Minimum atteint (4-7 cœurs)', pre.cpu_message);
    } else {
      setPrereqStatus('prereq-cpu', 'error', '✗ Insuffisant (< 4 cœurs)', pre.cpu_message);
    }

    // 4. GPU : VM, Intel, Nvidia Moderne, Nvidia Legacy, AMD
    if (pre.gpu) {
      detectedGpuDriver = pre.gpu.driver_type || "amd";
      const driverLabels = {
        'vm': 'Machine Virtuelle (VM)',
        'nvidia': 'NVIDIA Moderne (Propriétaire)',
        'nvidia-legacy': 'NVIDIA Legacy 470',
        'amd': 'AMD Radeon (amdgpu)',
        'intel': 'Intel Graphics (Media Driver)'
      };
      const label = driverLabels[pre.gpu.driver_type] || pre.gpu.driver_type;
      setPrereqStatus('prereq-gpu', 'optimal', `✓ ${label}`, `${pre.gpu.name} — ${pre.gpu.detail}`);
    }

    // 5. Démarrage UEFI
    setPrereqStatus(
      'prereq-efi',
      pre.is_efi ? 'optimal' : 'warning',
      pre.is_efi ? '✓ Mode UEFI Détecté' : '⚠ Mode BIOS Legacy Détecté',
      pre.is_efi ? 'Amorçage sécurisé GPT / ESP supporté' : 'Attention : le mode UEFI est vivement recommandé'
    );

    // 6. Connexion Internet
    setPrereqStatus(
      'prereq-internet',
      pre.has_internet ? 'optimal' : 'warning',
      pre.has_internet ? '✓ Connecté à Internet' : '⚠ Mode Hors-Ligne',
      pre.has_internet ? 'Accès dépôts NixOS et mises à jour en ligne' : 'Installation locale sans téléchargements externes'
    );
  } catch (e) {
    console.error("Prerequisites error:", e);
  }
}

async function loadDesktops() {
  try {
    const desktops = await invoke('get_desktops');
    availableDesktops = desktops;
    for (const d of desktops) {
      if (d.id === 'gnome') {
        const el = document.getElementById('de-title-gnome');
        if (el) el.textContent = d.name;
      } else if (d.id === 'cinnamon') {
        const el = document.getElementById('de-title-cinnamon');
        if (el) el.textContent = d.name;
      }
    }
  } catch (e) {
    console.error("Failed to query desktops:", e);
  }
}

async function loadKeyboardLayouts() {
  try {
    availableLayouts = await invoke('get_layouts');
    const selLayout = document.getElementById('keyboard-layout-select');
    if (!selLayout) return;
    selLayout.innerHTML = '';

    availableLayouts.forEach(l => {
      const lid = l.id || l.code;
      const opt = document.createElement('option');
      opt.value = lid;
      opt.textContent = `${l.name} (${lid.toUpperCase()})`;
      if (lid === 'fr') opt.selected = true;
      selLayout.appendChild(opt);
    });

    updateVariantsDropdown(selLayout.value || 'fr');

    selLayout.addEventListener('change', async () => {
      const lid = selLayout.value;
      updateVariantsDropdown(lid);
      await applyKeyboard();
    });

    const selVariant = document.getElementById('keyboard-variant-select');
    if (selVariant) {
      selVariant.addEventListener('change', async () => {
        await applyKeyboard();
      });
    }

    // Appliquer le clavier immédiatement au chargement
    await applyKeyboard();
  } catch (e) {
    console.error("Failed to load layouts:", e);
  }
}

function updateVariantsDropdown(layoutId) {
  const selVariant = document.getElementById('keyboard-variant-select');
  if (!selVariant) return;
  selVariant.innerHTML = '';

  const found = availableLayouts.find(l => (l.id === layoutId || l.code === layoutId));
  if (!found || !found.variants || found.variants.length === 0) {
    const defOpt = document.createElement('option');
    defOpt.value = "";
    defOpt.textContent = "Par défaut (Standard)";
    selVariant.appendChild(defOpt);
    return;
  }

  found.variants.forEach(v => {
    const opt = document.createElement('option');
    const vid = typeof v === 'string' ? v : (v.id ?? "");
    const vname = typeof v === 'string' ? (v || "Par défaut (Standard)") : (v.name || "Par défaut (Standard)");
    opt.value = vid;
    opt.textContent = vname;
    selVariant.appendChild(opt);
  });
}

async function applyKeyboard() {
  const selLayout = document.getElementById('keyboard-layout-select');
  const selVariant = document.getElementById('keyboard-variant-select');
  const layout = selLayout ? selLayout.value : "fr";
  const variant = selVariant ? selVariant.value : "";
  try {
    await invoke('apply_keyboard_live', { layout, variant });
  } catch (e) {
    console.error("Apply keyboard failed:", e);
  }
}

async function loadTimezones() {
  try {
    const timezones = await invoke('get_timezones_list');
    let detectedTz = "Europe/Paris";
    try {
      detectedTz = await invoke('get_detected_timezone');
    } catch (_) {}

    const selTimezone = document.getElementById('timezone-select');
    if (!selTimezone) return;
    selTimezone.innerHTML = '';

    const regions = {};
    timezones.forEach(tz => {
      const reg = tz.region || "Autres";
      if (!regions[reg]) regions[reg] = [];
      regions[reg].push(tz);
    });

    Object.keys(regions).forEach(reg => {
      const optGroup = document.createElement('optgroup');
      optGroup.label = `─── ${reg} ───`;
      regions[reg].forEach(tz => {
        const opt = document.createElement('option');
        opt.value = tz.id;
        opt.textContent = tz.name;
        if (tz.id === detectedTz) {
          opt.selected = true;
        }
        optGroup.appendChild(opt);
      });
      selTimezone.appendChild(optGroup);
    });

    if (!timezones.some(tz => tz.id === detectedTz)) {
      const customOpt = document.createElement('option');
      customOpt.value = detectedTz;
      customOpt.textContent = `${detectedTz} (Détecté)`;
      customOpt.selected = true;
      selTimezone.insertBefore(customOpt, selTimezone.firstChild);
    }

    selTimezone.addEventListener('change', async () => {
      const tz = selTimezone.value;
      try {
        await invoke('apply_timezone_live', { timezone: tz });
      } catch (e) {
        console.warn("Apply timezone live error:", e);
      }
    });

    if (detectedTz) {
      invoke('apply_timezone_live', { timezone: detectedTz }).catch(() => {});
    }
  } catch (e) {
    console.error("Failed to load timezones:", e);
  }
}

async function loadDisks() {
  try {
    availableDisks = await invoke('get_disks');
    const container = document.getElementById('disks-container') || document.getElementById('disk-list');
    if (!container) return;

    if (availableDisks.length === 0) {
      container.innerHTML = '<div class="alert alert-warn" style="padding: 14px; background: rgba(250, 179, 135, 0.1); border: 1px solid var(--mocha-peach); border-radius: 10px; color: var(--mocha-peach);">Aucun disque fixe détecté. Mode simulation actif.</div>';
      return;
    }

    container.innerHTML = availableDisks.map((d, idx) => `
      <div class="disk-card ${idx === 0 ? 'selected' : ''}" data-path="${d.path}">
        <div class="disk-meta">
          <span class="disk-icon">${d.is_nvme ? '⚡' : (d.is_rotational ? '💽' : '💾')}</span>
          <div class="disk-details">
            <div style="font-weight: 600; color: var(--mocha-text); font-size: 1rem;">
              ${d.model || 'Disque de Stockage'} <span style="color: var(--mocha-mauve); font-family: 'JetBrains Mono', monospace; font-size: 0.9rem;">(${d.path})</span>
            </div>
            <div style="color: var(--mocha-subtext0); font-size: 0.82rem; margin-top: 2px;">
              ${d.size_gb} Go • ${d.is_nvme ? 'NVMe SSD' : (d.is_rotational ? 'Disque Dur Mécanique (HDD)' : 'SATA SSD')}
            </div>
          </div>
        </div>
        <span class="badge ${idx === 0 ? 'badge-primary' : 'badge-neutral'}">${idx === 0 ? '✓ Sélectionné' : 'Cliquer pour choisir'}</span>
      </div>
    `).join('');

    document.querySelectorAll('.disk-card').forEach(card => {
      card.addEventListener('click', () => {
        document.querySelectorAll('.disk-card').forEach(c => {
          c.classList.remove('selected');
          const b = c.querySelector('.badge');
          if (b) {
            b.className = 'badge badge-neutral';
            b.textContent = 'Cliquer pour choisir';
          }
        });
        card.classList.add('selected');
        const b = card.querySelector('.badge');
        if (b) {
          b.className = 'badge badge-primary';
          b.textContent = '✓ Sélectionné';
        }
      });
    });
  } catch (e) {
    console.error("Failed to load disks:", e);
  }
}

const SWAP_STEPS = [0, 4096, 8192, 16384, 32768];
const SWAP_LABELS = [
  "Désactivé (0 Go)",
  "4 Go",
  "8 Go (Recommandé)",
  "16 Go",
  "32 Go"
];

function getSwapSizeMb() {
  const slider = document.getElementById('swap-slider');
  if (!slider) return 8192;
  const idx = parseInt(slider.value, 10);
  return SWAP_STEPS[idx] !== undefined ? SWAP_STEPS[idx] : 8192;
}

function initSwapSlider() {
  const slider = document.getElementById('swap-slider');
  const valSpan = document.getElementById('swap-size-val');
  if (!slider || !valSpan) return;

  function updateSwapDisplay() {
    const idx = parseInt(slider.value, 10);
    valSpan.textContent = SWAP_LABELS[idx] || "8 Go (Recommandé)";

    document.querySelectorAll('.swap-scale span').forEach((el) => {
      const elVal = parseInt(el.dataset.val, 10);
      if (elVal === idx) {
        el.classList.add('active');
      } else {
        el.classList.remove('active');
      }
    });
  }

  slider.addEventListener('input', updateSwapDisplay);

  document.querySelectorAll('.swap-scale span').forEach((el) => {
    el.addEventListener('click', () => {
      const idx = parseInt(el.dataset.val, 10);
      if (!isNaN(idx)) {
        slider.value = idx;
        updateSwapDisplay();
      }
    });
  });

  updateSwapDisplay();
}

function collectSelections() {
  const selectedDisk = document.querySelector('.disk-card.selected');
  const diskPath = selectedDisk ? selectedDisk.dataset.path : (availableDisks[0] ? availableDisks[0].path : "/dev/sda");

  return {
    hostname: document.getElementById('input-hostname').value || "chomiamos",
    username: document.getElementById('input-username').value || "chomiam",
    fullname: document.getElementById('input-fullname').value || "ChomiamOS User",
    password: document.getElementById('input-password').value || null,
    desktop_env: document.querySelector('input[name="desktop_env"]:checked')?.value || "gnome",
    browser: document.getElementById('browser-select').value || "chrome",
    discord_client: "discord",
    keyboard_layout: document.getElementById('keyboard-layout-select').value || "fr",
    keyboard_variant: document.getElementById('keyboard-variant-select')?.value || "",
    timezone: document.getElementById('timezone-select')?.value || "Europe/Paris",
    target_disk: diskPath,
    swap_size_mb: getSwapSizeMb(),
    gpu_driver: detectedGpuDriver || "amd",
    steam: document.getElementById('chk-steam').checked,
    lutris: document.getElementById('chk-lutris').checked,
    heroic: document.getElementById('chk-heroic').checked,
    faugus: document.getElementById('chk-faugus').checked,
    decky_loader: false,
    geforce_now: document.getElementById('chk-geforce').checked,
    sunshine: document.getElementById('chk-sunshine').checked,
    sober: document.getElementById('chk-sober').checked,
    steering_wheels: document.getElementById('chk-wheels').checked,
  };
}

function updateSummary() {
  const s = collectSelections();
  const box = document.getElementById('summary-box');

  box.innerHTML = `
    <div class="summary-item"><label>Disque cible</label><span>${s.target_disk || 'Non sélectionné'}</span></div>
    <div class="summary-item"><label>Fichier de Swap</label><span>${s.swap_size_mb === 0 ? 'Désactivé' : (s.swap_size_mb / 1024) + ' Go'}</span></div>
    <div class="summary-item"><label>Disposition Clavier</label><span>${s.keyboard_layout.toUpperCase()} ${s.keyboard_variant ? '(' + s.keyboard_variant + ')' : ''}</span></div>
    <div class="summary-item"><label>Fuseau Horaire</label><span>${s.timezone}</span></div>
    <div class="summary-item"><label>Bureau Choisi</label><span>${s.desktop_env.toUpperCase()}</span></div>
    <div class="summary-item"><label>Pilote Graphique (GPU)</label><span>${(s.gpu_driver || 'amd').toUpperCase()}</span></div>
    <div class="summary-item"><label>Utilisateur / Hôte</label><span>${s.username} @ ${s.hostname}</span></div>
    <div class="summary-item"><label>Serveur Sunshine</label><span>${s.sunshine ? 'Activé' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Sober (Roblox)</label><span>${s.sober ? 'Activé' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>NVIDIA GeForce NOW</label><span>${s.geforce_now ? 'Activé' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Volants & Simracing</label><span>${s.steering_wheels ? 'Activé' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Navigateur Web</label><span>${s.browser}</span></div>
  `;
}

function initSummaryTrigger() {
  const btnNix = document.getElementById('btn-toggle-nix-preview');
  const preview = document.getElementById('vars-preview-code');

  btnNix.addEventListener('click', async () => {
    if (!preview.classList.contains('hidden')) {
      preview.classList.add('hidden');
      btnNix.textContent = "Voir le vars.nix généré";
      return;
    }

    const s = collectSelections();
    try {
      const code = await invoke('generate_configuration_preview', { selections: s });
      preview.textContent = code;
      preview.classList.remove('hidden');
      btnNix.textContent = "Masquer le vars.nix";
    } catch (e) {
      preview.textContent = "Erreur: " + e;
    }
  });
}

// Confirmation Modal & Installation Pipeline
function initConfirmationModal() {
  const btnInstall = document.getElementById('btn-install');
  const modal = document.getElementById('modal-confirm-install');
  const btnCancel = document.getElementById('btn-modal-cancel');
  const btnProceed = document.getElementById('btn-modal-proceed');
  const targetLabel = document.getElementById('modal-target-disk-label');

  btnInstall.addEventListener('click', () => {
    const s = collectSelections();
    targetLabel.textContent = s.target_disk || '/dev/sda';
    modal.classList.remove('hidden');
  });

  btnCancel.addEventListener('click', () => {
    modal.classList.add('hidden');
  });

  btnProceed.addEventListener('click', async () => {
    modal.classList.add('hidden');
    const s = collectSelections();
    startInstallation(s);
  });

  document.getElementById('btn-reboot-now')?.addEventListener('click', async () => {
    try {
      await invoke('reboot_system');
    } catch (e) {
      alert("Erreur reboot: " + e);
    }
  });

  document.getElementById('btn-poweroff')?.addEventListener('click', async () => {
    try {
      await invoke('poweroff_system');
    } catch (e) {
      alert("Erreur poweroff: " + e);
    }
  });
}

function appendLog(text) {
  const term = document.getElementById('install-terminal-log');
  if (!term) return;
  const line = document.createElement('div');
  line.className = 'log-line';

  if (text.includes('[ÉTAPE') || text.includes('=== ÉTAPE') || text.startsWith('=== ')) {
    line.classList.add('log-step');
  } else if (text.includes('[OK]') || text.includes('[SUCCESS]') || text.includes('✓') || text.includes('avec succès')) {
    line.classList.add('log-success');
  } else if (text.includes('[ERREUR') || text.includes('[ERR]') || text.includes('FATAL') || text.includes('Échec')) {
    line.classList.add('log-error');
  } else if (text.includes('[WARN]') || text.includes('[ATTENTION]')) {
    line.classList.add('log-warn');
  } else if (text.includes('[INFO]')) {
    line.classList.add('log-info');
  } else if (text.includes('[BUILD]')) {
    line.classList.add('log-build');
  }

  line.textContent = `> ${text}`;
  term.appendChild(line);
  term.scrollTop = term.scrollHeight;
}

async function startInstallation(s) {
  try {
    // Basculer vers l'écran d'installation (Panel 8)
    const curPanel = document.getElementById(`panel-step-${currentStep}`);
    if (curPanel) curPanel.classList.remove('active');

    const installPanel = document.getElementById('panel-step-8');
    if (installPanel) installPanel.classList.add('active');

    document.querySelector('.wizard-actions')?.classList.add('hidden');
    document.querySelector('.stepper-sidebar')?.classList.add('hidden');

    appendLog("🚀 Démarrage du processus d'installation...");
    appendLog(`Disque cible configuré : ${s.target_disk}`);
    appendLog(`Taille de Swap sélectionnée : ${s.swap_size_mb === 0 ? 'Désactivé' : (s.swap_size_mb / 1024) + ' Go'}`);
    appendLog(`Environnement de bureau : ${s.desktop_env} | Pilote GPU : ${s.gpu_driver || 'amd'}`);

    await invoke('start_installation', { selections: s, dryRun: false });

    // Écoute directe des événements si disponible
    listen('install_progress', (e) => {
      const p = e.payload || e;
      if (p.percent !== undefined) {
        const bar = document.getElementById('install-bar-fill');
        const pct = document.getElementById('install-percent-val');
        if (bar) bar.style.width = `${p.percent}%`;
        if (pct) pct.textContent = `${p.percent}%`;
      }
      if (p.step) {
        const title = document.getElementById('install-step-title');
        if (title) title.textContent = p.step;
      }
    });

    listen('install_log', (e) => {
      const line = e.payload || e;
      appendLog(line);
    });

    // Boucle de polling (200ms) pour garantir la réception de tous les logs et états
    let lastLogCount = 0;
    const pollInterval = setInterval(async () => {
      try {
        const snap = await invoke('get_install_state', { sinceLogIdx: lastLogCount });

        if (snap.new_logs && snap.new_logs.length > 0) {
          for (const line of snap.new_logs) {
            appendLog(line);
          }
          lastLogCount = snap.total_logs_count;
        }

        if (snap.percent !== undefined) {
          const bar = document.getElementById('install-bar-fill');
          const pct = document.getElementById('install-percent-val');
          if (bar) bar.style.width = `${snap.percent}%`;
          if (pct) pct.textContent = `${snap.percent}%`;
        }
        if (snap.step) {
          const title = document.getElementById('install-step-title');
          if (title) title.textContent = snap.step;
        }

        if (snap.is_finished) {
          clearInterval(pollInterval);
          if (snap.success) {
            document.getElementById('install-complete-card')?.classList.remove('hidden');
            const h = document.getElementById('install-heading');
            if (h) h.textContent = "Installation Terminée !";
            const sub = document.getElementById('install-subheading');
            if (sub) sub.textContent = "ChomiamOS Gaming Edition est prêt.";
          } else {
            appendLog(`[ERREUR FATALE] ${snap.error || 'Erreur inconnue'}`);
            alert(`Erreur d'installation: ${snap.error}`);
          }
        }
      } catch (err) {
        console.error("Polling install state error:", err);
      }
    }, 200);
  } catch (err) {
    console.error("Fatal startInstallation error:", err);
    appendLog(`[ERREUR FATALE LANCEMENT] ${err}`);
    alert(`Erreur lors du lancement de l'installation: ${err}`);
  }
}


let currentUpdateInfo = null;

function ensureUpdateModalExists() {
  let modal = document.getElementById('modal-update');
  if (!modal) {
    console.log("Injecting modal-update dynamically into DOM...");
    const wrapper = document.createElement('div');
    wrapper.innerHTML = `
      <div class="modal-backdrop hidden" id="modal-update">
        <div class="modal-card update-modal">
          <div class="modal-header">
            <div class="modal-icon-badge update-icon-badge">🔄</div>
            <h3>Mise à jour de l'Installateur</h3>
          </div>
          <div class="modal-body">
            <p id="update-status-message">Recherche des dernières mises à jour...</p>
            <div class="version-comparison-card">
              <div class="version-row">
                <span class="version-label">Version actuelle :</span>
                <span class="version-val current" id="modal-current-ver">v1.1.0</span>
              </div>
              <div class="version-row">
                <span class="version-label">Nouvelle version disponible :</span>
                <span class="version-val latest" id="modal-latest-ver">v1.2.0</span>
              </div>
            </div>
            <div class="update-notes-container hidden" id="update-notes-container" style="margin-top: 14px;">
              <div class="update-notes-title">Notes de mise à jour :</div>
              <div id="update-notes-content" style="white-space: pre-wrap; font-family: inherit;"></div>
            </div>
            <div class="update-progress-wrap hidden" id="update-progress-section">
              <div class="update-progress-header">
                <span id="update-progress-label">Téléchargement en cours...</span>
                <span id="update-progress-percent">0%</span>
              </div>
              <div class="update-progress-track">
                <div class="update-progress-bar" id="update-progress-bar" style="width: 0%;"></div>
              </div>
              <p class="update-progress-subtext" id="update-progress-subtext">L'installateur redémarrera automatiquement dès la fin du téléchargement.</p>
            </div>
          </div>
          <div class="modal-footer">
            <button type="button" class="btn btn-secondary" id="btn-close-update-modal">Fermer</button>
            <button type="button" class="btn btn-primary" id="btn-start-update">Mettre à jour maintenant</button>
          </div>
        </div>
      </div>
    `;
    document.body.appendChild(wrapper.firstElementChild);
    modal = document.getElementById('modal-update');
  }

  // Bind close buttons
  const btnClose = document.getElementById('btn-close-update-modal');
  if (btnClose && !btnClose.dataset.bound) {
    btnClose.dataset.bound = "true";
    btnClose.addEventListener('click', (e) => {
      e.preventDefault();
      modal.classList.add('hidden');
    });
  }

  if (modal && !modal.dataset.bound) {
    modal.dataset.bound = "true";
    modal.addEventListener('click', (e) => {
      if (e.target === modal) {
        modal.classList.add('hidden');
      }
    });
  }

  // Bind start update button
  const btnStart = document.getElementById('btn-start-update');
  if (btnStart && !btnStart.dataset.bound) {
    btnStart.dataset.bound = "true";
    btnStart.addEventListener('click', async (e) => {
      e.preventDefault();
      if (!currentUpdateInfo || !currentUpdateInfo.download_url) {
        showUpdateError("Aucun lien de téléchargement disponible. Veuillez vérifier votre connexion Internet.");
        return;
      }
      btnStart.disabled = true;
      btnStart.classList.add('hidden');

      const progSection = document.getElementById('update-progress-section');
      if (progSection) progSection.classList.remove('hidden');

      try {
        await invoke('apply_installer_update', { downloadUrl: currentUpdateInfo.download_url });
      } catch (err) {
        showUpdateError(err);
        btnStart.disabled = false;
        btnStart.classList.remove('hidden');
      }
    });
  }

  return modal;
}

// ── Affichage d'erreur stylisé dans la modale de mise à jour ──
function showUpdateError(errorMessage) {
  const progSection = document.getElementById('update-progress-section');
  if (progSection) progSection.classList.add('hidden');

  // Créer ou réutiliser le container d'erreur
  let errorBox = document.getElementById('update-error-box');
  if (!errorBox) {
    errorBox = document.createElement('div');
    errorBox.id = 'update-error-box';
    errorBox.className = 'update-error-box';
    // Insérer après le progress section ou dans le modal-body
    const modalBody = document.querySelector('#modal-update .modal-body');
    if (modalBody) modalBody.appendChild(errorBox);
  }

  // Analyser l'erreur pour donner un message humain
  let title = "Échec de la mise à jour";
  let detail = String(errorMessage);
  let suggestion = "Veuillez réessayer ultérieurement.";

  if (detail.includes("os error 2") || detail.includes("No such file")) {
    title = "Outil de téléchargement introuvable";
    detail = "La commande nécessaire au téléchargement (curl) n'a pas été trouvée sur votre système.";
    suggestion = "Vérifiez que curl est installé dans votre environnement NixOS.";
  } else if (detail.includes("curl") && detail.includes("code")) {
    title = "Erreur de téléchargement";
    suggestion = "Vérifiez votre connexion Internet et que les serveurs GitHub sont accessibles.";
  } else if (detail.includes("trop petit") || detail.includes("corrompu")) {
    title = "Fichier corrompu";
    suggestion = "Le fichier téléchargé est invalide. Réessayez ou téléchargez manuellement depuis GitHub.";
  } else if (detail.includes("timeout") || detail.includes("Timeout")) {
    title = "Délai d'attente dépassé";
    suggestion = "La connexion est trop lente ou le serveur ne répond pas. Réessayez plus tard.";
  }

  errorBox.innerHTML = `
    <div class="update-error-icon">⚠️</div>
    <div class="update-error-content">
      <div class="update-error-title">${title}</div>
      <div class="update-error-detail">${detail}</div>
      <div class="update-error-suggestion">💡 ${suggestion}</div>
    </div>
  `;
  errorBox.classList.remove('hidden');
}

async function initUpdateManager() {
  const pillBtn = document.getElementById('btn-update-pill');

  if (pillBtn && !pillBtn.dataset.bound) {
    pillBtn.dataset.bound = "true";
    pillBtn.addEventListener('click', (e) => {
      e.preventDefault();
      openUpdateModal();
    });
  }

  // Initialise le modal dans le DOM
  ensureUpdateModalExists();

  // Écoute des événements de progression en direct depuis Rust
  listen('update_progress', (event) => {
    const p = event.payload;
    if (!p) return;
    const progSection = document.getElementById('update-progress-section');
    const progBar = document.getElementById('update-progress-bar');
    const progLabel = document.getElementById('update-progress-label');
    const progPct = document.getElementById('update-progress-percent');
    const progSub = document.getElementById('update-progress-subtext');

    if (progSection) progSection.classList.remove('hidden');
    if (progBar) progBar.style.width = `${p.percent}%`;
    if (progPct) progPct.textContent = `${p.percent}%`;
    if (progLabel) progLabel.textContent = p.message || `Téléchargement (${p.percent}%)...`;
    if (progSub && p.percent >= 98) progSub.textContent = "Redémarrage de l'installateur dans quelques instants...";
  });

  await checkAndUpdatePill();
}

async function checkAndUpdatePill() {
  const dot = document.getElementById('update-dot');
  const text = document.getElementById('update-status-text');
  const pillBtn = document.getElementById('btn-update-pill');

  try {
    const info = await invoke('check_installer_update');
    currentUpdateInfo = info;

    if (info && info.has_update) {
      if (dot) {
        dot.className = 'status-dot orange';
      }
      if (text) {
        text.textContent = `Mise à jour v${info.latest_version}`;
      }
      if (pillBtn) {
        pillBtn.className = 'update-pill-btn update-available';
        pillBtn.title = `Mise à jour v${info.latest_version} disponible ! Cliquez pour installer.`;
      }
    } else {
      const curVer = info ? info.current_version : "1.2.2";
      if (dot) {
        dot.className = 'status-dot green';
      }
      if (text) {
        text.textContent = `À jour (v${curVer})`;
      }
      if (pillBtn) {
        pillBtn.className = 'update-pill-btn up-to-date';
        pillBtn.title = `L'installateur est à jour (v${curVer}).`;
      }
    }
  } catch (err) {
    console.warn("Check update error:", err);
  }
}

function openUpdateModal() {
  const modal = ensureUpdateModalExists();
  if (!modal) return;

  const curVer = currentUpdateInfo ? currentUpdateInfo.current_version : "1.2.2";
  const latestVer = currentUpdateInfo ? currentUpdateInfo.latest_version : "1.2.2";
  const hasUpdate = currentUpdateInfo ? currentUpdateInfo.has_update : false;

  const elCur = document.getElementById('modal-current-ver');
  const elLat = document.getElementById('modal-latest-ver');
  const elMsg = document.getElementById('update-status-message');
  const elNotesWrap = document.getElementById('update-notes-container');
  const elNotes = document.getElementById('update-notes-content');
  const btnStart = document.getElementById('btn-start-update');
  const progSection = document.getElementById('update-progress-section');

  if (elCur) elCur.textContent = `v${curVer}`;
  if (elLat) {
    elLat.textContent = `v${latestVer}`;
    elLat.className = `version-val latest ${hasUpdate ? 'has-update' : ''}`;
  }

  if (progSection) progSection.classList.add('hidden');

  if (hasUpdate) {
    if (elMsg) elMsg.textContent = `Une nouvelle version de l'installateur (v${latestVer}) est disponible avec les derniers correctifs.`;
    if (btnStart) {
      btnStart.classList.remove('hidden');
      btnStart.disabled = false;
      btnStart.textContent = `Mettre à jour vers v${latestVer}`;
    }
    if (currentUpdateInfo.notes && elNotes && elNotesWrap) {
      elNotes.textContent = currentUpdateInfo.notes;
      elNotesWrap.classList.remove('hidden');
    } else if (elNotesWrap) {
      elNotesWrap.classList.add('hidden');
    }
  } else {
    if (elMsg) elMsg.textContent = "Votre installateur ChomiamOS est parfaitement à jour. Aucune mise à jour requise.";
    if (btnStart) btnStart.classList.add('hidden');
    if (elNotesWrap) elNotesWrap.classList.add('hidden');
  }

  modal.classList.remove('hidden');
}

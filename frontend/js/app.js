// ==========================================================================
// ChomiamOS Installer - Tauri v2 Controller
// ==========================================================================

let currentStep = 1;
const totalSteps = 11;
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


// ── Sélection du Système de Fichiers (ext4 vs Btrfs) & Compression (v1.2.21) ─
let selectedFilesystem = "ext4";
let selectedBtrfsCompression = "zstd:1";

function initFilesystemHandlers() {
  const fsCards = document.querySelectorAll('.fs-tile-card');
  const compCards = document.querySelectorAll('.comp-option-card');
  const compContainer = document.getElementById('btrfs-compression-container');

  fsCards.forEach(card => {
    card.addEventListener('click', () => {
      fsCards.forEach(c => {
        c.classList.remove('active');
        const radio = c.querySelector('input[type="radio"]');
        if (radio) radio.checked = false;
      });
      card.classList.add('active');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) radio.checked = true;

      selectedFilesystem = card.dataset.fs || "ext4";

      if (selectedFilesystem === "btrfs") {
        if (compContainer) compContainer.classList.remove('hidden');
      } else {
        if (compContainer) compContainer.classList.add('hidden');
      }
    });
  });

  compCards.forEach(card => {
    card.addEventListener('click', () => {
      compCards.forEach(c => {
        c.classList.remove('active');
        const radio = c.querySelector('input[type="radio"]');
        if (radio) radio.checked = false;
      });
      card.classList.add('active');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) {
        radio.checked = true;
        selectedBtrfsCompression = radio.value;
      }
    });
  });
}

// ── Gestionnaires Interactifs Navigateurs & Mail (v1.2.18) ───────────────────
let selectedBrowser = "chrome";
let browserPkgTypes = {
  chrome: "system",
  firefox: "system",
  brave: "system",
  zen: "flatpak",
  librewolf: "flatpak"
};
let selectedMailClient = "thunderbird";
let selectedDiscordClient = "discord";

function initBrowserAndMailHandlers() {
  // 1. Sélection de tuile navigateur
  const browserCards = document.querySelectorAll('.browser-tile-card');
  browserCards.forEach(card => {
    card.addEventListener('click', (e) => {
      // Ne pas changer la sélection globale si le clic est sur un bouton de bille
      if (e.target.closest('.btn-pkg-pill')) return;

      browserCards.forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      selectedBrowser = card.dataset.browser || "chrome";
    });
  });

  // 2. Commutateur de bille Système / Flatpak
  const pillButtons = document.querySelectorAll('.btn-pkg-pill');
  pillButtons.forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.stopPropagation();
      const browser = btn.dataset.browser;
      const type = btn.dataset.type;
      if (!browser || !type) return;

      browserPkgTypes[browser] = type;

      // Mettre à jour l'état visuel des boutons pour ce navigateur
      const siblingPills = btn.closest('.pkg-switcher-row')?.querySelectorAll('.btn-pkg-pill');
      siblingPills?.forEach(p => p.classList.remove('active'));
      btn.classList.add('active');

      // Activer la carte parente
      const parentCard = btn.closest('.browser-tile-card');
      if (parentCard) {
        browserCards.forEach(c => c.classList.remove('active'));
        parentCard.classList.add('active');
        selectedBrowser = browser;
      }
    });
  });

  // 3. Sélection de tuile Client Mail
  const mailCards = document.querySelectorAll('.mail-tile-card');
  mailCards.forEach(card => {
    card.addEventListener('click', () => {
      mailCards.forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) {
        radio.checked = true;
        selectedMailClient = radio.value;
      }
    });
  });

  // 4. Sélection de tuile Discord
  const discordCards = document.querySelectorAll('.discord-tile-card');
  discordCards.forEach(card => {
    card.addEventListener('click', () => {
      discordCards.forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) {
        radio.checked = true;
        selectedDiscordClient = radio.value;
      }
    });
  });

  // 5. Gestion des cartes DE
  const deCards = document.querySelectorAll('.de-comparison-card');
  deCards.forEach(card => {
    card.addEventListener('click', () => {
      deCards.forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      const radio = card.querySelector('input[type="radio"]');
      if (radio) radio.checked = true;
    });
  });
}


// ── Détection Dynamique des Versions DE via Nixpkgs (v1.2.18) ───────────────
async function initDesktopVersionsDetection() {
  try {
    const vers = await invoke('get_desktop_versions');
    if (vers) {
      if (vers.gnome) {
        const el = document.getElementById('de-ver-gnome');
        if (el) el.textContent = 'v' + vers.gnome;
      }
      if (vers.kde) {
        const el = document.getElementById('de-ver-kde');
        if (el) el.textContent = 'v' + vers.kde;
      }
      if (vers.cosmic) {
        const el = document.getElementById('de-ver-cosmic');
        if (el) el.textContent = 'v' + vers.cosmic + ' (unstable)';
      }
      if (vers.cinnamon) {
        const el = document.getElementById('de-ver-cinnamon');
        if (el) el.textContent = 'v' + vers.cinnamon;
      }
      console.log('Versions DE détectées via nixpkgs:', vers);
    }
  } catch (err) {
    console.warn('Impossible de détecter les versions DE via nixpkgs:', err);
  }
}


// ── Verrouillage Sécurisé de la Session Gamescope sur GPU NVIDIA (v1.2.18) ──
function applyGamescopeGpuLock() {
  const isNvidia = detectedGpuDriver === 'nvidia' || detectedGpuDriver === 'nvidia-legacy';
  const gsChk = document.getElementById('chk-gamescope-session');
  const wrap = document.getElementById('wrap-gamescope-session');
  const lockBadge = document.getElementById('gamescope-lock-badge');
  const note = document.getElementById('gamescope-gpu-note');

  if (isNvidia) {
    if (gsChk) {
      gsChk.checked = false;
      gsChk.disabled = true;
    }
    if (wrap) {
      wrap.classList.add('disabled');
      wrap.title = "Session verrouillée : le pilote propriétaire NVIDIA ne prend pas en charge de manière stable le micro-compositeur Wayland Gamescope";
    }
    if (lockBadge) {
      lockBadge.classList.remove('hidden');
    }
    if (note) {
      note.classList.add('warning-nvidia');
      note.innerHTML = '<span class="note-icon">⚠️</span><span><strong>GPU NVIDIA Détecté :</strong> La session Gamescope en mode console est <strong>bloquée et désactivée</strong> par mesure de sécurité en raison d\'incompatibilités critiques du pilote propriétaire NVIDIA avec le gestionnaire de tampons DRM Gamescope.</span>';
    }
  } else {
    if (gsChk) {
      gsChk.disabled = false;
    }
    if (wrap) {
      wrap.classList.remove('disabled');
      wrap.title = "Activer la session Steam Gamescope";
    }
    if (lockBadge) {
      lockBadge.classList.add('hidden');
    }
    if (note) {
      note.classList.remove('warning-nvidia');
      note.innerHTML = '<span class="note-icon">💡</span><span>Optimisé pour les cartes graphiques <strong>AMD Radeon</strong> et <strong>Intel Arc</strong>. Désactivé automatiquement sur GPU NVIDIA en raison des limitations des pilotes propriétaires sur le DRM Gamescope.</span>';
    }
  }
}

let selectedDavinciResolve = "none";

function initDavinciResolveHandlers() {
  const cards = document.querySelectorAll('.davinci-tile-card');
  cards.forEach(card => {
    card.addEventListener('click', () => {
      cards.forEach(c => c.classList.remove('active'));
      card.classList.add('active');
      selectedDavinciResolve = card.dataset.davinci || "none";
    });
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  // 1. Initialisations synchrones immédiates de l'UI (aucune attente réseau)
  initNavigation();
  initSwapSlider();
  initPasswordSecurity();
  initKeyboardModifiers();
  initPasswordVisibilityToggles();
  initHostnameValidation();
  initBrowserAndMailHandlers();
  initDavinciResolveHandlers();
  initFilesystemHandlers();
  initSummaryTrigger();
  initConfirmationModal();
  initTerminalActions();
  initDiagnosticHandlers();

  // 2. Chargements asynchrones en arrière-plan
  loadPrerequisites();
  loadDesktops();
  loadKeyboardLayouts();
  loadTimezones();
  loadDisks();
  initMirrorDetection();
  initUpdateManager();

  // Détection des versions DE en arrière-plan sans bloquer l'affichage initial
  setTimeout(() => {
    initDesktopVersionsDetection();
  }, 1000);
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
  if (step === 10) {
    const hostnameInput = document.getElementById('input-hostname');
    let hostname = hostnameInput?.value.trim().toLowerCase() || "";
    hostname = hostname.replace(/^-+|-+$/g, '');
    if (!hostname || !/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/.test(hostname)) {
      alert("Le nom d'hôte de la machine (hostname) n'est pas valide.\nUtilisez uniquement des lettres minuscules (a-z), chiffres (0-9) et tirets (-), sans espace, et ne commencez ni ne terminez par un tiret.");
      if (hostnameInput) hostnameInput.focus();
      return false;
    }
    if (hostnameInput) hostnameInput.value = hostname;

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

  // Remonter en haut de page lors du changement d'étape
  const scrollArea = document.querySelector('.step-content-area');
  if (scrollArea) {
    scrollArea.scrollTop = 0;
  }

  if (step === 6) {
    applyGamescopeGpuLock();
  }

  if (step === 10 && typeof window.syncKeyboardHardwareLocks === 'function') {
    window.syncKeyboardHardwareLocks();
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
      applyGamescopeGpuLock();
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

  const modalSwap = document.getElementById('modal-swap-warning');
  const btnRevert = document.getElementById('btn-revert-swap');
  const btnKeepZero = document.getElementById('btn-confirm-no-swap');

  let prevIdx = parseInt(slider.value, 10);

  function checkSwapWarning(newIdx) {
    if (newIdx === 0 && prevIdx !== 0) {
      if (modalSwap) modalSwap.classList.remove('hidden');
    }
    prevIdx = newIdx;
  }

  slider.addEventListener('input', () => {
    updateSwapDisplay();
  });

  slider.addEventListener('change', () => {
    const idx = parseInt(slider.value, 10);
    checkSwapWarning(idx);
  });

  document.querySelectorAll('.swap-scale span').forEach((el) => {
    el.addEventListener('click', () => {
      const idx = parseInt(el.dataset.val, 10);
      if (!isNaN(idx)) {
        slider.value = idx;
        updateSwapDisplay();
        checkSwapWarning(idx);
      }
    });
  });

  if (btnRevert) {
    btnRevert.addEventListener('click', () => {
      slider.value = '2'; // 8 Go (Recommandé)
      prevIdx = 2;
      updateSwapDisplay();
      if (modalSwap) modalSwap.classList.add('hidden');
    });
  }

  if (btnKeepZero) {
    btnKeepZero.addEventListener('click', () => {
      if (modalSwap) modalSwap.classList.add('hidden');
    });
  }

  if (modalSwap) {
    modalSwap.addEventListener('click', (e) => {
      if (e.target === modalSwap) {
        modalSwap.classList.add('hidden');
      }
    });
  }

  updateSwapDisplay();
}

function collectSelections() {
  const selectedDisk = document.querySelector('.disk-card.selected');
  const diskPath = selectedDisk ? selectedDisk.dataset.path : (availableDisks[0] ? availableDisks[0].path : "/dev/sda");

  return {
    hostname: (document.getElementById('input-hostname')?.value.trim().toLowerCase().replace(/^-+|-+$/g, '') || "chomiamos"),
    username: document.getElementById('input-username')?.value || "chomiam",
    fullname: document.getElementById('input-fullname')?.value || "ChomiamOS User",
    password: document.getElementById('input-password')?.value || null,
    desktop_env: document.querySelector('input[name="desktop_env"]:checked')?.value || "gnome",
    browser: selectedBrowser || "chrome",
    browser_type: browserPkgTypes[selectedBrowser] || "system",
    mail_client: selectedMailClient || "thunderbird",
    discord_client: selectedDiscordClient || "discord",
    keyboard_layout: document.getElementById('keyboard-layout-select')?.value || "fr",
    keyboard_variant: document.getElementById('keyboard-variant-select')?.value || "",
    timezone: document.getElementById('timezone-select')?.value || "Europe/Paris",
    target_disk: diskPath,
    filesystem: selectedFilesystem || "ext4",
    btrfs_compression: (selectedFilesystem === "btrfs" ? (selectedBtrfsCompression || "zstd:1") : "none"),
    swap_size_mb: getSwapSizeMb(),
    gpu_driver: detectedGpuDriver || "amd",

    // Suite d'Émulation & Rétrogaming
    emu_es_de: document.getElementById('chk-emu-es-de')?.checked ?? true,
    emu_retroarch: document.getElementById('chk-emu-retroarch')?.checked ?? true,
    emu_duckstation: document.getElementById('chk-emu-duckstation')?.checked ?? true,
    emu_pcsx2: document.getElementById('chk-emu-pcsx2')?.checked ?? true,
    emu_rpcs3: document.getElementById('chk-emu-rpcs3')?.checked ?? false,
    emu_dolphin: document.getElementById('chk-emu-dolphin')?.checked ?? true,
    emu_ppsspp: document.getElementById('chk-emu-ppsspp')?.checked ?? true,
    emu_eden: document.getElementById('chk-emu-eden')?.checked ?? true,
    emu_azahar: document.getElementById('chk-emu-azahar')?.checked ?? true,
    emu_melonds: document.getElementById('chk-emu-melonds')?.checked ?? true,
    emu_mgba: document.getElementById('chk-emu-mgba')?.checked ?? true,

    // Gaming
    steam: document.getElementById('chk-steam')?.checked ?? true,
    lutris: document.getElementById('chk-lutris')?.checked ?? true,
    heroic: document.getElementById('chk-heroic')?.checked ?? true,
    faugus: document.getElementById('chk-faugus')?.checked ?? true,
    decky_loader: false,
    gamescope_session: (detectedGpuDriver === 'nvidia' || detectedGpuDriver === 'nvidia-legacy') ? false : (document.getElementById('chk-gamescope-session')?.checked ?? true),
    geforce_now: document.getElementById('chk-geforce')?.checked ?? false,
    sunshine: document.getElementById('chk-sunshine')?.checked ?? false,
    sober: document.getElementById('chk-sober')?.checked ?? false,
    steering_wheels: document.getElementById('chk-wheels')?.checked ?? false,

    // Multimédia & Audio
    stremio: document.getElementById('chk-stremio')?.checked ?? true,
    vlc: document.getElementById('chk-vlc')?.checked ?? true,
    mpv: document.getElementById('chk-mpv')?.checked ?? true,
    davinci_resolve: selectedDavinciResolve || "none",
    audacity: document.getElementById('chk-audacity')?.checked ?? false,
    ardour: document.getElementById('chk-ardour')?.checked ?? false,

    // Productivité & Création
    obs_studio: document.getElementById('chk-obs')?.checked ?? false,
    kdenlive: document.getElementById('chk-kdenlive')?.checked ?? false,
    blender: document.getElementById('chk-blender')?.checked ?? false,
    godot: document.getElementById('chk-godot')?.checked ?? false,
    antigravity: document.getElementById('chk-antigravity')?.checked ?? false,
    pear_desktop: document.getElementById('chk-peardesktop')?.checked ?? true,
    goverlay: document.getElementById('chk-goverlay')?.checked ?? true,
    flatseal: document.getElementById('chk-goverlay')?.checked ?? true,
    tailscale: document.getElementById('chk-tailscale')?.checked ?? false,
    localsend: document.getElementById('chk-localsend')?.checked ?? true,
    motrix: document.getElementById('chk-motrix')?.checked ?? false,

    // Impression 3D
    slicer_orcaslicer: document.getElementById('chk-slicer-orca')?.checked ?? false,
    slicer_prusaslicer: document.getElementById('chk-slicer-prusa')?.checked ?? false,
    slicer_bambustudio: document.getElementById('chk-slicer-bambu')?.checked ?? false,
    slicer_cura: document.getElementById('chk-slicer-cura')?.checked ?? false,

    // Suite IA Locale
    ai_suite_enable: document.getElementById('chk-ai-suite')?.checked ?? false,
  };
}

function updateSummary() {
  const s = collectSelections();
  const box = document.getElementById('summary-box');

  box.innerHTML = `
    <div class="summary-item"><label>Disque cible</label><span>${s.target_disk || 'Non sélectionné'}</span></div>
    <div class="summary-item"><label>Système de fichiers</label><span>${s.filesystem === 'btrfs' ? 'Btrfs (Compression ' + s.btrfs_compression + ', sous-volumes @, @home, @nix, @swap)' : 'ext4 (Standard journalisé)'}</span></div>
    <div class="summary-item"><label>Fichier de Swap</label><span>${s.swap_size_mb === 0 ? 'Désactivé' : (s.swap_size_mb / 1024) + ' Go'}</span></div>
    <div class="summary-item"><label>Disposition Clavier</label><span>${s.keyboard_layout.toUpperCase()} ${s.keyboard_variant ? '(' + s.keyboard_variant + ')' : ''}</span></div>
    <div class="summary-item"><label>Fuseau Horaire</label><span>${s.timezone}</span></div>
    <div class="summary-item"><label>Bureau Choisi</label><span>${s.desktop_env.toUpperCase()}</span></div>
    <div class="summary-item"><label>Pilote Graphique (GPU)</label><span>${(s.gpu_driver || 'amd').toUpperCase()}</span></div>
    <div class="summary-item"><label>Utilisateur / Hôte</label><span>${s.username} @ ${s.hostname}</span></div>
    <div class="summary-item"><label>Navigateur Web</label><span>${s.browser.toUpperCase()} (${s.browser_type === 'flatpak' ? 'Flatpak' : 'Système'})</span></div>
    <div class="summary-item"><label>Messagerie & Discord</label><span>${s.mail_client === 'none' ? 'Webmail (aucun)' : s.mail_client.charAt(0).toUpperCase() + s.mail_client.slice(1)} • ${s.discord_client}</span></div>
    <div class="summary-item"><label>Rétro Gaming & Émulation</label><span>${[
      s.emu_es_de ? 'ES-DE' : null,
      s.emu_retroarch ? 'RetroArch' : null,
      s.emu_duckstation ? 'DuckStation (PS1)' : null,
      s.emu_pcsx2 ? 'PCSX2 (PS2)' : null,
      s.emu_dolphin ? 'Dolphin (GC/Wii)' : null,
      s.emu_eden ? 'Eden (Switch)' : null,
      s.emu_ppsspp ? 'PPSSPP (PSP)' : null,
      s.emu_azahar ? 'Azahar (3DS)' : null,
      s.emu_melonds ? 'melonDS (DS)' : null,
      s.emu_mgba ? 'mGBA (GBA)' : null,
      s.emu_rpcs3 ? 'RPCS3 (PS3)' : null,
    ].filter(Boolean).join(', ') || 'Désactivé'}</span></div>
    <div class="summary-item"><label>Multimédia</label><span>${[s.stremio?'Stremio':null, s.vlc?'VLC':null, s.mpv?'MPV':null].filter(Boolean).join(', ') || 'Standard'}</span></div>
    <div class="summary-item"><label>Création & Vidéo</label><span>${[s.davinci_resolve !== 'none' ? 'DaVinci Resolve (' + (s.davinci_resolve === 'studio' ? 'Studio' : 'Gratuit') + ')' : null, s.obs_studio?'OBS':null, s.blender?'Blender':null, s.godot?'Godot':null, s.kdenlive?'Kdenlive':null, s.antigravity?'Antigravity':null].filter(Boolean).join(', ') || 'Standard'}</span></div>
    <div class="summary-item"><label>Impression 3D</label><span>${[s.slicer_orcaslicer?'OrcaSlicer':null, s.slicer_prusaslicer?'Prusa':null, s.slicer_bambustudio?'Bambu':null, s.slicer_cura?'Cura':null].filter(Boolean).join(', ') || 'Aucun'}</span></div>
    <div class="summary-item"><label>Suite IA Locale</label><span>${s.ai_suite_enable ? 'Ollama + Open-WebUI (Activé)' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Options Gaming</label><span>Mode Console: ${(s.gpu_driver === 'nvidia' || s.gpu_driver === 'nvidia-legacy') ? 'Bloqué (NVIDIA)' : s.gamescope_session ? 'Activé' : 'Désactivé'} | Sunshine: ${s.sunshine ? 'Oui' : 'Non'} | Sober: ${s.sober ? 'Oui' : 'Non'}</span></div>
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

let autoScrollEnabled = true;
const rawInstallationLogs = [];

function appendLog(text) {
  const term = document.getElementById('install-terminal-log');
  rawInstallationLogs.push(`[${new Date().toLocaleTimeString()}] ${text}`);

  if (!term) return;
  const line = document.createElement('div');
  line.className = 'log-line';

  if (text.includes('[ÉTAPE') || text.includes('=== ÉTAPE') || text.startsWith('=== ')) {
    line.classList.add('log-step');
  } else if (text.includes('[VALIDATION-CLÉ]') || text.includes('[SÉCURITÉ]') || text.includes('[SUCCÈS SÉCURITÉ]')) {
    line.classList.add('log-security');
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

  if (autoScrollEnabled) {
    term.scrollTop = term.scrollHeight;
  }
}

function initTerminalActions() {
  const btnToggleAutoScroll = document.getElementById('btn-toggle-autoscroll');
  const autoscrollText = document.getElementById('autoscroll-text');
  const autoscrollIcon = document.getElementById('autoscroll-icon');
  const btnExportLogs = document.getElementById('btn-export-logs');
  const term = document.getElementById('install-terminal-log');

  if (term) {
    term.addEventListener('scroll', () => {
      const isAtBottom = term.scrollHeight - term.scrollTop - term.clientHeight < 35;
      if (!isAtBottom && autoScrollEnabled) {
        autoScrollEnabled = false;
        if (btnToggleAutoScroll) btnToggleAutoScroll.classList.remove('active');
        if (autoscrollIcon) autoscrollIcon.textContent = '⏸';
        if (autoscrollText) autoscrollText.textContent = 'Défilement auto : OFF';
      } else if (isAtBottom && !autoScrollEnabled) {
        autoScrollEnabled = true;
        if (btnToggleAutoScroll) btnToggleAutoScroll.classList.add('active');
        if (autoscrollIcon) autoscrollIcon.textContent = '⬇';
        if (autoscrollText) autoscrollText.textContent = 'Défilement auto : ON';
      }
    });
  }

  if (btnToggleAutoScroll) {
    btnToggleAutoScroll.addEventListener('click', () => {
      autoScrollEnabled = !autoScrollEnabled;
      if (autoScrollEnabled) {
        btnToggleAutoScroll.classList.add('active');
        if (autoscrollIcon) autoscrollIcon.textContent = '⬇';
        if (autoscrollText) autoscrollText.textContent = 'Défilement auto : ON';
        if (term) term.scrollTop = term.scrollHeight;
      } else {
        btnToggleAutoScroll.classList.remove('active');
        if (autoscrollIcon) autoscrollIcon.textContent = '⏸';
        if (autoscrollText) autoscrollText.textContent = 'Défilement auto : OFF';
      }
    });
  }

  if (btnExportLogs) {
    btnExportLogs.addEventListener('click', async () => {
      const header = [
        "==================================================================",
        "  ChomiamOS Gaming Edition — Journal d'installation",
        `  Date : ${new Date().toLocaleString()}`,
        "  Version Installateur : v1.2.18-testing (Rust + Tauri v2)",
        "==================================================================",
        "",
      ].join("\n");

      const logBody = rawInstallationLogs.length > 0
        ? rawInstallationLogs.join("\n")
        : (term ? Array.from(term.children).map(c => c.textContent).join("\n") : "");
      const fullContent = `${header}\n${logBody}\n`;

      try {
        const savedPath = await invoke('save_installation_logs', { content: fullContent });
        alert(`✅ Journal d'installation enregistré avec succès :\n${savedPath}`);
      } catch (err) {
        if (err && String(err).includes("Annulé")) {
          return;
        }
        try {
          const blob = new Blob([fullContent], { type: 'text/plain;charset=utf-8' });
          const url = URL.createObjectURL(blob);
          const a = document.createElement('a');
          a.href = url;
          a.download = `chomiamos-installation-${Date.now()}.txt`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(url);
        } catch (blobErr) {
          alert("Erreur lors de l'enregistrement des logs : " + err);
        }
      }
    });
  }
}

async function startInstallation(s) {
  try {
    // Basculer vers l'écran d'installation (Panel 10)
    const curPanel = document.getElementById(`panel-step-${currentStep}`);
    if (curPanel) curPanel.classList.remove('active');

    const installPanel = document.getElementById('panel-step-install');
    if (installPanel) installPanel.classList.add('active');

    // Verrouillage du scroll sur le conteneur parent pour forcer le scroll uniquement dans le terminal
    document.querySelector('.step-content-area')?.classList.add('no-scroll');
    document.querySelector('.wizard-actions')?.classList.add('hidden');
    document.querySelector('.stepper-sidebar')?.classList.add('hidden');

    initMirrorDetection();
    appendLog("🚀 Démarrage du processus d'installation...");
    appendLog(`Disque cible configuré : ${s.target_disk}`);
    appendLog(`Système de fichiers : ${s.filesystem.toUpperCase()}${s.filesystem === 'btrfs' ? ' (compression ' + s.btrfs_compression + ', sous-volumes @, @home, @nix, @swap)' : ' (ext4)'}`);
    appendLog(`Taille de Swap sélectionnée : ${s.swap_size_mb === 0 ? 'Désactivé' : (s.swap_size_mb / 1024) + ' Go'}`);
    appendLog(`Environnement de bureau : ${s.desktop_env} | Pilote GPU : ${s.gpu_driver || 'amd'}`);

    await invoke('start_installation', { selections: s, dryRun: false });

    // Écoute directe de la progression en direct avec suivi des paquets
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

      // Mise à jour dynamique du compteur de paquets
      const countEl = document.getElementById('install-packages-count');
      const pkgEl = document.getElementById('install-current-pkg');
      if (p.current_pkg !== undefined && p.current_pkg !== null) {
        if (countEl) {
          if (p.total_pkgs && p.total_pkgs > 0) {
            const remaining = Math.max(0, p.total_pkgs - p.current_pkg);
            countEl.textContent = `📦 ${p.current_pkg} / ${p.total_pkgs} paquets installés (${remaining} restants)`;
          } else {
            countEl.textContent = `📦 ${p.current_pkg} paquets installés...`;
          }
        }
      }
      if (p.pkg_name && pkgEl) {
        pkgEl.textContent = `• ${p.pkg_name}`;
        pkgEl.title = p.pkg_name;
      }
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
            showInstallationErrorDiagnostic(snap.error, rawInstallationLogs);
          }
        }
      } catch (err) {
        console.error("Polling install state error:", err);
      }
    }, 200);
  } catch (err) {
    console.error("Fatal startInstallation error:", err);
    appendLog(`[ERREUR FATALE LANCEMENT] ${err}`);
    showInstallationErrorDiagnostic(String(err), rawInstallationLogs);
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

let currentChannel = localStorage.getItem('chomiamos_update_channel') || 'stable';

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
  initChannelButtons();

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

  checkAndUpdatePill();
}

function initChannelButtons() {
  document.querySelectorAll('.btn-channel').forEach(btn => {
    if (btn.dataset.bound) return;
    btn.dataset.bound = "true";
    btn.addEventListener('click', async (e) => {
      e.preventDefault();
      const newChan = btn.dataset.channel;
      if (newChan === currentChannel && currentUpdateInfo) return;
      currentChannel = newChan;
      localStorage.setItem('chomiamos_update_channel', currentChannel);

      updateChannelButtonsUI();
      const msg = document.getElementById('update-status-message');
      if (msg) msg.textContent = `Vérification du canal ${currentChannel === 'testing' ? 'Testing' : 'Stable'}...`;

      await checkAndUpdatePill(currentChannel);
      renderUpdateModalContent();
    });
  });
}

function updateChannelButtonsUI() {
  document.querySelectorAll('.btn-channel').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.channel === currentChannel);
  });
  const badge = document.getElementById('modal-active-channel-badge');
  if (badge) {
    badge.textContent = currentChannel === 'testing' ? 'Testing' : 'Stable';
    badge.className = `channel-badge ${currentChannel}`;
  }
}

async function checkAndUpdatePill(channelOverride) {
  const channel = channelOverride || currentChannel;
  const dot = document.getElementById('update-dot');
  const text = document.getElementById('update-status-text');
  const pillBtn = document.getElementById('btn-update-pill');

  try {
    const info = await invoke('check_installer_update', { channel });
    currentUpdateInfo = info;

    if (info && info.has_update) {
      if (dot) {
        dot.className = 'status-dot orange';
      }
      if (text) {
        text.textContent = info.is_downgrade 
          ? `Rétrogradation v${info.latest_version}` 
          : `Mise à jour v${info.latest_version}`;
      }
      if (pillBtn) {
        pillBtn.className = 'update-pill-btn update-available';
        pillBtn.title = info.is_downgrade
          ? `Rétrogradation disponible vers la version Stable (v${info.latest_version}). Cliquez pour installer.`
          : `Mise à jour v${info.latest_version} (${channel}) disponible ! Cliquez pour installer.`;
      }
    } else {
      const curVer = info ? info.current_version : "1.2.16";
      if (dot) {
        dot.className = 'status-dot green';
      }
      if (text) {
        text.textContent = `À jour (v${curVer} • ${channel === 'testing' ? 'Testing' : 'Stable'})`;
      }
      if (pillBtn) {
        pillBtn.className = 'update-pill-btn up-to-date';
        pillBtn.title = `L'installateur est à jour sur la branche ${channel} (v${curVer}).`;
      }
    }
    return info;
  } catch (err) {
    console.warn("Check update error:", err);
    return null;
  }
}

function renderUpdateModalContent() {
  const curVer = currentUpdateInfo ? currentUpdateInfo.current_version : "1.2.16";
  const latestVer = currentUpdateInfo ? currentUpdateInfo.latest_version : "1.2.16";
  const hasUpdate = currentUpdateInfo ? currentUpdateInfo.has_update : false;
  const isDowngrade = currentUpdateInfo ? currentUpdateInfo.is_downgrade : false;

  const elCur = document.getElementById('modal-current-ver');
  const elLat = document.getElementById('modal-latest-ver');
  const elMsg = document.getElementById('update-status-message');
  const elNotesWrap = document.getElementById('update-notes-container');
  const elNotes = document.getElementById('update-notes-content');
  const btnStart = document.getElementById('btn-start-update');
  const progSection = document.getElementById('update-progress-section');
  const downgradeBanner = document.getElementById('downgrade-alert-box');
  const downgradeCur = document.getElementById('downgrade-cur-ver');
  const downgradeTarget = document.getElementById('downgrade-target-ver');

  updateChannelButtonsUI();

  if (elCur) elCur.textContent = `v${curVer}`;
  if (elLat) {
    elLat.textContent = `v${latestVer}`;
    elLat.className = `version-val latest ${hasUpdate ? 'has-update' : ''}`;
  }

  if (progSection) progSection.classList.add('hidden');

  if (hasUpdate) {
    if (isDowngrade) {
      // Cas de rétrogradation (Downgrade vers Stable)
      if (downgradeBanner) downgradeBanner.classList.remove('hidden');
      if (downgradeCur) downgradeCur.textContent = `v${curVer}`;
      if (downgradeTarget) downgradeTarget.textContent = `v${latestVer}`;

      if (elMsg) elMsg.textContent = `Vous êtes sur une version testing (v${curVer}). Le canal Stable officiel est actuellement en v${latestVer}.`;
      if (btnStart) {
        btnStart.classList.remove('hidden');
        btnStart.className = 'btn btn-downgrade';
        btnStart.disabled = false;
        btnStart.textContent = `Rétrograder vers la version Stable (v${latestVer})`;
      }
    } else {
      // Cas de mise à jour classique (Upgrade)
      if (downgradeBanner) downgradeBanner.classList.add('hidden');
      if (elMsg) elMsg.textContent = `Une nouvelle version de l'installateur (v${latestVer}) est disponible sur le canal ${currentChannel === 'testing' ? 'Testing' : 'Stable'}.`;
      if (btnStart) {
        btnStart.classList.remove('hidden');
        btnStart.className = 'btn btn-primary';
        btnStart.disabled = false;
        btnStart.textContent = `Mettre à jour vers v${latestVer}`;
      }
    }

    if (currentUpdateInfo.notes && elNotes && elNotesWrap) {
      elNotes.textContent = currentUpdateInfo.notes;
      elNotesWrap.classList.remove('hidden');
    } else if (elNotesWrap) {
      elNotesWrap.classList.add('hidden');
    }
  } else {
    // Cas à jour
    if (downgradeBanner) downgradeBanner.classList.add('hidden');
    if (elMsg) {
      elMsg.textContent = `Votre installateur ChomiamOS est parfaitement à jour sur la branche ${currentChannel === 'testing' ? 'Testing' : 'Stable'} (v${curVer}).`;
    }
    if (btnStart) btnStart.classList.add('hidden');
    if (elNotesWrap) elNotesWrap.classList.add('hidden');
  }
}

function openUpdateModal() {
  const modal = ensureUpdateModalExists();
  if (!modal) return;
  renderUpdateModalContent();
  modal.classList.remove('hidden');
}

// ── Indicateurs Clavier (Verr Maj / Caps Lock & Verr Num / Num Lock) ─────────
function initKeyboardModifiers() {
  function updatePills(capsLock, numLock) {
    const capsPill = document.getElementById('indicator-caps-lock');
    const capsStatus = document.getElementById('status-caps-lock');
    if (capsPill && capsStatus) {
      if (capsLock) {
        capsPill.className = 'keyboard-indicator-pill caps-active';
        capsStatus.textContent = 'Actif (Maj)';
        capsPill.title = 'Attention : les majuscules sont actives, le mot de passe est sensible à la casse';
      } else {
        capsPill.className = 'keyboard-indicator-pill';
        capsStatus.textContent = 'Désactivé';
        capsPill.title = 'Majuscules désactivées';
      }
    }

    const numPill = document.getElementById('indicator-num-lock');
    const numStatus = document.getElementById('status-num-lock');
    if (numPill && numStatus) {
      if (numLock) {
        numPill.className = 'keyboard-indicator-pill num-active';
        numStatus.textContent = 'Actif';
        numPill.title = 'Pavé numérique actif';
      } else {
        numPill.className = 'keyboard-indicator-pill';
        numStatus.textContent = 'Inactif';
        numPill.title = 'Pavé numérique inactif';
      }
    }
  }

  async function syncHardwareLocks() {
    try {
      const locks = await invoke('get_keyboard_locks');
      if (locks) {
        updatePills(locks.caps_lock, locks.num_lock);
      }
    } catch (err) {
      // Ignorer si non disponible
    }
  }

  window.syncKeyboardHardwareLocks = syncHardwareLocks;

  function handleKeyEvent(e) {
    if (!e) return;
    let caps = null;
    let num = null;

    if (e.getModifierState) {
      caps = e.getModifierState('CapsLock');
      num = e.getModifierState('NumLock');
    }

    // Heuristique de détection de frappe directe
    if (e.key && e.key.length === 1 && !e.shiftKey) {
      if (e.key >= 'A' && e.key <= 'Z') caps = true;
      else if (e.key >= 'a' && e.key <= 'z') caps = false;
    }

    if (caps !== null || num !== null) {
      const currentCaps = caps !== null ? caps : (document.getElementById('indicator-caps-lock')?.classList.contains('caps-active') ?? false);
      const currentNum = num !== null ? num : (document.getElementById('indicator-num-lock')?.classList.contains('num-active') ?? false);
      updatePills(currentCaps, currentNum);
    }

    // Si CapsLock ou NumLock a été pressé, interroger le hardware avec double vérification
    if (e.key === 'CapsLock' || e.key === 'NumLock') {
      setTimeout(syncHardwareLocks, 30);
      setTimeout(syncHardwareLocks, 120);
    }
  }

  const pwdInputs = [document.getElementById('input-password'), document.getElementById('input-password-confirm')];
  pwdInputs.forEach(input => {
    if (!input) return;
    input.addEventListener('keydown', handleKeyEvent);
    input.addEventListener('keyup', handleKeyEvent);
    input.addEventListener('input', handleKeyEvent);
    input.addEventListener('focus', () => syncHardwareLocks());
  });

  // Écouteurs globaux en mode capture
  window.addEventListener('keydown', handleKeyEvent, true);
  window.addEventListener('keyup', handleKeyEvent, true);
  window.addEventListener('focus', () => syncHardwareLocks());

  // Polling doux périodique spécifiquement sur l'étape 9
  setInterval(() => {
    if (currentStep === 10) {
      syncHardwareLocks();
    }
  }, 800);

  // Synchronisation matérielle immédiate
  syncHardwareLocks();
}

// ── Validation et Sanitisation en direct du Hostname (RFC 1123) ──────────────
function initHostnameValidation() {
  const input = document.getElementById('input-hostname');
  const errorMsg = document.getElementById('hostname-validation-msg');
  if (!input) return;

  let errorTimeout = null;
  function showHostnameError(msg) {
    if (!errorMsg) return;
    errorMsg.textContent = msg;
    errorMsg.classList.remove('hidden');
    if (errorTimeout) clearTimeout(errorTimeout);
    errorTimeout = setTimeout(() => {
      if (errorMsg) errorMsg.classList.add('hidden');
    }, 2800);
  }

  function sanitize(val) {
    let s = val.toLowerCase();
    // Remplacer espaces, underscores et points par des tirets
    s = s.replace(/[\s_.]+/g, '-');
    // Supprimer tout caractère qui n'est pas a-z, 0-9 ou tiret
    s = s.replace(/[^a-z0-9-]/g, '');
    // Ne pas commencer par un tiret
    s = s.replace(/^-+/, '');
    // Éviter les tirets consécutifs
    s = s.replace(/--+/g, '-');
    return s.slice(0, 63);
  }

  // Bloquer immédiatement toute frappe de touche interdite
  input.addEventListener('keydown', (e) => {
    // Laisser passer les touches de commande et de contrôle
    if (e.ctrlKey || e.altKey || e.metaKey || e.key.length > 1) {
      return;
    }

    const char = e.key;
    // Caractères permis : a-z, A-Z (qui sera transformé en minuscule), 0-9, et le tiret '-'
    if (!/^[a-zA-Z0-9-]$/.test(char)) {
      e.preventDefault();
      showHostnameError("Caractère '" + char + "' non autorisé. Seules les lettres (a-z), chiffres (0-9) et tirets (-) sont acceptés.");
      return;
    }

    // Empêcher de commencer par un tiret
    if (char === '-' && (input.selectionStart === 0 || input.value.length === 0)) {
      e.preventDefault();
      showHostnameError("Le nom d'hôte ne peut pas commencer par un tiret.");
    }
  });

  // Sanitisation instantanée lors de la saisie ou d'un coller
  input.addEventListener('input', () => {
    const original = input.value;
    const cleaned = sanitize(original);
    if (original !== cleaned) {
      input.value = cleaned;
    }
  });

  input.addEventListener('blur', () => {
    input.value = input.value.replace(/-+$/, '');
    if (!input.value.trim()) {
      input.value = 'chomiamos';
    }
  });
}

// ── Bouton œil pour afficher / masquer le mot de passe ──────────────────────
function initPasswordVisibilityToggles() {
  document.querySelectorAll('.btn-toggle-password').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const targetId = btn.dataset.target;
      const input = document.getElementById(targetId);
      if (!input) return;

      if (input.type === 'password') {
        input.type = 'text';
        btn.textContent = '🙈';
        btn.title = 'Masquer le mot de passe';
        btn.setAttribute('aria-label', 'Masquer le mot de passe');
      } else {
        input.type = 'password';
        btn.textContent = '👁️';
        btn.title = 'Afficher le mot de passe';
        btn.setAttribute('aria-label', 'Afficher le mot de passe');
      }
      input.focus();
    });
  });
}

// ── Détection du Miroir NixOS et Latence (v1.2.18) ──────────────────────────
async function initMirrorDetection() {
  try {
    const info = await invoke('get_mirror_info');
    if (info) {
      const textEl = document.getElementById('install-mirror-text');
      const dotEl = document.getElementById('mirror-dot');
      const pillEl = document.getElementById('install-mirror-pill');

      if (textEl) {
        textEl.textContent = `Fastly CDN • ${info.location} (${info.latency_ms} ms)`;
      }
      if (pillEl) {
        pillEl.title = `Miroir optimal détecté : ${info.location} (Latence : ${info.latency_ms} ms)`;
      }
      if (dotEl) {
        dotEl.className = `status-dot ${info.quality === 'optimal' ? 'green' : (info.quality === 'good' ? 'green' : 'orange')} pulse`;
      }
    }
  } catch (e) {
    console.warn("Erreur détection miroir:", e);
  }
}


// ==========================================================================
// 🔍 Système de Diagnostic Intelligent des Pannes d'Installation
// ==========================================================================

let lastDiagnosticData = null;

function diagnoseInstallationLogs(fatalError, logs = []) {
  const allText = logs.join('\n');

  let type = "GENERIC_BUILD";
  let title = "Échec de la Dérivation Système";
  let icon = "⚠️";
  let badge = "Erreur Dérivation";
  let culprit = "Processus d'installation NixOS";
  let rawCulprit = "nixos-install";
  let explanation = "Une étape exécutée par le gestionnaire de paquets Nix a retourné un code de sortie d'erreur non nul.";
  let recommendations = [
    "Consultez les lignes d'erreur dans le terminal ci-dessous pour identifier le composant précis.",
    "Enregistrez le journal complet des logs avec le bouton ci-dessous pour le transmettre au support ChomiamOS."
  ];
  let recommendedStep = 11;

  // 0.5 Détection Erreur de Partitionnement / GPT / Parted / Disque Occupé
  if (/Échec de création du label GPT|Partition\(s\) on .* are being used|Échec de création de la partition/i.test(allText)) {
    type = "PARTITIONING_ERROR";
    title = "Conflit de Partitionnement Disque (Parted)";
    icon = "💽";
    badge = "Disque Occupé (Partition active)";
    culprit = "Disque cible verrouillé par le système";
    rawCulprit = "Partitions déjà montées ou verrouillées par le bureau live";
    explanation = "Le partitionneur (parted) n'a pas pu initialiser la table GPT car une ou plusieurs partitions de ce disque étaient encore montées ou utilisées par le système.";
    recommendations = [
      "Le programme force désormais le démontage et l'effacement propre des verrous du disque.",
      "Cliquez sur <strong>« Modifier mes choix & Réessayer »</strong> pour relancer l'installation sans encombre."
    ];
    recommendedStep = 3;
    return {
      type, title, icon, badge, culprit, rawCulprit, explanation, recommendations, recommendedStep,
      relevantLines: logs.filter(l => /ERREUR FATALE|parted|label GPT|wipefs/i.test(l)).slice(-5),
      fullLogText: allText
    };
  }

    // 1. Détection Out Of Memory (OOM-Killer / Saturation RAM & Swap)
  const isOOM = /Killed\s+(npm|cargo|rustc|vite|node|\$npmBuildScript|\$\{npmWorkspace)/i.test(allText)
    || /line\s+\d+:\s+\d+\s+Killed/i.test(allText)
    || /Out of memory/i.test(allText)
    || /signal 9/i.test(allText)
    || /exit code:?\s*(Some\(137\)|137)/i.test(allText)
    || /JavaScript heap out of memory/i.test(allText);

  if (isOOM) {
    type = "OOM_KILLER";
    title = "Saturation de la Mémoire Vive (Out Of Memory)";
    icon = "🧠";
    badge = "OOM-Killer (RAM saturée)";
    recommendedStep = 9;

    if (allText.includes("open-webui") || allText.includes("CellEditor.svelte") || allText.includes("vite-plugin-svelte")) {
      culprit = "Suite IA Locale (Interface Web Open-WebUI)";
      rawCulprit = "open-webui-frontend-0.11.3.drv (Vite / Node.js)";
      explanation = "La compilation locale du frontend d'Open-WebUI (plus de 6 300 modules TypeScript et Svelte) a dépassé la mémoire vive disponible. Le noyau Linux a brutalement arrêté le processus (signal SIGKILL / 989 Killed) pour protéger le système.";
      recommendations = [
        "<strong>Action immédiate :</strong> Cliquez sur <em>« Modifier mes choix & Réessayer »</em> pour <strong>décocher la Suite IA Locale</strong> à l'Étape 9. Vous pourrez l'installer facilement une fois votre système prêt.",
        "Si vous installez ChomiamOS dans une <strong>Machine Virtuelle (VM)</strong>, allouez-lui au moins <strong>8 à 10 Go de RAM</strong>.",
        "À l'Étape 3 (Disque), allouez un fichier ou une partition <strong>Swap d'au moins 4 à 8 Go</strong>."
      ];
    } else {
      culprit = "Compilation d'un composant lourd";
      rawCulprit = "Processus arrêté par le noyau (OOM)";
      explanation = "Un processus de compilation a saturé l'intégralité de la RAM et du Swap de votre machine, forçant le noyau Linux à intervenir.";
      recommendations = [
        "Désactivez les options ou outils facultatifs lourds pour cette première installation.",
        "Augmentez la mémoire RAM allouée ou prévoyez un espace de Swap plus spacieux à l'Étape 3."
      ];
    }
  }
  // 2. Détection Erreur Réseau / Miroir / Téléchargement
  else if (/download failed|stalled-download-timeout|Could not resolve host|temporary failure in name resolution|Failed to connect to|Connection refused|timed out|502 Bad Gateway|503 Service Unavailable|504 Gateway Timeout/i.test(allText)) {
    type = "NETWORK_ERROR";
    title = "Interruption de la Connexion Réseau";
    icon = "🌐";
    badge = "Erreur Réseau / Miroir";
    culprit = "Serveur de Téléchargement des Paquets (Cache / Miroir)";
    rawCulprit = "Cachix / cache.nixos.org";
    explanation = "L'installateur n'a pas pu récupérer les archives binaires indispensables en raison d'une déconnexion Internet ou d'un serveur de cache temporairement injoignable.";
    recommendations = [
      "Vérifiez que votre connexion Internet filaire ou Wi-Fi est stable et active.",
      "À l'Étape 1 (Prérequis), vérifiez le test de vitesse et assurez-vous que les serveurs sont opérationnels.",
      "Assurez-vous qu'aucun pare-feu d'entreprise ou portail captif ne bloque les requêtes HTTP/HTTPS vers <code>cache.nixos.org</code> ou <code>chomiamos.cachix.org</code>."
    ];
    recommendedStep = 1;
  }
  // 2.5 Détection Erreur Montage Disque / Subvolumes Btrfs
  else if (/montage temporaire|subvolume Btrfs|Device or resource busy|EBUSY|failed to mount/i.test(allText)) {
    type = "MOUNT_ERROR";
    title = "Conflit ou Verrouillage Disque / Montage Btrfs";
    icon = "💽";
    badge = "Erreur Montage (EBUSY)";
    culprit = "Périphérique NVMe / SSD occupé";
    rawCulprit = "Périphérique verrouillé temporairement par le système";
    explanation = "Le noyau Linux ou le gestionnaire udev maintenait un accès exclusif sur la partition fraîchement formatée lors de la tentative de montage.";
    recommendations = [
      "Cliquez ci-dessous sur <strong>« Modifier mes choix & Réessayer »</strong> et relancez l'installation : la temporisation automatique et udev settle résoudront le verrouillage.",
      "Assurez-vous qu'aucun explorateur de fichiers ou terminal n'est ouvert sur le disque en session live."
    ];
    recommendedStep = 3;
  }
  // 3. Détection Espace Disque Saturé
  else if (/No space left on device|ENOSPC|disk full|write error: No space/i.test(allText)) {
    type = "DISK_FULL";
    title = "Espace Disque Insuffisant";
    icon = "💾";
    badge = "Disque Saturé (ENOSPC)";
    culprit = "Partition Racine (/mnt)";
    rawCulprit = "Espace disque libre épuisé";
    explanation = "L'espace disponible sur la partition cible est insuffisant pour extraire et stocker l'intégralité de l'image système de ChomiamOS.";
    recommendations = [
      "Choisissez un disque de destination disposant d'au moins 60 à 80 Go d'espace libre.",
      "À l'Étape 3 (Disque), supprimez les anciennes partitions ou réduisez la taille du Swap si votre disque est trop exigu."
    ];
    recommendedStep = 3;
  }
  // 4. Détection Problème Bootloader / EFI
  else if (/bootloader failed|efibootmgr|Failed to install bootloader|no efi system partition|ESP|systemd-boot/i.test(allText)) {
    type = "BOOTLOADER_ERROR";
    title = "Échec de l'Amorçage EFI (Bootloader)";
    icon = "⚡";
    badge = "Erreur Chargeur EFI";
    culprit = "Gestionnaire de démarrage UEFI (systemd-boot)";
    rawCulprit = "Inscription NVRAM EFI rejetée";
    explanation = "Le programme d'installation n'a pas pu enregistrer les entrées de démarrage EFI dans la carte mère de l'ordinateur.";
    recommendations = [
      "Accédez aux réglages du BIOS de votre ordinateur et <strong>désactivez le Secure Boot</strong>.",
      "Assurez-vous que la machine a bien démarré la clé d'installation en mode <strong>UEFI</strong> natif (et non en mode Legacy / CSM)."
    ];
    recommendedStep = 3;
  }
  // 5. Détection Hash Mismatch
  else if (/hash mismatch|sha256 mismatch/i.test(allText)) {
    type = "HASH_MISMATCH";
    title = "Incompatibilité de Condensat Cryptographique";
    icon = "🔒";
    badge = "Hash Mismatch";
    culprit = "Fichier source d'archive corrompu";
    rawCulprit = "Condensat SHA256 inattendu";
    explanation = "Un fichier téléchargé ne correspond pas à l'empreinte de sécurité attendue (paquet altéré lors du transit réseau ou mise à jour amont non répercutée).";
    recommendations = [
      "Relancez l'installation pour retélécharger proprement le fichier.",
      "Basculez sur un autre miroir réseau à l'Étape 1."
    ];
    recommendedStep = 1;
  }
  // 6. Détection Erreur de build générique
  else if (/Cannot build '([^']+)'/i.test(allText) || /builder for '([^']+)' failed/i.test(allText)) {
    const match = allText.match(/Cannot build '([^']+)'/) || allText.match(/builder for '([^']+)' failed/);
    const drv = match ? match[1].split('/').pop().replace('.drv', '') : "Dérivation inconnue";
    culprit = `Échec sur le paquet : ${drv}`;
    rawCulprit = match ? match[1].split('/').pop() : drv;
    explanation = `La compilation du paquet source <code>${drv}</code> a échoué et ce binaire n'était pas disponible dans le cache.`;
    recommendations = [
      "Vérifiez si ce paquet correspond à une option facultative sélectionnée et décochez-la temporairement.",
      "Enregistrez les logs complets pour demander de l'aide à la communauté ChomiamOS."
    ];
    recommendedStep = 11;
  }

  // Filtrage des 8 dernières lignes techniques d'erreur
  const errorLines = logs.filter(l => l.includes("[ERR]") || l.includes("error:") || l.includes("Killed") || l.includes("FATALE")).slice(-8);
  const rawSnippet = errorLines.length > 0 ? errorLines.join('\n') : (fatalError || "Aucun détail supplémentaire capturé.");

  return {
    type,
    title,
    icon,
    badge,
    culprit,
    rawCulprit,
    explanation,
    recommendations,
    recommendedStep,
    rawSnippet,
    fatalError
  };
}

function showInstallationErrorDiagnostic(fatalError, logs = []) {
  const diag = diagnoseInstallationLogs(fatalError, logs);
  lastDiagnosticData = diag;

  // 1. Mettre à jour et afficher la bannière persistante
  const banner = document.getElementById('install-diagnostic-banner');
  if (banner) {
    const iconEl = document.getElementById('diag-banner-icon');
    const titleEl = document.getElementById('diag-banner-title-text');
    const badgeEl = document.getElementById('diag-banner-badge');
    const subEl = document.getElementById('diag-banner-sub');

    if (iconEl) iconEl.textContent = diag.icon;
    if (titleEl) titleEl.textContent = diag.title;
    if (badgeEl) badgeEl.textContent = diag.badge;
    if (subEl) subEl.textContent = diag.culprit ? `Composant : ${diag.culprit}` : "Cause identifiée par l'analyse des journaux.";
    banner.classList.remove('hidden');
  }

  // 2. Mettre à jour les données de la fenêtre modale
  const modal = document.getElementById('modal-install-diagnostic');
  if (modal) {
    const iconEl = document.getElementById('diag-icon-badge');
    const titleEl = document.getElementById('diag-modal-title');
    const badgeEl = document.getElementById('diag-modal-badge');
    const valEl = document.getElementById('diag-culprit-val');
    const rawEl = document.getElementById('diag-culprit-raw');
    const explEl = document.getElementById('diag-explanation-text');

    if (iconEl) iconEl.textContent = diag.icon;
    if (titleEl) titleEl.textContent = diag.title;
    if (badgeEl) badgeEl.textContent = diag.badge;
    if (valEl) valEl.textContent = diag.culprit;
    if (rawEl) rawEl.textContent = diag.rawCulprit;
    if (explEl) explEl.innerHTML = diag.explanation;

    const list = document.getElementById('diag-solutions-list');
    if (list) {
      list.innerHTML = diag.recommendations.map((rec, i) => `
        <li class="diag-solution-item">
          <div class="diag-solution-num">${i + 1}</div>
          <div class="diag-solution-content">${rec}</div>
        </li>
      `).join('');
    }

    const snippet = document.getElementById('diag-snippet-box');
    if (snippet) {
      snippet.textContent = diag.rawSnippet;
    }

    // Afficher la modale
    modal.classList.remove('hidden');
  }
}

function restoreWizardFromInstallation(targetStep = 11) {
  // 1. Fermer la modale et cacher la bannière
  document.getElementById('modal-install-diagnostic')?.classList.add('hidden');

  // 2. Désactiver le panneau d'installation
  document.getElementById('panel-step-install')?.classList.remove('active');

  // 3. Réactiver la navigation complète du wizard
  document.querySelector('.step-content-area')?.classList.remove('no-scroll');
  document.querySelector('.wizard-actions')?.classList.remove('hidden');
  document.querySelector('.stepper-sidebar')?.classList.remove('hidden');

  // 4. Naviguer vers l'étape recommandée
  goToStep(targetStep);
}

function initDiagnosticHandlers() {
  // 1. Ouvrir la modale depuis la bannière
  document.getElementById('btn-diag-banner-open')?.addEventListener('click', () => {
    document.getElementById('modal-install-diagnostic')?.classList.remove('hidden');
  });

  // 2. Boutons "Modifier mes choix & Réessayer"
  const handleRetry = () => {
    const target = lastDiagnosticData ? lastDiagnosticData.recommendedStep : 11;
    restoreWizardFromInstallation(target);
  };
  document.getElementById('btn-diag-banner-retry')?.addEventListener('click', handleRetry);
  document.getElementById('btn-diag-retry')?.addEventListener('click', handleRetry);

  // 3. Fermer la modale pour voir le terminal
  document.getElementById('btn-diag-close')?.addEventListener('click', () => {
    document.getElementById('modal-install-diagnostic')?.classList.add('hidden');
  });

  // 4. Sauvegarder les logs
  document.getElementById('btn-diag-export-logs')?.addEventListener('click', async () => {
    try {
      const content = rawInstallationLogs.join('\n');
      const savedPath = await invoke('save_installation_logs', { content });
      alert(`Journal sauvegardé avec succès dans :\n${savedPath}`);
    } catch (err) {
      if (!String(err).includes('Annulé')) {
        alert(`Erreur lors de la sauvegarde: ${err}`);
      }
    }
  });

  // 5. Copier le rapport d'incident dans le presse-papier
  document.getElementById('btn-diag-copy')?.addEventListener('click', async () => {
    if (!lastDiagnosticData) return;
    const btn = document.getElementById('btn-diag-copy');
    const originalText = btn ? btn.textContent : "📋 Copier le rapport d'incident";

    const report = [
      "### 🚨 Rapport d'Incident d'Installation ChomiamOS",
      `- **Horodatage** : ${new Date().toLocaleString()}`,
      `- **Type de panne** : ${lastDiagnosticData.title} (${lastDiagnosticData.badge})`,
      `- **Composant concerné** : ${lastDiagnosticData.culprit} (\`${lastDiagnosticData.rawCulprit}\`)`,
      "",
      "#### 📖 Explication",
      lastDiagnosticData.explanation.replace(/<[^>]*>/g, ''),
      "",
      "#### 💡 Solutions suggérées",
      ...lastDiagnosticData.recommendations.map((r, i) => `${i + 1}. ${r.replace(/<[^>]*>/g, '')}`),
      "",
      "#### 🔍 Dernières lignes d'erreurs capturées",
      "```text",
      lastDiagnosticData.rawSnippet,
      "```"
    ].join('\n');

    try {
      await navigator.clipboard.writeText(report);
      if (btn) btn.textContent = "✓ Rapport Copié !";
      setTimeout(() => {
        if (btn) btn.textContent = originalText;
      }, 3000);
    } catch (e) {
      alert("Impossible de copier automatiquement dans le presse-papier.");
    }
  });
}

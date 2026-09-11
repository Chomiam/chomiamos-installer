// ==========================================================================
// ChomiamOS Installer - Tauri v2 Controller
// ==========================================================================

let currentStep = 1;
const totalSteps = 7;
let availableLayouts = [];
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
  await loadDisks();
  initSwapSlider();
  initSummaryTrigger();
  initConfirmationModal();
  await checkForAppUpdates();
});

function initNavigation() {
  const btnPrev = document.getElementById('btn-prev');
  const btnNext = document.getElementById('btn-next');
  const btnInstall = document.getElementById('btn-install');

  btnPrev.addEventListener('click', () => {
    if (currentStep > 1) goToStep(currentStep - 1);
  });

  btnNext.addEventListener('click', () => {
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

async function loadPrerequisites() {
  try {
    const pre = await invoke('get_prerequisites');
    updatePrereqCard('prereq-efi', pre.is_efi, pre.is_efi ? 'Mode UEFI Détecté' : 'Mode BIOS Legacy Détecté');
    updatePrereqCard('prereq-ram', pre.has_sufficient_ram, `${pre.ram_gb} Go de RAM détectés`);
    updatePrereqCard('prereq-disk', pre.has_sufficient_disk, `${pre.disk_gb} Go d'espace disponible`);
    updatePrereqCard('prereq-net', pre.has_internet, pre.has_internet ? 'Connecté à Internet' : 'Connexion Internet Absente');
  } catch (e) {
    console.error("Prerequisites error:", e);
  }
}

function updatePrereqCard(id, passed, detail) {
  const card = document.getElementById(id);
  if (!card) return;
  const statusEl = card.querySelector('.prereq-status');
  const detailEl = card.querySelector('.prereq-detail');
  if (passed) {
    statusEl.textContent = '✓ Conforme';
    statusEl.className = 'prereq-status status-ok';
  } else {
    statusEl.textContent = '✗ Attention';
    statusEl.className = 'prereq-status status-warn';
  }
  if (detailEl && detail) detailEl.textContent = detail;
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
    const selVariant = document.getElementById('keyboard-variant-select');
    selLayout.innerHTML = '';

    availableLayouts.forEach(l => {
      const opt = document.createElement('option');
      opt.value = l.id;
      opt.textContent = `${l.name} (${l.id.toUpperCase()})`;
      if (l.id === 'fr') opt.selected = true;
      selLayout.appendChild(opt);
    });

    updateVariantsDropdown('fr');

    selLayout.addEventListener('change', async () => {
      const lid = selLayout.value;
      updateVariantsDropdown(lid);
      await applyKeyboard();
    });

    selVariant.addEventListener('change', async () => {
      await applyKeyboard();
    });
  } catch (e) {
    console.error("Failed to load layouts:", e);
  }
}

function updateVariantsDropdown(layoutId) {
  const selVariant = document.getElementById('keyboard-variant-select');
  selVariant.innerHTML = '';

  const found = availableLayouts.find(l => l.id === layoutId);
  const defOpt = document.createElement('option');
  defOpt.value = "";
  defOpt.textContent = "Par défaut (Standard)";
  selVariant.appendChild(defOpt);

  if (found && found.variants) {
    found.variants.forEach(v => {
      const opt = document.createElement('option');
      opt.value = v.id;
      opt.textContent = v.name;
      selVariant.appendChild(opt);
    });
  }
}

async function applyKeyboard() {
  const layout = document.getElementById('keyboard-layout-select').value;
  const variant = document.getElementById('keyboard-variant-select').value;
  try {
    await invoke('apply_keyboard_live', { layout, variant });
  } catch (e) {
    console.error("Apply keyboard failed:", e);
  }
}

async function loadDisks() {
  try {
    availableDisks = await invoke('get_disks');
    const container = document.getElementById('disks-container');
    if (availableDisks.length === 0) {
      container.innerHTML = '<div class="alert alert-warn">Aucun disque fixe détecté. Mode simulation actif.</div>';
      return;
    }

    container.innerHTML = availableDisks.map((d, idx) => `
      <div class="disk-card ${idx === 0 ? 'selected' : ''}" data-path="${d.path}">
        <span class="disk-icon">💾</span>
        <div class="disk-details">
          <strong>${d.model || 'Disque Système'} (${d.path})</strong>
          <small>${d.size_gb} Go • ${d.is_removable ? 'Amovible' : 'Fixe'}</small>
        </div>
        <span class="badge">${idx === 0 ? 'Sélectionné' : 'Cliquer pour choisir'}</span>
      </div>
    `).join('');

    document.querySelectorAll('.disk-card').forEach(card => {
      card.addEventListener('click', () => {
        document.querySelectorAll('.disk-card').forEach(c => {
          c.classList.remove('selected');
          c.querySelector('.badge').textContent = 'Cliquer pour choisir';
        });
        card.classList.add('selected');
        card.querySelector('.badge').textContent = 'Sélectionné';
      });
    });
  } catch (e) {
    console.error("Failed to load disks:", e);
  }
}

function initSwapSlider() {
  const slider = document.getElementById('swap-slider');
  const valSpan = document.getElementById('swap-size-val');

  slider.addEventListener('input', () => {
    const val = parseInt(slider.value);
    if (val === 0) {
      valSpan.textContent = "Désactivé";
    } else {
      valSpan.textContent = `${val / 1024} Go`;
    }
  });
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
    keyboard_variant: document.getElementById('keyboard-variant-select').value || "",
    target_disk: diskPath,
    swap_size_mb: parseInt(document.getElementById('swap-slider').value) || 8192,
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
    <div class="summary-item"><label>Disposition Clavier</label><span>${s.keyboard_layout} ${s.keyboard_variant ? '(' + s.keyboard_variant + ')' : ''}</span></div>
    <div class="summary-item"><label>Bureau Choisi</label><span>${s.desktop_env.toUpperCase()}</span></div>
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
  line.textContent = `> ${text}`;
  term.appendChild(line);
  term.scrollTop = term.scrollHeight;
}

async function startInstallation(s) {
  // Basculer vers l'écran d'installation (Panel 8)
  document.getElementById(`panel-step-${currentStep}`).classList.remove('active');
  document.getElementById('panel-step-8').classList.add('active');
  document.querySelector('.wizard-actions').classList.add('hidden');
  document.querySelector('.wizard-nav').classList.add('hidden');

  appendLog("🚀 Démarrage du processus d'installation...");
  appendLog(`Disque cible configuré : ${s.target_disk}`);

  try {
    await invoke('start_installation', { selections: s, dryRun: false });
  } catch (err) {
    appendLog(`[ERREUR LANCEMENT] ${err}`);
    alert(`Erreur: ${err}`);
    return;
  }

  // Écoute directe des événements si disponible
  listen('install_progress', (e) => {
    const p = e.payload || e;
    if (p.percent !== undefined) {
      document.getElementById('install-bar-fill').style.width = `${p.percent}%`;
      document.getElementById('install-percent-val').textContent = `${p.percent}%`;
    }
    if (p.step) document.getElementById('install-step-title').textContent = p.step;
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
        document.getElementById('install-bar-fill').style.width = `${snap.percent}%`;
        document.getElementById('install-percent-val').textContent = `${snap.percent}%`;
      }
      if (snap.step) {
        document.getElementById('install-step-title').textContent = snap.step;
      }

      if (snap.is_finished) {
        clearInterval(pollInterval);
        if (snap.success) {
          document.getElementById('install-complete-card').classList.remove('hidden');
          document.getElementById('install-heading').textContent = "Installation Terminée !";
          document.getElementById('install-subheading').textContent = "ChomiamOS Gaming Edition est prêt.";
        } else {
          appendLog(`[ERREUR FATALE] ${snap.error || 'Erreur inconnue'}`);
          alert(`Erreur d'installation: ${snap.error}`);
        }
      }
    } catch (err) {
      console.error("Polling install state error:", err);
    }
  }, 200);
}


async function checkForAppUpdates() {
  try {
    const info = await invoke('check_installer_update');
    if (info && info.has_update) {
      const banner = document.getElementById('update-notification');
      const verLabel = document.getElementById('update-version-label');
      const btnUpdate = document.getElementById('btn-apply-update');

      if (banner && verLabel && btnUpdate) {
        verLabel.textContent = `v${info.latest_version}`;
        banner.classList.remove('hidden');

        btnUpdate.addEventListener('click', async () => {
          btnUpdate.disabled = true;
          btnUpdate.textContent = "Téléchargement...";
          try {
            await invoke('apply_installer_update', { downloadUrl: info.download_url });
          } catch (err) {
            alert("Erreur lors de la mise à jour: " + err);
            btnUpdate.disabled = false;
            btnUpdate.textContent = "Mettre à jour";
          }
        });
      }
    }
  } catch (err) {
    console.debug("Check update error:", err);
  }
}

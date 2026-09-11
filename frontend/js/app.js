const { invoke } = window.__TAURI__.core;

let currentStep = 1;
const totalSteps = 7;
let availableLayouts = [];
let availableDisks = [];

document.addEventListener('DOMContentLoaded', async () => {
  await setupInstallationListeners();
  initInstallButton();
  initNavigation();
  await loadPrerequisites();
  await loadKeyboardLayouts();
  await loadDisks();
  initSwapSlider();
  initSummaryTrigger();
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

  // Desktop Environment radio click handling
  document.querySelectorAll('input[name="desktop_env"]').forEach(radio => {
    radio.addEventListener('change', () => {
      document.querySelectorAll('.selection-card').forEach(card => card.classList.remove('active'));
      radio.closest('.selection-card').classList.add('active');
    });
  });
}

function goToStep(step) {
  document.getElementById(`panel-step-${currentStep}`).classList.remove('active');
  document.querySelector(`.step-item[data-step="${currentStep}"]`).classList.remove('active');
  if (step > currentStep) {
    document.querySelector(`.step-item[data-step="${currentStep}"]`).classList.add('completed');
  }

  currentStep = step;

  document.getElementById(`panel-step-${currentStep}`).classList.add('active');
  document.querySelector(`.step-item[data-step="${currentStep}"]`).classList.add('active');

  const btnPrev = document.getElementById('btn-prev');
  const btnNext = document.getElementById('btn-next');
  const btnInstall = document.getElementById('btn-install');

  btnPrev.disabled = currentStep === 1;

  if (currentStep === totalSteps) {
    btnNext.classList.add('hidden');
    btnInstall.classList.remove('hidden');
    updateSummary();
  } else {
    btnNext.classList.remove('hidden');
    btnInstall.classList.add('hidden');
  }
}

async function loadPrerequisites() {
  try {
    const pre = await invoke('get_prerequisites');

    updatePrereqCard('prereq-efi', pre.is_efi, pre.is_efi ? 'Mode UEFI Détecté' : 'Mode BIOS Legacy Détecté');
    updatePrereqCard('prereq-ram', pre.ram_ok, `${pre.total_ram_gb} Go Détectés (${pre.cpu_cores} threads CPU)`);
    updatePrereqCard('prereq-internet', pre.has_internet, pre.has_internet ? 'Connecté (Accès caches Nix)' : 'Non connecté (Mode hors-ligne)');
    updatePrereqCard('prereq-disk', pre.disks_count > 0, `${pre.disks_count} disque(s) disponible(s)`);
  } catch (e) {
    console.error("Failed to load prerequisites:", e);
  }
}

function updatePrereqCard(id, ok, message) {
  const card = document.getElementById(id);
  card.classList.remove('loading');
  card.classList.add(ok ? 'success' : 'warning');
  card.querySelector('.prereq-status').textContent = message;
}

async function loadKeyboardLayouts() {
  try {
    availableLayouts = await invoke('get_layouts');
    const layoutSelect = document.getElementById('keyboard-layout-select');
    const variantSelect = document.getElementById('keyboard-variant-select');
    const testInput = document.getElementById('keyboard-test-input');

    layoutSelect.innerHTML = availableLayouts.map(l => `<option value="${l.code}">${l.name}</option>`).join('');

    const updateVariants = () => {
      const selectedCode = layoutSelect.value;
      const layout = availableLayouts.find(l => l.code === selectedCode);
      if (layout) {
        variantSelect.innerHTML = layout.variants.map(v => `<option value="${v}">${v === '' ? 'Par défaut (Standard)' : v}</option>`).join('');
      }
      applyKeyboardLive();
    };

    layoutSelect.addEventListener('change', updateVariants);
    variantSelect.addEventListener('change', applyKeyboardLive);

    updateVariants();
  } catch (e) {
    console.error("Failed to load keyboard layouts:", e);
  }
}

async function applyKeyboardLive() {
  const layout = document.getElementById('keyboard-layout-select').value;
  const variant = document.getElementById('keyboard-variant-select').value;
  try {
    await invoke('apply_keyboard_live', { layout, variant });
  } catch (e) {
    console.warn("Live keyboard apply:", e);
  }
}

async function loadDisks() {
  try {
    availableDisks = await invoke('get_disks');
    const list = document.getElementById('disk-list');

    if (availableDisks.length === 0) {
      list.innerHTML = `<div class="callout-card"><span>⚠️</span><div>Aucun disque trouvé.</div></div>`;
      return;
    }

    list.innerHTML = availableDisks.map((d, idx) => `
      <div class="disk-card ${idx === 0 ? 'selected' : ''}" data-path="${d.path}">
        <div class="disk-meta">
          <span class="disk-icon">${d.is_nvme ? '⚡' : (d.is_rotational ? '💽' : '💾')}</span>
          <div>
            <strong>${d.model} (${d.path})</strong>
            <small style="color: var(--mocha-subtext0); display: block;">${d.size_gb} Go • ${d.is_nvme ? 'NVMe PCIe' : (d.is_rotational ? 'Disque mécanique HDD' : 'SSD SATA')}</small>
          </div>
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
  const btnBench = document.getElementById('btn-benchmark-swap');
  const benchResult = document.getElementById('swap-bench-result');

  slider.addEventListener('input', () => {
    const val = parseInt(slider.value);
    if (val === 0) {
      valSpan.textContent = "Désactivé";
    } else {
      valSpan.textContent = `${val / 1024} Go`;
    }
  });

  btnBench.addEventListener('click', async () => {
    const sizeMb = parseInt(slider.value) || 4096;
    btnBench.disabled = true;
    btnBench.textContent = "Test en cours...";
    benchResult.classList.remove('hidden');
    benchResult.textContent = `Allocation de ${sizeMb / 1024} Go via posix_fallocate...`;

    try {
      const elapsedMs = await invoke('test_instant_swap', { sizeMb });
      benchResult.textContent = `⚡ Succès: ${sizeMb / 1024} Go préalloués en ${elapsedMs.toFixed(2)} ms !`;
    } catch (e) {
      benchResult.textContent = `Erreur: ${e}`;
    } finally {
      btnBench.disabled = false;
      btnBench.textContent = "Tester la vitesse Rust";
    }
  });
}

function collectSelections() {
  const selectedDisk = document.querySelector('.disk-card.selected');
  const diskPath = selectedDisk ? selectedDisk.dataset.path : (availableDisks[0] ? availableDisks[0].path : "");

  return {
    hostname: document.getElementById('input-hostname').value || "chomiamos",
    username: document.getElementById('input-username').value || "chomiam",
    fullname: document.getElementById('input-fullname').value || "ChomiamOS User",
    password: document.getElementById('input-password').value || null,
    desktop_env: document.querySelector('input[name="desktop_env"]:checked').value || "gnome",
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
    <div class="summary-item"><label>Swap (posix_fallocate)</label><span>${s.swap_size_mb === 0 ? 'Désactivé' : (s.swap_size_mb / 1024) + ' Go'}</span></div>
    <div class="summary-item"><label>Disposition Clavier</label><span>${s.keyboard_layout} ${s.keyboard_variant ? '(' + s.keyboard_variant + ')' : ''}</span></div>
    <div class="summary-item"><label>Bureau Choisi</label><span>${s.desktop_env.toUpperCase()}</span></div>
    <div class="summary-item"><label>Utilisateur / Hôte</label><span>${s.username} @ ${s.hostname}</span></div>
    <div class="summary-item"><label>Option Sunshine</label><span>${s.sunshine ? 'Activé (Streaming local)' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Option Sober</label><span>${s.sober ? 'Activé (Roblox Flatpak)' : 'Désactivé'}</span></div>
    <div class="summary-item"><label>Navigateur</label><span>${s.browser}</span></div>
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


// Tauri Event Listeners & Installation Wiring
let unlistenProgress = null;
let unlistenLog = null;
let unlistenFinished = null;

async function setupInstallationListeners() {
  if (window.__TAURI__ && window.__TAURI__.event) {
    unlistenProgress = await window.__TAURI__.event.listen('install_progress', (e) => {
      const p = e.payload;
      document.getElementById('install-bar-fill').style.width = `${p.percent}%`;
      document.getElementById('install-percent-val').textContent = `${p.percent}%`;
      document.getElementById('install-step-title').textContent = p.step;
      appendLog(`[${p.percent}%] ${p.message}`);
    });

    unlistenLog = await window.__TAURI__.event.listen('install_log', (e) => {
      appendLog(e.payload);
    });

    unlistenFinished = await window.__TAURI__.event.listen('install_finished', (e) => {
      const res = e.payload;
      if (res.success) {
        document.getElementById('install-complete-card').classList.remove('hidden');
        document.getElementById('install-heading').textContent = "Installation Terminée !";
        document.getElementById('install-subheading').textContent = "ChomiamOS Gaming Edition est prêt.";
      } else {
        appendLog(`[ERREUR FATALE] ${res.error || 'Erreur inconnue'}`);
        alert(`Erreur d'installation: ${res.error}`);
      }
    });
  }
}

function appendLog(text) {
  const term = document.getElementById('install-terminal-log');
  const line = document.createElement('div');
  line.className = 'log-line';
  line.textContent = `> ${text}`;
  term.appendChild(line);
  term.scrollTop = term.scrollHeight;
}


function initInstallButton() {
  const btnInstall = document.getElementById('btn-install');
  btnInstall.addEventListener('click', async () => {
    const s = collectSelections();
    const confirmed = confirm(`Êtes-vous sûr de vouloir installer ChomiamOS Gaming Edition sur le disque ${s.target_disk || 'sélectionné'} ?\n\nToutes les données présentes sur ce disque seront effacées.`);
    if (!confirmed) return;

    // Switch to step 8 panel
    document.getElementById(`panel-step-${currentStep}`).classList.remove('active');
    document.getElementById('panel-step-8').classList.add('active');
    document.querySelector('.wizard-actions').classList.add('hidden');
    document.querySelector('.wizard-nav').classList.add('hidden');

    try {
      appendLog("Initialisation du processus d'installation...");
      await invoke('start_installation', { selections: s, dryRun: false });
    } catch (err) {
      appendLog(`Erreur au lancement: ${err}`);
      alert(`Erreur: ${err}`);
    }
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

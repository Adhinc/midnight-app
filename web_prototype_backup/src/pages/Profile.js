import { navigate } from '../router.js';

export default function Profile() {
    setTimeout(() => {
        document.getElementById('switch-mode-btn').addEventListener('click', () => {
            navigate('/listener-dashboard');
        });
    }, 0);

    return `
    <header style="margin-bottom: 32px; text-align: center;">
      <div class="avatar-placeholder">AC</div>
      <h1 class="t-h2" style="margin-top: 16px;">Adhin C</h1>
      <p class="t-caption">Member since Jan 2026</p>
    </header>

    <div class="profile-actions" style="display: flex; flex-direction: column; gap: 16px;">
      <div class="glass-panel" style="padding: 20px;">
        <h3 class="t-h2" style="margin-bottom: 8px;">Your Statistics</h3>
        <p class="t-body">Moods tracked: 12</p>
        <p class="t-body">Sessions: 3</p>
      </div>

      <button id="switch-mode-btn" class="btn btn-primary" style="width: 100%; justify-content: center;">
        Switch to Listener Mode
      </button>
      
      <button class="btn" style="width: 100%; justify-content: center;">
        Settings
      </button>
    </div>

    <style>
      .avatar-placeholder {
        width: 80px;
        height: 80px;
        border-radius: 50%;
        background: var(--accent-gradient);
        margin: 0 auto;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 2rem;
        font-weight: 700;
        box-shadow: 0 0 20px rgba(123, 97, 255, 0.3);
      }
    </style>
  `;
}

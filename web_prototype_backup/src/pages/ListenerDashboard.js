import { navigate } from '../router.js';

export default function ListenerDashboard() {
    setTimeout(() => {
        document.getElementById('training-btn').addEventListener('click', () => {
            alert('Starting Empathy Training simulation...');
            // Logic for training would go here
        });

        document.getElementById('back-btn').addEventListener('click', () => {
            navigate('/profile');
        });
    }, 0);

    return `
    <header style="margin-bottom: 24px; padding-top: 20px;">
        <button id="back-btn" class="btn" style="margin-bottom: 16px; padding: 8px 16px;">← Back</button>
      <h1 class="t-h1" style="color: var(--secondary-color);">Listener Dashboard</h1>
      <p class="t-body">Help others and earn karma.</p>
    </header>

    <div class="dashboard-grid" style="display: flex; flex-direction: column; gap: 20px;">
      <div class="glass-panel" style="padding: 24px; border-color: var(--secondary-color);">
        <h3 class="t-h2" style="margin-bottom: 12px;">Empathy Check</h3>
        <p class="t-body" style="margin-bottom: 16px;">Complete your daily training to accept requests.</p>
        <button id="training-btn" class="btn btn-primary" style="background: var(--secondary-color); color: #000;">
          Start Training
        </button>
      </div>

      <div class="glass-panel" style="padding: 24px;">
        <h3 class="t-h2" style="margin-bottom: 12px;">Open Requests</h3>
        
        <div class="request-item" style="border-bottom: 1px solid rgba(255,255,255,0.1); padding: 12px 0;">
            <p class="t-body"><strong>Anonymous</strong> is feeling <em>Anxious</em></p>
            <p class="t-caption">2 mins ago</p>
        </div>
        
         <div class="request-item" style="padding: 12px 0;">
            <p class="t-body"><strong>StarGazer</strong> is feeling <em>Lonely</em></p>
            <p class="t-caption">5 mins ago</p>
        </div>
      </div>
    </div>
  `;
}

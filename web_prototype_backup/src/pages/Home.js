export default function Home() {
    const moods = [
        { label: 'Happy', emoji: '😊', color: '#00b894' },
        { label: 'Calm', emoji: '😌', color: '#0984e3' },
        { label: 'Anxious', emoji: '😰', color: '#6c5ce7' },
        { label: 'Sad', emoji: '😢', color: '#636e72' },
        { label: 'Tired', emoji: '😴', color: '#fdcb6e' },
        { label: 'Angry', emoji: '😡', color: '#d63031' }
    ];

    setTimeout(() => {
        // Add interactions after render
        document.querySelectorAll('.mood-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                const mood = e.currentTarget.dataset.mood;
                alert(`You selected: ${mood}. We are here for you.`);
            });
        });
    }, 0);

    return `
    <header style="margin-bottom: 32px;">
      <h1 class="t-h1" style="margin-bottom: 8px;">Hi there, Friend</h1>
      <p class="t-body" style="opacity: 0.8;">How are you feeling tonight?</p>
    </header>

    <div class="mood-grid">
      ${moods.map(mood => `
        <button class="mood-btn glass-panel" data-mood="${mood.label}" style="--hover-color: ${mood.color}">
          <span class="mood-emoji">${mood.emoji}</span>
          <span class="mood-label">${mood.label}</span>
        </button>
      `).join('')}
    </div>

    <style>
      .mood-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 16px;
      }
      
      .mood-btn {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 24px;
        border: 1px solid rgba(255, 255, 255, 0.1);
        cursor: pointer;
        transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
      }
      
      .mood-btn:hover {
        background: rgba(255, 255, 255, 0.1);
        border-color: var(--hover-color);
        transform: translateY(-4px);
        box-shadow: 0 10px 20px -10px var(--hover-color);
      }
      
      .mood-emoji {
        font-size: 2.5rem;
        margin-bottom: 12px;
      }
      
      .mood-label {
        font-size: 1rem;
        font-weight: 500;
      }
    </style>
  `;
}

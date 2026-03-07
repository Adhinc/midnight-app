export default function Inbox() {
    const messages = [
        { from: 'Listener Sarah', preview: 'I am glad you are feeling better!', time: '2m ago' },
        { from: 'System', preview: 'Welcome to Midnight.', time: '1d ago' }
    ];

    return `
    <header style="margin-bottom: 24px;">
      <h1 class="t-h1">Inbox</h1>
    </header>

    <div class="message-list">
      ${messages.map(msg => `
        <div class="message-item glass-panel">
          <div class="msg-header">
            <span class="msg-from">${msg.from}</span>
            <span class="msg-time t-caption">${msg.time}</span>
          </div>
          <p class="msg-preview t-body" style="opacity: 0.8;">${msg.preview}</p>
        </div>
      `).join('')}
    </div>

    <style>
      .message-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }
      
      .message-item {
        padding: 16px;
        transition: transform 0.2s;
        cursor: pointer;
      }
      
      .message-item:hover {
        background: rgba(255, 255, 255, 0.1);
      }
      
      .msg-header {
        display: flex;
        justify-content: space-between;
        margin-bottom: 4px;
      }
      
      .msg-from {
        font-weight: 600;
        color: var(--secondary-color);
      }
    </style>
  `;
}

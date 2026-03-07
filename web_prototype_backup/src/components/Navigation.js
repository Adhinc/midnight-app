export default function Navigation(activePath) {
    const links = [
        { path: '/', label: 'Home', icon: '🏠' },
        { path: '/inbox', label: 'Inbox', icon: '💬' },
        { path: '/profile', label: 'Profile', icon: '👤' },
    ];

    return `
    <nav class="bottom-nav glass-panel">
      ${links.map(link => `
        <a href="#${link.path}" class="nav-item ${activePath === link.path ? 'active' : ''}">
          <span class="nav-icon">${link.icon}</span>
          <span class="nav-label">${link.label}</span>
        </a>
      `).join('')}
    </nav>
  `;
}

// Additional styles for navigation that we append dynamically or assume in global css
export const navStyles = `
  .bottom-nav {
    position: fixed;
    bottom: 20px;
    left: 50%;
    transform: translateX(-50%);
    width: 90%;
    max-width: 440px;
    height: 70px;
    display: flex;
    justify-content: space-around;
    align-items: center;
    z-index: 100;
  }
  
  .nav-item {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-decoration: none;
    color: var(--text-secondary);
    transition: all 0.3s ease;
    padding: 8px;
    border-radius: 12px;
  }
  
  .nav-item.active {
    color: var(--primary-color);
    background: rgba(123, 97, 255, 0.1);
    transform: translateY(-5px);
  }
  
  .nav-icon {
    font-size: 1.25rem;
    margin-bottom: 4px;
  }
  
  .nav-label {
    font-size: 0.75rem;
    font-weight: 500;
  }
`;

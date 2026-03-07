import './style.css';
import { initRouter } from './router.js';
import Navigation, { navStyles } from './components/Navigation.js';

// Inject component styles
const styleSheet = document.createElement('style');
styleSheet.textContent = navStyles;
document.head.appendChild(styleSheet);

const app = document.querySelector('#app');

initRouter((path, pageContent) => {
  // Clear app
  app.innerHTML = '';

  // Create Main Content Container
  const main = document.createElement('main');
  main.className = 'main-content fade-in';
  main.innerHTML = pageContent;

  // Render
  app.appendChild(main);

  // Render Navigation
  const navHTML = Navigation(path);
  const navContainer = document.createElement('div');
  navContainer.innerHTML = navHTML;
  app.appendChild(navContainer.firstElementChild);
});

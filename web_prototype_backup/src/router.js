
export const routes = {
  '/': { title: 'Home', render: () => import('./pages/Home.js').then(m => m.default()) },
  '/inbox': { title: 'Inbox', render: () => import('./pages/Inbox.js').then(m => m.default()) },
  '/profile': { title: 'Profile', render: () => import('./pages/Profile.js').then(m => m.default()) },
  '/listener-dashboard': { title: 'Listener Dashboard', render: () => import('./pages/ListenerDashboard.js').then(m => m.default()) },
};

export function navigate(path) {
  window.location.hash = path;
}

export function initRouter(onRouteChanged) {
  const handleRoute = async () => {
    let path = window.location.hash.slice(1) || '/';
    // Handle root or invalid paths
    if (!routes[path]) path = '/';
    
    const route = routes[path];
    const styles = []; // For dynamic style loading if needed
    
    // Render content
    const content = await route.render();
    
    if (onRouteChanged) {
      onRouteChanged(path, content);
    }
  };

  window.addEventListener('hashchange', handleRoute);
  window.addEventListener('load', handleRoute);
  
  // Initial call
  handleRoute();
}

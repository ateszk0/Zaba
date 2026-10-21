// Takes the loading screen away when Flutter has drawn its first frame. If the
// event is missed (an older engine, an error), the screen goes after 30 seconds
// anyway so it can never cover a working app for good.
(function () {
  function remove() {
    var splash = document.getElementById('splash');
    if (splash && splash.parentNode) {
      splash.parentNode.removeChild(splash);
    }
  }
  window.addEventListener('flutter-first-frame', remove);
  setTimeout(remove, 30000);
})();

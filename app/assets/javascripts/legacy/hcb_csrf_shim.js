(function () {
  var meta = document.querySelector('meta[name="csrf-token"]');
  if (!meta) return;
  var original = window.fetch;
  window.fetch = function (input, init) {
    init = init || {};
    var method = (init.method || "GET").toUpperCase();
    if (method !== "GET" && method !== "HEAD") {
      init.headers = Object.assign({}, init.headers, { "X-CSRF-Token": meta.content });
    }
    return original.call(this, input, init);
  };
})();

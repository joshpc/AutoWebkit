if (window.addEventListener) {
  var documentIsReady = function() {
    window.webkit.messageHandlers.bridge.postMessage(JSON.stringify({ body: "window onload" }));
  };

  if (document.readyState === "complete") {
    window.setTimeout(documentIsReady, 0);
  }
  else {
    window.addEventListener("load", function() {
      window.setTimeout(documentIsReady, 0);
	});
  }
}

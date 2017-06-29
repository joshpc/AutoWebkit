if (window.addEventListener) {
	var documentIsReady = function() {
		window.webkit.messageHandlers.bridge.postMessage(JSON.stringify({ body: "window onload" }));
	};
	
	window.addEventListener("load", function() {
		window.setTimeout(documentIsReady, 0);
	});
}

import 'dart:io';

List<WebSocket> sockets = [];

void main(List<String> args) async {
  final server = await HttpServer.bind('10.0.0.9', 8080);
  print('Listening on ws://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(handleWebSocket);
    } else {
      request.response
        ..statusCode = HttpStatus.forbidden
        ..close();
    }
  }
}

void handleWebSocket(WebSocket socket) {
  sockets.add(socket);

  socket.listen(
    (data) {
      print('Received: $data');
      sockets.forEach((socket) => socket.add(data));
    },
    onDone: () {
      print('Connection closed');
    },
    onError: (error) {
      print('Error: $error');
    },
  );
}

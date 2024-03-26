import 'dart:convert';
import 'dart:io';

List<WebSocket> sockets = [];

void main(List<String> args) async {
  final server = await HttpServer.bind('10.0.0.9', 8080);
  print('Listening on ws://${server.address.address}:${server.port}');

  final data = await File('messages.json').readAsString().then(json.decode);

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(handleWebSocket);
    } else {
      final path = request.requestedUri.path;
      final method = request.method;
      final route = '${method} ${path}';

      print('Received: ${method} ${path}');

      switch(route) {
        case 'GET /chat_messages':
        case 'GET /chat_messages/':
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader, '${ContentType.json};charset=UTF-8')
            ..write(_jsonEncode(data))
            ..close();
          break;

        default:
          request.response
            ..statusCode = HttpStatus.forbidden
            ..close();
      }
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

String _jsonEncode(Object? data) =>
    json.encode(data);

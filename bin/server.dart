import 'dart:convert';
import 'dart:io';

List<WebSocket> sockets = [];
File file = File('messages.json');

void main(List<String> args) async {
  final server = await HttpServer.bind('0.0.0.0', 8081);
  print('Listening on ws://${server.address.address}:${server.port}');

  await for (HttpRequest request in server) {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      WebSocketTransformer.upgrade(request).then(handleWebSocket);
    } else {
      final path = request.requestedUri.path;
      final method = request.method;
      final route = '${method} ${path}';

      print('Received: ${method} ${path}');

      switch (route) {
        case 'GET /chat_messages':
        case 'GET /chat_messages/':
          final data = await file.readAsString().then(json.decode);

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader,
                '${ContentType.json};charset=UTF-8')
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
    (data) async {
      final message = json.decode(data) as Map<String, dynamic>;

      if (message['type'] == 'MESSAGE') {
        final _message = message['message'] as Map<String, dynamic>;
        final messages =
            await file.readAsString().then(json.decode) as List<dynamic>;

        messages.add(_message);

        file.createSync();
        file.writeAsStringSync(jsonEncode(messages));
      }

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

String _jsonEncode(Object? data) => json.encode(data);

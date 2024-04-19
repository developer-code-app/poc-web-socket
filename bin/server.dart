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
      final route = '$method $path';
      final query = request.requestedUri.queryParameters;

      print('Received: $method $path $query');

      switch (route) {
        case 'GET /chat_messages':
        case 'GET /chat_messages/':
          List<dynamic> messages =
              await file.readAsString().then(json.decode) as List<dynamic>;
          final latest = query['latest'];

          if (latest != null) {
            messages = messages.where((message) {
              return DateTime.parse(message['created_at'])
                      .microsecondsSinceEpoch >
                  DateTime.parse(latest).microsecondsSinceEpoch;
            }).toList();
          }

          messages.sort(
            ((a, b) => DateTime.parse(a['created_at'])
                .microsecondsSinceEpoch
                .compareTo(
                    DateTime.parse(b['created_at']).microsecondsSinceEpoch)),
          );

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.set(HttpHeaders.contentTypeHeader,
                '${ContentType.json};charset=UTF-8')
            ..write(_jsonEncode(messages))
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
      final response = json.decode(data) as Map<String, dynamic>;

      if (response['type'] == 'MESSAGE') {
        final message = response['message'] as Map<String, dynamic>;
        final messages =
            await file.readAsString().then(json.decode) as List<dynamic>;

        messages.add(message);

        file.createSync();
        file.writeAsStringSync(jsonEncode(messages));
      } else if (response['type'] == 'EVENT' &&
          response['event']['type'] == 'DELETE') {
        final messages =
            await file.readAsString().then(json.decode) as List<dynamic>;
        final message = messages.firstWhere(
            (message) => message['id'] == response['event']['message_id']);

        if (message != null) {
          messages.remove(message);

          message['deleted_at'] = DateTime.now().toIso8601String();
          messages.add(message);

          file.createSync();
          file.writeAsStringSync(jsonEncode(messages));
        }
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

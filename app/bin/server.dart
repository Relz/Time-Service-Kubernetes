import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as io;

Future<void> main(List<String> args) async {
  final ArgParser parser = ArgParser()..addOption('port', abbr: 'p');
  final ArgResults result = parser.parse(args);

  final String portStr = result['port'] as String // ignore: avoid_as
      ??
      Platform.environment['PORT'] ??
      '8080';
  final int port = int.tryParse(portStr);

  if (port == null) {
    stdout.writeln('Could not parse port value "$portStr" into a number.');
    // 64: command line usage error
    exitCode = 64;
    return;
  }

  final shelf.Handler handler = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(_echoRequest);

  final HttpServer server = await io.serve(handler, '0.0.0.0', port);
  // ignore: avoid_print
  print('Serving at http://${server.address.host}:${server.port}');
}

shelf.Response _echoRequest(shelf.Request request) => shelf.Response.ok(
      json.encode(
        <String, String>{
          'hostname': Platform.localHostname,
          'local_time': DateTime.now().toString(),
        },
      ),
      headers: {
        'Content-Type': 'application/json',
      },
    );

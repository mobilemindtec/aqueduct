import 'dart:async';
import 'dart:isolate';
import 'dart:mirrors';

import '../http/request_sink.dart';
import '../utilities/resource_registry.dart';
import 'application.dart';
import 'application_configuration.dart';
import 'isolate_supervisor.dart';

class ApplicationIsolateServer extends ApplicationServer {
  SendPort supervisingApplicationPort;
  ReceivePort supervisingReceivePort;

  ApplicationIsolateServer(
      ApplicationConfiguration configuration,
      int identifier,
      this.supervisingApplicationPort)
      : super(configuration, identifier) {
    supervisingReceivePort = new ReceivePort();
    supervisingReceivePort.listen(listener);

    supervisingApplicationPort.send(supervisingReceivePort.sendPort);
  }

  @override
  Future start(RequestSink sink, {bool shareHttpServer: false}) async {
    var result = await super.start(sink, shareHttpServer: shareHttpServer);
    supervisingApplicationPort.send(ApplicationIsolateSupervisor.MessageListening);
    return result;
  }

  void listener(dynamic message) {
    if (message == ApplicationIsolateSupervisor.MessageStop) {
      stop();
    }
  }

  Future stop() async {
    supervisingReceivePort.close();
    await close();
    await ResourceRegistry.release();
    supervisingApplicationPort
        .send(ApplicationIsolateSupervisor.MessageStop);
  }
}

/// This method is used internally.
void isolateServerEntryPoint(ApplicationInitialServerMessage params) {
  var server = new ApplicationIsolateServer(
      params.configuration, params.identifier, params.parentMessagePort);

  var sinkSourceLibraryMirror =
  currentMirrorSystem().libraries[params.streamLibraryURI];
  var sinkTypeMirror = sinkSourceLibraryMirror
      .declarations[new Symbol(params.streamTypeName)] as ClassMirror;

  RequestSink sink = sinkTypeMirror
      .newInstance(new Symbol(""), [params.configuration]).reflectee;

  server.start(sink, shareHttpServer: true);
}

class ApplicationInitialServerMessage {
  String streamTypeName;
  Uri streamLibraryURI;
  ApplicationConfiguration configuration;
  SendPort parentMessagePort;
  int identifier;

  ApplicationInitialServerMessage(this.streamTypeName, this.streamLibraryURI,
      this.configuration, this.identifier, this.parentMessagePort);
}

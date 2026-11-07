// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

import 'otel_xray_suppression.dart';

const _tracerName = 'dartastic_otel_libs_xray';

APITracer _tracer() => OTelAPI.tracerProvider().getTracer(_tracerName);

/// Wraps an AWS X-Ray PutTraceSegments call in a PRODUCER span.
Future<T> tracedXrayPutSegments<T>({
  required Future<T> Function() invoke,
  String? region,
  int? segmentCount,
  int? rejectedCount,
}) async {
  if (xrayInstrumentationSuppressed()) {
    return invoke();
  }
  final m = <String, Object>{
    'rpc.system': 'aws-api',
    'rpc.service': 'XRay',
    'rpc.method': 'PutTraceSegments',
    'messaging.system': 'aws_xray',
    'messaging.operation': 'publish',
  };
  if (region != null) m['cloud.region'] = region;
  if (segmentCount != null) {
    m['messaging.batch.message_count'] = segmentCount;
  }

  final span = _tracer().startSpan(
    'xray PutTraceSegments',
    kind: SpanKind.producer,
    attributes: OTelAPI.attributesFromMap(m),
  );
  try {
    final v = await invoke();
    if (rejectedCount != null) {
      span.addAttributes(OTelAPI.attributes([
        OTelAPI.attributeInt('aws.xray.rejected_count', rejectedCount),
      ]));
      if (rejectedCount > 0) {
        span.setStatus(
          SpanStatusCode.Error,
          'X-Ray rejected $rejectedCount segments',
        );
      }
    }
    return v;
  } catch (e, st) {
    span.addAttributes(OTelAPI.attributes([
      OTelAPI.attributeString(
        ErrorAttributes.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

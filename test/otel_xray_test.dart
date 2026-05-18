// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_xray/otel_xray.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_xray-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('PutTraceSegments records PRODUCER span', () async {
    await tracedXrayPutSegments<String>(
      region: 'us-east-1',
      segmentCount: 50,
      rejectedCount: 0,
      invoke: () async => 'ok',
    );
    final a = attrsOf(spans.findSpanByName('xray PutTraceSegments')!);
    expect(a['rpc.system'], 'aws-api');
    expect(a['cloud.region'], 'us-east-1');
    expect(a['messaging.batch.message_count'], 50);
    expect(a['aws.xray.rejected_count'], 0);
  });

  test('rejected segments mark span Error', () async {
    await tracedXrayPutSegments<String>(
      rejectedCount: 3,
      invoke: () async => 'partial',
    );
    expect(
      spans.findSpanByName('xray PutTraceSegments')!.status,
      SpanStatusCode.Error,
    );
  });

  test('suppression skips spans', () async {
    await runWithoutXrayInstrumentationAsync(() async {
      await tracedXrayPutSegments<String>(invoke: () async => 'ok');
    });
    expect(spans.findSpansStartingWith('xray '), isEmpty);
  });
}

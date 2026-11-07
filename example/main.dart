// Licensed under the Apache License, Version 2.0
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:otel_xray/otel_xray.dart';

/// Traces AWS X-Ray PutTraceSegments calls with OpenTelemetry.
///
/// `otel_xray` depends on the OpenTelemetry API only, so the application
/// initializes an SDK once at startup. Wrap each AWS X-Ray PutTraceSegments call in
/// [tracedXrayPutSegments]; the `invoke` callback makes the real call and reports what
/// came back, which is recorded on the span.
Future<void> main() async {
  await OTel.initialize(serviceName: 'xray-example');

  // Wraps an AWS X-Ray PutTraceSegments call in a PRODUCER span.
  final xrayPutSegmentsId = await tracedXrayPutSegments<String>(
    region: 'us-east-1',
    segmentCount: 3,
    rejectedCount: 3,
    invoke: () async {
      // Make the AWS X-Ray PutTraceSegments call here, then report what it returned.
      return 'xray_8f3a2c';
    },
  );
  OTelLog.info('tracedXrayPutSegments returned $xrayPutSegmentsId');

  // Calls that should not be traced, such as health checks, run inside
  // runWithoutXrayInstrumentationAsync.
  await runWithoutXrayInstrumentationAsync(
    () => tracedXrayPutSegments<String>(
      region: 'us-east-1',
      segmentCount: 3,
      rejectedCount: 3,
      invoke: () async {
        return 'xray_8f3a2c';
      },
    ),
  );

  await OTel.shutdown();
}

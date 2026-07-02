import 'dart:async';
import 'dart:convert';

import 'package:shelf/shelf.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message, {this.details});

  final int statusCode;
  final String message;
  final Object? details;
}

Response jsonResponse(
  Object? data, {
  int statusCode = 200,
  Map<String, String>? headers,
}) {
  return Response(
    statusCode,
    body: jsonEncode({'data': data}),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ..._corsHeaders,
      ...?headers,
    },
  );
}

Response jsonError(int statusCode, String message, {Object? details}) {
  return Response(
    statusCode,
    body: jsonEncode({
      // ignore: use_null_aware_elements
      'error': {'message': message, if (details != null) 'details': details},
    }),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ..._corsHeaders,
    },
  );
}

Future<Map<String, dynamic>> readJson(Request request) async {
  final raw = await request.readAsString();
  if (raw.trim().isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw ApiException(400, 'JSON body must be an object.');
  }
  return decoded;
}

Middleware apiMiddleware() {
  return (innerHandler) {
    return (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok('', headers: _corsHeaders);
      }
      try {
        final response = await Future.sync(() => innerHandler(request));
        return response.change(headers: _corsHeaders);
      } on ApiException catch (error) {
        return jsonError(
          error.statusCode,
          error.message,
          details: error.details,
        );
      } on FormatException {
        return jsonError(400, 'Invalid JSON payload.');
      } on TimeoutException {
        return jsonError(504, 'The request timed out.');
      } catch (error) {
        return jsonError(
          500,
          'Unexpected server error.',
          details: error.toString(),
        );
      }
    };
  };
}

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers':
      'Origin, Content-Type, Authorization, X-Migration-Key',
};

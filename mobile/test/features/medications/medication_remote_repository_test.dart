import 'dart:convert';
import 'dart:typed_data';

import 'package:aura/core/errors/app_failure.dart';
import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/api_client.dart';
import 'package:aura/core/session/auth_session.dart';
import 'package:aura/core/session/token_store.dart';
import 'package:aura/features/medications/data/datasources/medication_remote_datasource.dart';
import 'package:aura/features/medications/data/repositories/medication_repository_impl.dart';
import 'package:aura/features/medications/domain/entities/medication.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor dublado: responde [status]/[body] e guarda cada pedido do app.
class _FakeBackend implements HttpClientAdapter {
  _FakeBackend(this.status, this.body, {this.offline = false});

  final int status;
  final Object body;
  final bool offline;
  final List<RequestOptions> seen = [];

  RequestOptions get last => seen.last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    seen.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'sem rede',
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> _med({
  String id = 'med-1',
  String name = 'Losartana',
  List<String> schedule = const ['08:00', '20:00'],
  int? stockDoses = 30,
}) =>
    {
      'id': id,
      'homeId': 'home-1',
      'name': name,
      'dosage': '50mg',
      'schedule': schedule,
      'notes': null,
      'active': true,
      'stockDoses': stockDoses,
      'createdAt': '2026-10-01T10:00:00Z',
    };

void main() {
  late ApiClient client;
  late MedicationRepositoryImpl repository;

  setUp(() async {
    dotenv.testLoad(fileInput: 'BACKEND_BASE_URL=http://aura.test');
    FlutterSecureStorage.setMockInitialValues({});
    final store = TokenStore(const FlutterSecureStorage());
    await store.saveSession(
      accessToken: 'jwt-da-ana',
      refreshToken: 'r',
      role: 'cuidadora',
    );
    client = ApiClient(tokenStore: store, session: AuthSession(store));
    repository =
        MedicationRepositoryImpl(MedicationRemoteDataSourceImpl(client));
  });

  _FakeBackend serve(int status, Object body, {bool offline = false}) {
    final backend = _FakeBackend(status, body, offline: offline);
    client.dio.httpClientAdapter = backend;
    return backend;
  }

  test('lista vem do servidor (GET /homes/{id}/medications), por nome',
      () async {
    final backend = serve(200, [
      _med(id: 'b', name: 'Sinvastatina', stockDoses: null),
      _med(id: 'a', name: 'losartana'),
    ]);

    final result = await repository.getMedications('home-1');

    expect(backend.last.method, 'GET');
    expect(backend.last.path, '/homes/home-1/medications');
    expect(backend.last.headers['Authorization'], 'Bearer jwt-da-ana');
    final meds = (result as Success<List<Medication>>).data;
    expect(meds.map((m) => m.id), ['a', 'b']);
    expect(meds.first.times, ['08:00', '20:00']);
    expect(meds.first.schedule, '08:00, 20:00');
    expect(meds.first.stockDoses, 30);
    expect(meds.last.stockDoses, isNull);
  });

  test('cadastro envia horários HH:mm e estoque inicial no POST', () async {
    final backend = serve(201, _med(id: 'novo'));

    final result = await repository.create(
      'home-1',
      const MedicationInput(
        name: 'Losartana',
        dosage: '50mg',
        times: ['08:00', '20:00'],
        stockDoses: 30,
      ),
    );

    expect(backend.last.method, 'POST');
    expect(backend.last.path, '/homes/home-1/medications');
    expect(backend.last.data, {
      'name': 'Losartana',
      'dosage': '50mg',
      'schedule': ['08:00', '20:00'],
      'stockDoses': 30,
    });
    expect((result as Success<Medication>).data.id, 'novo');
  });

  test('edição usa PUT /medications/{id} e limpa campos esvaziados', () async {
    final backend = serve(200, _med());

    await repository.update(
      'med-1',
      const MedicationInput(name: 'Losartana', times: []),
    );

    expect(backend.last.method, 'PUT');
    expect(backend.last.path, '/medications/med-1');
    expect(backend.last.data, {
      'name': 'Losartana',
      'dosage': '',
      'schedule': <String>[],
      'notes': '',
    });
  });

  test('remoção usa DELETE /medications/{id}', () async {
    final backend = serve(200, {'deleted': true});

    final result = await repository.delete('med-1');

    expect(result, isA<Success<void>>());
    expect(backend.last.method, 'DELETE');
    expect(backend.last.path, '/medications/med-1');
  });

  test('confirmar dose posta {taken} e devolve o estoque restante', () async {
    final backend = serve(201, {
      'signalId': 'sig-1',
      'taken': true,
      'stockDoses': 29,
    });

    final result = await repository.confirmDose('med-1', taken: true);

    expect(backend.last.method, 'POST');
    expect(backend.last.path, '/medications/med-1/confirm');
    expect(backend.last.data, {'taken': true});
    final confirmation = (result as Success<DoseConfirmation>).data;
    expect(confirmation.signalId, 'sig-1');
    expect(confirmation.stockDoses, 29);
  });

  test('"Não tomei" posta taken=false', () async {
    final backend = serve(201, {
      'signalId': 'sig-2',
      'taken': false,
      'stockDoses': 30,
    });

    final result = await repository.confirmDose('med-1', taken: false);

    expect(backend.last.data, {'taken': false});
    expect((result as Success<DoseConfirmation>).data.taken, isFalse);
  });

  test('400 do servidor vira falha de validação com a mensagem dele', () async {
    serve(400, {
      'error': {
        'code': 'VALIDATION_ERROR',
        'message': 'Horário deve estar no formato HH:mm (ex.: 08:00)',
      },
    });

    final result = await repository.create(
      'home-1',
      const MedicationInput(name: 'X', times: ['8h']),
    );

    final failure = (result as Failure<Medication>).failure as AppFailure;
    expect(failure, isA<AppFailure>());
    failure.maybeWhen(
      validation: (m) => expect(m, contains('HH:mm')),
      orElse: () => fail('esperava falha de validação, veio $failure'),
    );
  });

  test('sem rede vira falha de rede, não exceção', () async {
    serve(0, {}, offline: true);

    final result = await repository.getMedications('home-1');

    final failure = (result as Failure<List<Medication>>).failure;
    (failure as AppFailure).maybeWhen(
      networkError: (m) => expect(m, contains('Sem conexão')),
      orElse: () => fail('esperava falha de rede, veio $failure'),
    );
  });
}

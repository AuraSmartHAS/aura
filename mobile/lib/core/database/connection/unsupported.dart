import 'package:drift/drift.dart';

/// Fallback for platforms without a database implementation.
QueryExecutor openConnection() =>
    throw UnsupportedError('Plataforma sem suporte a banco de dados.');

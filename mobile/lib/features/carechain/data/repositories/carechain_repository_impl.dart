import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../../domain/entities/recommendation.dart';
import '../../domain/repositories/carechain_repository.dart';
import '../datasources/carechain_remote_datasource.dart';

class CareChainRepositoryImpl implements CareChainRepository {
  CareChainRepositoryImpl(this._remoteDataSource);

  final CareChainRemoteDataSource _remoteDataSource;

  @override
  Future<Result<Recommendation>> createRecommendation({
    required String homeId,
    String? scoreId,
    required SeverityLevel level,
  }) async {
    try {
      final reco = await _remoteDataSource.createRecommendation(
        homeId,
        scoreId: scoreId,
      );
      return Success(_toRecommendation(reco, level));
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<Recommendation?>> findPendingRecommendation({
    required String homeId,
    required SeverityLevel level,
  }) async {
    try {
      final list = await _remoteDataSource.listRecommendations(homeId);
      // O servidor devolve da mais recente para a mais antiga: a primeira que
      // ainda espera decisão é a que a cuidadora viu por último.
      for (final raw in list) {
        final json = raw as Map<String, dynamic>;
        final reco = _toRecommendation(json, level);
        if (reco.isPending) return Success(reco);
      }
      return const Success(null);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  @override
  Future<Result<String>> approve(String recommendationId) async {
    try {
      final data = await _remoteDataSource.approve(recommendationId);
      return Success(data['orderId'] as String);
    } catch (e) {
      return Failure(mapDioError(e));
    }
  }

  /// Preço, instalação, norma e rótulos em português vêm no mesmo payload
  /// (correção C1) — sem segunda chamada ao catálogo, que era justamente o que
  /// escondia o preço quando falhava.
  Recommendation _toRecommendation(
    Map<String, dynamic> json,
    SeverityLevel level,
  ) {
    final sku = json['sku'] as String;
    return Recommendation(
      recommendationId: json['recommendationId'] as String,
      sku: sku,
      productName: (json['productName'] as String?) ?? sku,
      price: (json['price'] as num?)?.toDouble(),
      reason: (json['reason'] as String?) ?? '',
      normRef: (json['normRef'] as String?) ?? 'NBR 9050',
      factors: _strings(json['factors']),
      weights: ((json['weights'] as List?) ?? const [])
          .map((e) => (e as num).toDouble())
          .toList(),
      level: level,
      status: (json['status'] as String?) ?? 'recommended',
      factorLabels: _strings(json['factorLabels']),
      installable: json['installable'] as bool?,
      installationIncluded: json['installationIncluded'] as bool?,
      installationPrice: (json['installationPrice'] as num?)?.toDouble(),
    );
  }

  List<String> _strings(dynamic value) =>
      ((value as List?) ?? const []).map((e) => e.toString()).toList();
}

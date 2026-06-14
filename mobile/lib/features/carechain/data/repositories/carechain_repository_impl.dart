import 'package:aura/core/errors/result.dart';
import 'package:aura/core/network/error_mapper.dart';
import 'package:aura/shared/models/severity_level.dart';
import '../../domain/entities/catalog_item.dart';
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
      final sku = reco['sku'] as String;

      // Enrich with catalog details (name, price, norm) for the card.
      CatalogItem? item;
      try {
        item = CatalogItem.fromJson(await _remoteDataSource.getCatalogItem(sku));
      } catch (_) {
        item = null;
      }

      return Success(
        Recommendation(
          recommendationId: reco['recommendationId'] as String,
          sku: sku,
          productName: item?.name ?? sku,
          price: item?.price,
          reason: (reco['reason'] as String?) ?? '',
          normRef: item?.normRef ?? 'NBR 9050',
          factors: ((reco['factors'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
          weights: ((reco['weights'] as List?) ?? const [])
              .map((e) => (e as num).toDouble())
              .toList(),
          level: level,
        ),
      );
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
}

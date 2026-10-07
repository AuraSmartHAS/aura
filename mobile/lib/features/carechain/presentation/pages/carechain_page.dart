import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/router/app_routes.dart';
import '../bloc/carechain_bloc.dart';
import '../widgets/carechain_body.dart';

class CareChainPage extends StatelessWidget {
  const CareChainPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CareChainBloc>()..add(const LoadRecommendationEvent()),
      child: BlocListener<CareChainBloc, CareChainState>(
        listenWhen: (prev, curr) =>
            prev.approvedOrderId != curr.approvedOrderId &&
            curr.approvedOrderId != null,
        listener: (context, state) {
          // RN-022: a aprovação criou o pedido → abre o acompanhamento POR CIMA
          // do Care-Chain. `go` trocava a pilha: a tela do pedido ficava sem
          // seta de voltar e o voltar do sistema fechava o app. Voltar agora
          // devolve ao Care-Chain, já recarregado: o servidor manda o item com
          // o pedido em andamento, então a tela mostra "já pedido" em vez de
          // um "Aprovar" velho que daria 409.
          final bloc = context.read<CareChainBloc>();
          context.push(AppRoutes.orderDetail(state.approvedOrderId!));
          bloc.add(const LoadRecommendationEvent());
        },
        child: CareChainBody(supportPhone: AppConfig.supportPhone),
      ),
    );
  }
}

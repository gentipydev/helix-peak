import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/biology/gene_record.dart';
import '../../../core/catalog/protein_target.dart';
import '../../../core/network/api_exception.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../gene_lookup/domain/usecases/fetch_gene.dart';

sealed class LabRecordState {
  const LabRecordState();
}

final class LabRecordLoading extends LabRecordState {
  const LabRecordLoading();
}

final class LabRecordFailed extends LabRecordState {
  const LabRecordFailed(this.message);

  final String message;
}

final class LabRecordReady extends LabRecordState {
  const LabRecordReady(this.record);

  final GeneRecord record;
}

/// One protein's record, fetched for a lab flow through the lab's own
/// [FetchGene], and so through the lab's own track cache.
class LabRecordCubit extends Cubit<LabRecordState> {
  LabRecordCubit(this._fetchGene, this.target)
    : super(const LabRecordLoading());

  final FetchGene _fetchGene;
  final ProteinTarget target;

  Future<void> load() async {
    emit(const LabRecordLoading());
    try {
      final GeneRecord record = await _fetchGene(target.query);
      if (!isClosed) {
        emit(LabRecordReady(record));
      }
    } on ApiException catch (error) {
      if (!isClosed) {
        emit(LabRecordFailed(error.userMessage));
      }
    } on Object {
      if (!isClosed) {
        emit(LabRecordFailed(const UnknownApiException().userMessage));
      }
    }
  }
}

/// Fetches [target]'s record, then builds [builder] with it: the waiting and
/// the failure every lab flow would otherwise write again.
class LabRecordView extends StatelessWidget {
  const LabRecordView({
    required this.target,
    required this.title,
    required this.builder,
    super.key,
  });

  final ProteinTarget target;

  /// The app bar's title while the record is on its way.
  final String title;
  final Widget Function(BuildContext context, GeneRecord record) builder;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LabRecordCubit>(
      create: (BuildContext context) =>
          LabRecordCubit(context.read<FetchGene>(), target)..load(),
      child: BlocBuilder<LabRecordCubit, LabRecordState>(
        builder: (BuildContext context, LabRecordState state) =>
            switch (state) {
              LabRecordLoading() => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: LoadingView(label: 'LOADING ${target.accession}'),
              ),
              LabRecordFailed(:final String message) => Scaffold(
                appBar: AppBar(title: Text(title)),
                body: ErrorView(
                  title: 'Fetch failed',
                  message: message,
                  onRetry: () => context.read<LabRecordCubit>().load(),
                ),
              ),
              LabRecordReady(:final GeneRecord record) => builder(
                context,
                record,
              ),
            },
      ),
    );
  }
}

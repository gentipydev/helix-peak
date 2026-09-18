import 'package:bloc/bloc.dart';

import '../../../../core/network/api_exception.dart';
import '../../domain/entities/gene_query.dart';
import '../../domain/entities/gene_record.dart';
import '../../domain/usecases/fetch_gene.dart';
import 'gene_lookup_state.dart';

/// A Cubit rather than a Bloc: this is a one-shot fetch with a retry, and there
/// are no events worth modelling beyond the two methods below.
final class GeneLookupCubit extends Cubit<GeneLookupState> {
  GeneLookupCubit(this._fetchGene) : super(const GeneLookupInitial());

  final FetchGene _fetchGene;

  GeneQuery? _lastQuery;

  Future<void> load(GeneQuery query) async {
    if (state is GeneLookupLoading) {
      return;
    }
    _lastQuery = query;
    await _run(query);
  }

  Future<void> retry() async {
    final GeneQuery? query = _lastQuery;
    if (query == null || state is GeneLookupLoading) {
      return;
    }
    await _run(query);
  }

  Future<void> _run(GeneQuery query) async {
    emit(GeneLookupLoading(query));
    try {
      final GeneRecord record = await _fetchGene(query);
      emit(GeneLookupSuccess(record));
    } on ApiException catch (error) {
      emit(GeneLookupFailure(error.userMessage));
    } catch (_) {
      emit(
        const GeneLookupFailure(
          'Something went wrong fetching this gene. Try again.',
        ),
      );
    }
  }
}

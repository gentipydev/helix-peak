import 'package:flutter/foundation.dart';

import '../../domain/entities/gene_query.dart';
import '../../domain/entities/gene_record.dart';

@immutable
sealed class GeneLookupState {
  const GeneLookupState();
}

@immutable
final class GeneLookupInitial extends GeneLookupState {
  const GeneLookupInitial();
}

@immutable
final class GeneLookupLoading extends GeneLookupState {
  const GeneLookupLoading(this.query);

  final GeneQuery query;
}

@immutable
final class GeneLookupSuccess extends GeneLookupState {
  const GeneLookupSuccess(this.record);

  final GeneRecord record;
}

@immutable
final class GeneLookupFailure extends GeneLookupState {
  const GeneLookupFailure(this.message);

  final String message;
}

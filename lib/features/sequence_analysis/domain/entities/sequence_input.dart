import 'package:freezed_annotation/freezed_annotation.dart';

part 'sequence_input.freezed.dart';

@freezed
abstract class SequenceInput with _$SequenceInput {
  const factory SequenceInput({required String rawText}) = _SequenceInput;
}

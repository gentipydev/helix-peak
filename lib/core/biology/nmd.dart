/// How far upstream of the last exon-exon junction a premature stop has to
/// sit for nonsense-mediated decay to destroy the mRNA, in bases, counted
/// from the stop codon's first base.
///
/// The junction itself is never a constant: it is read off each record's own
/// exon table, after the edit.
const int nmdThresholdBp = 55;

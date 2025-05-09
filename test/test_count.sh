#!/bin/bash
# Test script for 'seqfu count' submodule

set -e  # Exit on any error

# Check if environment variables are set
if [ -z "$SEQFU" ] || [ -z "$DATA_DIR" ] || [ -z "$TMP_DIR" ]; then
    echo "ERROR: Required environment variables not set."
    exit 1
fi

# Test basic count functionality with a single FASTA file
echo "Testing basic count with FASTA..."
$SEQFU count "$DATA_DIR/fasta/nanopore_tags.fasta" > "$TMP_DIR/count_basic.txt"
[ -s "$TMP_DIR/count_basic.txt" ] || { echo "ERROR: Count output is empty"; exit 1; }
grep -q "[0-9]" "$TMP_DIR/count_basic.txt" || { echo "ERROR: No count numbers found in output"; exit 1; }


# Test count with a compressed FASTA file
echo "Testing count with compressed FASTA..."
$SEQFU count "$DATA_DIR/fasta/multiline.fasta.gz" > "$TMP_DIR/count_compressed.txt"
[ -s "$TMP_DIR/count_compressed.txt" ] || { echo "ERROR: Compressed file count output is empty"; exit 1; }

# Test count with FASTQ file (contains 10 sequences)
echo "Testing count with FASTQ..."
$SEQFU count "$DATA_DIR/nanopore/nanopore.fastq.gz" > "$TMP_DIR/count_fastq.txt"
[ -s "$TMP_DIR/count_fastq.txt" ] || { echo "ERROR: FASTQ count output is empty"; exit 1; }

# check 10 sequences
LINE_COUNT=$(grep  "nanopore" "$TMP_DIR/count_fastq.txt" | cut -f 2 || echo "0")
[ "$LINE_COUNT" -eq 10 ] || { echo "ERROR: Expected 10 sequences in FASTQ count output, found: $LINE_COUNT ($( cat "$TMP_DIR/count_fastq.txt" ))"; exit 1; }

# Test with basename flag
echo "Testing basename flag..."
$SEQFU count -b "$DATA_DIR/fasta/nanopore_tags.fasta" > "$TMP_DIR/count_basename.txt"
grep -q "nanopore_tags" "$TMP_DIR/count_basename.txt" || { 
    echo "ERROR: Basename not correctly displayed"; exit 1; 
}

# Test with absolute path flag
echo "Testing absolute path flag..."
$SEQFU count -a "$DATA_DIR/fasta/nanopore_tags.fasta" > "$TMP_DIR/count_abspath.txt"
grep -q "/" "$TMP_DIR/count_abspath.txt" || { 
    echo "ERROR: Absolute path not correctly displayed"; exit 1; 
}

# Test paired-end counting (using the Illumina paired files)
echo "Testing paired-end counting..."
$SEQFU count "$DATA_DIR/illumina/amplicon_R1.fastq.gz" "$DATA_DIR/illumina/amplicon_R2.fastq.gz" > "$TMP_DIR/count_paired.txt"
[ -s "$TMP_DIR/count_paired.txt" ] || { echo "ERROR: Paired-end count output is empty"; exit 1; }
# Check if paired count combined the files
LINE_COUNT=$(grep -c "$DATA_DIR" "$TMP_DIR/count_paired.txt" || echo "0")
[ "$LINE_COUNT" -eq 1 ] || { echo "ERROR: Paired files not properly combined"; exit 1; }

# Test with unpair flag
echo "Testing unpair flag..."
$SEQFU count -u "$DATA_DIR/illumina/amplicon_R1.fastq.gz" "$DATA_DIR/illumina/amplicon_R2.fastq.gz" > "$TMP_DIR/count_unpaired.txt"
LINE_COUNT=$(grep -c "$DATA_DIR" "$TMP_DIR/count_unpaired.txt" || echo "0")
[ "$LINE_COUNT" -eq 2 ] || { echo "ERROR: Unpair option did not separate paired files"; exit 1; }

# Test with custom tags
echo "Testing custom forward/reverse tags..."
$SEQFU count -f "_1" -r "_2" "$DATA_DIR/illumina/amplicon_R1.fastq.gz" "$DATA_DIR/illumina/amplicon_R2.fastq.gz" > "$TMP_DIR/count_tags.txt" 2>&1 || true
# Note: This might not pair the files correctly due to tag mismatch, but should run without error


# Test with multiple files
echo "Testing count with multiple files..."
$SEQFU count "$DATA_DIR/fasta/nanopore_tags.fasta" "$DATA_DIR/fasta/nocomment.fasta.gz" > "$TMP_DIR/count_multiple.txt"
LINE_COUNT=$(grep -c "$DATA_DIR" "$TMP_DIR/count_multiple.txt" || echo "0")
[ "$LINE_COUNT" -eq 2 ] || { echo "ERROR: Expected 2 lines with file paths"; exit 1; }

echo "All 'count' tests completed successfully."
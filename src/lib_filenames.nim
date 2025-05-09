#[
  Utilities for: `seqfu count`
]#
import strutils

proc extractTagFromFilename*(filename: string, patternFor: string, patternRev: string): (string, string) =
    ## Extracts basename and read tag (R1, R2, or SE) from sequencing filenames.
    ##
    ## Parameters:
    ##   filename: Input filename to process
    ##   patternFor: Pattern to find in filename. If "auto", tries common R1/R2 patterns
    ##   patternRev: Pattern for reverse reads (unused in current implementation)
    ##
    ## Returns:
    ##   Tuple (basename, tag) where:
    ##   - basename: Filename with the pattern removed
    ##   - tag: "R1", "R2", or "SE" (Single End) indicating read type
    ##
    ## Notes:
    ##   When patternFor="auto", checks for "_R1.", "_R1_", "_1." patterns (and R2 equivalents).
    ##   If no patterns match, returns (filename, "SE").
    ##
    ## Examples:
    ##   extractTag("sample_R1.fastq", "auto", "") # → ("sample", "R1")
    ##   extractTag("sample_R2_001.fastq", "auto", "") # → ("sample", "R2")
    ##   extractTag("sample.fastq", "auto", "") # → ("sample.fastq", "SE")
    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R1.")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_R1_")
      if len(basename) > 1:
        return (basename[0], "R1")
      basename = split(filename, "_1.")
      if len(basename) > 1:
        return (basename[0], "R1")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R1")

    if patternFor == "auto":
      # automatic guess
      var basename = split(filename, "_R2.")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_R2_")
      if len(basename) > 1:
        return (basename[0], "R2")
      basename = split(filename, "_2.")
      if len(basename) > 1:
        return (basename[0], "R2")
    else:
      var basename = split(filename, patternFor)
      if len(basename) > 1:
        return (basename[0], "R2")

    return (filename, "SE")

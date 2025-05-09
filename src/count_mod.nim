import tables, strutils
from os import fileExists, dirExists
import ./lib_filenames
import ../readfx/readfx
import malebolgia
# Default MultiQC header template for sequence count reports
const MULTIQC_HEADER = """# plot_type: 'table'
# section_name: 'SeqFu counts'
# description: 'Number of reads per sample'
# pconfig:
#     namespace: 'Cust Data'
# headers:
#     col1:
#         title: '#Seqs'
#         description: 'Number of sequences'
#         format: '{:,.0f}'
#     col2:
#         title: 'Type'
#         description: 'Paired End (PE) or Single End (SE) dataset'
Sample	col1	col2
"""

proc count_seqs*(filename: string): int =
  ## Count sequences in a FASTQ/FASTA file
  ## Args:
  ##   filename: Path to the sequence file (or "-" for stdin)
  ## Returns:
  ##   Number of sequences in the file
  result = 0
  for r in readFQptr(filename):
    result += 1
  return result

proc fastx_count*(argv: var seq[string]): int =
  ## Main function to count sequences in FASTQ/FASTA files
  ## Returns: error count (0 if successful)
  
  # Parse command line arguments using docopt
  let args = docopt("""
Usage: count [options] [<inputfile> ...]

Options:
  -a, --abs-path         Print absolute paths
  -b, --basename         Print only filenames
  -u, --unpair           Print separate records for paired end files
  -f, --for-tag R1       Forward string, like _R1 [default: auto]
  -r, --rev-tag R2       Reverse string, like _R2 [default: auto]
  -m, --multiqc FILE     Save report in MultiQC format
  -v, --verbose          Verbose output
  -h, --help             Show this help

  """, version=version(), argv=argv)

  # Extract command line options
  let 
    verbose = args["--verbose"]
    abspath = args["--abs-path"]
    basename = args["--basename"]
    unpaired = args["--unpair"]
    forwardTag = $args["--for-tag"]
    reverseTag = $args["--rev-tag"]
    multiqcFile = $args["--multiqc"]
  
  var 
    inputFiles: seq[string]
    mqcReport = MULTIQC_HEADER
    errorCount = 0
    
  # NOTE: For multi-threaded implementation, we could declare:
  # countResults = newTable[string, FlowVar[int]]() 
  # This would store thread handles for each counting operation
  
  # Handle file inputs - use stdin if no files provided
  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu count] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    inputFiles.add("-")
  else:
    for file in args["<inputfile>"]:
      inputFiles.add(file)

  # Table to store sequence counts per sample: sampleID -> {direction -> count}
  var fileTable = initTable[string, Table[string, string]]()
  
  # Process each input file
  for filename in sorted(inputFiles):
    # Skip if file doesn't exist
    if filename != "-" and not fileExists(filename):
      if dirExists(filename):
        stderr.writeLine("WARNING: Directories are not supported. Skipping ", filename)
      else:
        stderr.writeLine("WARNING: File ", filename, " not found.")
      continue
    
    # Extract filename components
    let
      (_, filenameNoExt, extension) = splitFile(filename)
      # Extract sample ID and direction (R1, R2, or SE) from filename
      (sampleId, direction) = extractTagFromFilename(filenameNoExt, forwardTag, reverseTag)
    
    # Determine how filename should be displayed based on options
    var displayFilename = filename
    if abspath:
      displayFilename = absolutePath(filename)
    elif basename:
      displayFilename = filenameNoExt & extension

    # ===============================================================
    # For multi-threaded implementation, replace this section with:
    # ===============================================================
    # # Start a new thread to count sequences
    # if not (sampleId in countResults):
    #   countResults[sampleId] = newTable[string, FlowVar[int]]()
    # countResults[sampleId][direction] = spawn count_seqs(filename)
    # ===============================================================
    
    # Count sequences in the file using the isolated counting procedure
    let seqCount = count_seqs(filename)
    
    if verbose:
      echo(filename & " (" & direction & "): " & $seqCount)
    
    # Store count information
    if not (sampleId in fileTable):
      fileTable[sampleId] = initTable[string, string]()
    
    fileTable[sampleId][direction] = $seqCount
    fileTable[sampleId]["filename_" & direction] = displayFilename
    
    # ===============================================================
    # For multi-threaded implementation, we would wait and collect 
    # results after all spawns have been started, using ^() operator
    # to get values from FlowVar objects
    # ===============================================================
  
  # Output results and build MultiQC report
  for sampleId, counts in fileTable:
    if "SE" in counts:
      # Single-end data
      echo counts["filename_SE"], "\t", counts["SE"], "\tSE"
      mqcReport.add(counts["filename_SE"] & "\t" & counts["SE"] & "\tSE\n")
    else:
      # Paired-end data (or forward-only)
      if "R2" in counts:
        if counts["R1"] == counts["R2"]:
          # Forward and reverse have same count (good)
          echo counts["filename_R1"], "\t", counts["R1"], "\tPaired"
          mqcReport.add(counts["filename_R1"] & "\t" & counts["R1"] & "\tPE\n")
          
          # Add separate R2 entry if unpaired option is selected
          if unpaired:
            echo counts["filename_R2"], "\t", counts["R2"], "\tPaired:R2"
            mqcReport.add(counts["filename_R2"] & "\t" & counts["R2"] & "\tPE (Reverse)\n")
        else:
          # Error: paired files have different number of sequences
          errorCount += 1
          stderr.writeLine("ERROR: Different counts in ", counts["filename_R1"], " and ", counts["filename_R2"])
          stderr.writeLine("# ", counts["filename_R1"], ": ", counts["R1"])
          stderr.writeLine("# ", counts["filename_R2"], ": ", counts["R2"])
          mqcReport.add(counts["filename_R1"] & "\t" & counts["R1"] & "/" & counts["R2"] & "\tError\n")
      else:
        # Forward-only data (no R2 found)
        echo counts["filename_R1"], "\t", counts["R1"], "\tSE"
        mqcReport.add(counts["filename_R1"] & "\t" & counts["R1"] & "\tSE\n")
  
  # Save MultiQC report if requested
  if multiqcFile != "nil":
    if args["--verbose"]:
      stderr.writeLine("Saving MultiQC report to ", multiqcFile)
    
    try:
      var reportFile = open(multiqcFile, fmWrite)
      defer: reportFile.close()
      reportFile.write(mqcReport)
    except Exception:
      stderr.writeLine("Unable to write MultiQC report to ", multiqcFile, ": printing to STDOUT instead.")
      echo mqcReport

  # Return error count
  if errorCount > 0:
    stderr.writeLine(errorCount, " errors found.")
    return errorCount
  
  return 0
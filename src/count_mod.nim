import tables, strutils, docopt, locks, sequtils
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

# Data structure to hold sequence count results
type
  CountResult = object
    filename: string
    sampleId: string
    direction: string
    displayFilename: string
    count: int
  
  # Thread-safe data structure to store results
  ThreadSafeData = object
    lock: Lock
    results: seq[CountResult]

proc count_seqs(filename: string): int {.gcsafe.} =
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
  ## Main function to count sequences in FASTQ/FASTA files using parallel processing
  ## For proper compilation:
  ##   nim c -d:ThreadPoolSize=N -d:FixedChanSize=16 --threads:on yourfile.nim
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
  -t, --threads INT      Maximum threads to use [default: 4]
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
    threadCount = if parseInt($args["--threads"]) > 8: 8 else: parseInt($args["--threads"])
  
  if parseInt($args["--threads"]) > threadCount:
    stderr.writeLine("WARNING: Thread count limited to ", threadCount)
  
  # Variables for storing input files and results
  var 
    inputFiles: seq[string]
    mqcReport = MULTIQC_HEADER
    errorCount = 0
    
    # Initialize thread-safe data structure
    sharedData: ThreadSafeData
    fileTable = initTable[string, Table[string, string]]() # Table to store the count information
  
  # Initialize the lock
  initLock(sharedData.lock)
  
  # Handle file inputs - use stdin if no files provided
  if args["<inputfile>"].len() == 0:
    if getEnv("SEQFU_QUIET") == "":
      stderr.writeLine("[seqfu count] Waiting for STDIN... [Ctrl-C to quit, type with --help for info].")
    inputFiles.add("-")
  else:
    for file in args["<inputfile>"]:
      inputFiles.add(file)

  # Process files using Malebolgia for parallel execution
  if verbose:
    stderr.writeLine("Processing files using up to ", threadCount, " threads")
  
  # Define the thread task explicitly to avoid undeclared identifier errors
  proc processFileTask(file: string, forTag, revTag: string, 
                      useAbsPath, useBasename: bool, 
                      sharedPtr: ptr ThreadSafeData) {.gcsafe.} =
    # Skip if file doesn't exist
    if file != "-" and not fileExists(file):
      if dirExists(file):
        stderr.writeLine("WARNING: Directories are not supported. Skipping ", file)
      else:
        stderr.writeLine("WARNING: File ", file, " not found.")
      return
    
    # Extract filename components
    let
      (_, filenameNoExt, extension) = splitFile(file)
      (sampleId, direction) = extractTagFromFilename(filenameNoExt, forTag, revTag)
    
    # Determine how filename should be displayed based on options
    var displayFilename = file
    if useAbsPath:
      displayFilename = absolutePath(file)
    elif useBasename:
      displayFilename = filenameNoExt & extension

    # Count sequences in the file
    let seqCount = count_seqs(file)
    
    # Create result object
    var result = CountResult(
      filename: file,
      sampleId: sampleId,
      direction: direction,
      displayFilename: displayFilename,
      count: seqCount
    )
    
    # Add to shared results using lock for thread safety
    withLock(sharedPtr[].lock):
      sharedPtr[].results.add(result)
  
  # Create Malebolgia master
  var m = createMaster()
  
  # Process files in parallel with controlled concurrency
  m.awaitAll:
    var batch = 0
    while batch * threadCount < inputFiles.len:
      # Process up to threadCount files in each batch
      let startIdx = batch * threadCount
      let endIdx = min(startIdx + threadCount, inputFiles.len)
      
      for i in startIdx ..< endIdx:
        # Spawn a task for each file in the current batch
        m.spawn processFileTask(inputFiles[i], forwardTag, reverseTag, 
                              abspath, basename, addr sharedData)
      
      batch += 1
  
  # Process the results and update the fileTable
  for result in sharedData.results:
    if verbose:
      echo(result.filename & " (" & result.direction & "): " & $result.count)
    
    # Store count information
    if not (result.sampleId in fileTable):
      fileTable[result.sampleId] = initTable[string, string]()
    
    fileTable[result.sampleId][result.direction] = $result.count
    fileTable[result.sampleId]["filename_" & result.direction] = result.displayFilename
  
  # Output results and build MultiQC report
  for sampleId, counts in fileTable:
    if "SE" in counts:
      # Single-end data
      echo counts["filename_SE"], "\t", counts["SE"], "\tSE"
      mqcReport.add(counts["filename_SE"] & "\t" & counts["SE"] & "\tSE\n")
    else:
      # Paired-end data (or forward-only)
      if "R2" in counts:
        # Make sure both R1 and R2 exist before comparing
        if "R1" in counts and counts["R1"] == counts["R2"]:
          # Forward and reverse have same count (good)
          echo counts["filename_R1"], "\t", counts["R1"], "\tPaired"
          mqcReport.add(counts["filename_R1"] & "\t" & counts["R1"] & "\tPE\n")
          
          # Add separate R2 entry if unpaired option is selected
          if unpaired:
            echo counts["filename_R2"], "\t", counts["R2"], "\tPaired:R2"
            mqcReport.add(counts["filename_R2"] & "\t" & counts["R2"] & "\tPE (Reverse)\n")
        else:
          # Error: paired files have different number of sequences or missing R1
          errorCount += 1
          let r1count = if "R1" in counts: counts["R1"] else: "missing"
          let r2count = counts["R2"]
          stderr.writeLine("ERROR: Different counts in ", 
                          (if "filename_R1" in counts: counts["filename_R1"] else: "missing R1"), 
                          " and ", counts["filename_R2"])
          stderr.writeLine("# R1: ", r1count)
          stderr.writeLine("# R2: ", r2count)
          mqcReport.add(counts["filename_R2"] & "\t" & r2count & "/error\tError\n")
      elif "R1" in counts:
        # Forward-only data (no R2 found)
        echo counts["filename_R1"], "\t", counts["R1"], "\tSE"
        mqcReport.add(counts["filename_R1"] & "\t" & counts["R1"] & "\tSE\n")
      else:
        # Should never happen, but handle it gracefully
        var dirList = ""
        for dir in toSeq(counts.keys()):
          if dirList.len > 0: dirList.add(", ")
          dirList.add(dir)
        stderr.writeLine("WARNING: Strange direction found for sample ", sampleId, ": ", dirList)
  
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

  # Clean up the lock
  deinitLock(sharedData.lock)

  # Return error count
  if errorCount > 0:
    stderr.writeLine(errorCount, " errors found.")
    return errorCount
  
  return 0
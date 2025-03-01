#' Import transcript quantification with metadata
#' 
#' The tximeta package imports abundances (TPM), estimated counts,
#' and effective lengths from Salmon, alevin, piscem or other quantification
#' tools, and will output a SummarizedExperiment object. For
#' Salmon / alevin / piscem quantification data, \code{tximeta} will
#' try to identify the correct provenance of the reference transcripts
#' and automatically attach the transcript ranges to the
#' SummarizedExperiment, to facilitate downstream integration with
#' other datasets. The automatic identification of reference transcripts
#' should work out-of-the-box for human or mouse transcriptomes from
#' the sources: GENCODE, Ensembl, or RefSeq.
#'
#' The main functions are:
#' \itemize{
#' \item \code{\link{tximeta}} - with key argument: \code{coldata}
#' \item \code{\link{summarizeToGene,SummarizedExperiment-method}} - summarize quants to gene-level
#' \item \code{\link{retrieveDb}} - retrieve the transcript database
#' \item \code{\link{addIds}} - add transcript or gene ID (see \code{gene} argument)
#' }
#' 
#' All software-related questions should be posted to the Bioconductor Support Site:
#' 
#' \url{https://support.bioconductor.org}
#'
#' The code can be viewed at the GitHub repository,
#' which also lists the contributor code of conduct:
#'
#' \url{https://github.com/thelovelab/tximeta}
#' 
#' @references
#'
#' \strong{tximeta} reference:
#' 
#' Michael I. Love, Charlotte Soneson, Peter F. Hickey, Lisa K. Johnson
#' N. Tessa Pierce, Lori Shepherd, Martin Morgan, Rob Patro (2020)
#' Tximeta: reference sequence checksums for provenance identification
#' in RNA-seq. PLOS Computational Biology.
#' \url{https://doi.org/10.1371/journal.pcbi.1007664}
#'
#' \strong{tximport} reference (the effective length offset and counts-from-abundance):
#' 
#' Charlotte Soneson, Michael I. Love, Mark D. Robinson (2015)
#' Differential analyses for RNA-seq: transcript-level estimates
#' improve gene-level inferences. F1000Research.
#' \url{http://doi.org/10.12688/f1000research.7563}
#'
#' @author Michael I. Love, Charlotte Soneson, Peter Hickey, Rob Patro
#' 
#' @name tximeta-package
#' @aliases tximeta-package
#' @keywords package
"_PACKAGE"

#' Import transcript quantification with metadata
#' 
#' \code{tximeta} leverages the hashed digest of the Salmon or piscem index,
#' in addition to a number of core Bioconductor packages (GenomicFeatures,
#' ensembldb, AnnotationHub, GenomeInfoDb, BiocFileCache) to automatically
#' populate metadata for the user, without additional effort from the user.
#' For other quantifiers see the \code{customMetaInfo} argument below.
#'
#' Most of the code in \code{tximeta} works to add metadata and transcript ranges
#' when the quantification was performed with Salmon. However,
#' \code{tximeta} can be used with any quantification \code{type} that is supported
#' by \code{\link{tximport}}, where it will return an non-ranged SummarizedExperiment.
#' 
#' \code{tximeta} performs a lookup of the hashed digest of the index
#' (stored in an auxilary information directory of the Salmon output)
#' against a database of known transcriptomes, which lives within the tximeta
#' package and is continually updated on Bioconductor's release schedule.
#' In addition, \code{tximeta} performs a lookup of the digest against a
#' locally stored table of \code{linkedTxome}'s (see \code{link{makeLinkedTxome}}).
#' If \code{tximeta} detects a match, it will automatically populate,
#' e.g. the transcript locations, the transcriptome release,
#' the genome with correct chromosome lengths, etc. It allows for automatic
#' and correct summarization of transcript-level quantifications to the gene-level
#' via \code{\link{summarizeToGene}} without the need to manually build
#' a \code{tx2gene} table.
#'
#' \code{tximeta} on the first run will ask where the BiocFileCache for
#' this package should be kept, either using a default location or a temporary
#' directory. At any point, the user can specify a location using
#' \code{\link{setTximetaBFC}} and this choice will be saved for future sessions.
#' Multiple users can point to the same BiocFileCache, such that
#' transcript databases (TxDb or EnsDb) associated with certain Salmon indices
#' and \code{linkedTxomes} can be accessed by different users without additional
#' effort or time spent downloading and building the relevant TxDb / EnsDb.
#' Note that, if the TxDb or EnsDb is present in AnnotationHub, \code{tximeta} will
#' use this object instead of downloading and building a TxDb/EnsDb from GTF
#' (to disable this set useHub=FALSE).
#'
#' In order to allow that multiple users can read and write to the
#' same location, one should set the BiocFileCache directory to
#' have group write permissions (g+w).
#'
#' @param coldata a data.frame with at least two columns (others will propogate to object):
#' \itemize{
#' \item{\code{files} - character, paths of quantification files}
#' \item{\code{names} - character, sample names}
#' }
#' if \code{coldata} is a vector, it is assumed to be the paths of quantification files
#' and unique sample names are created
#' @param type what quantifier was used (see \code{\link{tximport}})
#' @param txOut whether to output transcript-level data.
#' \code{tximeta} is designed to have transcript-level output
#' with Salmon, so default is \code{TRUE},
#' and it's recommended to use \code{\link{summarizeToGene}}
#' following \code{tximeta} for gene-level summarization.
#' For an alevin file, \code{tximeta} will import the
#' gene level counts ignoring this argument (alevin
#' produces only gene-level quantification).
#' @param skipMeta whether to skip metadata generation
#' (e.g. to avoid errors if not connected to internet).
#' This calls \code{tximport} directly and so either
#' \code{txOut=TRUE} or \code{tx2gene} should be specified.
#' @param skipSeqinfo whether to skip the addition of Seqinfo,
#' which requires an internet connection to download the
#' relevant chromosome information table from UCSC
#' @param useHub whether to first attempt to download a TxDb/EnsDb
#' object from AnnotationHub, rather than creating from a
#' GTF file from FTP (default is TRUE). If FALSE, it will
#' force \code{tximeta} to download and parse the GTF
#' @param markDuplicateTxps whether to mark the status
#' (\code{hasDuplicate}) and names of duplicate transcripts
#' (\code{duplicates}) in the rowData of the SummarizedExperiment output.
#' Subsequent summarization to gene level will keep track
#' of the number of transcripts sets per gene (\code{numDupSets})
#' @param cleanDuplicateTxps whether to try to clean
#' duplicate transcripts (exact sequence duplicates) by replacing
#' the transcript names that do not appear in the GTF
#' with those that do appear in the GTF
#' @param customMetaInfo the relative path to a custom metadata
#' information JSON file, relative to the paths in \code{files} of
#' \code{coldata}. For example, \code{customMetaInfo="meta_info.json"}
#' would indicate that in the same directory as the quantification
#' files in \code{files}, there are custom metadata information
#' JSON files. These should contain the SHA-256 hash of the
#' reference transcripts with the \code{index_seq_hash} tag
#' (see details in vignette).
#' @param skipFtp whether to avoid \code{ftp://} in case of
#' firewall, default is FALSE
#' @param ... arguments passed to \code{tximport}
#' 
#' @return a SummarizedExperiment with metadata on the \code{rowRanges}.
#' (if the hashed digest in the Salmon or Sailfish index does not match
#' any known transcriptomes, or any locally saved \code{linkedTxome},
#' \code{tximeta} will just return a non-ranged SummarizedExperiment)
#'
#' @examples
#'
#' # point to a Salmon quantification file:
#' dir <- system.file("extdata/salmon_dm", package="tximportData")
#' files <- file.path(dir, "SRR1197474", "quant.sf") 
#' coldata <- data.frame(files, names="SRR1197474", condition="A", stringsAsFactors=FALSE)
#'
#' # normally we would just run the following which would download the appropriate metadata
#' # se <- tximeta(coldata)
#'
#' # for this example, we instead point to a local path where the GTF can be found
#' # by making a linkedTxome:
#' indexDir <- file.path(dir, "Dm.BDGP6.22.98_salmon-0.14.1")
#' fastaFTP <- c("ftp://ftp.ensembl.org/pub/release-98/fasta/drosophila_melanogaster/cdna/Drosophila_melanogaster.BDGP6.22.cdna.all.fa.gz",
#'               "ftp://ftp.ensembl.org/pub/release-98/fasta/drosophila_melanogaster/ncrna/Drosophila_melanogaster.BDGP6.22.ncrna.fa.gz")
#' gtfPath <- file.path(dir, "Drosophila_melanogaster.BDGP6.22.98.gtf.gz")
#' makeLinkedTxome(indexDir=indexDir, source="LocalEnsembl", organism="Drosophila melanogaster",
#'                 release="98", genome="BDGP6.22", fasta=fastaFTP, gtf=gtfPath, write=FALSE)
#' se <- tximeta(coldata)
#'
#' # to clear the entire linkedTxome table
#' # (don't run unless you want to clear this table!)
#' # bfcloc <- getTximetaBFC()
#' # bfc <- BiocFileCache(bfcloc)
#' # bfcremove(bfc, bfcquery(bfc, "linkedTxomeTbl")$rid)
#'
#' @importFrom SummarizedExperiment SummarizedExperiment assays assayNames colData rowData rowRanges<- rowRanges
#' @importFrom S4Vectors metadata mcols mcols<-
#' @importFrom IRanges CharacterList LogicalList NumericList
#' @importFrom GenomicRanges seqnames strand start end start<- end<-
#' @importFrom tximport tximport summarizeToGene
#' @importFrom jsonlite fromJSON toJSON
#' @importFrom AnnotationDbi loadDb saveDb select keys mapIds
#' @importFrom GenomicFeatures transcripts genes exonsBy cdsBy
#' @importFrom txdbmaker makeTxDbFromGFF makeTxDbFromGRanges
#' @importFrom ensembldb ensDbFromGtf EnsDb
#' @importFrom BiocFileCache BiocFileCache bfcquery bfcnew bfcadd bfccount bfcrpath
#' @importFrom AnnotationHub AnnotationHub query dbconn dbfile
#' @importFrom Biostrings readDNAStringSet %in%
#' @importFrom tibble tibble
#' @importFrom GenomeInfoDb Seqinfo genome<- seqlengths seqinfo seqinfo<- seqlevels
#' @importFrom tools R_user_dir file_ext
#' @importFrom utils menu packageVersion read.csv read.delim head
#' @importFrom methods is as
#'
#' @export
tximeta <- function(coldata,
                    type=NULL,
                    txOut=TRUE,
                    skipMeta=FALSE,
                    skipSeqinfo=FALSE,
                    useHub=TRUE,
                    markDuplicateTxps=FALSE,
                    cleanDuplicateTxps=FALSE,
                    customMetaInfo=NULL,
                    skipFtp=FALSE,
                    ...) {

  if (is(coldata, "vector")) {
    coldata <- data.frame(files=coldata, names=seq_along(coldata))
  }
  
  stopifnot(all(c("files","names") %in% names(coldata)))
  
  files <- as.character(coldata$files)
  names(files) <- coldata$names

  if (!all(file.exists(files))) {
    stop("the files do not exist at the location specified by 'coldata$files'")
  }

  # try to autodetect piscem, if not default to salmon
  if (is.null(type)) {
    if (grepl(".quant$",coldata$files[1])) {
      type <- "piscem"
    } else {    
      type <- "salmon" # default
    }
  }
  
  if (type == "alevin") {
    if (length(files) > 1) stop("alevin import currently only supports a single experiment")
  }
  
  # remove the files column from colData
  coldata <- subset(coldata, select=-files)

  # tximeta metadata
  tximetaInfo <- list(version=packageVersion("tximeta"),
                      type=type,
                      importTime=Sys.time())

  metadata <- list(tximetaInfo=tximetaInfo)

  skipMetaLogic <- skipMeta |
    ( !type %in% c("salmon","sailfish","alevin","piscem") &
      is.null(customMetaInfo) )
  
  if (skipMetaLogic) {
    txi <- tximport(files, type=type, txOut=txOut, ...)
    metadata$countsFromAbundance <- txi$countsFromAbundance
    if (type == "alevin") {
      coldata <- data.frame(row.names=colnames(txi[["counts"]]))
    }
    se <- makeUnrangedSE(txi, coldata, metadata)
    return(se)
  } else {
    if (!txOut) stop("tximeta is designed to have transcript-level output for Salmon and piscem.
  set txOut=TRUE and use summarizeToGene for gene-level summarization")
  }

  if (type == "alevin") {
    metaInfo <- list(getMetaInfo(dirname(files),
                                 type = "salmon",
                                 customMetaInfo = customMetaInfo))
  } else {
    # get quantifier metadata from JSON files within quant dirs
    metaInfo <- lapply(files, getMetaInfo,
                       type=type,
                       customMetaInfo=customMetaInfo)
  }

  if (type != "piscem") {
    # Salmon's SHA-256 hash of the index is called "index_seq_hash" in the meta_info.json file
    indexSeqHash <- metaInfo[[1]]$index_seq_hash # first sample
  } else if (type == "piscem") {
    # piscem has the SHA-256 hash slightly differently...
    indexSeqHash <- metaInfo[[1]]$signatures$sha256_seqs # first sample
  }
  
  if (length(files) > 1) {
    if (type != "piscem") {
      hashes <- sapply(metaInfo, function(x) x$index_seq_hash)
    } else if (type == "piscem") {
      hashes <- sapply(metaInfo, function(x) x$signatures$sha256_seqs)
    }
    if (!all(hashes == indexSeqHash)) {
      stop("the samples do not share the same index, and cannot be imported")
    }
    if ("num_bootstraps" %in% names(metaInfo[[1]])) {
      nboot <- sapply(metaInfo, function(x) x$num_bootstraps)
      if (!all(nboot == nboot[1])) {
        message("\nNOTE: inferential replicate number not equal across files,
may lead to errors in object construction, unless 'dropInfReps=TRUE'")
        if (any(nboot == 0)) {
          message(paste("\nNOTE: the following files (by #) have 0 inferential replicates:
  ",paste(which(nboot == 0),collapse=",")),"\n")
        }
      }
    }
  }
  # reshape
  metaInfo <- reshapeMetaInfo(metaInfo)
  # add to metadata list
  metadata$quantInfo <- metaInfo
  
  # try to import files early, so we don't waste user time
  # with metadata magic before a tximport error
  message("importing quantifications")
  txi <- tximport(files, type=type, txOut=TRUE, ...)
  metadata$countsFromAbundance <- txi$countsFromAbundance

  # try and find a matching txome
  txomeInfo <- getTxomeInfo(indexSeqHash)
  if (is.null(txomeInfo)) {
    message("couldn't find matching transcriptome, returning non-ranged SummarizedExperiment")
    if (type == "alevin") {
      coldata <- data.frame(row.names=colnames(txi[["counts"]]))
    }
    se <- makeUnrangedSE(txi, coldata, metadata)
    return(se)
  }

  # build or load a TxDb from the gtf
  txdb <- getTxDb(txomeInfo, useHub=useHub, skipFtp=skipFtp)

  # build or load transcript ranges (alevin gets gene ranges instead)
  if (type != "alevin") {
    txps <- getRanges(txdb=txdb, txomeInfo=txomeInfo, type="txp")
    metadata$level <- "txp"
  } else if (type == "alevin") {
    # alevin gets gene ranges instead
    message("generating gene ranges")
    # here gene ranges are named 'txps' for compatibility with code below...
    txps <- getRanges(txdb=txdb, txomeInfo=txomeInfo, type="gene")
    metadata$level <- "gene"
  }

  # package up the assays
  if (type == "alevin") {
    # special alevin code
    if ("variance" %in% names(txi)) {
      if ("infReps" %in% names(txi)) {
        assays <- c(txi[c("counts","variance")], txi$infReps)
        names(assays) <- c("counts", "variance", paste0("infRep", seq_along(txi$infReps)))
      } else {
        assays <- txi[c("counts","variance")]
      }
    } else {
      assays <- txi["counts"]
    }
    # add mean information as well if it exists in the list
    if ("mean" %in% names(txi)) {
      assays <- c(assays, txi["mean"])
    }
    # add tier information as well if it exists in the list
    if ("tier" %in% names(txi)) {
      assays <- c(assays, txi["tier"])
    }
    coldata <- data.frame(row.names=colnames(assays[["counts"]]))
  } else {
    # for methods other than alevin...
    # put 'counts' in front to facilitate DESeqDataSet construction
    # and remove countsFromAbundance
    txi.nms <- c("counts", c(setdiff(names(txi), c("counts","countsFromAbundance","infReps"))))
    assays <- txi[txi.nms]
    # if there are inferential replicates
    if ("infReps" %in% names(txi)) {
      infReps <- rearrangeInfReps(txi$infReps)
      infReps <- lapply(infReps, function(mat) {
        rownames(mat) <- rownames(assays[["counts"]])
        colnames(mat) <- colnames(assays[["counts"]])
        mat
      })
      assays <- c(assays, infReps)
    }
  }
  
  # Ensembl FASTA has txp version numbers,
  # but in the Ensembl GTF it is not in the txname,
  # so here we have to remove the version number to build the SummarizedExperiment
  if (txomeInfo$source %in% c("Ensembl","LocalEnsembl")) {
    txId <- sub("\\..*", "", rownames(assays[["counts"]]))
    for (nm in names(assays)) {
      rownames(assays[[nm]]) <- txId
    }
  }

  # code for marking or cleaning duplicate txps
  assay.nms <- rownames(assays[["counts"]])
  txps.missing <- !assay.nms %in% names(txps)
  # either we want to mark duplicates, or clean up duplicates (if we can)
  if (markDuplicateTxps | (cleanDuplicateTxps & sum(txps.missing) > 0)) {
    dup.list <- makeDuplicateTxpsList(txomeInfo)
  }
  if (cleanDuplicateTxps & sum(txps.missing) > 0) {
    # this function swaps out rows missing in `txps`
    # for duplicate txps which are in `txps`. needed bc
    # Ensembl includes haplotype chromosome txps that duplicate
    # standard chromosome txps (identical sequence)
    missing.txps <- assay.nms[txps.missing]
    dup.table <- makeDuplicateTxpsTable(missing.txps, dup.list, names(txps))
    if (is.null(dup.table)) {
      message("no duplicated transcripts to clean")
    } else {
      message(paste("cleaning",nrow(dup.table),"duplicate transcript names"))
      # which rownames to fix
      m <- match(dup.table$dups.to.fix, assay.nms)
      stopifnot(all(!is.na(m)))
      # change the rownames to alternatives that are in `txps`
      for (nm in names(assays)) {
        assay.nms[m] <- dup.table$alts
        rownames(assays[[nm]]) <- assay.nms
      }
    }
  }

  # special edits to rownames for GENCODE to remove chars after `|`
  # (and user didn't use --gencode when building Salmon index)
  testTxp <- rownames(assays[[1]])[1]
  if (grepl("ENST|ENSMUST", testTxp) & grepl("\\|", testTxp)) {
    for (i in names(assays)) {
      rownames(assays[[i]]) <- sub("\\|.*","",rownames(assays[[i]]))
    }
  }

  assays <- checkAssays2Txps(assays, txps)
  
  # TODO we could give a warning here if there are txps in TxDb not in index
  txps <- txps[rownames(assays[["counts"]])]

  # mark duplicates in the rowData
  if (markDuplicateTxps) {
    # assay names could have changed due to cleanDuplicateTxps
    assay.nms <- rownames(assays[["counts"]])
    dups.in.rownms <- unlist(dup.list) %in% assay.nms
    dups.in.rownms <- LogicalList(split(dups.in.rownms, rep(seq_along(dup.list), lengths(dup.list))))
    names(dups.in.rownms) <- NULL
    num.dups.in.rownms <- sapply(dups.in.rownms, sum)
    just.one <- num.dups.in.rownms == 1
    if (!all(just.one)) {
      dup.list <- dup.list[just.one]
      dups.in.rownms <- dups.in.rownms[just.one]
    }
    duplicates <- dup.list[ !dups.in.rownms ]
    duplicates.id <- as.character(dup.list[ dups.in.rownms ])
    mcols(txps)$hasDuplicate <- FALSE
    mcols(txps)$duplicates <- CharacterList(as.list(rep("",length(txps))))
    if (length(duplicates) > 0) {
      message(paste(length(duplicates), "duplicate set founds"))
      mcols(txps)$hasDuplicate[ names(txps) %in% duplicates.id ] <- TRUE
      # if necessary remove any of these not in txps
      duplicates <- duplicates[ duplicates.id %in% names(txps) ]
      duplicates.id <- duplicates.id[ duplicates.id %in% names(txps) ]
      mcols(txps)$duplicates[ match(duplicates.id, names(txps)) ] <- duplicates
    } else {
      message("no duplicates found")
    }
  }
  
  # Ensembl already has nice seqinfo attached...
  # if GENCODE, and not from AHub (which have seqinfo)
  missingSeqinfo <- any(is.na(seqlengths(txps)))
  if (txomeInfo$source == "GENCODE" & !skipSeqinfo & missingSeqinfo) {
    message("fetching genome info for GENCODE")
    ucsc.genome <- genome2UCSC(txomeInfo$genome)
    try(seqinfo(txps) <- Seqinfo(genome=ucsc.genome)[seqlevels(txps)])
  } else if (txomeInfo$source == "RefSeq" & !skipSeqinfo & missingSeqinfo) {
    # if RefSeq...
    message("fetching genome info for RefSeq")
    refseq.genome <- gtf2RefSeq(txomeInfo$gtf, txomeInfo$genome)
    stopifnot(all(seqlevels(txps) %in% seqnames(refseq.genome)))
    try(seqinfo(txps) <- refseq.genome[seqlevels(txps)])
  }
  
  # add more metadata
  txdbInfo <- metadata(txdb)$value
  names(txdbInfo) <- metadata(txdb)$name
  metadata$txomeInfo <- txomeInfo
  metadata$txdbInfo <- txdbInfo

  se <- SummarizedExperiment(assays=assays,
                             rowRanges=txps,
                             colData=coldata,
                             metadata=metadata)
  se
  
}

missingMetadata <- function(se, summarize=FALSE) {
  msg <- "use of this function requires transcriptome metadata which is missing.
  either: (1) the object was not produced by tximeta, or
  (2) tximeta could not recognize the digest of the transcriptome.
  If (2), use a linkedTxome to provide the missing metadata and rerun tximeta"
  if (summarize) {
    msg <- paste0(msg, "
  or provide a `tx2gene` data.frame and set `skipRanges=TRUE`")
  }
  if (is.null(metadata(se)$txomeInfo)) stop(msg)
}

# read metadata files from Salmon/piscem directory
# customMetaInfo = path of the custom metadata info file
getMetaInfo <- function(file, type, customMetaInfo=NULL) {
  dir <- dirname(file)

  # users can specify any arbitrary location for the metadata,
  # allowing for any quantification tool to be paired with tximeta.
  # we first deal with this case, then move to Salmon and piscem
  if (!is.null(customMetaInfo)) {
    jsonPath <- file.path(dir, customMetaInfo)

    # salmon or piscem have different metadata locations,
    # so we handle these separately...
  } else {

    # salmon:
    if (type == "salmon") {
      # the default Salmon auxiliary information location
      auxDir <- "aux_info" 
      if (!file.exists(file.path(dir, auxDir))) {
        auxDir <- customAuxDir(dir, auxDir)
      }
      # read in the metadata
      jsonPath <- file.path(dir, auxDir, "meta_info.json")

      # piscem:
    } else if (type == "piscem") {

      # read in the metadata
      quantFile <- basename(file)
      metadataFile <- sub(".quant", ".meta_info.json", quantFile)
      jsonPath <- file.path(dir, metadataFile)
      
    } else {
      stop("expected type = 'salmon' or 'piscem'")
    }
  }
  if (!file.exists(jsonPath)) {
    stop("\n\n  the quantification files exist, but the metadata files are missing.
  tximeta (and other downstream software) require the entire output directory
  of Salmon/alevin, or for piscem the metadata files to be colocated with the
  quant files. The total output of Salmon/alevin/piscem includes files with
  critical metadata for tximeta to work. Alternatively, you can set
  skipMeta=TRUE or use tximport \n\n") 
  }
  fromJSON(jsonPath)
}

# Salmon allows users to change the name of the auxiliary directory
# just in case this was changed by the user...
customAuxDir <- function(dir, auxDir) {
  jsonPath <- file.path(dir, "cmd_info.json")
  if (!file.exists(jsonPath)) {
    stop("metadata files are missing, tximeta requires the full Salmon/piscem output files")
  }
  cmd_info <- jsonlite::fromJSON(jsonPath)
  if ("auxDir" %in% names(cmd_info)) {
    auxDir <- cmd_info$auxDir
  }
  auxDir
}

# reshape metadata info from Salmon
reshapeMetaInfo <- function(metaInfo) {
  unionTags <- unique(unlist(lapply(metaInfo, names)))
  out <- lapply(unionTags, function(t) {
    sapply(seq_along(metaInfo), function(i) {
      metaInfo[[i]][[t]]
    })
  })
  names(out) <- unionTags
  if (all(out$eq_class_properties == list())) {
    out$eq_class_properties <- NULL
  }
  stopifnot(all(out$index_seq_hash == out$index_seq_hash[1]))
  stopifnot(all(out$index_name_hash == out$index_name_hash[1]))
  out$index_seq_hash <- out$index_seq_hash[1]
  out$index_name_hash <- out$index_name_hash[1]
  out
}

# temporary function to map from GRCh38 to hg38 to allow easy
# comparison with UCSC objects from AnnotationHub...
# TODO we need a better solution for obtaining seqinfo for GENCODE
genome2UCSC <- function(x) {
  if (x == "GRCh38") {
    "hg38"
  } else if (x == "GRCm38") {
    "mm10"
  } else if (x == "GRCm39") {
    "mm39"
  } else {
    x
  }
}

gtf2RefSeq <- function(gtf, genome) {
  report <- sub("genomic.gff.gz","assembly_report.txt",basename(gtf))
  dir <- dirname(gtf)
  reportFtp <- paste0(dir, "/", report)
  tab <- read.delim(reportFtp, comment.char="#", header=FALSE, sep="\t", stringsAsFactors=FALSE)
  # TODO - need to figure out what to do about these un-parser friendly files
  tab <- tab[,c(7,9,10)]
  names(tab) <- c("refseqAccn","length","ucscName")
  Seqinfo(seqnames=tab$refseqAccn,
          seqlengths=tab$length,
          isCircular=NA,
          genome=genome)
}

# identify the txome based on the indexSeqHash
# - first look into the linkedTxomeTbl
# - secondly look into the pre-computed hash table in `extdata`
getTxomeInfo <- function(indexSeqHash) {

  # first try to find any linkedTxomes in the linkedTxomeTbl
  bfcloc <- getBFCLoc()
  bfc <- BiocFileCache(bfcloc)
  q <- bfcquery(bfc, "linkedTxomeTbl")
  # there should only be one such entry in the tximeta bfc
  stopifnot(bfccount(q) < 2)
  if (bfccount(q) == 1) {
    loadpath <- bfcrpath(bfc, "linkedTxomeTbl")
    linkedTxomeTbl <- readRDS(loadpath)
    m <- match(indexSeqHash, linkedTxomeTbl$sha256)
    if (!is.na(m)) {
      txomeInfo <- as.list(linkedTxomeTbl[m,])
      txomeInfo$linkedTxome <- TRUE
      message(paste0("found matching linked transcriptome:\n[ ",
                     txomeInfo$source," - ",txomeInfo$organism," - release ",txomeInfo$release," ]"))
      return(txomeInfo)
    }
  }

  # if not in linkedTxomes try the pre-computed hashtable...

  # TODO best this would be an external data package / future GA4GH RefGet API
  hashfile <- file.path(system.file("extdata",package="tximeta"),"hashtable.csv")
  hashtable <- read.csv(hashfile,stringsAsFactors=FALSE)
  m <- match(indexSeqHash, hashtable$sha256)
  if (!is.na(m)) {
    # now we can go get the GTF to annotate the ranges
    txomeInfo <- as.list(hashtable[m,])
    if (grepl(" ", txomeInfo$fasta)) {
      txomeInfo$fasta <- strsplit(txomeInfo$fasta, " ")
    }
    txomeInfo$linkedTxome <- FALSE
    message(paste0("found matching transcriptome:\n[ ",
                   txomeInfo$source," - ",txomeInfo$organism," - release ",txomeInfo$release," ]"))
    return(txomeInfo)
  }
  
  return(NULL)
}

# build or load a TxDb/EnsDb for the dataset
getTxDb <- function(txomeInfo, useHub=TRUE, skipFtp=FALSE) {
  # TODO what if there are multiple GTF files?
  stopifnot(length(txomeInfo$gtf) == 1)
  stopifnot(txomeInfo$gtf != "")
  txdbName <- basename(txomeInfo$gtf)
  bfcloc <- getBFCLoc()
  bfc <- BiocFileCache(bfcloc)
  # look up txdbName
  q <- bfcquery(bfc, txdbName)
  # then filter for equality with rname
  q <- q[q$rname==txdbName,]

  if (skipFtp) {
    txomeInfo$gtf <- sub("ftp://","https://",txomeInfo$gtf)
  }

  ### No TxDb was found in the BiocFilecache ###
  if (bfccount(q) == 0) {

    # Ensembl and GENCODE best case we can find database on AnnotationHub
    hubSources <- c("Ensembl","GENCODE")
    srcName <- txomeInfo$source
    hubWorked <- FALSE
    if (srcName %in% hubSources) {
      ensSrc <- srcName == "Ensembl"
      dbType <- if (ensSrc) "EnsDb" else "TxDb"
      if (useHub) {
        message(paste("useHub=TRUE: checking for", dbType, "via 'AnnotationHub'"))
        ah <- AnnotationHub()
        # get records
        records <- query(ah, c(srcName, txomeInfo$organism, txomeInfo$release))
        # confirm source, organism, dbType through metadata columns
        records <- records[records$dataprovider==srcName &
                           records$species==txomeInfo$organism &
                           records$rdataclass==dbType,]        
        if (ensSrc) {
          # Confirm release number through grep on the title
          # EnsDb record titles look like "Ensembl 123 EnsDb for Homo sapiens"
          records <- records[grepl(paste(srcName, txomeInfo$release, dbType), records$title),]
        } else {
          # Narrow records based on the genome coordinates
          # GENCODE record titles look like "TxDb for Gencode v123 on hg38 coordinates"
          coords <- genome2UCSC(txomeInfo$genome)
          records <- records[grepl(coords, records$title),]
        }
        if (length(records) == 1) {
          message(paste("found matching", dbType, "via 'AnnotationHub'"))
          hubWorked <- TRUE
          txdb <- ah[[names(records)]]
          bfcadd(bfc, rname=txdbName, fpath=dbfile(dbconn(txdb)))
        } else {
          message(paste("did not find matching", dbType, "via 'AnnotationHub'"))
        }
      }
      # if check on AnnotationHub failed (or wasn't attempted)
      if (!hubWorked) {
        # build db for Ensembl
        if (ensSrc) {
          message("building EnsDb with 'ensembldb' package")
          # split code based on whether linkedTxome (bc GTF filename may be modified)
          if (!txomeInfo$linkedTxome) {
            # TODO what about suppressing all these warnings
            suppressWarnings({
              savepath <- ensDbFromGtf(
                txomeInfo$gtf,
                outfile = bfcnew(bfc, rname=txdbName, ext=".sqlite")
              )
            })
          } else {
            message("NOTE: linkedTxome with source='Ensembl', ensembldb will be used to parse GTF.
this may produce errors if the GTF is not from Ensembl, or has been modified")
            # for linkedTxome, because the GTF filename may be modified
            # we manually provide organism, genomeVersion, and version
            suppressWarnings({
              savepath <- ensDbFromGtf(
                txomeInfo$gtf,
                outfile = bfcnew(bfc, rname=txdbName, ext=".sqlite"),
                organism = txomeInfo$organism,
                genomeVersion = txomeInfo$genome,
                version = txomeInfo$release
              )
            })
          }
          txdb <- EnsDb(savepath)
        }
      }
    }

    # two cases left:
    # 1) Neither Ensembl or GENCODE source
    # 2) GENCODE source but AHub didn't work
    if ((!srcName %in% hubSources) | (srcName == "GENCODE" & !hubWorked)) {
      message("building TxDb with 'txdbmaker' package")
      # allow .rds instead of GTF
      if (tools::file_ext(txomeInfo$gtf) == "rds") {
        gtf2gr <- readRDS(txomeInfo$gtf)
        txdb <- makeTxDbFromGRanges(gtf2gr)
      } else {
        # the typical case: parse the GTF
        txdb <- makeTxDbFromGFF(txomeInfo$gtf)
      }
      saveDb(
        txdb,
        file = bfcnew(bfc, rname=txdbName, ext=".sqlite")
      )
    }

  } else {
    ### Yes, TxDb was found in the BiocFilecache ###
    loadpath <- bfcrpath(bfc, txdbName)
    if (txomeInfo$source == "Ensembl") {
      message(paste("loading existing EnsDb created:",q$create_time[1]))
      txdb <- EnsDb(loadpath)
    } else {
      message(paste("loading existing TxDb created:",q$create_time[1]))
      txdb <- loadDb(loadpath)
    }
  }
  
  txdb
}

# check to see if there are any missing transcripts not available
# for the rows of the tximport assay matrices. if so, give warning and subset
# (or error if all are missing)
checkAssays2Txps <- function(assays, txps) {
  assay.nms <- rownames(assays[["counts"]])
  txps.missing <- !assay.nms %in% names(txps)
  if (!all(assay.nms %in% names(txps))) {

    # it's probably ok that the messaging here uses the term 'txps',
    # because it's unlikely that we'd have genes not present in the GTF
    # which nevertheless had txps in the GTF...
    
    if (all(!assay.nms %in% names(txps))) {
      stop("none of the transcripts in the quantification files are in the GTF")
    } else {

      if (sum(txps.missing) > 3) {
        example.missing <- paste0("Example missing txps: [",
                                  paste(head(assay.nms[txps.missing],3),collapse=", "),
                                  ", ...]")
      } else {
        example.missing <- paste0("Missing txps: [",
                                  paste(assay.nms[txps.missing],collapse=", "), "]")
      }
      
      # TODO what to do here, GTF is missing some txps in FASTA for Ensembl
      warning(paste0("

Warning: the annotation is missing some transcripts that were quantified.
", sum(txps.missing), " out of ", nrow(assays[["counts"]]),
" txps were missing from GTF/GFF but were in the indexed FASTA.
(This occurs sometimes with Ensembl txps on haplotype chromosomes.)
In order to build a ranged SummarizedExperiment, these txps were removed.
To keep these txps, and to skip adding ranges, use skipMeta=TRUE

", example.missing, "
"))

      # after warning, then subset
      for (nm in names(assays)) {
        assays[[nm]] <- assays[[nm]][!txps.missing,,drop=FALSE]
      }
      
    }
  }
  assays
}

makeUnrangedSE <- function(txi, coldata, metadata) {
  assays <- txi[c("counts","abundance","length")]
  # if there are inferential replicates
  if ("infReps" %in% names(txi)) {
    infReps <- rearrangeInfReps(txi$infReps)
    assays <- c(assays, infReps)
  } else if ("variance" %in% names(txi)) {
    assays <- c(assays, txi["variance"])
  }
  if ("mean" %in% names(txi)) {
    assays <- c(assays, txi["mean"])
  }
  if ("tier" %in% names(txi)) {
    assays <- c(assays, txi["tier"])
  }
  assays <- assays[!sapply(assays, is.null)]
  SummarizedExperiment(assays=assays,
                       colData=coldata,
                       metadata=metadata)
}

# arrange list of inferential replicate matrices (per sample)
# into per replicate (infRep1, infRep2, ...)
rearrangeInfReps <- function(infReps) {
  nreps <- ncol(infReps[[1]])
  stopifnot(all(sapply(infReps, ncol) == nreps))
  getCols <- function(j,l) do.call(cbind, lapply(seq_along(l), function(k)  l[[k]][,j]))
  infReps <- lapply(seq_len(nreps), getCols, infReps)
  names(infReps) <- paste0("infRep",seq_len(nreps))
  infReps
}

# split list of inferential replicate matrices (per replicate)
# into per sample (sample1, sample2, ...)
splitInfReps <- function(infReps) {
  nsamps <- ncol(infReps[[1]])
  sample.names <- colnames(infReps[[1]])
  getCols <- function(j,l) do.call(cbind, lapply(seq_along(l), function(k)  l[[k]][,j]))
  infReps <- lapply(seq_len(nsamps), getCols, infReps)
  names(infReps) <- sample.names
  infReps
}

# build or load ranges
# either transcript, exon-by-transcript, or gene ranges
getRanges <- function(txdb=txdb, txomeInfo=txomeInfo, type=c("txp","exon","cds","gene")) {
  long <- c(txp="transcript",exon="exon",cds="CDS",gene="gene")
  stopifnot(length(txomeInfo$gtf) == 1)
  stopifnot(txomeInfo$gtf != "")

  # TODO the entry in the BiocFileCache assumes that the GTF/GFF file
  # has a distinctive naming structure... works for GENCODE/Ensembl/RefSeq 
  rngsName <- paste0(type,"Rngs-",basename(txomeInfo$gtf))
  
  bfcloc <- getBFCLoc()
  bfc <- BiocFileCache(bfcloc)
  q <- bfcquery(bfc, rngsName)
  if (bfccount(q) == 0) {
    # now generate ranges
    message(paste("generating",long[type],"ranges"))
    # TODO what to do about warnings about out-of-bound ranges? pass along somewhere?

    if (type == "txp") {
      ################
      ## txp ranges ##
      ################

      if (txomeInfo$source == "Ensembl") {
        suppressWarnings({
          rngs <- transcripts(txdb)
        })
      } else {
        suppressWarnings({
          rngs <- transcripts(txdb, columns=c("tx_id","gene_id","tx_name"))
        })
      }
      names(rngs) <- rngs$tx_name
      # dammit de novo transcript annotation will have
      # the transcript names as seqnames (seqid in the GFF3)
      if (tolower(txomeInfo$source) == "dammit") {
        names(rngs) <- seqnames(rngs)
      }
    } else if (type == "exon") {
      #################
      ## exon ranges ##
      #################

      # TODO suppress warnings about out-of-bound ranges for now... how to pass this on
      suppressWarnings({
        rngs <- exonsBy(txdb, by="tx", use.names=TRUE)
      })
    } else if (type == "cds") {
      #################
      ## CDS ranges ##
      #################

      # TODO suppress warnings about out-of-bound ranges for now... how to pass this on
      suppressWarnings({
        rngs <- cdsBy(txdb, by="tx", use.names=TRUE)
      })
    } else if (type == "gene") {
      #################
      ## gene ranges ##
      #################

      # TODO suppress warnings about out-of-bound ranges for now... how to pass this on
      suppressWarnings({
        rngs <- genes(txdb)
      })
    }
    savepath <- bfcnew(bfc, rngsName, ext=".rds")
    saveRDS(rngs, file=savepath)
  } else {
    loadpath <- bfcrpath(bfc, rngsName)
    message(paste("loading existing",long[type],"ranges created:",q$create_time[1]))
    rngs <- readRDS(loadpath)
  }
  rngs
}

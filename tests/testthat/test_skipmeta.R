context("skipMeta")
test_that("you can still use summarizeToGene", {

  dir <- system.file("extdata/salmon_dm", package="tximportData")
  files <- file.path(dir, "SRR1197474", "quant.sf") 
  coldata <- data.frame(files, names="SRR1197474", condition="A", stringsAsFactors=FALSE)

  se <- tximeta(coldata, skipMeta=TRUE)

  expect_error(summarizeToGene(se), "skipRanges")

  tx2gene <- data.frame(tx=rownames(se), gene=sort(rep(1:1000, length.out=nrow(se))))
  gse <- summarizeToGene(se, skipRanges=TRUE, tx2gene=tx2gene)
  
})

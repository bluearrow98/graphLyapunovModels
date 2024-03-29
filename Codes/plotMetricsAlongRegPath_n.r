rm(list = ls())

library(ggplot2)
library(reshape2)
library(dplyr)

p <- c(5, 10, 15, 20, 25)
n <- c(100, 200, 500, 1000, 5000, 10^4, 10^5, Inf)
method <- list("ResultsLassoBIC", "ResultsWithRegEdgeBIC", "ResultsWith1EdgeBIC",
  "ResultsWithGlassoBIC", "ResultsWithLassoIniBIC")
data <- vector('list', length(method))

# Colour blind friendly colours
cbbPalette <- c("#E69F00", "#000000", "#56B4E9", "#009E73", "#F0E442", "#0072B2", "#D55E00", "#CC79A7")

for (i in p) {

  for (j in 1:length(method)) {
    # Best subset results
    data[[j]] <- data.frame(n = n,
      bs = t(sapply(n, function(x){
        load(paste0(getwd(), "/../Results/", method[[j]], 
          "/completeResults_edgeProb25/", x, "_", i, "_res.RData"))
        return (c(results$max_acc, results$max_f1, results$aucroc, results$aucpr))})))

    colnames(data[[j]]) <- c("n", "Max. Acc", "Max. F1 Score", 
        "AUC ROC", "AUC PR")
    data[[j]] <- melt(data[[j]],id.vars = "n", variable.name = "Metrics",value.name = "metrics")

  }

  # Combine data
  combineData <- bind_rows(data, .id = "Method")
  
  p1 <- ggplot(combineData) +
    geom_point(aes(x = as.character(n), y = metrics, group = Method, color=Method),size = 2) + 
    geom_line(aes(x = as.character(n), y = metrics, group = Method, color =Method),linewidth = 0.5) +
    scale_x_discrete(limits = sapply(n, as.character)) +
    scale_color_manual(values = cbbPalette[1:5],
                       labels = c("Lasso", "MIP_reg", "MIP_1edge", "MIP_glasso", "MIP_lasso")) +
    labs(title = paste0("Performance measures for p = ", i),
         x = "Sample size") + theme(axis.text = element_text(size = 7)) +
    facet_wrap(Metrics ~ ., ncol = 2)


  dir = getwd()
  # pdf(file = paste0(dir,"/../Results/Plots for Constant signal size/MetricsAlongRegPath/d25/", 
  #   "p",i,"_res.pdf"))
  print(p1)
  dev.off()
}
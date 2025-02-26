#
# Copyright (C) 2013-2021 University of Amsterdam
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

mlClassificationLda <- function(jaspResults, dataset, options, ...) {

  # Preparatory work
  dataset <- .mlClassificationReadData(dataset, options)
  .mlClassificationErrorHandling(dataset, options, type = "lda")

  # Check if analysis is ready to run
  ready <- .mlClassificationReady(options, type = "lda")

  # Compute results and create the model summary table
  .mlClassificationTableSummary(dataset, options, jaspResults, ready, position = 1, type = "lda")

  # If the user wants to add the classes to the data set
  .mlClassificationAddPredictionsToData(dataset, options, jaspResults, ready)

  # Add test set indicator to data
  .mlAddTestIndicatorToData(options, jaspResults, ready, purpose = "classification")

  # Create the data split plot
  .mlPlotDataSplit(dataset, options, jaspResults, ready, position = 2, purpose = "classification", type = "lda")

  # Create the confusion table
  .mlClassificationTableConfusion(dataset, options, jaspResults, ready, position = 3)

  # Create the class proportions table
  .mlClassificationTableProportions(dataset, options, jaspResults, ready, position = 4)

  # Create the validation measures table
  .mlClassificationTableMetrics(dataset, options, jaspResults, ready, position = 5)

  # Create the coefficients table
  .mlClassificationLdaTableCoef(options, jaspResults, ready, position = 6)

  # Create the prior and posterior table
  .mlClassificationLdaTablePriorPosterior(options, jaspResults, ready, position = 7)

  # Create the group means table
  .mlClassificationLdaTableMeans(options, jaspResults, ready, position = 8)

  # Create the test of equality of means table
  .mlClassificationLdaTableEqualityMeans(dataset, options, jaspResults, ready, position = 9)

  # Create the test of equality of covariance matrices table
  .mlClassificationLdaTableEqualityCovMat(dataset, options, jaspResults, ready, position = 10)

  # Create the multicollinearity table
  .mlClassificationLdaTableMulticollinearity(dataset, options, jaspResults, ready, position = 11)

  # Create the ROC curve
  .mlClassificationPlotRoc(dataset, options, jaspResults, ready, position = 12, type = "lda")

  # Create the Andrews curves
  .mlClassificationPlotAndrews(dataset, options, jaspResults, ready, position = 13)

  # Create the LDA matrix plot
  .mlClassificationLdaPlotDiscriminants(dataset, options, jaspResults, ready, position = 14)

  # Decision boundaries
  .mlClassificationPlotBoundaries(dataset, options, jaspResults, ready, position = 15, type = "lda")
}

# Error handling
.classLdaErrorHandling <- function(dataset, options) {
  # Error Check 1: There should be at least 5 observations in the target variable
  .hasErrors(
    dataset = dataset, type = c("observations", "variance", "infinity"),
    all.target = options$target, observations.amount = "< 5", exitAnalysisIfErrors = TRUE
  )
  # Error Check 2: The target variable should have at least 2 classes
  if (nlevels(dataset[, options$target]) < 2) {
    jaspBase:::.quitAnalysis(gettext("The target variable should have at least 2 classes."))
  }
}

# Compute results
.ldaClassification <- function(dataset, options, jaspResults) {
  # Import model formula from jaspResults
  formula <- jaspResults[["formula"]]$object
  # Split the data into training and test sets
  if (options[["holdoutData"]] == "testSetIndicator" && options[["testSetIndicatorVariable"]] != "") {
    # Select observations according to a user-specified indicator (included when indicator = 1)
    trainingIndex <- which(dataset[, options[["testSetIndicatorVariable"]]] == 0)
  } else {
    # Sample a percentage of the total data set
    trainingIndex <- sample.int(nrow(dataset), size = ceiling((1 - options[["testDataManual"]]) * nrow(dataset)))
  }
  trainingSet <- dataset[trainingIndex, ]
  testSet <- dataset[-trainingIndex, ]
  # Create the generated test set indicator
  testIndicatorColumn <- rep(1, nrow(dataset))
  testIndicatorColumn[trainingIndex] <- 0
  method <- switch(options[["estimationMethod"]],
    "moment" = "moment",
    "mle" = "mle",
    "covMve" = "mve",
    "t" = "t"
  )
  fit <- MASS::lda(formula = formula, data = trainingSet, method = method, CV = FALSE)
  testPredictions <- stats::predict(fit, newdata = testSet)
  # Create results object
  result <- list()
  result[["model"]] <- fit
  result[["method"]] <- method
  result[["scaling"]] <- fit[["scaling"]]
  result[["confTable"]] <- table("Pred" = testPredictions[["class"]], "Real" = testSet[, options[["target"]]])
  result[["testAcc"]] <- sum(diag(prop.table(result[["confTable"]])))
  result[["auc"]] <- .classificationCalcAUC(testSet, trainingSet, options, "ldaClassification", LDAmethod = method)
  result[["testPred"]] <- testPredictions[["class"]]
  result[["testReal"]] <- testSet[, options[["target"]]]
  result[["meanTable"]] <- fit[["means"]]
  result[["relInf"]] <- summary(fit, plot = FALSE)
  result[["prior"]] <- fit[["prior"]]
  result[["postprob"]] <- colMeans(testPredictions[["posterior"]])
  result[["ntrain"]] <- nrow(trainingSet)
  result[["ntest"]] <- nrow(testSet)
  result[["train"]] <- trainingSet
  result[["test"]] <- testSet
  result[["testIndicatorColumn"]] <- testIndicatorColumn
  result[["classes"]] <- predict(fit, newdata = dataset)$class
  return(result)
}

.mlClassificationLdaTableCoef <- function(options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["coefficientsTable"]]) || !options[["coefficientsTable"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Linear Discriminant Coefficients"))
  table$position <- position
  table$dependOn(options = c(
    "coefficientsTable", "trainingDataManual", "scaleVariables", "modelOptimization",
    "target", "predictors", "seed", "setSeed", "modelValid", "estimationMethod",
    "testSetIndicatorVariable", "testSetIndicator", "validationDataManual",
    "holdoutData", "testDataManual"
  ))
  table$addColumnInfo(name = "pred_level", title = "", type = "string")
  jaspResults[["coefficientsTable"]] <- table
  if (!ready) {
    return()
  }
  state <- jaspResults[["classificationResult"]]$object
  for (ldacoef in colnames(state[["scaling"]])) {
    table$addColumnInfo(name = ldacoef, type = "number")
  }
  coefficients <- state[["scaling"]]
  # For constants see: https://stats.stackexchange.com/questions/166942/why-are-discriminant-analysis-results-in-r-lda-and-spss-different-constant-t
  groupmean <- (state[["model"]]$prior %*% state[["model"]]$means)
  constants <- (groupmean %*% state[["scaling"]])
  row <- cbind(
    pred_level = c(gettext("(Constant)"), rownames(coefficients)),
    as.data.frame(rbind(constants, coefficients))
  )
  table$addRows(row)
}

.mlClassificationLdaTablePriorPosterior <- function(options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["priorTable"]]) || !options[["priorTable"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Prior and Posterior Class Probabilities"))
  table$position <- position
  table$dependOn(options = c(
    "priorTable", "trainingDataManual", "scaleVariables", "modelOptimization",
    "target", "predictors", "seed", "setSeed", "modelValid", "estimationMethod",
    "testSetIndicatorVariable", "testSetIndicator", "validationDataManual",
    "holdoutData", "testDataManual"
  ))
  table$addColumnInfo(name = "typeprob", title = "", type = "string")
  table$addColumnInfo(name = "prior", title = gettext("Prior"), type = "number")
  table$addColumnInfo(name = "posterior", title = gettext("Posterior"), type = "number")
  jaspResults[["priorTable"]] <- table
  if (!ready) {
    return()
  }
  state <- jaspResults[["classificationResult"]]$object
  levelPriors <- state[["prior"]]
  levelPost <- state[["postprob"]]
  row <- data.frame(typeprob = names(levelPriors), prior = levelPriors, posterior = levelPost)
  table$addRows(row)
}

.mlClassificationLdaTableMeans <- function(options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["meanTable"]]) || !options[["meanTable"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Class Means in Training Data"))
  table$position <- position
  table$dependOn(options = c(
    "meanTable", "trainingDataManual", "scaleVariables", "modelOptimization", "testSetIndicatorVariable", "testSetIndicator", "validationDataManual",
    "target", "predictors", "seed", "setSeed", "modelValid", "estimationMethod",
    "holdoutData", "testDataManual"
  ))
  table$addColumnInfo(name = "target_level", title = "", type = "string")
  for (i in options[["predictors"]]) {
    table$addColumnInfo(name = i, type = "number", title = i)
  }
  jaspResults[["meanTable"]] <- table
  if (!ready) {
    return()
  }
  state <- jaspResults[["classificationResult"]]$object
  groupMeans <- state[["meanTable"]]
  colnames(groupMeans) <- colnames(groupMeans)
  row <- cbind(target_level = rownames(groupMeans), as.data.frame(groupMeans))
  table$addRows(row)
}

.mlClassificationLdaPlotDiscriminants <- function(dataset, options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["matrixPlot"]]) || !options[["matrixPlot"]]) {
    return()
  }
  plot <- createJaspPlot(title = gettext("Linear Discriminant Matrix"), height = 400, width = 300)
  plot$position <- position
  plot$dependOn(options = c(
    "matrixPlot", "plotDensities", "plotStatistics", "trainingDataManual", "scaleVariables", "modelOptimization", "holdoutData", "testDataManual",
    "target", "predictors", "seed", "setSeed", "modelValid", "estimationMethod", "testSetIndicatorVariable", "testSetIndicator", "validationDataManual"
  ))
  jaspResults[["matrixPlot"]] <- plot
  if (!ready) {
    return()
  }
  .ldaFillMatrixPlot(dataset, options, jaspResults, jaspResults[["classificationResult"]]$object, plot)
}

.ldaFillMatrixPlot <- function(dataset, options, jaspResults, classificationResult, plot) {
  variables <- colnames(classificationResult[["scaling"]])
  l <- length(variables)
  if (l <= 2 && (options[["plotDensities"]] || options[["plotStatistics"]])) {
    width <- 580
    height <- 580
  } else if (l <= 2) {
    width <- 580
    height <- 580
  } else {
    width <- 250 * l
    height <- 250 * l
  }
  plot[["width"]] <- width
  plot[["height"]] <- height
  cexText <- 1.6
  plotMat <- matrix(list(), l, l)
  adjMargin <- ggplot2::theme(plot.margin = ggplot2::unit(c(.25, .40, .25, .25), "cm"))
  oldFontSize <- jaspGraphs::getGraphOption("fontsize")
  jaspGraphs::setGraphOption("fontsize", .85 * oldFontSize)
  startProgressbar(length(plotMat) + 1)
  for (row in seq_len(l)) {
    for (col in seq_len(l)) {
      if (row == col) {
        if (options[["plotDensities"]]) {
          plotMat[[row, col]] <- .ldaDensityplot(classificationResult, options, col) + adjMargin # plot marginal (histogram with density estimator)
        } else {
          p <- jaspGraphs::drawAxis(xName = "", yName = "", force = TRUE) +
            adjMargin +
            ggplot2::xlab("") +
            ggplot2::ylab("") +
            jaspGraphs::geom_rangeframe() +
            jaspGraphs::themeJaspRaw()

          plotMat[[row, col]] <- p
        }
      }
      if (col > row) {
        if (options[["plotStatistics"]]) {
          plotMat[[row, col]] <- .ldaScatterPlot(classificationResult, options, col) + adjMargin # plot scatterplot
        } else {
          p <- jaspGraphs::drawAxis(xName = "", yName = "", force = TRUE) +
            adjMargin +
            ggplot2::xlab("") +
            ggplot2::ylab("") +
            jaspGraphs::geom_rangeframe() +
            jaspGraphs::themeJaspRaw()

          plotMat[[row, col]] <- p
        }
      }
      if (col < row) {
        if (l < 7) {
          if (options[["plotStatistics"]]) {
            p <- jaspGraphs::drawAxis(xName = "", yName = "", force = TRUE) +
              adjMargin +
              ggplot2::xlab("") +
              ggplot2::ylab("") +
              jaspGraphs::geom_rangeframe() +
              jaspGraphs::themeJaspRaw()

            plotMat[[row, col]] <- p
          } else {
            p <- jaspGraphs::drawAxis(xName = "", yName = "", force = TRUE) +
              adjMargin +
              ggplot2::xlab("") +
              ggplot2::ylab("") +
              jaspGraphs::geom_rangeframe() +
              jaspGraphs::themeJaspRaw()

            plotMat[[row, col]] <- p
          }
        }
        if (col == 1 && row == 2) {
          plotMat[[2, 1]] <- .legendPlot(dataset, options, col)
        }
        progressbarTick()
      }
    }
  }
  jaspGraphs::setGraphOption("fontsize", oldFontSize)
  # slightly adjust the positions of the labels left and above the plots.
  labelPos <- matrix(.5, 4, 2)
  labelPos[1, 1] <- .55
  labelPos[4, 2] <- .65
  p <- jaspGraphs::ggMatrixPlot(
    plotList = plotMat, leftLabels = variables, topLabels = variables,
    scaleXYlabels = NULL, labelPos = labelPos
  )
  progressbarTick()
  plot$plotObject <- p
}

.ldaDensityplot <- function(classificationResult, options, col) {
  target <- classificationResult[["train"]][, options[["target"]]]
  ldaFitScaled <- cbind.data.frame(
    LD = .ldaModelMatrix(classificationResult[["model"]], classificationResult[["train"]]) %*% classificationResult[["scaling"]][, col],
    V2 = classificationResult[["train"]][, options[["target"]]]
  )
  ldaFitScaled[["V2"]] <- as.factor(ldaFitScaled[["V2"]])
  xBreaks <- jaspGraphs::getPrettyAxisBreaks(ldaFitScaled[, "LD"], min.n = 4)
  if (length(colnames(classificationResult[["scaling"]])) == 1) {
    p <- ggplot2::ggplot(data = ldaFitScaled, ggplot2::aes(x = LD, group = V2, color = V2, show.legend = TRUE)) +
      jaspGraphs::geom_line(stat = "density") +
      ggplot2::labs(color = options[["target"]]) +
      ggplot2::theme(legend.key = ggplot2::element_blank()) +
      ggplot2::scale_color_manual(values = .mlColorScheme(length(unique(target)))) +
      ggplot2::scale_x_continuous(name = NULL, breaks = xBreaks, limits = range(xBreaks)) +
      ggplot2::scale_y_continuous(name = gettext("Density")) +
      jaspGraphs::geom_rangeframe() +
      jaspGraphs::themeJaspRaw(legend.position = "right") +
      ggplot2::theme(axis.ticks.y = ggplot2::element_blank(), axis.text.y = ggplot2::element_blank()) +
      ggplot2::guides(color = ggplot2::guide_legend(override.aes = list(shape = 21)))
  } else {
    p <- ggplot2::ggplot(data = ldaFitScaled, ggplot2::aes(x = LD, group = V2, color = V2)) +
      jaspGraphs::geom_line(stat = "density") +
      ggplot2::scale_color_manual(values = .mlColorScheme(length(unique(target)))) +
      ggplot2::scale_x_continuous(name = NULL, breaks = xBreaks, limits = range(xBreaks)) +
      ggplot2::scale_y_continuous(name = gettext("Density")) +
      jaspGraphs::geom_rangeframe() +
      jaspGraphs::themeJaspRaw() +
      ggplot2::theme(axis.ticks.y = ggplot2::element_blank(), axis.text.y = ggplot2::element_blank())
  }
  return(p)
}

.ldaScatterPlot <- function(classificationResult, options, col) {
  data <- classificationResult[["train"]]
  target <- data[, options[["target"]]]
  model <- classificationResult[["model"]]
  predictions <- stats::predict(model, newdata = data)$x[, c(col, col - 1)]
  plotData <- data.frame(predictions, target = target)
  colnames(plotData) <- c("x", "y", "target")
  xBreaks <- jaspGraphs::getPrettyAxisBreaks(plotData[, "x"], min.n = 4)
  yBreaks <- jaspGraphs::getPrettyAxisBreaks(plotData[, "y"], min.n = 4)
  p <- ggplot2::ggplot(plotData, ggplot2::aes(x = x, y = y)) +
    jaspGraphs::geom_point(ggplot2::aes(fill = target)) +
    ggplot2::labs(fill = options[["target"]]) +
    ggplot2::scale_fill_manual(values = .mlColorScheme(length(unique(target)))) +
    ggplot2::scale_x_continuous(name = NULL, breaks = xBreaks, limits = range(xBreaks)) +
    ggplot2::scale_y_continuous(name = NULL, breaks = yBreaks, limits = range(yBreaks)) +
    jaspGraphs::geom_rangeframe() +
    jaspGraphs::themeJaspRaw()
  return(p)
}

.mlClassificationLdaTableEqualityMeans <- function(dataset, options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["manovaTable"]]) || !options[["manovaTable"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Tests of Equality of Class Means"))
  table$position <- position
  table$dependOn(options = c("manovaTable", "scaleVariables", "target", "predictors"))
  table$addColumnInfo(name = "model", title = "", type = "string")
  table$addColumnInfo(name = "f", title = "F", type = "number")
  table$addColumnInfo(name = "df1", title = "df1", type = "integer")
  table$addColumnInfo(name = "df2", title = "df2", type = "integer")
  table$addColumnInfo(name = "p", title = "p", type = "pvalue")
  table$addFootnote(gettext("The null hypothesis specifies equal class means."))
  jaspResults[["manovaTable"]] <- table
  if (!ready) {
    return()
  }
  target <- as.numeric(dataset[, options[["target"]]])
  predictors <- as.matrix(dataset[, options[["predictors"]]])
  tryCatch(
    {
      manovaResult <- manova(predictors ~ target)
      manovaSummary <- summary(manovaResult, test = "Wilks")
      # Individual models
      anovaSummary <- summary.aov(manovaResult)
      for (i in 1:length(anovaSummary)) {
        sumTmp <- as.matrix(anovaSummary[[i]])
        Fstat <- sumTmp[1, 4]
        df1 <- sumTmp[1, 1]
        df2 <- sumTmp[2, 1]
        p <- sumTmp[1, 5]
        row <- data.frame(model = options[["predictors"]][i], f = Fstat, df1 = df1, df2 = df2, p = p)
        table$addRows(row)
      }
    },
    error = function(e) table$setError(.extractErrorMessage(e))
  )
}

.mlClassificationLdaTableEqualityCovMat <- function(dataset, options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["boxTest"]]) || !options[["boxTest"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Tests of Equality of Covariance Matrices"))
  table$position <- position
  table$dependOn(options = c("boxTest", "scaleVariables", "target", "predictors"))
  table$addColumnInfo(name = "test", title = "", type = "string")
  table$addColumnInfo(name = "x", title = "\u03C7\u00B2", type = "number")
  table$addColumnInfo(name = "df", title = gettext("df"), type = "integer")
  table$addColumnInfo(name = "p", title = gettext("p"), type = "pvalue")
  table$addFootnote(gettext("The null hypothesis specifies equal covariance matrices."))
  jaspResults[["boxTest"]] <- table
  if (!ready) {
    return()
  }
  boxSum <- .boxM(dataset[, options[["predictors"]]], dataset[, options[["target"]]])
  chi <- as.numeric(boxSum[["statistic"]])
  df <- as.numeric(boxSum[["parameter"]])
  p <- as.numeric(boxSum[["p.value"]])
  row <- data.frame(test = "Box's M", x = chi, df = df, p = p)
  table$addRows(row)
}

.mlClassificationLdaTableMulticollinearity <- function(dataset, options, jaspResults, ready, position) {
  if (!is.null(jaspResults[["multicolTable"]]) || !options[["multicolTable"]]) {
    return()
  }
  table <- createJaspTable(title = gettext("Pooled Within-Class Matrices Correlations"))
  table$position <- position
  table$dependOn(options = c("multicolTable", "scaleVariables", "target", "predictors"))
  jaspResults[["multicolTable"]] <- table
  if (!ready) {
    return()
  }
  boxSum <- .boxM(dataset[, options[["predictors"]]], dataset[, options[["target"]]])
  corPooled <- cor(boxSum[["pooled"]])
  table$addColumnInfo(name = "empty", title = "", type = "string")
  for (i in 1:ncol(corPooled)) {
    table$addColumnInfo(name = paste0("v", i), title = unlist(options[["predictors"]])[i], type = "number")
  }
  for (i in 1:nrow(corPooled)) {
    row <- data.frame(empty = unlist(options[["predictors"]])[i])
    for (j in 1:ncol(corPooled)) {
      if (j <= i) {
        row[[paste0("v", j)]] <- corPooled[j, i]
      }
    }
    table$addRows(row)
  }
}

.ldaModelMatrix <- function(ldafit, data) {
  # adapted from MASS:::lda.formula
  x <- model.matrix(ldafit$terms, data)
  xint <- match("(Intercept)", colnames(x), nomatch = 0L)
  if (xint > 0L) {
    x <- x[, -xint, drop = FALSE]
  }
  return(x)
}

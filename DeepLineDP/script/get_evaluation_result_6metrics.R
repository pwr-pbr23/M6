library(tidyverse)
library(gridExtra)
library(ModelMetrics)
library(caret)
library(reshape2)
library(pROC)
library(effsize)
library(ScottKnottESD)

save.fig.dir <- "../output/figure/"

dir.create(file.path(save.fig.dir), showWarnings = FALSE)

preprocess <- function(x, reverse) {
  colnames(x) <- c("variable", "value")
  tmp <- do.call(cbind, split(x, x$variable))
  tmp <- tmp[, grep("value", names(tmp))]
  names(tmp) <- gsub(".value", "", names(tmp))
  df <- tmp
  ranking <- NULL
  
  if (reverse == TRUE) {
    ranking <- (max(sk_esd(df)$group) - sk_esd(df)$group) + 1
  } else {
    ranking <- sk_esd(df)$group
  }
  x$rank <- paste("Rank", ranking[as.character(x$variable)])
  return(x)
}

get.top.k.tokens <- function(df, k) {
  top.k <- df %>%
    filter(is.comment.line == "False" & file.level.ground.truth == "True" & prediction.label == "True") %>%
    group_by(test, filename) %>%
    top_n(k, token.attention.score) %>%
    select("project", "train", "test", "filename", "token") %>%
    distinct()
  
  top.k$flag <- "topk"
  
  return(top.k)
}


prediction_dir <- "../output/prediction/DeepLineDP/within-release/"

all_files <- list.files(prediction_dir)

df_all <- NULL

for (f in all_files)
{
  df <- read.csv(paste0(prediction_dir, f))
  df_all <- rbind(df_all, df)
}

## prepare data for baseline
line.ground.truth <- select(df_all, project, train, test, filename, file.level.ground.truth, prediction.prob, line.number, line.level.ground.truth)
line.ground.truth <- filter(line.ground.truth, file.level.ground.truth == "True" & prediction.prob >= 0.5)
line.ground.truth <- distinct(line.ground.truth)

get.line.metrics.result <- function(baseline.df, cur.df.file) {
  baseline.df.with.ground.truth <- merge(baseline.df, cur.df.file, by = c("filename", "line.number"))
  
  sorted <- baseline.df.with.ground.truth %>%
    group_by(filename) %>%
    arrange(-line.score, .by_group = TRUE) %>%
    mutate(order = row_number())
  
  # IFA
  IFA <- sorted %>%
    filter(line.level.ground.truth == "True") %>%
    group_by(filename) %>%
    top_n(1, -order)
  
  ifa.list <- IFA$order
  
  total_true <- sorted %>%
    group_by(filename) %>%
    summarize(total_true = sum(line.level.ground.truth == "True"))
  
  # Recall20%LOC
  recall20LOC <- sorted %>%
    group_by(filename) %>%
    mutate(effort = round(order / n(), digits = 2)) %>%
    filter(effort <= 0.2) %>%
    summarize(correct_pred = sum(line.level.ground.truth == "True")) %>%
    merge(total_true) %>%
    mutate(recall20LOC = correct_pred / total_true)
  
  recall.list <- recall20LOC$recall20LOC
  # Effort20%Recall
  effort20Recall <- sorted %>%
    merge(total_true) %>%
    group_by(filename) %>%
    mutate(cummulative_correct_pred = cumsum(line.level.ground.truth == "True"), recall = round(cumsum(line.level.ground.truth == "True") / total_true, digits = 2)) %>%
    summarise(effort20Recall = sum(recall <= 0.2) / n())
  
  effort.list <- effort20Recall$effort20Recall
  
 
# Precision
  precision <- sorted %>%
    group_by(filename) %>%
    summarize(TP = sum(line.level.ground.truth == "True" & line.score > 0), FP = sum(line.level.ground.truth == "False" & line.score > 0)) %>%
    mutate(Precision = TP / (TP + FP))

  precision.list <- precision$Precision

  # Matthews Correlation Coefficient (MCC)
  mcc <- sorted %>%
  group_by(filename) %>%
  summarize(TP = sum(line.level.ground.truth == "True" & line.score > 0),
            FP = sum(line.level.ground.truth == "False" & line.score > 0),
            TN = sum(line.level.ground.truth == "False" & line.score == 0),
            FN = sum(line.level.ground.truth == "True" & line.score == 0)) %>%
  mutate(TP = as.numeric(TP), 
         FP = as.numeric(FP), 
         TN = as.numeric(TN), 
         FN = as.numeric(FN)) %>%
  mutate(MCC = ifelse((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN) != 0,
                     (TP * TN - FP * FN) / exp((log(TP + FP) + log(TP + FN) + log(TN + FP) + log(TN + FN)) / 2),
                     0))

mcc.list <- mcc$MCC

  # Balanced Accuracy
  balanced_accuracy <- sorted %>%
    group_by(filename) %>%
    summarize(TP = sum(line.level.ground.truth == "True" & line.score > 0),
              FP = sum(line.level.ground.truth == "False" & line.score > 0),
              TN = sum(line.level.ground.truth == "False" & line.score == 0),
              FN = sum(line.level.ground.truth == "True" & line.score == 0)) %>%
    mutate(Balanced_Accuracy = ifelse((TP + FN) * (TN + FP) != 0,
                                      0.5 * (TP / (TP + FN) + TN / (TN + FP)),
                                      0))

  balanced_accuracy.list <- balanced_accuracy$Balanced_Accuracy

  result.df <- data.frame(ifa.list, recall.list, effort.list, precision.list, mcc.list, balanced_accuracy.list)
  
  return(result.df)
}

# all_eval_releases <- c("activemq-5.2.0", "activemq-5.3.0", "activemq-5.8.0")
all_eval_releases = c('activemq-5.2.0', 'activemq-5.3.0', 'activemq-5.8.0',
                      'camel-2.10.0', 'camel-2.11.0' ,
                      'derby-10.5.1.1' , 'groovy-1_6_BETA_2' , 'hbase-0.95.2',
                      'hive-0.12.0', 'jruby-1.5.0', 'jruby-1.7.0.preview1',
                      'lucene-3.0.0', 'lucene-3.1', 'wicket-1.5.3')

rf.result.dir <- "../output/RF-line-level-result/"
xgb.result.dir <- "../output/XGB-line-level-result/"
lgbm.result.dir <- "../output/LGBM-line-level-result/"

n.gram.result.df <- NULL
error.prone.result.df <- NULL
rf.result.df <- NULL
xgb.result.df <- NULL
lgbm.result.df <- NULL

## get result from baseline
for (rel in all_eval_releases)
{
  rf.result <- read.csv(paste0(rf.result.dir, rel, "-line-lvl-result.csv"))
  rf.result <- select(rf.result, "filename", "line_number", "line.score.pred")
  names(rf.result) <- c("filename", "line.number", "line.score")
  
  cur.df.file <- filter(line.ground.truth, test == rel)
  cur.df.file <- select(cur.df.file, filename, line.number, line.level.ground.truth)
  
  rf.eval.result <- get.line.metrics.result(rf.result, cur.df.file)
  
  rf.result.df <- rbind(rf.result.df, rf.eval.result)
  
  xgb.result <- read.csv(paste0(xgb.result.dir, rel, "-line-lvl-result.csv"))
  xgb.result <- select(xgb.result, "filename", "line_number", "line.score.pred")
  names(xgb.result) <- c("filename", "line.number", "line.score")
  
  cur.df.file <- filter(line.ground.truth, test == rel)
  cur.df.file <- select(cur.df.file, filename, line.number, line.level.ground.truth)
  
  xgb.eval.result <- get.line.metrics.result(xgb.result, cur.df.file)
  
  xgb.result.df <- rbind(xgb.result.df, xgb.eval.result)
  
  lgbm.result <- read.csv(paste0(lgbm.result.dir, rel, "-line-lvl-result.csv"))
  lgbm.result <- select(lgbm.result, "filename", "line_number", "line.score.pred")
  names(lgbm.result) <- c("filename", "line.number", "line.score")
  
  cur.df.file <- filter(line.ground.truth, test == rel)
  cur.df.file <- select(cur.df.file, filename, line.number, line.level.ground.truth)
  
  lgbm.eval.result <- get.line.metrics.result(lgbm.result, cur.df.file)
  
  lgbm.result.df <- rbind(lgbm.result.df, lgbm.eval.result)
  
  print(paste0("finished ", rel))
}

# Force attention score of comment line is 0
df_all[df_all$is.comment.line == "True", ]$token.attention.score <- 0

tmp.top.k <- get.top.k.tokens(df_all, 1500)

merged_df_all <- merge(df_all, tmp.top.k, by = c("project", "train", "test", "filename", "token"), all.x = TRUE)

merged_df_all[is.na(merged_df_all$flag), ]$token.attention.score <- 0

## use top-k tokens
sum_line_attn <- merged_df_all %>%
  filter(file.level.ground.truth == "True" & prediction.label == "True") %>%
  group_by(test, filename, is.comment.line, file.level.ground.truth, prediction.label, line.number, line.level.ground.truth) %>%
  summarize(attention_score = sum(token.attention.score), num_tokens = n())

sorted <- sum_line_attn %>%
  group_by(test, filename) %>%
  arrange(-attention_score, .by_group = TRUE) %>%
  mutate(order = row_number())

## get result from DeepLineDP
# calculate IFA
IFA <- sorted %>%
  filter(line.level.ground.truth == "True") %>%
  group_by(test, filename) %>%
  top_n(1, -order)

total_true <- sorted %>%
  group_by(test, filename) %>%
  summarize(total_true = sum(line.level.ground.truth == "True"))

# calculate Recall20%LOC
recall20LOC <- sorted %>%
  group_by(test, filename) %>%
  mutate(effort = round(order / n(), digits = 2)) %>%
  filter(effort <= 0.2) %>%
  summarize(correct_pred = sum(line.level.ground.truth == "True")) %>%
  merge(total_true) %>%
  mutate(recall20LOC = correct_pred / total_true)

# calculate Effort20%Recall
effort20Recall <- sorted %>%
  merge(total_true) %>%
  group_by(test, filename) %>%
  mutate(cummulative_correct_pred = cumsum(line.level.ground.truth == "True"), recall = round(cumsum(line.level.ground.truth == "True") / total_true, digits = 2)) %>%
  summarise(effort20Recall = sum(recall <= 0.2) / n())
# Precision
deeplinedp.precision <- sorted %>%
  group_by(test, filename) %>%
  summarize(TP = sum(line.level.ground.truth == "True" & attention_score > 0), FP = sum(line.level.ground.truth == "False" & attention_score > 0)) %>%
  mutate(Precision = TP / (TP + FP)) %>%
  .$Precision

# Matthews Correlation Coefficient (mcc)
deeplinedp.mcc <- sorted %>%
  group_by(test, filename) %>%
  summarize(TP = sum(line.level.ground.truth == "True" & attention_score > 0),
            FP = sum(line.level.ground.truth == "False" & attention_score > 0),
            TN = sum(line.level.ground.truth == "False" & attention_score == 0),
            FN = sum(line.level.ground.truth == "True" & attention_score == 0)) %>%
  mutate(MCC = (TP * TN - FP * FN) / sqrt((TP + FP) * (TP + FN) * (TN + FP) * (TN + FN))) %>%
  .$MCC

# Balanced Accuracy
deeplinedp.balanced_accuracy <- sorted %>%
  group_by(test, filename) %>%
  summarize(TP = sum(line.level.ground.truth == "True" & attention_score > 0),
            FP = sum(line.level.ground.truth == "False" & attention_score > 0),
            TN = sum(line.level.ground.truth == "False" & attention_score == 0),
            FN = sum(line.level.ground.truth == "True" & attention_score == 0)) %>%
  mutate(Balanced_Accuracy = 0.5 * (TP / (TP + FN) + TN / (TN + FP))) %>%
  .$Balanced_Accuracy

## prepare data for plotting
deeplinedp.ifa <- IFA$order
deeplinedp.recall <- recall20LOC$recall20LOC
deeplinedp.effort <- effort20Recall$effort20Recall

deepline.dp.line.result <- data.frame(deeplinedp.ifa, deeplinedp.recall, deeplinedp.effort, deeplinedp.precision, deeplinedp.mcc, deeplinedp.balanced_accuracy)

names(rf.result.df) <- c("IFA", "Recall20%LOC", "Effort@20%Recall", "Precision", "MCC", "Balanced Accuracy")
names(xgb.result.df) <- c("IFA", "Recall20%LOC", "Effort@20%Recall", "Precision", "MCC", "Balanced Accuracy")
names(lgbm.result.df) <- c("IFA", "Recall20%LOC", "Effort@20%Recall", "Precision", "MCC", "Balanced Accuracy")
names(deepline.dp.line.result) <- c("IFA", "Recall20%LOC", "Effort@20%Recall", "Precision", "MCC", "Balanced Accuracy")

rf.result.df$technique <- "RF"
xgb.result.df$technique <- "XGB"
lgbm.result.df$technique <- "LGBM"
deepline.dp.line.result$technique <- "DeepLineDP"
all.line.result <- rbind(rf.result.df, xgb.result.df, lgbm.result.df, deepline.dp.line.result)

recall.result.df <- select(all.line.result, c("technique", "Recall20%LOC"))
ifa.result.df <- select(all.line.result, c("technique", "IFA"))
effort.result.df <- select(all.line.result, c("technique", "Effort@20%Recall"))
precision.result.df <- select(all.line.result, c("technique", "Precision"))
mcc.result.df <- select(all.line.result, c("technique", "MCC"))
balanced_accuracy.result.df <- select(all.line.result, c("technique", "Balanced Accuracy"))

print(recall.result.df)
print(ifa.result.df)
print(effort.result.df)
print(precision.result.df)
print(mcc.result.df)
print(balanced_accuracy.result.df)

recall.result.df <- preprocess(recall.result.df, FALSE)
ifa.result.df <- preprocess(ifa.result.df, TRUE)
effort.result.df <- preprocess(effort.result.df, TRUE)
precision.result.df <- preprocess(precision.result.df, reverse = FALSE)
mcc.result.df <- preprocess(mcc.result.df, reverse = TRUE)
balanced_accuracy.result.df <- preprocess(balanced_accuracy.result.df, reverse = TRUE)

ggplot(recall.result.df, aes(x = reorder(variable, -value, FUN = median), y = value)) +
  geom_boxplot() +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("Recall@Top20%LOC") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-Recall@Top20LOC.png"), width = 4, height = 2.5)

ggplot(effort.result.df, aes(x = reorder(variable, value, FUN = median), y = value)) +
  geom_boxplot() +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("Effort@Top20%Recall") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-Effort@Top20Recall.png"), width = 4, height = 2.5)

ggplot(ifa.result.df, aes(x = reorder(variable, value, FUN = median), y = value)) +
  geom_boxplot() +
  coord_cartesian(ylim = c(0, 175)) +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("IFA") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-IFA.png"), width = 4, height = 2.5)

ggplot(precision.result.df, aes(x = reorder(variable, -value, FUN = median), y = value)) +
  geom_boxplot() +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("Precision") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-Precision.png"), width = 4, height = 2.5)

ggplot(mcc.result.df, aes(x = reorder(variable, value, FUN = median), y = value)) +
  geom_boxplot() +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("MCC") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-MCC.png"), width = 4, height = 2.5)

ggplot(balanced_accuracy.result.df, aes(x = reorder(variable, value, FUN = median), y = value)) +
  geom_boxplot() +
  coord_cartesian(ylim = c(0, 1)) +
  facet_grid(~rank, drop = TRUE, scales = "free", space = "free") +
  ylab("Balanced Accuracy") +
  xlab("")
ggsave(paste0(save.fig.dir, "file-BalancedAccuracy.png"), width = 4, height = 2.5)

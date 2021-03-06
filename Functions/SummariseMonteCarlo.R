SummariseMonteCarlo <- function(df){
 df %>% 
    mutate(PGfract = (max(PowerGen)- PowerGen)/max(PowerGen)) %>%
    group_by(NodesAttacked, Cascade) %>%
    summarise(mean = mean(GCfract),
              sd = sd(GCfract),
              GC95 = quantile(GCfract, .95),
              GC05 = quantile(GCfract, .05),
              count = n(),
              mPGfract = mean(PGfract),
              medPGfract = median(PGfract),
              PG95 = quantile(PGfract, .95),
              PG05 = quantile(PGfract, .05),
              PGmax = max(PGfract),
              PGmin = min(PGfract),
              mLoad = mean(GridLoading),
              GL95 = quantile(GridLoading, .95),
              GL05 = quantile(GridLoading, .05)) %>%
    ungroup %>%
    group_by(Cascade) %>%
     mutate(ID =n():1) %>%
    ungroup
  
}
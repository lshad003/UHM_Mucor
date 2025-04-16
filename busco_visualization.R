# Load necessary libraries
library(tidyverse)
library(forcats)

# Set directory and sample IDs
busco_dir <- "/bigdata/stajichlab/lshad003/Mucor/BUSCO"
sample_ids <- c("UHM10_S1", "UHM23_S2", "UHM31_S3", "UHM32_S4", "UHM35_S5")

# Function to parse a BUSCO summary file
parse_busco <- function(file_path, sample_name) {
  lines <- readLines(file_path)
  categories <- c(
    "Complete and single-copy BUSCOs", 
    "Complete and duplicated BUSCOs", 
    "Fragmented BUSCOs", 
    "Missing BUSCOs"
  )
  labels <- c("Complete (Single)", "Complete (Duplicated)", "Fragmented", "Missing")
  
  counts <- sapply(categories, function(cat) {
    line <- grep(cat, lines, value = TRUE)
    if (length(line) == 0) return(NA)
    as.numeric(str_extract(line, "^\\s*\\d+"))
  })
  
  total_line <- grep("Total BUSCO groups searched", lines, value = TRUE)
  total_buscos <- as.numeric(str_extract(total_line, "\\d+"))
  
  tibble(
    Sample = sample_name,
    Category = labels,
    Count = counts,
    Percentage = round((counts / total_buscos) * 100, 2)
  )
}

# Read and bind all parsed results
busco_data <- purrr::map_dfr(sample_ids, function(id) {
  file <- file.path(busco_dir, paste0(id, "_busco"), 
                    paste0("short_summary.specific.mucoromycota_odb10.", id, "_busco.txt"))
  if (file.exists(file)) {
    parse_busco(file, id)
  } else {
    warning(paste("Missing file for", id))
    NULL
  }
})

# Reorder Samples by descending 'Complete (Single)' percentage
reorder_levels <- busco_data %>%
  filter(Category == "Complete (Single)") %>%
  arrange(desc(Percentage)) %>%
  pull(Sample)

busco_data <- busco_data %>%
  mutate(Sample = factor(Sample, levels = reorder_levels))

# Plot BUSCO summary
ggplot(busco_data, aes(x = Sample, y = Percentage, fill = Category)) +
  geom_bar(stat = "identity", position = "stack", color = "black") +
  scale_fill_manual(values = c(
    "Complete (Single)" = "#2196F3",
    "Complete (Duplicated)" = "#8BC34A",
    "Fragmented" = "#FFC107",
    "Missing" = "#F44336"
  )) +
  theme_minimal(base_size = 14) +
  labs(
    title = "BUSCO Summary Across 5 Mucor Genomes",
    y = "Percentage of BUSCOs",
    x = "Genome Sample",
    fill = "BUSCO Category"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

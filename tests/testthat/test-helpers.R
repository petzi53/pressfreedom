## Minimal stand-in for rwb_standardized, covering only the columns
## df_chart() touches: year_n, score, rank, country_en, iso.
make_df <- function() {
  data.frame(
    year_n     = c(2010L, 2012L, 2013L, 2014L, 2015L, 2015L, 2020L),
    score      = c(30,     32,    NA,    40,    45,    50,    NA),
    rank       = c(100,    98,    95,    90,    85,    12,    5),
    country_en = factor(c(
      "Elbonia", "Elbonia", "Elbonia", "Elbonia", "Elbonia", "Freedonia", "Freedonia"
    )),
    iso        = c("ELB", "ELB", "ELB", "ELB", "ELB", "FRE", "FRE"),
    stringsAsFactors = FALSE
  )
}

test_that("df_chart() restricts score to 2013+ due to the scale change", {
  result <- df_chart(make_df(), "score", "Elbonia")
  expect_true(all(result$year_n >= 2013))
  # 2013 is dropped anyway because score is NA that year
  expect_equal(result$year_n, c(2014L, 2015L))
})

test_that("df_chart() does not restrict rank to 2013+", {
  result <- df_chart(make_df(), "rank", "Elbonia")
  expect_true(any(result$year_n < 2013))
  expect_equal(result$year_n, c(2010L, 2012L, 2013L, 2014L, 2015L))
})

test_that("df_chart() filters to the requested countries", {
  result <- df_chart(make_df(), "rank", "Freedonia")
  expect_true(all(result$country_en == "Freedonia"))
  expect_equal(nrow(result), 2)
})

test_that("df_chart() supports multiple selected countries", {
  result <- df_chart(make_df(), "rank", c("Elbonia", "Freedonia"))
  expect_setequal(as.character(unique(result$country_en)), c("Elbonia", "Freedonia"))
})

test_that("df_chart() drops rows with NA in the selected variable", {
  result <- df_chart(make_df(), "score", c("Elbonia", "Freedonia"))
  expect_false(anyNA(result$score))
  # The 2020 Freedonia row (NA score) should be gone
  expect_false(2020L %in% result$year_n[result$country_en == "Freedonia"])
})

test_that("df_chart() returns rows sorted by year", {
  result <- df_chart(make_df(), "rank", "Elbonia")
  expect_equal(result$year_n, sort(result$year_n))
})

test_that("df_chart() selects only the expected columns", {
  result <- df_chart(make_df(), "score", "Elbonia")
  expect_named(result, c("year_n", "score", "country_en", "iso"))
})

test_that("df_chart() drops unused factor levels from country_en", {
  result <- df_chart(make_df(), "rank", "Elbonia")
  expect_setequal(levels(result$country_en), "Elbonia")
})

test_that("df_chart() returns zero rows for a country not present", {
  result <- df_chart(make_df(), "rank", "Nowhere")
  expect_equal(nrow(result), 0)
})

test_that("card_title() builds the expected prefix for known variables", {
  expect_match(card_title("score", "Elbonia", 2020), "^Global Score for")
  expect_match(card_title("rank", "Elbonia", 2020), "^Global Rank for")
  expect_match(card_title("political_context", "Elbonia", 2022), "^Political Context for")
  expect_match(card_title("economic_context", "Elbonia", 2022), "^Economic Context for")
  expect_match(card_title("legal_context", "Elbonia", 2022), "^Legal Context for")
  expect_match(card_title("social_context", "Elbonia", 2022), "^Social Context for")
  expect_match(card_title("safety", "Elbonia", 2022), "^Safety for")
})

test_that("card_title() falls back to 'Unknown for' for unrecognized variables", {
  expect_match(card_title("bogus_var", "Elbonia", 2020), "^Unknown for")
})

test_that("card_title() joins multiple countries with commas", {
  title <- card_title("score", c("Elbonia", "Freedonia"), 2020)
  expect_match(title, "Elbonia, Freedonia")
})

test_that("card_title() formats a single year without a dash", {
  title <- card_title("score", "Elbonia", 2020)
  expect_match(title, "in 2020$")
  expect_false(grepl("\u2013", title))
})

test_that("card_title() formats a year range with an en dash", {
  title <- card_title("score", "Elbonia", c(2013, 2014, 2020))
  expect_match(title, "in 2013 \u2013 2020$")
})

test_that("card_title() omits the year clause when years is NULL or empty", {
  title_null  <- card_title("score", "Elbonia", NULL)
  title_empty <- card_title("score", "Elbonia", numeric(0))
  expect_equal(title_null, "Global Score for Elbonia ")
  expect_equal(title_empty, "Global Score for Elbonia ")
})

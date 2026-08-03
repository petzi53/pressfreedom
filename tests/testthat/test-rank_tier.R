test_that("rank_tier() classifies interior ranks into the correct tier", {
  max_rank <- 180
  expect_equal(rank_tier(1, max_rank), "Top 2.5%")
  expect_equal(rank_tier(20, max_rank), "2.5%\u201315%")
  expect_equal(rank_tier(90, max_rank), "15%\u201385%")
  expect_equal(rank_tier(160, max_rank), "85%\u201397.5%")
  expect_equal(rank_tier(180, max_rank), "Bottom 2.5%")
})

test_that("rank_tier() boundaries match the ceiling/floor cutoffs", {
  max_rank <- 180
  # ceiling(180 * 0.025) = 5; floor(180 * 0.15) = 27
  # floor(180 * 0.85) = 153; floor(180 * 0.975) = 175
  expect_equal(rank_tier(5, max_rank), "Top 2.5%")
  expect_equal(rank_tier(6, max_rank), "2.5%\u201315%")
  expect_equal(rank_tier(27, max_rank), "2.5%\u201315%")
  expect_equal(rank_tier(28, max_rank), "15%\u201385%")
  expect_equal(rank_tier(153, max_rank), "15%\u201385%")
  expect_equal(rank_tier(154, max_rank), "85%\u201397.5%")
  expect_equal(rank_tier(175, max_rank), "85%\u201397.5%")
  expect_equal(rank_tier(176, max_rank), "Bottom 2.5%")
})

test_that("rank_tier() returns NA for missing ranks", {
  expect_true(is.na(rank_tier(NA_real_, 180)))
})

test_that("rank_tier() is vectorized and preserves order/length", {
  result <- rank_tier(c(1, NA, 180), 180)
  expect_equal(result, c("Top 2.5%", NA_character_, "Bottom 2.5%"))
  expect_length(result, 3)
})

test_that("rank_tier() handles a small max_rank without erroring", {
  # max_rank = 10 collapses p2_5 and p15 to the same cutoff (both 1),
  # so rank 1 falls into "Top 2.5%" rather than "2.5%-15%".
  expect_equal(rank_tier(1, 10), "Top 2.5%")
  expect_equal(rank_tier(10, 10), "Bottom 2.5%")
})

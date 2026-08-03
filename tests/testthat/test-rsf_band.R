test_that("rsf_band() classifies interior values into the correct band", {
  expect_equal(rsf_band(90), "Good")
  expect_equal(rsf_band(75), "Satisfactory")
  expect_equal(rsf_band(60), "Problematic")
  expect_equal(rsf_band(45), "Difficult")
  expect_equal(rsf_band(10), "Very Serious")
})

test_that("rsf_band() boundaries are inclusive on the lower edge", {
  expect_equal(rsf_band(85), "Good")
  expect_equal(rsf_band(70), "Satisfactory")
  expect_equal(rsf_band(55), "Problematic")
  expect_equal(rsf_band(40), "Difficult")
  expect_equal(rsf_band(0), "Very Serious")
})

test_that("rsf_band() handles the extremes of the 0-100 scale", {
  expect_equal(rsf_band(100), "Good")
  expect_equal(rsf_band(0), "Very Serious")
})

test_that("rsf_band() returns NA for missing scores", {
  expect_true(is.na(rsf_band(NA_real_)))
})

test_that("rsf_band() is vectorized and preserves order/length", {
  result <- rsf_band(c(90, 70, 40, NA, 0))
  expect_equal(result, c("Good", "Satisfactory", "Difficult", NA_character_, "Very Serious"))
  expect_length(result, 5)
})

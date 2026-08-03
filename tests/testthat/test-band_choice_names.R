test_that("band_choice_names() returns one tagList per level, in order", {
  result <- band_choice_names(
    c("Good", "Bad"),
    c(Good = "Good label", Bad = "Bad label"),
    c(Good = "#111111", Bad = "#222222")
  )
  expect_length(result, 2)
  expect_true(all(vapply(result, inherits, logical(1), "shiny.tag.list")))
})

test_that("band_choice_names() embeds the swatch color for each level", {
  result <- band_choice_names(
    c("Good", "Bad"),
    c(Good = "Good label", Bad = "Bad label"),
    c(Good = "#111111", Bad = "#222222")
  )
  swatch <- result[[1]][[1]]
  expect_equal(swatch$name, "span")
  expect_match(swatch$attribs$style, "background-color:#111111;", fixed = TRUE)

  swatch2 <- result[[2]][[1]]
  expect_match(swatch2$attribs$style, "background-color:#222222;", fixed = TRUE)
})

test_that("band_choice_names() embeds the label text for each level", {
  result <- band_choice_names(
    c("Good", "Bad"),
    c(Good = "Good label", Bad = "Bad label"),
    c(Good = "#111111", Bad = "#222222")
  )
  label <- result[[1]][[2]]
  expect_equal(label$name, "span")
  expect_equal(label$children[[1]], "Good label")

  label2 <- result[[2]][[2]]
  expect_equal(label2$children[[1]], "Bad label")
})

test_that("band_choice_names() works with the real rsf_band level/label/color sets", {
  result <- band_choice_names(rsf_band_levels, rsf_band_labels, rsf_band_colors)
  expect_length(result, length(rsf_band_levels))
  labels_found <- vapply(result, function(x) x[[2]]$children[[1]], character(1))
  expect_equal(labels_found, unname(rsf_band_labels[rsf_band_levels]))
})

test_that("band_choice_names() works with the real rank_tier level/label/color sets", {
  result <- band_choice_names(rank_tier_levels, rank_tier_labels, rank_tier_colors)
  expect_length(result, length(rank_tier_levels))
  labels_found <- vapply(result, function(x) x[[2]]$children[[1]], character(1))
  expect_equal(labels_found, unname(rank_tier_labels[rank_tier_levels]))
})

test_that("band_choice_names() returns an empty list for an empty levels vector", {
  result <- band_choice_names(character(0), character(0), character(0))
  expect_length(result, 0)
})

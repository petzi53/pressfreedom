test_that("iso3_to_flag_code() resolves standard codes via countrycode", {
  expect_equal(iso3_to_flag_code("USA"), "us")
  expect_equal(iso3_to_flag_code("DEU"), "de")
  expect_equal(iso3_to_flag_code("FRA"), "fr")
})

test_that("iso3_to_flag_code() applies manual overrides", {
  expect_equal(iso3_to_flag_code("XKX"), "xk")
  expect_equal(iso3_to_flag_code("XKO"), "xk")
  expect_equal(iso3_to_flag_code("USA1"), "us")
  expect_equal(iso3_to_flag_code("USA2"), "us")
  expect_equal(iso3_to_flag_code("USA_I"), "us")
})

test_that("iso3_to_flag_code() returns NA for codes with no sensible flag", {
  expect_true(is.na(iso3_to_flag_code("CTU")))
  expect_true(is.na(iso3_to_flag_code("CSS")))
  expect_true(is.na(iso3_to_flag_code("XCD")))
  expect_true(is.na(iso3_to_flag_code("ISR1")))
  expect_true(is.na(iso3_to_flag_code("YUG")))
  expect_true(is.na(iso3_to_flag_code("SCG")))
})

test_that("iso3_to_flag_code() returns NA for unresolvable/unknown codes", {
  expect_true(is.na(iso3_to_flag_code("ZZZ")))
})

test_that("iso3_to_flag_code() is vectorized and preserves order/length", {
  result <- iso3_to_flag_code(c("USA", "XKX", "CTU", "DEU"))
  expect_equal(result, c("us", "xk", NA_character_, "de"))
  expect_length(result, 4)
})

## Independently rebuild the expected regional-indicator emoji for a 2-letter
## code, rather than reusing flag_emoji()'s own arithmetic.
regional_indicator_emoji <- function(cc) {
  chars <- strsplit(toupper(cc), "")[[1]]
  paste0(
    intToUtf8(utf8ToInt(chars[1]) - utf8ToInt("A") + 0x1F1E6),
    intToUtf8(utf8ToInt(chars[2]) - utf8ToInt("A") + 0x1F1E6)
  )
}

test_that("flag_emoji() builds the correct regional-indicator emoji", {
  expect_equal(flag_emoji("USA"), regional_indicator_emoji("us"))
  expect_equal(flag_emoji("DEU"), regional_indicator_emoji("de"))
  expect_equal(flag_emoji("XKX"), regional_indicator_emoji("xk"))
})

test_that("flag_emoji() falls back to '' when no sensible flag exists", {
  expect_equal(flag_emoji("CTU"), "")
  expect_equal(flag_emoji("YUG"), "")
})

test_that("flag_emoji() falls back to '' for unresolvable codes", {
  expect_equal(flag_emoji("ZZZ"), "")
})

test_that("flag_emoji() is vectorized and preserves order/length", {
  result <- flag_emoji(c("USA", "CTU", "DEU"))
  expect_equal(result, c(regional_indicator_emoji("us"), "", regional_indicator_emoji("de")))
  expect_length(result, 3)
})

test_that("flag_img_tag() builds an <img> tag pointing at the right flag file", {
  tag <- flag_img_tag("USA")
  expect_s3_class(tag, "shiny.tag")
  expect_equal(tag$name, "img")
  expect_equal(tag$attribs$src, "flags/us.png")
})

test_that("flag_img_tag() defaults alt text to the iso3 argument", {
  tag <- flag_img_tag("USA")
  expect_equal(tag$attribs$alt, "USA")
})

test_that("flag_img_tag() supports a custom alt and height", {
  tag <- flag_img_tag("USA", alt = "United States", height = "2em")
  expect_equal(tag$attribs$alt, "United States")
  expect_match(tag$attribs$style, "height: 2em;")
})

test_that("flag_img_tag() returns NULL when no sensible flag exists", {
  expect_null(flag_img_tag("CTU"))
  expect_null(flag_img_tag("YUG"))
})

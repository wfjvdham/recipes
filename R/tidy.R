#' Tidy the Result of a Recipe
#'
#' `tidy` will return a data frame that contains information
#'  regarding a recipe or operation within the recipe (when a `tidy`
#'  method for the operation exists).
#'
#' @name tidy.recipe
#'
#' @param x A `recipe` object (trained or otherwise).
#' @param number An integer or `NA`. If missing and `id` is not provided,
#'  the return value is a list of the operations in the recipe.
#'  If a number is  given, a `tidy` method is executed for that operation
#'  in the recipe (if it exists). `number` must not be provided if
#'  `id` is.
#' @param id A character string or `NA`. If missing and `number` is not provided,
#'  the return value is a list of the operations in the recipe.
#'  If a character string is given, a `tidy` method is executed for that
#'  operation in the recipe (if it exists). `id` must not be provided
#'  if `number` is.
#' @param ... Not currently used.
#' @return A tibble with columns that would vary depending on what
#'  `tidy` method is executed. When `number` and `id` are `NA`, a
#'  tibble with columns `number` (the operation iteration),
#'  `operation` (either "step" or "check"),
#'  `type` (the method, e.g. "nzv", "center"), a logical
#'  column called `trained` for whether the operation has been
#'  estimated using `prep`, a logical for `skip`, and a character column `id`.
#'
#' @examples
#' library(modeldata)
#' data(okc)
#'
#' okc_rec <- recipe(~ ., data = okc) %>%
#'   step_other(all_nominal(), threshold = 0.05, other = "another") %>%
#'   step_date(date, features = "dow") %>%
#'   step_center(all_numeric()) %>%
#'   step_dummy(all_nominal()) %>%
#'   check_cols(starts_with("date"), age, height)
#'
#' tidy(okc_rec)
#'
#' tidy(okc_rec, number = 2)
#' tidy(okc_rec, number = 3)
#'
#' okc_rec_trained <- prep(okc_rec, training = okc)
#'
#' tidy(okc_rec_trained)
#' tidy(okc_rec_trained, number = 3)
NULL

#' @rdname tidy.recipe
#' @export
tidy.recipe <- function(x, number = NA, id = NA, ...) {
  # add id = NA as default. If both ID & number are non-NA, error.
  # If number is NA and ID is not, select the step with the corresponding
  # ID. Only a single ID is allowed, as this follows the convention for number
  num_oper <- length(x$steps)
  if (num_oper == 0)
    rlang::abort("No steps in recipe.")
  pattern <- "(^step_)|(^check_)"
  if (!is.na(id)) {
    if (!is.na(number))
      rlang::abort("You may specify `number` or `id`, but not both.")
    if (length(id) != 1L && !is.character(id))
      rlang::abort("If `id` is provided, it must be a length 1 character vector.")
    step_ids <- vapply(x$steps, function(x) x$id, character(1))
    if(!(id %in% step_ids)) {
      rlang::abort("Supplied `id` not found in the recipe.")
    }
    number <- which(id == step_ids)
  }
  if (is.na(number)) {
    skipped <- vapply(x$steps, function(x) x$skip, logical(1))
    ids <- vapply(x$steps, function(x) x$id, character(1))

    oper_classes <- lapply(x$steps, class)
    oper_classes <- grep("_", unlist(oper_classes), value = TRUE)

    oper <- strsplit(oper_classes, split = "_")
    oper <- vapply(oper, function(x) x[1], character(1))

    oper_types <- gsub(pattern, "", oper_classes)
    is_trained <- vapply(x$steps,
                         function(x) x$trained,
                         logical(1))
    res <- tibble(number = seq_along(x$steps),
                  operation = oper,
                  type = oper_types,
                  trained = is_trained,
                  skip = skipped,
                  id = ids)
  } else {
    if (number > num_oper || length(number) > 1)
      rlang::abort(
        paste0(
          "`number` should be a single value between 1 and ",
           num_oper,
          "."
          )
      )

    res <- tidy(x$steps[[number]], ...)
  }
  res
}

#' @rdname tidy.recipe
#' @export
tidy.step <- function(x, ...) {
  rlang::abort(
    paste0(
      "No `tidy` method for a step with classes: ",
      paste0(class(x), collapse = ", ")
    )
  )
}

#' @rdname tidy.recipe
#' @export
tidy.check <- function(x, ...) {
  rlang::abort(
    paste0(
       "No `tidy` method for a check with classes: ",
       paste0(class(x), collapse = ", ")
    )
  )
}

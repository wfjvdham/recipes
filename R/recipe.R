#' Create a Recipe for Preprocessing Data
#'
#' A recipe is a description of what steps should be applied to a data set in
#'   order to get it ready for data analysis.
#'
#' @aliases recipe recipe.default recipe.formula
#' @author Max Kuhn
#' @keywords datagen
#' @concept preprocessing
#' @concept model_specification
#' @export
recipe <- function(x, ...)
  UseMethod("recipe")

#' @rdname recipe
#' @export
recipe.default <- function(x, ...)
  rlang::abort("`x` should be a data frame, matrix, or tibble")

#' @rdname recipe
#' @param vars A character string of column names corresponding to variables
#'   that will be used in any context (see below)
#' @param roles A character string (the same length of `vars`) that
#'   describes a single role that the variable will take. This value could be
#'   anything but common roles are `"outcome"`, `"predictor"`,
#'   `"case_weight"`, or `"ID"`
#' @param ... Further arguments passed to or from other methods (not currently
#'   used).
#' @param formula A model formula. No in-line functions should be used here
#'  (e.g. `log(x)`, `x:y`, etc.) and minus signs are not allowed. These types of
#'  transformations should be enacted using `step` functions in this package.
#'  Dots are allowed as are simple multivariate outcome terms (i.e. no need for
#'  `cbind`; see Examples).
#' @param x,data A data frame or tibble of the *template* data set
#'   (see below).
#' @return An object of class `recipe` with sub-objects:
#'   \item{var_info}{A tibble containing information about the original data
#'   set columns}
#'   \item{term_info}{A tibble that contains the current set of terms in the
#'   data set. This initially defaults to the same data contained in
#'   `var_info`.}
#'   \item{steps}{A list of `step`  or `check` objects that define the sequence of
#'   preprocessing operations that will be applied to data. The default value is
#'   `NULL`}
#'   \item{template}{A tibble of the data. This is initialized to be the same
#'   as the data given in the `data` argument but can be different after
#'   the recipe is trained.}
#'
#' @details Recipes are alternative methods for creating design matrices and
#'   for preprocessing data.
#'
#' Variables in recipes can have any type of *role* in subsequent analyses
#'   such as: outcome, predictor, case weights, stratification variables, etc.
#'
#' `recipe` objects can be created in several ways. If the analysis only
#'   contains outcomes and predictors, the simplest way to create one is to use
#'   a simple formula (e.g. `y ~ x1 + x2`) that does not contain inline
#'   functions such as `log(x3)`. An example is given below.
#'
#' Alternatively, a `recipe` object can be created by first specifying
#'   which variables in a data set should be used and then sequentially
#'   defining their roles (see the last example).
#'
#' There are two different types of operations that can be
#'  sequentially added to a recipe. **Steps**  can include common
#'  operations like logging a variable, creating dummy variables or
#'  interactions and so on. More computationally complex actions
#'  such as dimension reduction or imputation can also be specified.
#'  **Checks** are operations that conduct specific tests of the
#'  data. When the test is satisfied, the data are returned without
#'  issue or modification. Otherwise, any error is thrown.
#'
#' Once a recipe has been defined, the [prep()] function can be
#'  used to estimate quantities required for the operations using a
#'  data set (a.k.a. the training data). [prep()] returns another
#'  recipe.
#'
#' To apply the recipe to a data set, the [bake()] function is
#'   used in the same manner as `predict` would be for models. This
#'   applies the steps to any data set.
#'
#' Note that the data passed to `recipe` need not be the complete data
#'   that will be used to train the steps (by [prep()]). The recipe
#'   only needs to know the names and types of data that will be used. For
#'   large data sets, `head` could be used to pass the recipe a smaller
#'   data set to save time and memory.
#'
#' @export
#' @examples
#'
#' ###############################################
#' # simple example:
#' library(modeldata)
#' data(biomass)
#'
#' # split data
#' biomass_tr <- biomass[biomass$dataset == "Training",]
#' biomass_te <- biomass[biomass$dataset == "Testing",]
#'
#' # When only predictors and outcomes, a simplified formula can be used.
#' rec <- recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur,
#'               data = biomass_tr)
#'
#' # Now add preprocessing steps to the recipe.
#'
#' sp_signed <- rec %>%
#'   step_normalize(all_predictors()) %>%
#'   step_spatialsign(all_predictors())
#' sp_signed
#'
#' # now estimate required parameters
#' sp_signed_trained <- prep(sp_signed, training = biomass_tr)
#' sp_signed_trained
#'
#' # apply the preprocessing to a data set
#' test_set_values <- bake(sp_signed_trained, new_data = biomass_te)
#'
#' # or use pipes for the entire workflow:
#' rec <- biomass_tr %>%
#'   recipe(HHV ~ carbon + hydrogen + oxygen + nitrogen + sulfur) %>%
#'   step_normalize(all_predictors()) %>%
#'   step_spatialsign(all_predictors())
#'
#' ###############################################
#' # multivariate example
#'
#' # no need for `cbind(carbon, hydrogen)` for left-hand side
#' multi_y <- recipe(carbon + hydrogen ~ oxygen + nitrogen + sulfur,
#'                   data = biomass_tr)
#' multi_y <- multi_y %>%
#'   step_center(all_outcomes()) %>%
#'   step_scale(all_predictors())
#'
#' multi_y_trained <- prep(multi_y, training = biomass_tr)
#'
#' results <- bake(multi_y_trained, biomass_te)
#'
#' ###############################################
#' # Creating a recipe manually with different roles
#'
#' rec <- recipe(biomass_tr) %>%
#'   update_role(carbon, hydrogen, oxygen, nitrogen, sulfur,
#'            new_role = "predictor") %>%
#'   update_role(HHV, new_role = "outcome") %>%
#'   update_role(sample, new_role = "id variable") %>%
#'   update_role(dataset, new_role = "splitting indicator")
#' rec
recipe.data.frame <-
  function(x,
           formula = NULL,
           ...,
           vars = NULL,
           roles = NULL) {

    if (!is.null(formula)) {
      if (!is.null(vars))
        rlang::abort(
          paste0("This `vars` specification will be ignored ",
             "when a formula is used"
             )
          )
      if (!is.null(roles))
        rlang::abort(
          paste0("This `roles` specification will be ignored ",
             "when a formula is used"
             )
          )

      obj <- recipe.formula(formula, x, ...)
      return(obj)
    }

    if (is.null(vars))
      vars <- colnames(x)

    if (!is_tibble(x))
      x <- as_tibble(x)

    if (any(table(vars) > 1))
      rlang::abort("`vars` should have unique members")
    if (any(!(vars %in% colnames(x))))
      rlang::abort("1+ elements of `vars` are not in `x`")

    x <- x[, vars]

    var_info <- tibble(variable = vars)

    ## Check and add roles when available
    if (!is.null(roles)) {
      if (length(roles) != length(vars))
        rlang::abort(
          paste0("The number of roles should be the same as the number of ",
             "variables")
        )
      var_info$role <- roles
    } else
      var_info$role <- NA

    ## Add types
    var_info <- full_join(get_types(x), var_info, by = "variable")
    var_info$source <- "original"

    ## Return final object of class `recipe`
    out <- list(
      var_info = var_info,
      term_info = var_info,
      steps = NULL,
      template = x,
      levels = NULL,
      retained = NA
    )
    class(out) <- "recipe"
    out
  }

#' @rdname recipe
#' @export
recipe.formula <- function(formula, data, ...) {
  # check for minus:
  f_funcs <- fun_calls(formula)
  if (any(f_funcs == "-")) {
    rlang::abort("`-` is not allowed in a recipe formula. Use `step_rm()` instead.")
  }

  # Check for other in-line functions
  args <- form2args(formula, data, ...)
  obj <- recipe.data.frame(
    x = args$x,
    formula = NULL,
    ...,
    vars = args$vars,
    roles = args$roles
  )
  obj
}

#' @rdname recipe
#' @export
recipe.matrix <- function(x, ...) {
  x <- as.data.frame(x)
  recipe.data.frame(x, ...)
}

form2args <- function(formula, data, ...) {
  if (!is_formula(formula))
    formula <- as.formula(formula)
  ## check for in-line formulas
  element_check(formula, allowed = NULL)

  if (!is_tibble(data))
    data <- as_tibble(data)

  ## use rlang to get both sides of the formula
  outcomes <- get_lhs_vars(formula, data)
  predictors <- get_rhs_vars(formula, data, no_lhs = TRUE)

  ## if . was used on the rhs, subtract out the outcomes
  predictors <- predictors[!(predictors %in% outcomes)]

  ## get `vars` from lhs and rhs of formula
  vars <- c(predictors, outcomes)

  ## subset data columns
  data <- data[, vars]

  ## derive roles
  roles <- rep("predictor", length(predictors))
  if (length(outcomes) > 0)
    roles <- c(roles, rep("outcome", length(outcomes)))

  ## pass to recipe.default with vars and roles

  list(x = data, vars = vars, roles = roles)
}


#' @aliases prep prep.recipe
#' @param x an object
#' @param ... further arguments passed to or from other methods (not currently
#'   used).
#' @author Max Kuhn
#' @keywords datagen
#' @concept preprocessing
#' @concept model_specification
#' @export
prep   <- function(x, ...)
  UseMethod("prep")

#' Train a Data Recipe
#'
#' For a recipe with at least one preprocessing operation, estimate the required
#'   parameters from a training set that can be later applied to other data
#'   sets.
#' @param training A data frame or tibble that will be used to estimate
#'   parameters for preprocessing.
#' @param fresh A logical indicating whether already trained operation should be
#'   re-trained. If `TRUE`, you should pass in a data set to the argument
#'   `training`.
#' @param verbose A logical that controls whether progress is reported as operations
#'   are executed.
#' @param log_changes A logical for printing a summary for each step regarding
#'  which (if any) columns were added or removed during training.
#' @param retain A logical: should the *preprocessed* training set be saved
#'   into the `template` slot of the recipe after training? This is a good
#'     idea if you want to add more steps later but want to avoid re-training
#'     the existing steps. Also, it is advisable to use `retain = TRUE`
#'     if any steps use the option `skip = FALSE`. **Note** that this can make
#'     the final recipe size large. When `verbose = TRUE`, a message is written
#'     with the approximate object size in memory but may be an underestimate
#'     since it does not take environments into account.
#' @param strings_as_factors A logical: should character columns be converted to
#'   factors? This affects the preprocessed training set (when
#'   `retain = TRUE`) as well as the results of `bake.recipe`.
#' @return A recipe whose step objects have been updated with the required
#'   quantities (e.g. parameter estimates, model objects, etc). Also, the
#'   `term_info` object is likely to be modified as the operations are
#'   executed.
#' @details Given a data set, this function estimates the required quantities
#'   and statistics required by any operations.
#'
#' [prep()] returns an updated recipe with the estimates.
#'
#' Note that missing data handling is handled in the steps; there is no global
#'   `na.rm` option at the recipe-level or in [prep()].
#'
#' Also, if a recipe has been trained using [prep()] and then steps
#'   are added, [prep()] will only update the new operations. If
#'   `fresh = TRUE`, all of the operations will be (re)estimated.
#'
#' As the steps are executed, the `training` set is updated. For example,
#'   if the first step is to center the data and the second is to scale the
#'   data, the step for scaling is given the centered data.
#'
#'
#' @examples
#' data(ames, package = "modeldata")
#'
#' library(dplyr)
#'
#' ames <- mutate(ames, Sale_Price = log10(Sale_Price))
#'
#' ames_rec <-
#'   recipe(
#'     Sale_Price ~ Longitude + Latitude + Neighborhood + Year_Built + Central_Air,
#'     data = ames
#'   ) %>%
#'   step_other(Neighborhood, threshold = 0.05) %>%
#'   step_dummy(all_nominal()) %>%
#'   step_interact(~ starts_with("Central_Air"):Year_Built) %>%
#'   step_ns(Longitude, Latitude, deg_free = 5)
#'
#' prep(ames_rec, verbose = TRUE)
#'
#' prep(ames_rec, log_changes = TRUE)
#' @rdname prep
#' @export
prep.recipe <-
  function(x,
           training = NULL,
           fresh = FALSE,
           verbose = FALSE,
           retain = TRUE,
           log_changes = FALSE,
           strings_as_factors = TRUE,
           ...) {

    training <- check_training_set(training, x, fresh)

    tr_data <- train_info(training)

    # Record the original levels for later checking
    orig_lvls <- lapply(training, get_levels)

    if (strings_as_factors) {
      lvls <- lapply(training, get_levels)
      training <- strings2factors(training, lvls)
    } else {
      lvls <- NULL
    }

    # The only way to get the results for skipped steps is to
    # use `retain = TRUE` so issue a warning if this is not the case
    skippers <- map_lgl(x$steps, is_skipable)
    if (any(skippers) & !retain)
      rlang::warn(
        paste0(
          "Since some operations have `skip = TRUE`, using ",
          "`retain = TRUE` will allow those steps results to ",
          "be accessible."
        )
      )


    running_info <- x$term_info %>% mutate(number = 0, skip = FALSE)
    for (i in seq(along.with = x$steps)) {
      needs_tuning <- map_lgl(x$steps[[i]], is_tune)
      if (any(needs_tuning)) {
        arg <- names(needs_tuning)[needs_tuning]
        arg <- paste0("'", arg, "'", collapse = ", ")
        msg <-
          paste0(
            "You cannot `prep()` a tuneable recipe. Argument(s) with `tune()`: ",
            arg,
            ". Do you want to use a tuning function such as `tune_grid()`?"
          )
        rlang::abort(msg)
      }
      note <- paste("oper",  i, gsub("_", " ", class(x$steps[[i]])[1]))
      if (!x$steps[[i]]$trained | fresh) {

        if (verbose) {
          cat(note, "[training]", "\n")
        }

        before_nms <- names(training)

        # Compute anything needed for the preprocessing steps
        # then apply it to the current training set
        x$steps[[i]] <-
          prep(x$steps[[i]],
               training = training,
               info = x$term_info)
        training <- bake(x$steps[[i]], new_data = training)
        x$term_info <-
          merge_term_info(get_types(training), x$term_info)

        # Update the roles and the term source
        if (!is.na(x$steps[[i]]$role)) {
          new_vars <- setdiff(x$term_info$variable, running_info$variable)
          pos_new_var <- x$term_info$variable %in% new_vars
          pos_new_and_na_role <- pos_new_var & is.na(x$term_info$role)
          pos_new_and_na_source <- pos_new_var  & is.na(x$term_info$source)

          x$term_info$role[pos_new_and_na_role] <- x$steps[[i]]$role
          x$term_info$source[pos_new_and_na_source] <- "derived"

        }

        changelog(log_changes, before_nms, names(training), x$steps[[i]])

        running_info <- rbind(
          running_info,
          mutate(x$term_info, number = i, skip = x$steps[[i]]$skip)
        )

      }
      else {
        if (verbose) cat(note, "[pre-trained]\n")
      }
    }

    ## The steps may have changed the data so reassess the levels
    if (strings_as_factors) {
      lvls <- lapply(training, get_levels)
      check_lvls <- has_lvls(lvls)
      if (!any(check_lvls)) lvls <- NULL
    } else lvls <- NULL

    if (retain) {
      if (verbose)
        cat("The retained training set is ~",
            format(object.size(training), units = "Mb", digits = 2),
            " in memory.\n\n")

      x$template <- training
    }

    x$tr_info <- tr_data
    x$levels <- lvls
    x$orig_lvls <- orig_lvls
    x$retained <- retain
    # In case a variable was removed, and that removal step used
    # `skip = TRUE`, we need to retain its record so that
    # selectors can be properly used with `bake`. This tibble
    # captures every variable originally in the data or that was
    # created along the way. `number` will be the last step where
    # that variable was available.
    x$last_term_info <-
      running_info %>%
      group_by(variable) %>%
      arrange(desc(number)) %>%
      slice(1)
    x
  }

# For columns that should be retained (based on the selectors used in `bake()`
# or `bake(new_data = NULL)`), match those to the existing columns in the data.
#
# Some details:
#  1. When running `bake(new_data = NULL)`, the resulting columns should be
#  consistent with the variables in `term_info$variables`. If selectors are
#  used, the final columns that are returned should be a subset of those.
#  2. `term_info$variables` is consistent with a recipe when _no_ steps are
#  skipped.
#  3. If a step is skipped, its effect is only seen in `bake()` when a data
#  frame is given to `new_data`. Also, if a
#  step is skipped, the columns names that should be returned are possibly
#  inconsistent with what is in `term_info$variables`. The results might be that
#  there are more/less/different columns between `bake()` and `bake(new_data = NULL)`.
#
# `final_vars()` follows this logic:
#
#  - During `bake(new_data = NULL)` it determines which of the selected columns
#    are consistent with `term_info$variables` and returns them.
#  - During `bake()`, the selected columns are subsetted with the names of the
#    processed data.
#
# The column ordering is non-trivial. The approach here is to order the data
# consistent with `term_info$variables` and to add other variables at the
# end of the tibble. This seems reasonable but might lead to unexpected (but
# consistent) results.
#
# Consider a recipe for the `mtcars` data with a single step:
#     `step_rm(cyl, skip = TRUE)`
# is used. For `bake(new_data = NULL)`, only ten columns are returned. However,
# when `bake()` is run on the recipe with new data, it should return all eleven.
# When `bake()` is run, `cyl` is not included in `term_info$variables` so this
# column would come at the end (instead of as the second column as it is in
# `mtcars`).

final_vars <- function(nms, vars, trms, baking) {
  # In case there are multiple roles for a column:
  trms <- trms[!duplicated(trms$variable), ]

  if (baking) {
    possible <- nms[nms %in% vars]
  } else {
    possible <- trms$variable[trms$variable %in% vars]
  }
  possible <- possible[!is.na(possible)]
  possible <- possible[!duplicated(possible)]
  possible <-
    tibble::tibble(variable = possible, .order_2 = seq_along(possible))
  trms$.order_1 <- 1:nrow(trms)
  both <-
    dplyr::left_join(possible, trms, by = "variable") %>%
    dplyr::arrange(.order_1, .order_2)
  both$variable
}

#' @rdname bake
#' @aliases bake bake.recipe
#' @author Max Kuhn
#' @keywords datagen
#' @concept preprocessing
#' @concept model_specification
#' @export
bake <- function(object, ...)
  UseMethod("bake")

#' Apply a Trained Data Recipe
#'
#' For a recipe with at least one preprocessing operation that has been trained by
#'   [prep.recipe()], apply the computations to new data.
#' @param object A trained object such as a [recipe()] with at least
#'   one preprocessing operation.
#' @param new_data A data frame or tibble for whom the preprocessing will be
#'   applied. If `NULL` is given to `new_data`, the pre-processed _training
#'   data_ will be returned (assuming that `prep(retain = TRUE)` was used).
#' @param ... One or more selector functions to choose which variables will be
#'   returned by the function. See [selections()] for more details.
#'   If no selectors are given, the default is to use
#'   [everything()].
#' @param composition Either "tibble", "matrix", "data.frame", or
#'  "dgCMatrix" for the format of the processed data set. Note that
#'  all computations during the baking process are done in a
#'  non-sparse format. Also, note that this argument should be
#'  called **after** any selectors and the selectors should only
#'  resolve to numeric columns (otherwise an error is thrown).
#' @return A tibble, matrix, or sparse matrix that may have different
#'  columns than the original columns in `new_data`.
#' @details [bake()] takes a trained recipe and applies the
#'   operations to a data set to create a design matrix.
#'
#' If the data set is not too large, time can be saved by using the
#'  `retain = TRUE` option of [prep()]. This stores the processed version of the
#'  training set. With this option set, `bake(object, new_data = NULL)`
#'  will return it for free.
#'
#' Also, any steps with `skip = TRUE` will not be applied to the
#'   data when `bake()` is invoked with a data set in `new_data`.
#'   `bake(object, new_data = NULL)` will always have all of the steps applied.
#' @seealso [recipe()], [prep()]
#' @rdname bake
#' @examples
#' data(ames, package = "modeldata")
#'
#' ames <- mutate(ames, Sale_Price = log10(Sale_Price))
#'
#' ames_rec <-
#'   recipe(Sale_Price ~ ., data = ames[-(1:6), ]) %>%
#'   step_other(Neighborhood, threshold = 0.05) %>%
#'   step_dummy(all_nominal()) %>%
#'   step_interact(~ starts_with("Central_Air"):Year_Built) %>%
#'   step_ns(Longitude, Latitude, deg_free = 2) %>%
#'   step_zv(all_predictors()) %>%
#'   prep()
#'
#' # return the training set (already embedded in ames_rec)
#' ames_train <- bake(ames_rec, new_data = NULL)
#'
#' # apply processing to other data:
#' ames_new <- bake(ames_rec, new_data = head(ames))
#' @export
bake.recipe <- function(object, new_data, ..., composition = "tibble") {
  if (rlang::is_missing(new_data)) {
    rlang::abort("'new_data' must be either a data frame or NULL. No value is not allowed.")
  }
  if (is.null(new_data)) {
    return(juice(object, ..., composition = composition))
  }

  if (!fully_trained(object)) {
    rlang::abort("At least one step has not been trained. Please run `prep`.")
  }

  if (!any(composition == formats)) {
    rlang::abort(
      paste0(
      "`composition` should be one of: ",
      paste0("'", formats, "'", collapse = ",")
      )
    )
  }

  terms <- quos(...)
  if (is_empty(terms)) {
    terms <- quos(everything())
  }

  # In case someone used the deprecated `newdata`:
  if (is.null(new_data) || is.null(ncol(new_data))) {
    if (any(names(terms) == "newdata")) {
      rlang::abort("Please use `new_data` instead of `newdata` with `bake`.")
    } else {
      rlang::abort("Please pass a data set to `new_data`.")
    }
  }

  if (!is_tibble(new_data)) {
    new_data <- as_tibble(new_data)
  }

  check_nominal_type(new_data, object$orig_lvls)

  # Determine return variables. The context (ie. `info`) can
  # change depending on whether a skip step was used. If so, we
  # use an alternate info tibble that has all possible terms
  # in it.
  has_skip <- vapply(object$steps, function(x) x$skip, logical(1))

  if (any(has_skip)) {
    keepers <-
      terms_select(terms = terms,
                   info = object$last_term_info,
                   empty_fun = passover)
  } else {
    keepers <-
      terms_select(terms = terms,
                   info = object$term_info,
                   empty_fun = passover)
  }

  if (length(keepers) > 0) {
    for (i in seq(along.with = object$steps)) {
      if (!is_skipable(object$steps[[i]])) {
        new_data <- bake(object$steps[[i]], new_data = new_data)
        if (!is_tibble(new_data))
          new_data <- as_tibble(new_data)
      }
    }
    vars <- final_vars(names(new_data), keepers, object$term_info, baking = TRUE)
    new_data <- new_data[, vars]

    ## The levels are not null when no nominal data are present or
    ## if strings_as_factors = FALSE in `prep`
    if (!is.null(object$levels)) {
      var_levels <- object$levels
      var_levels <- var_levels[keepers]
      check_values <-
        vapply(var_levels, function(x)
          (!all(is.na(x))), c(all = TRUE))
      var_levels <- var_levels[check_values]
      if (length(var_levels) > 0)
        new_data <- strings2factors(new_data, var_levels)
    }
  } else {
    new_data <- tibble(.rows = nrow(new_data))
  }

  if (composition == "dgCMatrix") {
    new_data <- convert_matrix(new_data, sparse = TRUE)
  } else if (composition == "matrix") {
    new_data <- convert_matrix(new_data, sparse = FALSE)
  } else if (composition == "data.frame") {
    new_data <- base::as.data.frame(new_data)
  }

  new_data
}

#' Print a Recipe
#'
#' @aliases print.recipe
#' @param x A `recipe` object
#' @param form_width The number of characters used to print the variables or
#'   terms in a formula
#' @param ... further arguments passed to or from other methods (not currently
#'   used).
#' @return The original object (invisibly)
#'
#' @author Max Kuhn
#' @export
print.recipe <- function(x, form_width = 30, ...) {
  cat("Data Recipe\n\n")
  cat("Inputs:\n\n")
  no_role <- is.na(x$var_info$role)
  if (any(!no_role)) {
    tab <- as.data.frame(table(x$var_info$role))
    colnames(tab) <- c("role", "#variables")
    print(tab, row.names = FALSE)
    if (any(no_role)) {
      cat("\n ", sum(no_role), "variables with undeclared roles\n")
    }
  } else {
    cat(" ", nrow(x$var_info), "variables (no declared roles)\n")
  }
  if ("tr_info" %in% names(x)) {
    nmiss <- x$tr_info$nrows - x$tr_info$ncomplete
    cat("\nTraining data contained ",
        x$tr_info$nrows,
        " data points and ",
        sep = "")
    if (x$tr_info$nrows == x$tr_info$ncomplete)
      cat("no missing data.\n")
    else
      cat(nmiss,
          "incomplete",
          ifelse(nmiss > 1, "rows.", "row."),
          "\n")
  }
  if (!is.null(x$steps)) {
    cat("\nOperations:\n\n")
    for (i in seq_along(x$steps))
      print(x$steps[[i]], form_width = form_width)
  }
  invisible(x)
}

#' Summarize a Recipe
#'
#' This function prints the current set of variables/features and some of their
#' characteristics.
#' @aliases summary.recipe
#' @param object A `recipe` object
#' @param original A logical: show the current set of variables or the original
#'   set when the recipe was defined.
#' @param ... further arguments passed to or from other methods (not currently
#'   used).
#' @return A tibble with columns `variable`, `type`, `role`,
#'   and `source`.
#' @details
#' Note that, until the recipe has been trained,
#' the current and original variables are the same.
#'
#' It is possible for variables to have multiple roles by adding them with
#' [add_role()]. If a variable has multiple roles, it will have more than one
#' row in the summary tibble.
#'
#' @examples
#' rec <- recipe( ~ ., data = USArrests)
#' summary(rec)
#' rec <- step_pca(rec, all_numeric(), num = 3)
#' summary(rec) # still the same since not yet trained
#' rec <- prep(rec, training = USArrests)
#' summary(rec)
#' @export
#' @seealso [recipe()] [prep.recipe()]
summary.recipe <- function(object, original = FALSE, ...) {
  if (original)
    object$var_info
  else
    object$term_info
}


#' Extract Finalized Training Set
#'
#' As of `recipes` version 0.1.14, **`juice()` is superseded** in favor of
#' `bake(object, new_data = NULL)`.
#'
#' As steps are estimated by `prep`, these operations are
#'  applied to the training set. Rather than running `bake()`
#'  to duplicate this processing, this function will return
#'  variables from the processed training set.
#' @inheritParams bake.recipe
#' @param object A `recipe` object that has been prepared
#'   with the option `retain = TRUE`.
#' @details When preparing a recipe, if the training data set is
#'  retained using `retain = TRUE`, there is no need to `bake()` the
#'  recipe to get the preprocessed training set.
#'
#'  `juice()` will return the results of a recipe where _all steps_
#'  have been applied to the data, irrespective of the value of
#'  the step's `skip` argument.
#' @export
#' @seealso [recipe()] [prep.recipe()] [bake.recipe()]
juice <- function(object, ..., composition = "tibble") {
  if (!fully_trained(object)) {
    rlang::abort("At least one step has not been trained. Please run `prep()`.")
  }

  if (!isTRUE(object$retained)) {
    rlang::abort(
      paste0("Use `retain = TRUE` in `prep()` to be able ",
             "to extract the training set"
             )
    )
  }

  if (!any(composition == formats)) {
    rlang::abort(
      paste0("`composition` should be one of: ",
         paste0("'", formats, "'", collapse = ",")
         )
      )
  }

  terms <- quos(...)
  if (is_empty(terms)) {
    terms <- quos(everything())
  }
  keepers <-
    terms_select(terms = terms,
                 info = object$term_info,
                 empty_fun = passover)

  if (length(keepers) > 0) {
    vars <- final_vars(names(object$template), keepers, object$term_info, baking = FALSE)
    new_data <- object$template[, vars]

    ## Since most models require factors, do the conversion from character
    if (!is.null(object$levels)) {
      var_levels <- object$levels
      var_levels <- var_levels[keepers]
      check_values <-
        vapply(var_levels, function(x)
          (!all(is.na(x))), c(all = TRUE))
      var_levels <- var_levels[check_values]
      if (length(var_levels) > 0)
        new_data <- strings2factors(new_data, var_levels)
    }


  } else {
    new_data <- tibble(.rows = nrow(object$template))
  }

  if (composition == "dgCMatrix") {
    new_data <- convert_matrix(new_data, sparse = TRUE)
  } else if (composition == "matrix") {
    new_data <- convert_matrix(new_data, sparse = FALSE)
  } else if (composition == "data.frame") {
    new_data <- base::as.data.frame(new_data)
  }

  new_data
}

formats <- c("tibble", "dgCMatrix", "matrix", "data.frame")

utils::globalVariables(c("number"))

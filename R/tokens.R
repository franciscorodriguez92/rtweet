#' Fetching Twitter authorization token(s).
#'
#' Call function used to fetch and load Twitter OAuth tokens.
#' Since Twitter application key should be stored privately, users should save
#' the path to token(s) as an environment variable. This allows Tokens
#' to be instantly [re]loaded in future sessions. See the "tokens"
#' vignette for instructions on obtaining and using access tokens.
#'
#' @return Twitter OAuth token(s) (Token1.0).
#' @details This function will search for tokens using R, internal,
#'   and global environment variables (in that order).
#' @examples
#'
#' \dontrun{
#' ## fetch default token(s)
#' token <- get_tokens()
#'
#' ## print token
#' token
#'
#' }
#'
#' @family tokens
#' @export
get_tokens <- function() {
  if (all(is.null(.state$twitter_tokens),
    !is.null(.state$twitter_token))) {
    .state$twitter_tokens <- .state$twitter_token
  }
  if (is.null(.state$twitter_tokens)) {
    .state$twitter_tokens <- load_tokens(twitter_pat())
  }
  if (is.null(.state$twitter_tokens)) {
    .state$twitter_tokens <- rtweet_token()
  }
  .state$twitter_tokens
}

#' @export
#' @rdname get_tokens
get_token <- function() get_tokens()

#' Creating Twitter authorization token(s).
#'
#' @description Sends request to generate OAuth 1.0 tokens. Twitter
#'   also allows users to create user-only (OAuth 2.0) access token.
#'   Unlike the 1.0 tokens, OAuth 2.0 tokens are not at all centered
#'   on a host user. Which means these tokens cannot be used to send
#'   information (follow requests, Twitter statuses, etc.).  If you
#'   have no interest in those capabilities, then 2.0 OAuth tokens do
#'   offer some higher rate limits. At the current time, the
#'   difference given the functions in this package is trivial, so I
#'   have yet to verified OAuth 2.0 token method.  Consequently, I
#'   encourage you to use 1.0 tokens.
#' @param app Name of user created Twitter application
#' @param consumer_key Application API key
#' @param consumer_secret Application API secret User-owned
#'   application must have \code{Read and write} access level and
#'   \code{Callback URL} of \code{http://127.0.0.1:1410}.
#' @param access_token Access token as supplied by Twitter (apps.twitter.com)
#' @param access_secret Access secret as supplied by Twitter (apps.twitter.com)
#' @param set_renv Logical indicating whether to save the created token
#'   as the default environment twitter token variable. Defaults to TRUE,
#'   meaning the token is saved to user's home directory as
#'   ".rtweet_token.rds" (or, if that already exists, then
#'   .rtweet_token1.rds or .rtweet_token2.rds, etc.) and the path to the
#'   token to said token is then set in the user's .Renviron file and re-
#'   read to start being used in current active session.
#' @seealso
#'   \url{https://developer.twitter.com/en/docs/basics/authentication/overview/oauth}
#'
#' @return Twitter OAuth token(s) (Token1.0).
#' @importFrom httr oauth_app oauth1.0_token oauth_endpoints
#' @family tokens
#' @export
create_token <- function(app = "mytwitterapp",
                         consumer_key,
                         consumer_secret,
                         access_token = NULL,
                         access_secret = NULL,
                         set_renv = TRUE) {
  create_token_(app, consumer_key, consumer_secret, access_token,
    access_secret, set_renv)
}

create_token_ <- function(app = "mytwitterapp",
                          consumer_key,
                          consumer_secret,
                          access_token = NULL,
                          access_secret = NULL,
                          set_renv = TRUE) {
  ## validate app name
  stopifnot(is.character(app))
  ## validate consumer key
  stopifnot(is.character(consumer_key), length(consumer_key) == 1L)
  consumer_key <- gsub("\\s+", "", consumer_key)
  if (grepl("[^[:alnum:]]", consumer_key)) {
    stop("consumer key must be alpha numeric (e.g., a98ds0879fa", call. = FALSE)
  }
  ## validate consumer secret
  stopifnot(is.character(consumer_secret), length(consumer_secret) == 1L)
  consumer_secret <- gsub("\\s+", "", consumer_secret)
  if (grepl("[^[:alnum:]]", consumer_secret)) {
    stop("consumer_secret must be alpha numeric (e.g., a98ds087", call. = FALSE)
  }
  ## create app object
  app <- httr::oauth_app(
    appname = app,
    key = consumer_key,
    secret = consumer_secret
  )
  ## if access token/secret use sign method otherwise browser
  if (!is.null(access_token) && !is.null(access_secret)) {
    stopifnot(is.character(access_token), is.character(access_secret))
    credentials <- list(oauth_token = access_token,
      oauth_token_secret = access_secret)
    params <- list(as_header = TRUE)
    token <- httr::Token1.0$new(app = app,
      endpoint = httr::oauth_endpoints("twitter"),
      params = params, credentials = credentials, cache = FALSE)
  } else {
    token <- httr::oauth1.0_token(
      httr::oauth_endpoints("twitter"), app, cache = FALSE)
  }
  ## save token and set as environment variable
  if (set_renv) {
    pathtotoken <- uq_filename(file.path(home(), ".rtweet_token.rds"))
    saveRDS(token, file = pathtotoken, compress = FALSE)
    set_renv("TWITTER_PAT" = pathtotoken)
  }
  ## return token
  token
}


has_ext <- function(x) {
  stopifnot(length(x) == 1L)
  x <- basename(x)
  grepl("[[:alnum:]]{1,}\\.[[:alpha:]]{1,}$", x)
}

only_ext <- function(x) {
  if (has_ext(x)) {
    gsub(".*(?=\\.)", "", x, perl = TRUE)
  } else {
    ""
  }
}

no_ext <- function(x) {
  if (has_ext(x)) {
    gsub("(?<=[[:alnum:]]{1})\\..*(?!=\\.)", "", x, perl = TRUE)
  } else {
    x
  }
}

paste_before_ext <- function(x, p) {
  paste0(no_ext(x), p, only_ext(x))
}


uq_filename <- function(file_name) {
  stopifnot(is.character(file_name) && length(file_name) == 1L)
  if (file.exists(file_name)) {
    files <- list.files(dirname(file_name), all.files = TRUE, full.names = TRUE)
    file_name <- paste_before_ext(file_name, 1:1000)
    file_name <- file_name[!file_name %in% files][1]
  }
  file_name
}


is.token <- function(x) {
  if (length(x) == 0) return(FALSE)
  if (inherits(x, "bearer")) return(TRUE)
  ## if it doesn't have request endpoint return FALSE
  if (!"endpoint" %in% names(x) || !"request" %in% names(x$endpoint)) {
    return(FALSE)
  }
  ## check if inherits token class and uses a twitter api endpoint
  any(c("token", "token1.0") %in% tolower(class(x))) &&
    (any(grepl("api.twitter", x[['endpoint']][['request']], ignore.case = TRUE)) ||
        (is.null(x[['endpoint']][['request']]) &&
            !is.null(x[['credentials']][['oauth_token']])))
}

rate_limit_used <- function(x) {
  x$used <- x$limit - x$remaining
  x <- x[, c("query", "limit", "remaining", "used", "reset", "reset_at")]
  x[order(x$used, decreasing = TRUE), ]
}


check_token <- function(token) {
  if (is.null(token)) {
    token <- get_tokens()
  } else if (inherits(token, "bearer")) {
    return(token)
  }
  ## if valid token, then return
  if (is.token(token)) {
    return(token)
  }
  ## if list then extract first
  if (is.list(token)) {
    token <- token[[1]]
  }
  ## if class OAuth, use values to create token
  if (identical(class(token), "OAuth")) {
    token <- create_token(
      sample(letters, 8),
      token$consumerKey,
      token$consumerSecret)
  }
  ## final check
  if (!is.token(token)) {
    stop("Not a valid access token.", call. = FALSE)
  }
  token
}


is_ttoken <- function(x) {
  if (is.token(x)) return(TRUE)
  if (is.list(x) && is.token(x[[1]])) return(TRUE)
  FALSE
}

is_tokenfile <- function(x) {
  if (is_ttoken(x)) return(TRUE)
  if (!file.exists(x)) return(FALSE)
  if (identical(x, ".httr-oauth") || if_rds(x)) {
    token <- readRDS(x)
    if (is_ttoken(token)) return(TRUE)
  }
  ## if it can be read/loaded
  if (if_load(x)) {
    ## load in new environment and then get it
    e <- new.env()
    load(x, envir = e)
    token <- ls(envir = e, all.names = TRUE)
    if (length(token) > 0) {
      token <- get(x, envir = e)
      if (is_ttoken(token)) return(TRUE)
    }
  }
  ## else look for .*token.* in GlobalEnv
  if (any(grepl("token",
    ls(envir = .GlobalEnv), ignore.case = TRUE))) {
    token <- global_token_finder()
    if (is_ttoken(token)) return(TRUE)
  }
  FALSE
}

twitter_pat <- function() {
  pat <- Sys.getenv("TWITTER_PAT")
  if (identical(pat, "")) {
    if (file.exists(".httr-oauth") && is_tokenfile(".httr-oauth")) {
      pat <- ".httr-oauth"
    } else if (file.exists("twitter_tokens") && is_tokenfile("twitter_tokens")) {
      pat <- "twitter_tokens"
    } else if (file.exists("twitter_token") && is_tokenfile("twitter_token")) {
      pat <- "twitter_token"
    } else if (file.exists("tokens") && is_tokenfile("tokens")) {
      pat <- "tokens"
    } else if (file.exists("token") && is_tokenfile("token")) {
      pat <- "token"
    } else {
      stop("API user token required. see http://rtweet.info/articles/auth.html for instructions", call. = FALSE)
    }
  }
  pat
}

if_load <- function(x) {
  lgl <- FALSE
  lgl <- suppressWarnings(
    tryCatch(load(x),
      error = function(e) return(NULL)))
  if (is.null(lgl) || length(lgl) == 0L) return(FALSE)
  if (identical(lgl, FALSE)) return(FALSE)
  TRUE
}

if_rds <- function(x) {
  lgl <- FALSE
  lgl <- suppressWarnings(
    tryCatch(readRDS(x),
      error = function(e) return(NULL)))
  if (is.null(lgl) || length(lgl) == 0L) return(FALSE)
  if (identical(lgl, FALSE)) return(FALSE)
  TRUE
}

global_token_finder <- function(env = globalenv()) {
  x <- NULL
  objs <- ls(envir = env)
  if ("twitter_tokens" %in% objs) {
    x <- get_tokens_global("twitter_tokens")
  } else if ("twitter_token" %in% objs) {
    x <- get_tokens_global("twitter_token")
  } else if ("tokens" %in% objs) {
    x <- get_tokens_global("tokens")
  } else if ("token" %in% objs) {
    x <- get_tokens_global("token")
  } else if (any(grepl("token", objs, ignore.case = TRUE))) {
    tkn <- grep("token", objs, ignore.case = TRUE, value = TRUE)
    if (identical(length(tkn), 1L)) {
      x <- get_tokens_global(tkn)
    } else if ("twitter_tokens" %in% tolower(tkn)) {
      x <- get_tokens_global(tkn[tolower(tkn) == "twitter_tokens"])
    } else if ("twitter_token" %in% tolower(tkn)) {
      x <- get_tokens_global(tkn[tolower(tkn) == "twitter_tokens"])
    } else if ("tokens" %in% tolower(tkn)) {
      x <- get_tokens_global(tkn[tolower(tkn) == "tokens"])
    } else if ("token" %in% tolower(tkn)) {
      x <- get_tokens_global(tkn[tolower(tkn) == "token"])
    }
  }
  x
}

get_tokens_global <- function(x, env = globalenv()) {
  if (is.character(x)) {
    eval(parse(text = x), envir = env)
  } else {
    eval(x, envir = env)
  }
}

load_tokens <- function(pat, env = globalenv()) {
  pat <- strsplit(pat, "\\,|\\;")[[1]]
  x <- Map("load_tokens_", pat = pat, MoreArgs = list(env = env))
  if (is.list(x) && length(x) == 1L) {
    x <- x[[1]]
  }
  .state$twitter_tokens <- x
  .state$twitter_tokens
}

load_tokens_ <- function(pat, env = globalenv()) {
  if (identical(pat, ".httr-oauth")) {
    readRDS(pat)
  } else if (identical(pat, "system")) {
    set_renv(TWITTER_PAT = NULL)
    stop("API user token required. see http://rtweet.info/articles/auth.html for instructions", call. = FALSE)
  } else if (if_load(pat)) {
    x <- load(pat)
    get(x)
  } else if (if_rds(pat)) {
    readRDS(pat)
  } else if (any(grepl("token",
    ls(envir = env), ignore.case = TRUE))) {
    global_token_finder()
  } else {
    rtweet_token()
  }
}

## home user
home_user <- function() {
  eval(call("home_user_"))
}

home_user_ <- function() {
  if (!exists(".state")) {
    .state <- new.env()
  }
  if (exists(".user", envir = .state)) {
    return(get(".user", envir = .state))
  }
  user <- Sys.getenv("TWITTER_SCREEN_NAME")
  if (!identical(user, "")) {
    assign(".user", user, envir = .state)
    return(user)
  }
  ## ask user for screen name
  user <- readline("What is your screen name on Twitter?")
  ## remove at sign
  user <- gsub("@", "", user)
  ## save as environment variable
  message("Saving your Twitter screen name as environment variable")
  cat(
    paste0("TWITTER_SCREEN_NAME=", user),
    fill = TRUE,
    file = file.path(normalizePath("~"), ".Renviron"),
    append = TRUE
  )
  ## store in pkg environment
  assign(".user", user, envir = .state)
  ## return screen name
  invisible(user)
}


## validate user token
validate_token <- function() {
  token <- tryCatch(get_tokens(), error = function(e) NULL)
  if (is.list(token) && inherits(token[[1]], "Token")) {
    token <- token[[1]]
  }
  if (is.null(token) || !inherits(token, "Token")) {
    stop(paste0(
      "Could not find token. Please save path to token associated with @",
      home_user(), "'s account as the \"TWITTER_PAT\" environment variable."),
      call. = FALSE)
  }
  token_user <- token[["credentials"]][["screen_name"]]
  if (!identical(home_user(), token_user)) {
    stop(paste0(
      "Invalid token. This token belongs to @",
      token_user, " and not @", home_user(), ".\n",
      "Please save path to token associated with @", home_user(),
      "'s account as the \"TWITTER_PAT\" environment variable."),
      call. = FALSE)
  }
  TRUE
}


rtweet_token <- function() {
  if (exists(".rtweet_token") &&
        exists("token", envir = get(".rtweet_token"))) {
    token <- get("token", envir = get(".rtweet_token"))
  } else {
    stop("API user token required. see http://rtweet.info/articles/auth.html for instructions", call. = FALSE)
  }
  if (identical(Sys.getenv("TWITTER_PAT"), "")) {
    pathtotoken <- uq_filename(file.path(home(), ".rtweet_token.rds"))
    saveRDS(token, file = pathtotoken)
    set_renv("TWITTER_PAT" = pathtotoken)
  }
  token
}

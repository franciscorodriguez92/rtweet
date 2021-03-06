% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/friends.R
\name{lookup_friendships}
\alias{lookup_friendships}
\title{Lookup friendship information between two specified users.}
\usage{
lookup_friendships(source, target, parse = TRUE, token = NULL)
}
\arguments{
\item{source}{Screen name or user id of source user.}

\item{target}{Screen name or user id of target user.}

\item{parse}{Logical indicating whether to return parsed data frame.
Defaults to true.}

\item{token}{OAuth token. By default \code{token = NULL} fetches a
non-exhausted token from an environment variable. Find instructions
on how to create tokens and setup an environment variable in the
tokens vignette (in r, send \code{?tokens} to console).}
}
\value{
Data frame converted form returned JSON object. If parse is
  not true, the HTTP response object is returned instead.
}
\description{
Gets information on friendship between two Twitter users.
}
\seealso{
Other friends: \code{\link{my_friendships}}
}
\concept{friends}

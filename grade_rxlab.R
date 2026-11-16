# Pull RxLab submissions from Supabase and check them against an answer key.
#
#   Sys.setenv(RXLAB_SUPABASE_URL = "https://<project>.supabase.co",
#              RXLAB_SUPABASE_SERVICE_KEY = "<secret key>")   # better: put both in .Renviron
#   source("grade_rxlab.R")
#   x <- rxlab_grade(key = CASE_KEY, since = "2027-01-15")
#
# Writes submissions/rxlab_<today>.csv: one row per save. A student who corrects and
# re-saves the same Rx appears twice; `latest` marks the last save.
# Needs the httr and jsonlite packages. Never put the secret key in RxLab.html.

# One row per product_id (the id in RxLab's PRODUCTS list). `offset` = days between the
# date written on the prescription and the day students fill it (0 = written today).
# The example uses the practice products that ship with RxLab; replace with your cases.
CASE_KEY <- data.frame(
  product_id     = c("x_hydrocortisone_oint", "x_omeprazole_susp"),
  offset         = c(0, 2),
  key_qty        = c(30, 150),
  key_unit       = c("g", "mL"),
  key_refills    = c(1, 0),
  key_prescriber = c("Bell", "Ortiz"),   # matched as a substring of the prescriber name
  stringsAsFactors = FALSE
)

# Optional roster CSV with columns name,email. Students enter themselves as the patient,
# and this is how a save made under a classmate's sign-in is caught.
roster_name <- function(email, roster = NULL) {
  guess <- gsub("[._]", " ", sub("@.*$", "", email))
  if (is.null(roster) || !file.exists(roster)) return(guess)
  ros <- read.csv(roster, stringsAsFactors = FALSE)
  hit <- ros$name[match(tolower(trimws(email)), tolower(trimws(ros$email)))]
  ifelse(is.na(hit), guess, hit)
}

rxlab_grade <- function(key = CASE_KEY, since = NULL, roster = NULL,
                        tz = "America/Chicago", out_dir = "submissions") {
  url <- Sys.getenv("RXLAB_SUPABASE_URL")
  sk  <- Sys.getenv("RXLAB_SUPABASE_SERVICE_KEY")
  stopifnot(nzchar(url), nzchar(sk))

  q <- "select=*&order=received_at.asc"
  if (!is.null(since)) q <- paste0(q, "&received_at=gte.", since)
  r <- httr::GET(paste0(url, "/rest/v1/rxlab_submissions?", q),
                 httr::add_headers(apikey = sk, Authorization = paste("Bearer", sk)))
  httr::stop_for_status(r)
  raw <- jsonlite::fromJSON(httr::content(r, "text", encoding = "UTF-8"), simplifyVector = FALSE)
  if (!length(raw)) { message("No submissions."); return(invisible(data.frame())) }

  g <- function(x, f) { v <- x[[f]]; if (is.null(v)) NA_character_ else as.character(v) }
  x <- do.call(rbind, lapply(raw, function(s) {
    rec <- s$payload$record
    data.frame(
      received_at = s$received_at, student_email = s$student_email,
      student_name = g(s, "student_name"), product_id = g(s, "product_id"), rx_number = g(s, "rx_number"),
      patient = trimws(paste(g(rec, "ptFirst"), g(rec, "ptLast"))), prescriber = g(rec, "drName"),
      drug = trimws(paste(g(rec, "drug"), g(rec, "strength"))),
      rx_written = g(rec, "rxWritten"), rx_filled = g(rec, "rxFilled"), rx_expires = g(rec, "rxExpires"),
      sig = g(rec, "sig"), qty = g(rec, "qty"), unit = g(rec, "qtyUnit"), refills = g(rec, "refills"),
      discard_after = g(rec, "bud"), lot = g(rec, "lot"), rph = g(rec, "rph"),
      label_text = g(s$payload, "label_text"), stringsAsFactors = FALSE)
  }))

  ts <- as.POSIXct(sub("(\\.\\d+)?([+-]\\d\\d:\\d\\d|Z)$", "", x$received_at), format = "%Y-%m-%dT%H:%M:%S", tz = "UTC")
  x$submitted_local <- format(ts, tz = tz, usetz = TRUE)
  sub_day <- as.Date(format(ts, tz = tz))

  x <- merge(cbind(x, sub_day = sub_day), key, by = "product_id", all.x = TRUE, sort = FALSE)
  exp_written <- x$sub_day - x$offset
  exp_expires <- as.Date(sapply(exp_written, function(d) if (is.na(d)) NA else seq(d, by = "1 year", length.out = 2)[2]),
                         origin = "1970-01-01")
  x$expected_written <- as.character(exp_written)
  x$expected_expires <- as.character(exp_expires)
  x$ok_written    <- x$rx_written == x$expected_written
  x$ok_expires    <- x$rx_expires == x$expected_expires
  x$ok_refills    <- suppressWarnings(as.numeric(x$refills)) == x$key_refills
  x$ok_qty        <- suppressWarnings(as.numeric(x$qty)) == x$key_qty & tolower(x$unit) == tolower(x$key_unit)
  x$ok_prescriber <- mapply(function(p, k) !is.na(k) && grepl(k, p, ignore.case = TRUE), x$prescriber, x$key_prescriber)
  x$student_name  <- ifelse(is.na(x$student_name) | !nzchar(x$student_name), roster_name(x$student_email, roster), x$student_name)
  norm <- function(s) gsub("[^a-z]", "", tolower(s))
  x$ok_patient    <- norm(x$patient) == norm(x$student_name)
  x$has_discard   <- !is.na(x$discard_after) & nzchar(x$discard_after)
  x$has_lot       <- !is.na(x$lot) & nzchar(x$lot)
  x$case_known    <- !is.na(x$offset)

  x <- x[order(x$student_email, x$product_id, x$received_at), ]
  x$latest <- !duplicated(paste(x$student_email, x$product_id), fromLast = TRUE)

  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  out <- file.path(out_dir, sprintf("rxlab_%s.csv", Sys.Date()))
  write.csv(x[, setdiff(names(x), c("offset", "received_at", "sub_day"))], out, row.names = FALSE, na = "")
  message(sprintf("%d submissions from %d students -> %s", nrow(x), length(unique(x$student_email)), out))
  invisible(x)
}

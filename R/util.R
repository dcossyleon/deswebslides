#' @import stats utils

createUniqueId <- function(bytes) {
  paste(as.hexmode(sample(256, bytes) - 1), collapse = "")
}

is_windows <- function() {
  identical(.Platform$OS.type, "windows")
}

is_osx <- function() {
  Sys.info()["sysname"] == "Darwin"
}

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

# determine the output file for a pandoc conversion
pandoc_output_file <- function(input, pandoc_options) {
  to <- strsplit(pandoc_options$to, "[+-]")[[1]][[1]]
  ext <- pandoc_output_ext(pandoc_options$ext, to, input)
  output <- paste0(tools::file_path_sans_ext(input), ext)
  basename(output)
}

pandoc_output_ext <- function(ext, to, input) {
  if (!is.null(ext)) return(ext)
  if (to %in% c("latex", "beamer")) return(".pdf")
  if (to %in% c("html", "html4", "html5", "s5", "slidy", "slideous", "dzslides", "revealjs"))
    return(".html")
  if (to == "markdown" && tolower(tools::file_ext(input)) != "md") return(".md")
  paste0(".", to)
}

pkg_file <- function(...) {
  system.file(..., package = "deswebslides")
}

pkg_file_arg <- function(...) {
  pandoc_path_arg(pkg_file(...))
}

#' @rdname rmarkdown_format
#' @export
from_rmarkdown <- function(implicit_figures = TRUE, extensions = NULL) {

  # paste extensions together and remove whitespace
  extensions <- paste0(extensions, collapse = "")
  extensions <- gsub(" ", "", extensions)

  # exclude implicit figures unless the user has added them back
  if (!implicit_figures && !grepl("implicit_figures", extensions))
    extensions <- paste0("-implicit_figures", extensions)

  rmarkdown_format(extensions)
}

is_null_or_string <- function(text) {
  is.null(text) || (is.character(text) && (length(text) == 1))
}

read_utf8 <- function(file) {
  if (inherits(file, 'connection')) con <- file else {
    con <- base::file(file, encoding = 'UTF-8'); on.exit(close(con), add = TRUE)
  }
  enc2utf8(readLines(con, warn = FALSE))
}

write_utf8 <- function(text, con, ...) {
  opts <- options(encoding = "native.enc"); on.exit(options(opts), add = TRUE)
  writeLines(enc2utf8(text), con, ..., useBytes = TRUE)
}

file_string <- function(path) one_string(read_utf8(path))

one_string <- function(x) paste(x, collapse = '\n')

# in a future version of yaml, it will disable the evaluation of !expr but we
# still need it (https://github.com/rstudio/rmarkdown/issues/1387)
yaml_load <- function(...) yaml::yaml.load(..., eval.expr = TRUE)

yaml_load_file <- function(input, ...) yaml_load(read_utf8(input), ...)

file_name_without_shell_chars <- function(file) {
  name <- gsub(.shell_chars_regex, '-', basename(file))
  dir <- dirname(file)
  if (nzchar(dir) && !identical(dir, "."))
    file.path(dir, name)
  else
    name
}

tmpfile_pattern <- "rmarkdown-str"

# return a string as a tempfile
as_tmpfile <- function(str) {
  if (length(str) == 0) return()
  f <- tempfile(tmpfile_pattern, fileext = ".html")
  write_utf8(str, f)
  f
}

# temp files created by as_tmpfile() cannot be immediately removed because they
# are needed later by the pandoc conversion; we have to clean up the temp files
# that have the pattern specified in `tmpfile_pattern` when render() exits
clean_tmpfiles <- function() {
  unlink(list.files(
    tempdir(), sprintf("^%s[0-9a-f]+[.]html$", tmpfile_pattern), full.names = TRUE
  ))
}

dir_exists <- function(x) {
  length(x) > 0 && utils::file_test('-d', x)
}

file_with_ext <- function(file, ext) {
  paste(tools::file_path_sans_ext(file), ".", ext, sep = "")
}


file_with_meta_ext <- function(file, meta_ext, ext = tools::file_ext(file)) {
  paste(tools::file_path_sans_ext(file),
        ".", meta_ext, ".", ext, sep = "")
}

knitr_files_dir <- function(file) {
  paste(tools::file_path_sans_ext(file), "_files", sep = "")
}

knitr_root_cache_dir <- function(file) {
  paste(tools::file_path_sans_ext(file), "_cache", sep = "")
}

knitr_cache_dir <- function(file, pandoc_to) {
  paste(tools::file_path_sans_ext(file), "_cache/", pandoc_to, "/", sep = "")
}

get_knitr_hook_list <- function(hook_names = NULL) {
  if (is.null(hook_names))
    hook_names <- c("knit_hooks", "opts_chunk", "opts_hooks", "opts_knit")
  knitr_ns <- asNamespace("knitr")
  hook_list <- lapply(hook_names, function(hook_name) {
    hooks <- get(hook_name, envir = knitr_ns, inherits = FALSE)
    hooks$get()
  })
  names(hook_list) <- hook_names
  hook_list
}

set_knitr_hook_list <- function(hook_list) {
  knitr_ns <- asNamespace("knitr")
  enumerate(hook_list, function(hook_name, hook_value) {
    hook <- get(hook_name, envir = knitr_ns, inherits = FALSE)
    hook$set(hook_value)
  })
}

highlighters <- function() {
  c("default",
    "tango",
    "pygments",
    "kate",
    "monochrome",
    "espresso",
    "zenburn",
    "haddock",
    "breezedark")
}

merge_lists <- function(base_list, overlay_list, recursive = TRUE) {
  if (length(base_list) == 0)
    overlay_list
  else if (length(overlay_list) == 0)
    base_list
  else {
    merged_list <- base_list
    for (name in names(overlay_list)) {
      base <- base_list[[name]]
      overlay <- overlay_list[[name]]
      if (is.list(base) && is.list(overlay) && recursive)
        merged_list[[name]] <- merge_lists(base, overlay)
      else {
        merged_list[[name]] <- NULL
        merged_list <- append(merged_list,
                              overlay_list[which(names(overlay_list) %in% name)])
      }
    }
    merged_list
  }
}

strip_white <- function(x) {
  if (!length(x))
    return(x)
  while (is_blank(x[1])) {
    x = x[-1]
    if (!length(x))
      return(x)
  }
  while (is_blank(x[(n <- length(x))])) {
    x = x[-n]
    if (n < 2)
      return(x)
  }
  x
}

is_blank <- function(x) {
  if (length(x))
    all(grepl("^\\s*$", x))
  else TRUE
}

trim_trailing_ws <- function(x) {
  sub("\\s+$", "", x)
}


# Find common base directory, throw error if it doesn't exist
base_dir <- function(x) {
  base <- unique(dirname(x))
  if (length(base) > 1) {
    stop("Input files not all in same directory, please supply explicit wd",
         call. = FALSE)
  }
  base
}

move_dir <- function(from, to) {
  dir.create(dirname(to), showWarnings = FALSE)
  suppressWarnings(file.rename(from, to)) || {
    file.copy(from, dirname(to), recursive = TRUE) && unlink(from, recursive = TRUE)
  }
}

# Check if two paths are the same after being normalized
same_path <- function(path1, path2, ...) {
  if (length(path1) * length(path2) != 1)
    stop('The two paths must be both of length 1')
  normalize_path(path1, ...) == normalize_path(path2, ...)
}

# normalizePath() doesn't work if the path contains Unicode characters that
# cannot be represented in the current system locale, even if the file exists
abs_path <- function(x) {
  if (!file.exists(x)) stop("The file '", x, "' does not exist.")
  res <- normalize_path(x, mustWork = FALSE)
  if (file.exists(res)) return(res)
  if (!requireNamespace('fs', quietly = TRUE)) warning(
    'normalizePath() cannot make the path(s) absolute. The fs package is required.'
  )
  as.character(fs::path_abs(x))
}

# Regular expression representing characters likely to be considered special by
# the shell (require quoting/escaping)
.shell_chars_regex <- '[ <>()|\\:&;#?*\']'

# Find a program within the PATH. On OSX we need to explictly call
# /usr/bin/which with a forwarded PATH since OSX Yosemite strips
# the PATH from the environment of child processes
find_program <- function(program) {
  if (is_osx()) {
    res <- suppressWarnings({
      # Quote the path (so it can contain spaces, etc.) and escape any quotes
      # and escapes in the path itself
      sanitized_path <- gsub("\\", "\\\\", Sys.getenv("PATH"), fixed = TRUE)
      sanitized_path <- gsub("\"", "\\\"", sanitized_path, fixed = TRUE)
      system(paste0("PATH=\"", sanitized_path, "\" /usr/bin/which ", program),
             intern = TRUE)
    })
    if (length(res) == 0)
      ""
    else
      res
  } else {
    Sys.which(program)
  }
}

# given a string, escape the regex metacharacters it contains:
# regex metas are these,
#   . \ | ( ) [ { ^ $ * + ?
# as defined here:
#   http://stat.ethz.ch/R-manual/R-devel/library/base/html/regex.html
escape_regex_metas <- function(in_str) {
  gsub("([.\\|()[{^$+?])", "\\\\\\1", in_str)
}

latexmk <- function(file, engine, biblatex = FALSE) {
  tinytex::latexmk(file, engine, if (biblatex) 'biber' else 'bibtex')
}

n_bytes <- function(string) {
  nchar(string, type = "bytes")
}

starts_with_bytes <- function(string, bytes) {
  Encoding(string) <- Encoding(bytes) <- "bytes"
  if (n_bytes(bytes) > n_bytes(string))
    return(FALSE)
  substring(string, 1, n_bytes(bytes)) == bytes
}

ends_with_bytes <- function(string, bytes) {
  Encoding(string) <- Encoding(bytes) <- "bytes"
  if (n_bytes(bytes) > n_bytes(string))
    return(FALSE)
  substring(string, n_bytes(string) - n_bytes(bytes) + 1, n_bytes(string)) == bytes
}

base64_encode_object <- function(object) {
  object <- rapply(object, unclass, how = "list")
  json <- charToRaw(jsonlite::toJSON(object, auto_unbox = TRUE))
  base64enc::base64encode(json)
}

base64_decode_object <- function(encoded) {
  json <- rawToChar(base64enc::base64decode(encoded))
  jsonlite::fromJSON(json)
}

read_file <- function(path, binary = FALSE) {
  n <- file.info(path)$size
  if (binary) {
    readBin(path, raw(), n)
  } else {
    readChar(path, n, TRUE)
  }
}

surround <- function(string, with) {
  paste(with, string, with, sep = "")
}

to_html_attributes <- function(data, on_empty = "", prefix = " ") {

  if (inherits(data, "html"))
    return(data)

  if (!length(data))
    return(on_empty)

  # escape attribute contents
  escaped <- unlist(lapply(data, function(el) {
    htmltools::htmlEscape(join(as.character(el), collapse = " "), attribute = TRUE)
  }))

  # generate html attributes as string
  quoted <- surround(escaped, with = "\"")
  result <- join(names(data), quoted, sep = "=", collapse = " ")

  # add prefix if necessary
  if (nzchar(prefix))
    result <- join(prefix, result)

  # mark as html and return
  class(result) <- "html"
  result

}

to_css <- function(data, on_empty = "", prefix = "") {

  if (inherits(data, "html"))
    return(data)

  if (!length(data))
    return(on_empty)

  # collapse vectors in data list
  collapsed <- unlist(lapply(data, function(el) {
    join(el, collapse = " ")
  }))

  # paste into single string
  joined <- join(names(data), collapsed, sep = ": ", collapse = "; ")

  # add prefix
  if (nzchar(prefix))
    joined <- join(prefix, joined)

  # return with trailing semi-colon
  result <- join(joined, ";", sep = "")
  class(result) <- "html"
  result
}

rbind_list <- function(data) {
  result <- do.call(mapply, c(c, data, USE.NAMES = FALSE, SIMPLIFY = FALSE))
  names(result) <- names(data[[1]])
  as.data.frame(result, stringsAsFactors = FALSE)
}

enumerate <- function(data, f, ...) {
  lapply(seq_along(data), function(i) {
    f(names(data)[[i]], data[[i]], ...)
  })
}

insert <- function(vector, index, ...) {

  dots <- list(...)
  mode(dots) <- mode(vector)
  n <- length(vector)

  result <- if (index == 0) {
    c(dots, vector)
  } else if (index == n) {
    c(vector, dots)
  } else {
    c(vector[1:index], dots, vector[(index + 1):n])
  }

  result
}

replace_binding <- function(binding, package, override) {
  # override in namespace
  if (!requireNamespace(package, quietly = TRUE))
    stop(sprintf("Failed to load namespace for package '%s'", package))

  namespace <- asNamespace(package)

  # get reference to original binding
  original <- get(binding, envir = namespace)

  # replace the binding
  if (is.function(override))
    environment(override) <- namespace

  do.call("unlockBinding", list(binding, namespace))
  assign(binding, override, envir = namespace)
  do.call("lockBinding", list(binding, namespace))

  # if package is attached, override there as well
  search_name <- paste("package", package, sep = ":")
  if (search_name %in% search()) {
    env <- as.environment(search_name)
    do.call("unlockBinding", list(binding, env))
    assign(binding, override, envir = env)
    do.call("lockBinding", list(binding, env))
  }

  # return original
  original
}

join <- function(..., sep = "", collapse = "") {
  paste(..., sep = sep, collapse = collapse)
}

shell_exec <- function(cmd, intern = FALSE, wait = TRUE, ...) {
  if (Sys.info()[["sysname"]] == "Windows")
    shell(cmd, intern = intern, wait = wait, ...)
  else
    system(cmd, intern = intern, wait = wait, ...)
}

# Adjust the graphical device in chunk options: if the device from the output
# format is png but knitr's global chunk option is not png, respect knitr's
# option, because (1) users may knitr::opts_chunk$set(dev) (which usually means
# they know what they are doing) before rmarkdown::render(), and we probably
# should not override the user's choice; (2) the png device does not work on
# certain platforms (e.g. headless servers without X11), in which case knitr
# will set the device to svg instead of png by default in knitr:::set_html_dev,
# and rmarkdown should also respect this setting, otherwise we will run into
# issues like https://github.com/rstudio/rmarkdown/issues/1100
adjust_dev <- function(opts) {
  dev <- knitr::opts_chunk$get('dev')
  if (identical(opts$dev, 'png') && length(dev) == 1 && dev != 'png') {
    opts$dev <- dev
  }
  opts
}

xfun_session_info <- function() {
  paste('Pandoc version:', pandoc_version())
}

# given a path of a file in a potential R package, figure out the package root
package_root <- function(path) {
  dir <- dirname(path)
  if (same_path(dir, file.path(dir, '..'))) return()
  if (!file.exists(desc <- file.path(dir, 'DESCRIPTION')) ||
      length(grep('^Package: ', read_utf8(desc))) == 0) return(package_root(dir))
  dir
}


# retrieve package version without fear of error
# loading namespace is ok as these packages have been or will be used
get_package_version_string <- function(package) {
  tryCatch(
    as.character(getNamespaceVersion(package)),
    error = function(e) {
      NULL
    }
  )
}
# find all loaded packages.
# May contain extra packages, but will contain all packages used while knitting
get_loaded_packages <- function() {
  packages <- sort(loadedNamespaces())
  version <- vapply(packages, get_package_version_string, character(1))

  data.frame(
    packages = packages,
    version = version,
    row.names = NULL, stringsAsFactors = FALSE
  )
}

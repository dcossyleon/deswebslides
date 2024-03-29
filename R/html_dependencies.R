#' @importFrom htmltools htmlDependency copyDependencyToDir
#'   makeDependencyRelative renderDependencies tagList tags
#'   restorePreserveChunks extractPreserveChunks HTML
NULL

#' Provide common HTML dependencies for R Markdown formats
#'
#' These functions provide common HTML dependencies (e.g. jquery, bootstrap)
#' for re-use by other R Markdown formats.
#'
#' @inheritParams html_document
#' @name html-dependencies
NULL

# Create an HTML dependency for jQuery
#' @rdname html-dependencies
#' @export
html_dependency_jquery <- function()  {

  htmlDependency(
    name = "jquery",
    version = "1.11.3",
    src = pkg_file("rmd/h/jquery"),
    script = "jquery.min.js")
}

# Create an HTML dependency for jQuery UI
#' @rdname html-dependencies
#' @export
html_dependency_jqueryui <- function() {

  htmlDependency(
    name = "jqueryui",
    version = "1.11.4",
    src = pkg_file("rmd/h/jqueryui"),
    script = "jquery-ui.min.js")
}

# Create an HTML dependency for Bootstrap
#' @rdname html-dependencies
#' @export
html_dependency_bootstrap <- function(theme) {

  if (identical(theme, "default")) {
    theme <- "bootstrap"
  }

  htmlDependency(
    name = "bootstrap",
    version = "3.3.5",
    src = pkg_file("rmd/h/bootstrap"),
    meta = list(viewport = "width=device-width, initial-scale=1"),
    script = c(
      "js/bootstrap.min.js",
      # These shims are necessary for IE 8 compatibility
      "shim/html5shiv.min.js",
      "shim/respond.min.js"),
    stylesheet = paste0("css/", theme, ".min.css"))
}

# Create an HTML dependency for tocify
#' @rdname html-dependencies
#' @export
html_dependency_tocify <- function() {

  htmlDependency(
    name = "tocify",
    version = "1.9.1",
    src = pkg_file("rmd/h/tocify"),
    script = "jquery.tocify.js",
    stylesheet = "jquery.tocify.css")
}

# Create an HTML dependency for FontAwesome
#' @rdname html-dependencies
#' @export
html_dependency_font_awesome <- function() {

  htmlDependency(
    "font-awesome",
    "5.1.0",
    src = pkg_file("rmd/h/fontawesome"),
    stylesheet = c(
      "css/all.css",
      "css/v4-shims.css")
  )
}

# Create an HTML dependency for Ionicons
#' @rdname html-dependencies
#' @export
html_dependency_ionicons <- function() {

  htmlDependency(
    name = "ionicons",
    version = "2.0.1",
    src = pkg_file("rmd/h/ionicons"),
    stylesheet = "css/ionicons.min.css")
}

html_dependency_navigation <- function(code_menu, source_embed) {

  # dynamically build script list
  script <- c("tabsets.js")
  if (code_menu)
    script <- c(script, "codefolding.js")
  if (source_embed)
    script <- c(script, "sourceembed.js")

  htmlDependency(name = "navigation",
                 version = "1.1",
                 src = pkg_file("rmd/h/navigation-1.1"),
                 script = script)
}

# analyze navbar html source for icon dependencies
navbar_icon_dependencies <- function(navbar) {

  # read the navbar source
  source <- read_utf8(navbar)

  # find icon references
  res <- regexec('<(span|i) +class *= *("|\') *(fa fa|ion ion)-', source)
  matches <- regmatches(source, res)
  libs <- c()
  for (match in matches) {
    if (length(match) > 0)
      libs <- c(libs, match[[4]])
  }
  libs <- unique(libs)

  # return their dependencies
  html_dependencies_fonts("fa fa" %in% libs, "ion ion" %in% libs)
}

# utilty function to return a list of font dependencies based
# whether we are including font_awesome and/or iconicons
html_dependencies_fonts <- function(font_awesome, ionicons) {
  deps <- list()
  if (font_awesome)
    deps <- append(deps, list(html_dependency_font_awesome()))
  if (ionicons)
    deps <- append(deps, list(html_dependency_ionicons()))
  deps
}

# flattens an arbitrarily nested list and returns all of the dependency
# objects it contains
flatten_dependencies <- function(knit_meta, test) {

  all_dependencies <- list()

  # knit_meta is a list of 'meta' attributes returned from custom knit_print
  # functions. since the 'meta' attribute could either be an html dependency or
  # a list of dependencies we recurse on lists that aren't named
  for (dep in knit_meta) {
    if (is.null(names(dep)) && is.list(dep)) {
      inner_dependencies <- flatten_dependencies(dep, test)
      all_dependencies <- append(all_dependencies, inner_dependencies)
    } else if (test(dep)) {
      all_dependencies[[length(all_dependencies) + 1]] <- dep
    }
  }

  all_dependencies
}

flatten_html_dependencies <- function(knit_meta) {
  flatten_dependencies(knit_meta, is_html_dependency)
}

# consolidate dependencies (use latest versions and remove duplicates). this
# routine is the default implementation for version dependency resolution;
# formats may specify their own.
html_dependency_resolver <- function(all_dependencies) {

  dependencies <- htmltools::resolveDependencies(all_dependencies)

  # validate each surviving dependency
  dependencies <- lapply(dependencies, validate_html_dependency)

  # return the consolidated dependencies
  dependencies
}

html_reference_path <- function(path, lib_dir, output_dir) {
  # write the full OS-specific path if no library
  if (is.null(lib_dir))
    pandoc_path_arg(path)
  else
    relative_to(output_dir, path)
}

# return the html dependencies as an HTML string suitable for inclusion
# in the head of a document
html_dependencies_as_string <- function(dependencies, lib_dir, output_dir) {

  if (!is.null(lib_dir)) {
    dependencies <- lapply(dependencies, copyDependencyToDir, lib_dir)
    dependencies <- lapply(dependencies, makeDependencyRelative, output_dir)
  }
  return(renderDependencies(dependencies, "file", encodeFunc = identity,
                            hrefFilter = function(path) {
                              html_reference_path(path, lib_dir, output_dir)
                            })
  )
}

# check class of passed list for 'html_dependency'
is_html_dependency <- function(list) {
  inherits(list, "html_dependency")
}

# validate that the passed list is a correctly formed html_dependency
validate_html_dependency <- function(list) {

  # ensure it's the right class
  if (!is_html_dependency(list))
    stop("passed object is not of class html_dependency", call. = FALSE)

  # validate required fields
  if (is.null(list$name))
    stop("name for html_dependency not provided", call. = FALSE)
  if (is.null(list$version))
    stop("version for html_dependency not provided", call. = FALSE)
  list <- fix_html_dependency(list)
  if (is.null(list$src$file))
    stop("path for html_dependency not provided", call. = FALSE)
  file <- list$src$file
  if (!is.null(list$package))
    file <- system.file(file, package = list$package)
  if (!file.exists(file)) {
    utils::str(list)
    stop("path for html_dependency not found: ", file, call. = FALSE)
  }

  list
}

# monkey patch HTML dependencies; currently only supports highlight.js
fix_html_dependency <- function(list) {
  if (!identical(list$name, 'highlightjs') || !identical(list$version, '1.1'))
    return(list)
  if (!identical(list$src$file, '')) return(list)
  html_dependency_highlightjs(gsub('[.]css$', '', list$stylesheet))
}

# check if the passed knit_meta has any (e.g. html/latex) dependencies
has_dependencies <- function(knit_meta, class) {

  if (inherits(knit_meta, class))
    return(TRUE)

  if (is.list(knit_meta)) {
    for (dep in knit_meta) {
      if (is.null(names(dep))) {
        if (has_dependencies(dep, class))
          return(TRUE)
      } else {
        if (inherits(dep, class))
          return(TRUE)
      }
    }
  }
  FALSE
}

has_html_dependencies <- function(knit_meta) {
  has_dependencies(knit_meta, "html_dependency")
}

# create an html_dependency for pagedtable
#' @rdname html-dependencies
#' @export
html_dependency_pagedtable <- function() {
  htmlDependency(
    "pagedtable",
    version = "1.1",
    src = pkg_file("rmd/h/pagedtable-1.1"),
    script = "js/pagedtable.js",
    stylesheet = "css/pagedtable.css"
  )
}

#' @param highlight Highlighter to use
#' @rdname html-dependencies
#' @export
html_dependency_highlightjs <- function(highlight) {
  htmlDependency(
    "highlightjs",
    version = "9.12.0",
    src = pkg_file("rmd/h/highlightjs"),
    script = "highlight.js",
    stylesheet = paste0(highlight, ".css")
  )
}

# create an html_dependency for rsiframe
html_dependency_rsiframe <- function() {

  # add session port to meta if we have it (note that RStudio will
  # only provide this in desktop mode)
  meta <- NULL
  session_port <- Sys.getenv("RSTUDIO_SESSION_PORT")
  if (nzchar(session_port))
    meta <- list(rstudio_origin = paste0("127.0.0.1:", session_port))

  htmlDependency(
    "rstudio-iframe",
    version = "1.1",
    src = pkg_file("rmd/h/rsiframe-1.1"),
    script = "rsiframe.js",
    meta = meta
  )
}

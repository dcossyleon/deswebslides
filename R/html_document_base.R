#' Base output format for HTML-based output formats
#'
#' Creates an HTML base output format suitable for passing as the
#' \code{base_format} argument of the \code{\link{output_format}} function.
#'
#' @inheritParams html_document
#'
#' @param dependency_resolver A dependency resolver
#' @param copy_resources Copy resources
#' @param extra_dependencies Extra dependencies
#' @param bootstrap_compatible Bootstrap compatible
#' @param ... Ignored
#'
#' @return HTML base output format.
#'
#' @export
html_document_base <- function(smart = TRUE,
                               theme = NULL,
                               self_contained = TRUE,
                               lib_dir = NULL,
                               mathjax = "default",
                               pandoc_args = NULL,
                               template = "default",
                               dependency_resolver = NULL,
                               copy_resources = FALSE,
                               extra_dependencies = NULL,
                               bootstrap_compatible = FALSE,
                               ...) {

  # default for dependency_resovler
  if (is.null(dependency_resolver))
    dependency_resolver <- html_dependency_resolver

  args <- c()

  # smart quotes, etc.
  if (smart && !pandoc2.0())
    args <- c(args, "--smart")

  # no email obfuscation
  args <- c(args, "--email-obfuscation", "none")

  # self contained document
  if (self_contained) {
    if (copy_resources)
      stop("Local resource copying is incompatible with self-contained documents.")
    validate_self_contained(mathjax)
    args <- c(args, "--self-contained")
  }

  # custom args
  args <- c(args, pandoc_args)

  preserved_chunks <- character()

  output_dir <- ""

  # dummy pre_knit and post_knit functions so that merging of outputs works
  pre_knit <- function(input, ...) {}
  post_knit <- function(metadata, input_file, runtime, ...) {}

  # pre_processor
  pre_processor <- function(metadata, input_file, runtime, knit_meta,
                            files_dir, output_dir) {

    args <- c()

    # use files_dir as lib_dir if not explicitly specified
    if (is.null(lib_dir))
      lib_dir <<- files_dir

    # copy supplied output_dir (for use in post-processor)
    output_dir <<- output_dir

    # handle theme
    if (!is.null(theme)) {
      theme <- match.arg(theme, themes())
      if (identical(theme, "default"))
        theme <- "bootstrap"
      args <- c(args, "--variable", paste0("theme:", theme))
    }

    # resolve and inject extras, including dependencies specified by the format
    # and dependencies specified by the user (via extra_dependencies)
    format_deps <- list()
    if (!is.null(theme)) {
      format_deps <- append(format_deps, list(html_dependency_jquery(),
                                              html_dependency_bootstrap(theme)))
    }
    else if (isTRUE(bootstrap_compatible) && is_shiny(runtime)) {
      # If we can add bootstrap for Shiny, do it
      format_deps <- append(format_deps,
                            list(html_dependency_bootstrap("bootstrap")))
    }
    format_deps <- append(format_deps, extra_dependencies)

    extras <- html_extras_for_document(knit_meta, runtime, dependency_resolver,
                                       format_deps)
    args <- c(args, pandoc_html_extras_args(extras, self_contained, lib_dir,
                                            output_dir))

    # mathjax
    args <- c(args, pandoc_mathjax_args(mathjax,
                                        template,
                                        self_contained,
                                        lib_dir,
                                        output_dir))

    preserved_chunks <<- extract_preserve_chunks(input_file)

    # a lua filters added if pandoc2.0
    args <- c(args, pandoc_lua_filters(c("pagebreak.lua", "latex-div.lua")))

    args
  }

  intermediates_generator <- function(original_input, intermediates_dir) {
    # copy intermediates; skip web resources if not self contained (pandoc can
    # create references to web resources without the file present)
    copy_render_intermediates(original_input, intermediates_dir, !self_contained)
  }

  post_processor <- function(metadata, input_file, output_file, clean, verbose) {
    # if there are no preserved chunks to restore and no resource to copy then no
    # post-processing is necessary
    if (length(preserved_chunks) == 0 && !isTRUE(copy_resources) && self_contained)
      return(output_file)

    # read the output file
    output_str <- read_utf8(output_file)

    # if we preserved chunks, restore them
    if (length(preserved_chunks) > 0) {
      # Pandoc adds an empty <p></p> around the IDs of preserved chunks, and we
      # need to remove these empty tags, otherwise we may have invalid HTML like
      # <p><div>...</div></p>. For the reason of the second gsub(), see
      # https://github.com/rstudio/rmarkdown/issues/133.
      for (i in names(preserved_chunks)) {
        output_str <- gsub(paste0("<p>", i, "</p>"), i, output_str,
                           fixed = TRUE, useBytes = TRUE)
        output_str <- gsub(paste0(' id="[^"]*?', i, '[^"]*?" '), ' ', output_str,
                           useBytes = TRUE)
      }
      output_str <- restorePreserveChunks(output_str, preserved_chunks)
    }

    if (copy_resources) {
      # The copy_resources flag copies all the resources referenced in the
      # document to its supporting files directory, and rewrites the document to
      # use the copies from that directory.
      output_str <- copy_html_resources(one_string(output_str), lib_dir, output_dir)
    } else if (!self_contained) {
      # if we're not self-contained, find absolute references to the output
      # directory and replace them with relative ones
      image_relative <- function(img_src, src) {
        in_file <- utils::URLdecode(src)
        # do not process paths that are already relative
        if (grepl('^[.][.]', in_file)) return(img_src)
        if (length(in_file) && file.exists(in_file)) {
          img_src <- sub(
            src, utils::URLencode(normalized_relative_to(output_dir, in_file)),
            img_src, fixed = TRUE)
        }
        img_src
      }
      output_str <- process_images(output_str, image_relative)
    }

    write_utf8(output_str, output_file)
    output_file
  }

  output_format(
    knitr = NULL,
    pandoc = pandoc_options(to = "html", from = NULL, args = args),
    keep_md = FALSE,
    clean_supporting = FALSE,
    pre_knit = pre_knit,
    post_knit = post_knit,
    pre_processor = pre_processor,
    intermediates_generator = intermediates_generator,
    post_processor = post_processor
  )
}

extract_preserve_chunks <- function(input_file, extract = extractPreserveChunks) {
  input_str <- read_utf8(input_file)
  preserve <- extract(input_str)
  if (!identical(preserve$value, input_str)) write_utf8(preserve$value, input_file)
  preserve$chunks
}

# Published v1.0.0 identity and unreleased v1.2.0 are separate contracts.
# cff-version describes the citation format, never the software version.
validate_metadata <- function(root = ".") {
  root <- normalizePath(root, winslash = "/", mustWork = TRUE)
  for (package in c("yaml", "jsonlite", "digest")) {
    if (!requireNamespace(package, quietly = TRUE)) stop("Package required: ", package)
  }
  check <- function(ok, label) {
    if (!isTRUE(ok)) stop("Metadata validation failed: ", label, call. = FALSE)
  }
  required <- function(object, fields, label) {
    absent <- setdiff(fields, names(object))
    check(!length(absent), paste(label, "missing", paste(absent, collapse = ", ")))
  }
  repository <- "https://github.com/secdelic/tte-method-library"
  title <- "Target Trial Emulation Statistical Analysis Method Library"
  cff <- yaml::read_yaml(file.path(root, "CITATION.cff"))
  zenodo <- jsonlite::fromJSON(file.path(root, ".zenodo.json"), simplifyVector = FALSE)
  description <- read.dcf(file.path(root, "DESCRIPTION"))
  check(nrow(description) == 1L, "one DESCRIPTION record required")
  description <- as.list(description[1, ])
  version <- trimws(readLines(file.path(root, "VERSION"), warn = FALSE))
  check(length(version) == 1L && version %in% c("1.0.0", "1.2.0"), "unsupported software version")
  required(cff, c("cff-version", "message", "title", "type", "authors", "version",
                  "license", "keywords", "repository-code"), "CITATION.cff")
  required(zenodo, c("title", "creators", "description", "keywords", "license", "version",
                     "upload_type", "related_identifiers"), ".zenodo.json")
  required(description, c("Package", "Title", "Version", "Authors@R", "License"), "DESCRIPTION")
  check(identical(cff$`cff-version`, "1.2.0"), "CFF format version")
  check(identical(cff$type, "software") && identical(zenodo$upload_type, "software"), "software type")
  check(identical(description$Version, version) && identical(cff$version, version) &&
          identical(zenodo$version, version), "software versions disagree")
  check(identical(description$Package, "tteMethodLibrary") &&
          identical(description$Title, title) && identical(cff$title, title) &&
          identical(zenodo$title, title), "software title or package identity")
  check(identical(cff$license, "MIT") && identical(zenodo$license, "MIT") &&
          identical(description$License, "MIT + file LICENSE"), "MIT license identity")
  check(identical(readLines(file.path(root, "LICENSE"), n = 1L), "MIT License"), "LICENSE heading")
  check(identical(cff$`repository-code`, repository), "CFF repository identity")
  check(length(zenodo$related_identifiers) == 1L, "one Zenodo repository identifier required")
  related <- zenodo$related_identifiers[[1]]
  check(identical(related$identifier, repository) && identical(related$scheme, "url") &&
          identical(related$relation, "isIdenticalTo") && identical(related$resource_type, "software"),
        "Zenodo repository identity")
  check(length(cff$authors) == 1L && length(zenodo$creators) == 1L, "author count")
  author <- cff$authors[[1]]
  creator <- zenodo$creators[[1]]
  check(identical(author$`given-names`, "xuankun") && identical(author$`family-names`, "zheng") &&
          identical(creator$name, "zheng, xuankun") &&
          identical(description$`Authors@R`, 'person("xuankun", "zheng", role = c("aut", "cre"))'),
        "author identity")
  check(identical(author$orcid, "https://orcid.org/0009-0006-7036-7811") &&
          grepl("^https://orcid[.]org/[0-9]{4}-[0-9]{4}-[0-9]{4}-[0-9]{3}[0-9X]$", author$orcid) &&
          identical(creator$orcid, "0009-0006-7036-7811"), "ORCID identity")
  check(is.character(cff$message) && length(cff$message) == 1L && nzchar(cff$message), "citation message")
  check(length(cff$keywords) > 0L && length(zenodo$keywords) > 0L, "keywords required")

  if (identical(version, "1.0.0")) {
    check(identical(as.character(cff$`date-released`), "2026-08-11") &&
            identical(zenodo$publication_date, "2026-08-11"), "historical release date")
    if ("doi" %in% names(cff)) {
      check(identical(cff$doi, "10.5281/zenodo.21879884"), "historical version DOI")
    } else {
      # Tag 1eeec7d points to 998e3c0a83656eae5e3ee8dae909e2edcd2625ec.
      # Its original CFF predates the DOI addition at commit 01c49c1.
      # Missing DOI is allowed ONLY for that exact five-file historical snapshot.
      hashes <- c(
        VERSION = "59854984853104df5c353e2f681a15fc7924742f9a2e468c29af248dce45ce03",
        DESCRIPTION = "d65f6800d4427fa00990f779f5aff9ba6b6d477109793483e44c155bf3a6e4af",
        CITATION.cff = "84150ba1cd659fbcf0f91891f418f39454c8cdfdd37432ba541e1496248ab20e",
        .zenodo.json = "1a2bf0718c453d7e9eb2d58bcfe2ce56dd9fd71b498df8bd0eca62915d230c97",
        LICENSE = "391fce62f391ebb6867f87a014d943b822e11a0a38c030452e7ad1771956c911"
      )
      for (name in names(hashes)) {
        path <- file.path(root, name)
        contents <- readChar(path, file.info(path)$size, useBytes = TRUE)
        canonical <- gsub("\r\n", "\n", contents, fixed = TRUE)
        check(identical(digest::digest(canonical, algo = "sha256", serialize = FALSE), unname(hashes[name])),
              paste("original v1.0.0 tag snapshot changed:", name))
      }
    }
    state <- "HISTORICAL_V1_0_0"
  } else {
    # Strict candidate field sets exclude DOI, dates, archive IDs, preferred
    # published citations and publication-state claims, including null fields.
    cff_fields <- c("cff-version", "message", "title", "type", "authors", "version", "license",
                    "keywords", "repository-code", "abstract")
    zenodo_fields <- c("title", "creators", "description", "keywords", "license", "version",
                       "upload_type", "related_identifiers")
    check(!length(setdiff(names(cff), cff_fields)), "candidate CFF contains publication or unsupported fields")
    check(!length(setdiff(names(zenodo), zenodo_fields)), "candidate Zenodo contains publication or unsupported fields")
    check(!any(c("Date", "Date/Publication") %in% names(description)), "candidate DESCRIPTION release date")
    check(startsWith(cff$message, "Unreleased v1.2.0 Release Candidate;") &&
            startsWith(zenodo$description, "Unreleased v1.2.0 Release Candidate."), "candidate must be explicitly unreleased")
    state <- "UNRELEASED_V1_2_0_CANDIDATE"
  }
  message("PUBLIC_METADATA_VALIDATION=PASS; version=", version, "; state=", state)
  invisible(state)
}

if (sys.nframe() == 0L) validate_metadata()

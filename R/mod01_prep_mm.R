#######################################
### Worflow functions               ###
### for EcoservR                    ###
### Sandra Angers-Blondin           ###
### 29 March 2021                   ###
#######################################

#' Prepare MasterMap
#'
#' This function imports the OS MasterMap from its specified folder. It only reads in polygons that intersect the study area but needs to query all files in the folder to do so. For optimal performance, set your mastermap folder to only contain OS tiles needed for a given project.

#' @param projectLog The RDS project log file generated by the wizard app and containing all file paths to data inputs and model parameters
#' @return Saves a project_title_MM_01.RDS file to project folder, and returns the buffered study area and the mm object to the environment.
#' @export
#'
prepare_basemap <- function(projectLog = parent.frame()$projectLog){
   # the parent frame bit makes sure the function knows that the argument comes from the users's environment

   timeA <- Sys.time() # start time

   ## Extract the file paths and other info from project log -----

   mmpath <- projectLog$df[projectLog$df$dataset == "mm", ][["path"]]
   mmlayer <- projectLog$df[projectLog$df$dataset == "mm", ][["layer"]]
   mm_cols <- projectLog$df[projectLog$df$dataset == "mm", ][["cols"]][[1]] # coerce to named character (remove list nesting)
   mmtype <- guessFiletype(mmpath) # extract filetype

   studypath <- projectLog$df[projectLog$df$dataset == "studyArea", ][["path"]]
   studybuffer <- projectLog$parameters$SAbuffer

   output_temp <- projectLog$output_temp
   title <- projectLog$title

   ### Fist check colnames are valid:
   checkNames(mmpath, mmlayer, mm_cols) # will stop execution if col names specified by user don't match names in layer


   ### Create output folder if doesn't exist
   if (!dir.exists(output_temp)){
      dir.create(output_temp)
   }

   ### Step 1. Import and buffer the study area ------------------------------------------

   ### Import the study area outline (specifying OSGB as crs)

   studyArea <- try(loadSpatial(studypath,
                                layer = NULL,
                                filetype = guessFiletype(studypath)) %>%
                       do.call(rbind, .))

   if (inherits(studyArea, "try-error")) stop("Could not import study area. Check file path and format.") else message("Study area imported.")

   studyArea <- suppressWarnings({
      checkcrs(studyArea, 27700) %>%   # check that CRS is Brit National Grid, and transform if not
         sf::st_set_crs(., 27700)  # set the crs manually to get rid of GDAL errors with init string format
   })

   ### Buffer and union

   studyAreaBuffer <- sf::st_buffer(studyArea, studybuffer) %>% # create a buffer around the study area shape
      sf::st_union() %>%  # dissolve so that overlapping parts do not generate overlapping polygons in other datasets
      sf::st_make_valid() %>% # make sure outline is valid
      sf::st_geometry() %>% sf::st_as_sf()  # retain only geometry

   rm(studyArea)  # remove original boundary

   # Save the buffer to disk for next scripts

   sf::st_write(studyAreaBuffer,
                dsn = file.path(output_temp,
                                paste(title, "_studyAreaBuffer_",studybuffer,"m.gpkg", sep="")),
                append = FALSE # will overwrite existing object if present
   )


   # and as R object for easy handling - recalling in other modules
   saveRDS(studyAreaBuffer, file.path(output_temp, paste0(title,"_studyAreaBuffer.RDS")))

   if(sf::st_is_valid(studyAreaBuffer)) {message("Study area buffered and saved to your output folder.")}


   ### Step 2. Import and tidy mastermap data ----------------------------------------------

   # NOTE: Most users will have done a data download that has many files, one for each 10km tile.
   # All the files should be in the same folder for the function to work (the name of the folder is the first argument of the function).


   # List available MasterMap files ------------------------------------------

   ## List all acceptable spatial files in folder
   fileList <- list.files(mmpath, pattern = paste0(mmtype, collapse="|"),
                          recursive = TRUE, full.names = TRUE,
                          ignore.case = TRUE)

   if (length(fileList) == 0){stop("Cannot find MasterMap data. Please check file path and format.")}


   ## Amend the file list and create a layer object based on the file type

   if (any(grepl("shp", mmtype))){

      ## If we're dealing with shapefiles, we want the file list to be the directories,
      ## and create a layer list with the actual layer names.

      # first we subset the files to just those with the right string
      # UPDATE 27 July 2021: mmlayer can be a list of layer names rather than a common string, so paste0 is required to test across all names

      fileList <- fileList[grepl(paste0(mmlayer, collapse = "|"), fileList)]

      if (length(fileList) == 0){stop("Could not find layers corresponding to ", mmlayer)}

      # Then we extract the layer names from the file name
      layer <- lapply(fileList, function(x)
         sub(pattern = mmtype,
             replacement = "\\1", basename(x), ignore.case = TRUE))  # remove extension from file name

      # And remove it from the dsn list

      fileList <- dirname(fileList)

   } else {

      ## If we are dealing with any other format, the fileList with the full extension is the dsn,
      ## and the layer name should always be what was detected by the wizard.

      layer <- mmlayer

   }

   ## Now we have two key objects to work with: fileList which is always the dsn argument of the read functions,
   ## and layer which is either a list of the same length as fileList (for shapefiles) or one
   ## character object, to be used in the layer argument of the read functions.


   # Prepare selection of relevant data from MasterMap files ------------------------

   ## This section only accesses the metadata of the Mastermap data,
   ## to identify which files(s) belong to each tile of the study area.

   ## These functions are custom wrapper functions to keep this script short.
   ## See fun_mastermap if problems with any of them

   ## Prepare the study area grids (10x10km OS squares intersected with the SA)

   SAgrid <- ecoservR::grid_study(studyAreaBuffer)


   ## Extract file extents without reading files in memory
   ex <- ecoservR::getFileExtent(fileList, layer)

   # This ex object is a polygon corresponding to the extent of every tile.
   # The file and layername variables can be used to read in the files.


   ## Now we can figure out which files belong to which study area tile
   ## (only those that intersect the square)
   ## Since we have all the spatial and file name info we need in ex, this section is not
   ## dependent on file format

   explo <- lapply(SAgrid, function(x){
      belongs_tile <- unlist(sf::st_intersects(x, ex, sparse=TRUE))
      sf::st_drop_geometry(ex[belongs_tile,])
   })

   ## This reduces the number of files against which to perform the spatial query for a given SA tile.
   ## It returns, for each study area tile, a dataframe of dsn and layer names to read in.


   # Import mastermap data ---------------------------------------------------

   mm <- vector(mode = "list", length = length(SAgrid))  # initialise empty mm object
   names(mm) <- names(SAgrid)


   for (i in 1:length(SAgrid)){   # loop through each part of the study area to import features,
      # tidy them and remove duplicates

      gridref <- names(SAgrid)[[i]]   # the grid reference we are working on for this iteration

      if (nrow(explo[[gridref]]) == 0){
         message("Warning: no MasterMap data for grid reference ", gridref)
         next
      } # skip if no matching files

      message("Importing MasterMap data for grid reference ", gridref)  # show progress

      # cycle through all files that intersect this grid reference, and import polygons overlapping SA

      mm[[i]] <- lapply(seq_along(c(1:nrow(explo[[gridref]]))), function(x){

         poly_in_boundary(explo[[gridref]][["file"]][x],                  # the dsn argument
                          SAgrid[[i]],                                    # the query layer
                          layer = c(explo[[gridref]][["layername"]][x])   # the layer name
         )  # read in features

      })


      # convert all names to lowercase for easier matching with mm_cols
      mm[[i]] <- lapply(mm[[i]], function(x){
         names(x) <- tolower(names(x))
         return(x)
      })

      # Each mm item is now NULL (no features), or a list of 1 or more items.
      # They might differ in number and names of columns so processing them right away before binding


      mm[[i]] <- lapply(mm[[i]], function(x){

         dplyr::select(x, all_of(tolower(mm_cols))) %>%   # keep only cols we need,
            ## using names specified by user and renaming on the fly with our standard names

            dplyr::mutate(dplyr::across(where(is.list) & !attr(., "sf_column"),  # convert weird list-columns to character
                                        ecoservR::list_to_char))  %>%
            dplyr::filter(PhysicalLevel != "51",  # remove things above ground level
                          Group != "Landform" ) %>%
            dplyr::mutate(TOID = as.character(gsub("[a-zA-Z ]", "", TOID))) %>%   # remove osgb characters which sometimes appear and sometimes not
            dplyr::select(-PhysicalLevel)  # remove useless column

      })


      # Now hopefully all list items are consistent, so can be bound together.
      # There will be many duplicated polygons at this stage (from neighbouring files containing the same straddling polygons) so remove them
      mm[[i]] <- do.call(rbind, mm[[i]])
      mm[[i]] <- mm[[i]][!duplicated(mm[[i]]$TOID),]


   }


   ### Once the loop is over we have a list as long as there are 10x10km grid references in the study area.
   ### We make sure all empty items are removed and do another duplicate check (there should not be duplicates within tiles, but there will be some across tiles)

   ## Remove empty tiles
   mm <- mm[sapply(mm, function(x) (!is.null(x)) == TRUE)]
   mm <- mm[sapply(mm, function(x) (nrow(x) > 0) == TRUE)]

   ## Remove duplicated polygons (same polygon can occur in multiple tiles)
   mm <- removeDuplicPoly(mm, "TOID")


   ## the duplicate check may dwindle a tile to nothing (this fixes a bug)
   ## so we check and remove empty tiles again
   mm <- mm[sapply(mm, function(x) (nrow(x) > 0) == TRUE)]


   ## Clip to study area
   message("Clipping to study area...")

   ## identify core vs edge tiles
   SAgrid <- ecoservR::grid[
      lengths(sf::st_intersects(ecoservR::grid, studyAreaBuffer))>0,]
   is_core <- unlist(sf::st_contains(studyAreaBuffer,SAgrid))

   ## Clip where necessary
   # (if a whole 10k tile is included within study area, no need)

   for (i in 1:length(mm)){


      # we only need to perform clipping on edge tiles
      if (names(mm)[[i]] %in% names(SAgrid)[is_core]){next}

      ## if we have an edge tile, we apply the faster_intersect custom function
      ## which deletes polygons outside the boundary, protects those inside
      ## and clips those on the edge

      mm[[i]] <- faster_intersect(mm[[i]], studyAreaBuffer)
      message("Clipped tile ", names(mm)[[i]])
   }


   # # (we only imported the features intersecting the SA but sometimes they are very long, e.g. roads, and stick out of the map)
   # mm <- lapply(mm, function(x) suppressWarnings(
   #    sf::st_intersection(x, sf::st_geometry(studyAreaBuffer))) %>% checkgeometry(., "POLYGON"))


   ### Step 6. Add a buffer for the sea -----

   ## Import coastline boundaries
   ## anything outside the UK boundary is labelled as sea and a buffer added...

   # Low-priority step --- is it really useful?


   # SAVE UPDATED MAP ----------------------------------------------------------------------------

   # Save the list of spatial objects as an RDS object (quicker to reload in R)

   saveRDS(mm, file.path(output_temp, paste0(title,"_MM_01.RDS")))

   # Update the project log with the information that map was updated

   projectLog$SAbuffer <- file.path(output_temp,
                                    paste(title, "_studyAreaBuffer_",studybuffer,"m.gpkg", sep=""))

   projectLog$last_success <- "MM_01.RDS"


   ### Create a "performance" list in the project log which saves the time taken
   ## for each module

   projectLog$performance <- vector(mode = "list", length = 17)
   names(projectLog$performance) <- c(
      "prep_mastermap",
      "add_greenspace",
      "add_corine",
      "add_NFI",
      "add_PHI",
      "add_CROME",
      "add_DTM",
      "add_hedges",
      "classify_map",
      "add_socioeco",
      "cap_carbon",
      "cap_air",
      "cap_flood",
      "cap_pollin",
      "cap_noise",
      "cap_clim",
      "cap_access"
   )

   timeB <- Sys.time() # stop time

   projectLog$performance[["prep_mastermap"]] <- as.numeric(difftime(
      timeB, timeA, units="mins"
   ))


   updateProjectLog(projectLog) # save revised log



   message(paste0("MasterMap preparation finished. Process took ",
                  round(difftime(timeB, timeA, units = "mins"), digits = 1), " minutes. Ready for
                  processing."))

   on.exit(invisible(gc())) # garbage collection - return some memory to computer

   return({
      ## returns the objects in the global environment
      invisible({
         mm <<- mm
         studyAreaBuffer <<- studyAreaBuffer
         projectLog <<- projectLog
      })
   })



}

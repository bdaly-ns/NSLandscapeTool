#######################################
### Worflow functions               ###
### for EcoservR                    ###
### Sandra Angers-Blondin           ###
### 15 October 2020                 ###
#######################################

#' Add National Forest Inventory
#'
#' This function adds National Forest Inventory data to the basemap (England).

#' @param mm The mm object loaded in the environment, can be at various stages of updating.
#' @param studyAreaBuffer The buffered study area generated during mod01 or reloaded when resuming a session.
#' @param projectLog The RDS project log file generated by the wizard app and containing all file paths to data inputs and model parameters
#' @return Saves a project_title_MM_04.RDS file to project folder
#' @export

add_NFI <- function(mm = parent.frame()$mm,
                    studyAreaBuffer = parent.frame()$studyAreaBuffer,
                    projectLog = parent.frame()$projectLog){

   timeA <- Sys.time() # start time


   ## Extract the file paths and other info from project log ----------------------

   output_temp <- projectLog$output_temp
   title <- projectLog$title
   scratch_path <- file.path(output_temp, "ecoservR_scratch")
   if (!dir.exists(scratch_path)) dir.create(scratch_path)

   # NFI info
   nfipath <- projectLog$df[projectLog$df$dataset == "nfi", ][["path"]]  # path to corine data, if available
   dsname <- projectLog$df[projectLog$df$dataset == "nfi", ][["prettynames"]]


   if (!is.na(nfipath) & !is.null(nfipath)){

      nfitype <- guessFiletype(nfipath)   # file type, gpkg or shp

      nfi_cols <- tolower(  # making all lowercase for easier matching
         projectLog$df[projectLog$df$dataset == "nfi", ][["cols"]][[1]]  # attributes
      )

   ## Data import -------------------------------------------------------------

   # Only load polygons intersecting study area
      nfi <- loadSpatial(folder = nfipath,
                         filetype = nfitype,
                         querylayer = studyAreaBuffer)

      nfi <- do.call(rbind, nfi) %>% sf::st_as_sf()  # putting back into one single sf object

   ## DATA PREP -----------------------------------------------------------------------------------

      message("Extracting NFI data...")

      # Rename columns if needed

      names(nfi) <- tolower(names(nfi)) # forcing lowercase attributes

      nfi <- dplyr::select(nfi, all_of(nfi_cols))

      ## Check and set projection if needed

      nfi <- checkcrs(nfi, studyAreaBuffer)

      # Keep only woodlands and tidy up the data

      nfi <- nfi %>%
         dplyr::filter(CATEGORY == "Woodland") %>%   # keep woodlands
         dplyr::select(woodtype = IFT_IOA) %>%
         checkgeometry(., "POLYGON") # check and repair geometry, multi to single part


      ## Rasterize data (will create tiles if needed)

      nfi_v <- prepTiles(mm, nfi, studyArea = studyAreaBuffer, value = "woodtype")
      rm(nfi)

      if(is.null(nfi_v)){

         projectLog$ignored <- c(projectLog$ignored, dsname)
         updateProjectLog(projectLog)

         return(message("WARNING: National Forest Inventory data not added: No data coverage for your study area."))
      }


      nfi_r <- makeTiles(nfi_v, value = "woodtype", name = "NFI")
      rm(nfi_v)


      # ZONAL STATISTICS TO UPDATE MASTERMAP ----------------------------------------------------------

      # Create a key from the rasters' levels to add the descriptions back into the mastermap after extraction
      key <- as.data.frame(raster::levels(nfi_r[[1]]))


      mm <- mapply(function(x, n) extractRaster(x, nfi_r,
                                                fun = "majority",
                                                tile = n,
                                                newcol = "nfi"),
                   x = mm,
                   n = names(mm), # passing the names of the tiles will allow to select corresponding raster, making function faster. If user is not working with named tiles, will be read as null and the old function will kick in (slower but works)
                   SIMPLIFY = FALSE)  # absolutely necessary

      rm(nfi_r)  # remove raster tiles

      # Replace the numeric codes by the text description (also a custom function)

      mm <- lapply(mm, function(x) addAttributes(x, "nfi", key))

      rm(key)

      # SAVE UPDATED MASTER MAP ---------------------------------------------------------------------

      saveRDS(mm, file.path(output_temp, paste0(title, "_MM_04.RDS")))

      # Update the project log with the information that map was updated

      projectLog$last_success <- "MM_04.RDS"

      timeB <- Sys.time() # stop time

      # add performance to log
      projectLog$performance[["add_NFI"]] <- as.numeric(difftime(
         timeB, timeA, units="mins"
      ))

      updateProjectLog(projectLog) # save revised log

      # and delete contents of scratch folder
      cleanUp(scratch_path)

      message(paste0("Finished updating with National Forest Inventory data. Process took ",
                     round(difftime(timeB, timeA, units = "mins"), digits = 1),
                     " minutes."))



   } else {message("No NFI data input specified.")} # end of running condition


   # Return mm to environment, whether it has been updated or not.
   return({
      invisible({
         mm <<- mm
         projectLog <<- projectLog
      })
   })

} # end of function

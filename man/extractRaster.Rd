% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fun_tiling_extract.R
\name{extractRaster}
\alias{extractRaster}
\title{Extract Raster into Polygons}
\usage{
extractRaster(sf, rast, fun, tile = NULL, newcol)
}
\arguments{
\item{sf}{One sf object, i.e. a basemap tile}

\item{rast}{A list of raster tiles, ideally named to match mastermap tiles}

\item{fun}{The function to be applied in zonal stats. Either "mean" for numeric values, or "majority" for the most common occurrence.}

\item{tile}{The OS tile grid reference to match raster to mastermap tile; can be set dynamically with mapply}

\item{newcol}{The name of the new attribute with extracted values}
}
\value{
An updated mm object with a new column containing the extracted values
}
\description{
This function extracts the information contained in raster tiles into the basemap. Ideally it operates a one-to-one matching using the tiles names. If unnamed, the workflow is slower and could leave out a small number of polygons. Extraction from centroids is used for small polygons that get missed during the standard extraction.
}

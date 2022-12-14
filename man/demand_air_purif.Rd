% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/demand_air.R
\name{demand_air_purif}
\alias{demand_air_purif}
\title{Air Purification Demand Model}
\usage{
demand_air_purif(
  x = parent.frame()$mm,
  studyArea = parent.frame()$studyArea,
  res = 5,
  local = 300,
  openroads = NULL,
  roadClassification = "roadClassification",
  indicators = TRUE,
  indic_weights = c(1, 1, 1, 1),
  projectLog = parent.frame()$projectLog,
  runtitle = parent.frame()$runtitle,
  save = NULL
)
}
\arguments{
\item{x}{A basemap, in a list of sf tiles or as one sf object. Must have attributes "HabCode_B", "housePop", "health".}

\item{studyArea}{The boundaries of the site, as one sf object. The final raster will be masked to this shape. For best results this shape should be smaller than the basemap (which should be buffered by typically 300 m - 1km to avoid edge effects).}

\item{res}{Desired resolution of the raster. Default is 5 m. Range recommended is 5-10m.}

\item{local}{Radius (m) for focal statistics at local range. Default is 300 m.}

\item{openroads}{Path to the folder containing OS Open Roads data or other (linestring) road classification to use as source of pollution.}

\item{roadClassification}{The attribute name in OS Open Roads containing the classification of road types, default "roadClassification". Only "Motorway" and "A Road" types are selected for analysis. (If using custom road network, please ensure classification matches these terms exactly.)}

\item{indicators}{Logical; should raw indicators (before transformation into z-scores and rescaling) be saved to the project folder? Default TRUE.}

\item{indic_weights}{A numeric vector of length 4, with weights for distance to roads, manmade surfaces, population and health, respectively. Default to equal weights of 1 (all indicators contributing equally to final sum).}

\item{projectLog}{The RDS project log file generated by the wizard app and containing all file paths to data inputs and model parameters}

\item{runtitle}{A customised title you can give a specific model run, which will be appended to your project title in the outputs. If comparing a basemap to an intervention map, we recommend using "pre" and "post", or a short description of the interventions, e.g. "baseline" vs "tree planting".}

\item{save}{Path to folder where outputs will be saved. By default a folder will be created using your chosen run title, prefixed by "services_". Do not use this argument unless you need to save the outputs somewhere else.}
}
\value{
Two rasters with demand scores: one with raw scores (arbitrary units), and one rescaled 0-100 (where 100 is maximum demand for the area).
}
\description{
Runs the air purification ecosystem service model, generating demand scores based on four indicators: distance to major roads, proportion of manmade surfaces, population, and health. (Specific indicators can be omitted by setting the appropriate weight to 0.)
}

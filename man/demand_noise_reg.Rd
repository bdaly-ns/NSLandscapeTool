% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/demand_noise_reg.R
\name{demand_noise_reg}
\alias{demand_noise_reg}
\title{Noise Regulation Demand Model}
\usage{
demand_noise_reg(
  x = parent.frame()$mm,
  studyArea = parent.frame()$studyArea,
  res = 5,
  distances = c(motorway = 800, dual = 600, primary = 550, railway = 650, airport =
    1500),
  local = 300,
  indicators = TRUE,
  indic_weights = c(1, 0.5, 0.5),
  projectLog = parent.frame()$projectLog,
  runtitle = parent.frame()$runtitle,
  save = NULL
)
}
\arguments{
\item{x}{A basemap, in a list of sf tiles or as one sf object. Must have attributes "HabCode_B", "housePop", "health".}

\item{studyArea}{The boundaries of the site, as one sf object. The final raster will be masked to this shape. For best results this shape should be smaller than the basemap (which should be buffered by typically 300 m - 1km to avoid edge effects).}

\item{res}{Desired resolution of the raster. Default is 5 m. Range recommended is 5-10m.}

\item{distances}{Distance threshold (in meters) for noise attenuation for the noise sources: motorways, dual carriageways, primary roads, railways, and airports. Must be a named vector of numeric values in meters; defaults to c("motorway" = 800,"dual" = 600,"primary" = 550,"railway" = 650,"airport" = 1500). Defra's Strategic Noise Mapping (https://www.gov.uk/government/publications/strategic-noise-mapping-2019) may help set sensible defaults.}

\item{local}{Radius (m) for focal statistics at local range. Default is 300 m.}

\item{indicators}{Logical; should raw indicators (before transformation into z-scores and rescaling) be saved to the project folder? Default TRUE.}

\item{indic_weights}{A numeric vector of length 3, with weights for distance to roads, population and health, respectively. Default to c(1, 0.5, 0.5) so that population and health combined has equal weight to noise sources.}

\item{projectLog}{The RDS project log file generated by the wizard app and containing all file paths to data inputs and model parameters}

\item{runtitle}{A customised title you can give a specific model run, which will be appended to your project title in the outputs. If comparing a basemap to an intervention map, we recommend using "pre" and "post", or a short description of the interventions, e.g. "baseline" vs "tree planting".}

\item{save}{Path to folder where outputs will be saved. By default a folder will be created using your chosen run title, prefixed by "services_". Do not use this argument unless you need to save the outputs somewhere else.}
}
\value{
Two rasters with demand scores: one with raw scores (arbitrary units), and one rescaled 0-100 (where 100 is maximum demand for the area).
}
\description{
Runs the noise regulation ecosystem service model, generating demand scores based on three indicators: distance to noise sources (airports, railways and major roads), population, and health. (Specific indicators can be omitted by setting the appropriate weight to 0.)
}

# Needs to be run as an admin that has write permissions to /etc/rstudio
# 
# This script when run against any R version will 
# * figure out which compatible BioConductor Version exist
# * get all the URLs for the repositories of BioConductor
# * Add both CRAN and BioConductor 
#       into files in /etc/rstudio/repos/repos-x.y.z.conf
# * add entries into /etc/rstudio/r-versions to define the respective 
#       R version (x.y.z) and point to the repos.conf file  
# * update Rprofile.site with the same repository informations 
# * add renv config into Renviron.site to use 
#       a global cache in /scratch/renv
# * install all needed R packages for Workbench to work and add them 
#       in a separate .libPath()
# * auto-detect which OS it is running on and add binary package support


binaryflag<-""

if(file.exists("/etc/debian_version")) {
    binaryflag <- paste0("__linux__/",system(". /etc/os-release && echo $VERSION_CODENAME", intern = TRUE),"/")
}

if(file.exists("/etc/redhat-release")) {
    binaryflag <- paste0("__linux__/centos",system(". /etc/os-release && echo $VERSION_ID", intern = TRUE),"/")
}

currver <- paste0(R.Version()$major,".",R.Version()$minor)
paste("version",currver)

pmurl <- "https://packagemanager.rstudio.com"
cranrepo <- paste0(pmurl,"/cran/")
cranrepolatest <- paste0(cranrepo,"latest")

libdir <- paste0("/opt/rstudio/r-integration/",currver)

if(dir.exists(libdir)) {unlink(libdir,recursive=TRUE)}
dir.create(libdir,recursive=TRUE)
.libPaths(libdir)

curldir<-paste0(system("mktemp -d",intern=TRUE),"/curl/",currver)
if(dir.exists(curldir)) {unlink(curldir,recursive=TRUE)}
dir.create(curldir,recursive=TRUE)
install.packages(c("RCurl","rjson"),curldir, repos="https://packagemanager.rstudio.com/cran/latest")
library(RCurl,lib.loc=curldir)
library(rjson,lib.loc=curldir)

jsondata<-fromJSON(file="https://raw.githubusercontent.com/rstudio/rstudio/main/src/cpp/session/resources/dependencies/r-packages.json")
pnames<-c()
for (feature in jsondata$features) { pnames<-unique(c(pnames,feature$packages)) }

#Start with a starting date for the time-based snapshot 60 days past the R release
releasedate <- as.Date(paste0(R.version$year,"-",R.version$month,"-",R.version$day))+60
paste("release", releasedate)
 
#Attempt to install packages from snapshot - if snapshot does not exist, decrease day by 1 and try again
getreleasedate <- function(repodate){
  
  repo=paste0(cranrepo,binaryflag,repodate)
  paste(repo)
  URLfound=FALSE
  while(!URLfound) {
   if (!RCurl::url.exists(paste0(repo,"/src/contrib/PACKAGES"),useragent="curl/7.39.0 Rcurl/1.95.4.5")) {
	repodate<-as.Date(repodate)-1
        paste(repodate)
        repo=paste0(cranrepo,repodate)
   } else {
   URLfound=TRUE
   }
 }
 return(repodate)
}

releasedate <- getreleasedate(as.Date(releasedate))

#Final CRAN snapsot URL
repo=paste0(cranrepo,binaryflag,releasedate)

avpack<-available.packages(paste0(repo,"/src/contrib"))

#Install all packages needed for RSW
for (package in pnames) {
  if (package %in% avpack) {
    install.packages(package,repos=repo,libdir)
  }
}

# also add batchtools, clustermq and tidyverse
install.packages(c("batchtools","clustermq","tidyverse"),repos=repo,libdir)



sink(paste0("/opt/R/",currver,"/lib/R/etc/Renviron.site"), append=TRUE)
  cat("RENV_PATHS_PREFIX_AUTO=TRUE\n")
  cat("RENV_PATHS_ROOT=/data/renv\n")
  cat("RENV_PATHS_SANDBOX=/data/renv/sandbox\n")
  cat("R_BATCHTOOLS_SEARCH_PATH=/opt/rstudio/r-integration/batchtools/")
sink()

# define batchtools default settings
dir.create("/opt/rstudio/r-integration/batchtools")
sink("/opt/rstudio/r-integration/batchtools/batchtools.conf.R")
  cat("cluster.functions = makeClusterFunctionsSlurm(template=/opt/rstudio/r-integration/batchtools/slurm.tmpl)\n")
  cat("default.resources = list(walltime = 60, ncpus=1, memory = 1024)\n")
sink()

system(paste0("cp ",libdir,"/batchtools/templates/slurm-simple.tmpl /opt/rstudio/r-integration/batchtools/slurm.tmpl"))
system("sed -i 's#Rscript#${R_HOME}/bin/Rscript#' /opt/rstudio/r-integration/batchtools/slurm.tmpl")

# tweak clustermq SLURM template
system(paste0("sed -i 's#R --no#${R_HOME}/bin/R --no#' ",libdir,"/clustermq/SLURM.tmpl"))
system(paste0("sed -i 's#| 1024#| 4096#' ",libdir,"/clustermq/SLURM.tmpl"))

# Prepare for BioConductor
options(BioC_mirror = paste0(pmurl,"/bioconductor"))

# Make sure BiocManager is loaded - needed to determine BioConductor Version
biocdir<-paste0(system("mktemp -d",intern=TRUE),"/bioc/",currver)
if(dir.exists(biocdir)) {unlink(biocdir,recursive=TRUE)}
dir.create(biocdir,recursive=TRUE)
install.packages("BiocManager",biocdir, repos=cranrepolatest)
library(BiocManager,lib.loc=biocdir,quietly=TRUE,verbose=FALSE)

# Version of BioConductor as given by BiocManager (can also be manually set)
biocvers <- BiocManager::version()

# Bioconductor Repositories
r<-BiocManager::repositories(version=biocvers)

# enforce CRAN is set to our snapshot 
r["CRAN"]<-repo

# Make sure CRAN is listed as first repository (rsconnect deployments will start
# searching for packages in repos in the order they are listed in options()$repos
# until it finds the package
# With CRAN being the most frequenly use repo, having CRAN listed first saves 
# a lot of time
nr=length(r)
r<-c(r[nr],r[1:nr-1])

# Populate r-versions and repos config for RSW
rverstring=paste0(R.version$major,".",R.version$minor)
 
system("mkdir -p /opt/rstudio/etc/rstudio/repos")
filename=paste0("/opt/rstudio/etc/rstudio/repos/repos-",rverstring,".conf")
sink(filename)
for (i in names(r)) {cat(noquote(paste0(i,"=",r[i],"\n"))) }
sink()

x<-unlist(strsplit(R.home(),"[/]"))
r_home<-paste0(x[2:length(x)-2],"/",collapse="")

sink("/opt/rstudio/etc/rstudio/r-versions", append=TRUE)
cat("\n")
cat(paste0("Path: ",r_home,"\n"))
cat(paste0("Label: R","\n"))
cat(paste0("Repo: ",filename,"\n"))
cat(paste0("Script: /opt/R/",rverstring,"/lib/R/etc/ldpaths \n"))
cat("\n")
sink()

sink(paste0("/opt/R/",rverstring,"/lib/R/etc/Rprofile.site"),append=TRUE)
if ( rverstring < "4.1.0" ) {
  cat('.env = new.env()\n')
}
cat('local({\n')
cat('r<-options()$repos\n')
for (line in names(r)) {
   cat(paste0('r["',line,'"]="',r[line],'"\n'))
}
cat('options(repos=r)\n') 

cat(paste0('.libPaths(c(.libPaths(),"',libdir,'"))\n'))
if ( rverstring < "4.1.0" ) {
cat('}, envir = .env)\n')
cat('attach(.env)\n')
} else {
cat('})\n')
}
sink()

#!/bin/bash
#wrapper script to build r-session containers
for i in *.sdef
do 
   apptainer build /opt/apptainer/containers/${i/sdef/simg} $i
done

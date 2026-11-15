# Serialization view only: the analysis result is not changed. Same JSON schema,
# scalar values, row order, complete records, digits=17 and null policy.
write_result_optimized <- function(answer,path,pretty=FALSE) {
  view<-answer
  if(!is.null(view$artificial_censors)) {
    view$artificial_censors<-lapply(view$artificial_censors,function(rows) {
      if(!length(rows)) return(rows)
      data.frame(id=vapply(rows,function(z)z$id,''),k=vapply(rows,function(z)as.numeric(z$k),0.0),stringsAsFactors=FALSE)
    })
  }
  jsonlite::write_json(view,path,auto_unbox=TRUE,pretty=pretty,digits=17,na='null',null='null',dataframe='rows')
}

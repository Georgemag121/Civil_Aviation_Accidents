##### Alternative node selections
testdf <- data.frame(matrix(NA, nrow = 20, ncol = 2))


for (yr in 2019:2019) {
  url.init <- paste0("http://aviation-safety.net/database/dblist.php?Year=", yr)
  
  pages.tmp <- url.init %>% read_html() %>% html_nodes(".pagenumbers") %>% html_text()
  
  if (pages.tmp == "") {
    pages <- 1
  }
  
  else {
    pages <- pages.tmp %>% strsplit("") %>% unlist() %>% as.numeric() %>% max(na.rm = T)
  }
  
  for (pg in 1:pages) {
    url1 <- paste0(url.init, "&lang=&page=", pg)
    
    links <- url1 %>% read_html() %>% html_nodes("nobr a") %>% html_attr('href')
    
    for (link.num in 1:length(links)) {
      url.tmp <- paste0("http://aviation-safety.net/", links[link.num])
      
      # node selection option 1: .captionhr:nth-child(7) , span , td, all even number of elements (in other words, all are convertable to dataframe)
      # node selection option 2: span , td
      
      if (is.na(tryCatch(read_html(url.tmp), error = function(error) {NA}))) {
        badlinks <- badlinks + 1
      }
      
      else {
        
        # tryout node selection: .captionhr:nth-child(7) , span , td
        # .captionhr:nth-child(7) , span , .caption+ td , .caption
        
        abc <- url.tmp %>% read_html() %>% html_nodes(".captionhr:nth-child(7) , span , .caption+ td , .caption") %>% html_text()
        testdf[link.num, ] <- c(link.num, length(abc))
        
        
      }
    }
  }
}


#Bag of words text analysis

# test <- df2 %>% filter(grepl("Passenger", Nature))
# test1 <- test %>% filter(Date > "1977-03-26", Date < "1977-03-28")
# 
# 
# #NLP
# dfsource <- DataframeSource(df2)
# dfcorp <- VCorpus(dfsource)
# 
# causes1 <- VectorSource(df2$Probable.Cause[which(!is.na(df2$Probable.Cause))])
# causeCorp <- VCorpus(causes1)
# 
# tolower(causeCorp)
# removePunctuation(causeCorp)
# stripWhitespace(causeCorp)
# 
# # stop words
# #stopwords("en")
# 
# clean_corpus <- function(corpus) {
#   corpus <- tm_map(corpus, content_transformer(tolower))
#   corpus <- tm_map(corpus, removeWords, c(stopwords("en"), "flight", "plane", "aircraft", "probable", "cause"))
#   corpus <- tm_map(corpus, stripWhitespace)
#   return(corpus)
# }
# 
# corp1 <- clean_corpus(causeCorp)
# 
# tdm1 <- TermDocumentMatrix(corp1)
# cause.mat1 <- as.matrix(tdm1)
# 
# term_frequency <- rowSums(cause.mat1)
# 
# term_frequency <- sort(term_frequency, decreasing = T)
# 
# term_frequency[1:10]
# 
# word_freqs <- data.frame(term = names(term_frequency), num = term_frequency)
# 
# wordcloud(word_freqs$term, word_freqs$num, max.words = 50, colors = terrain.colors(n = 5))
# 
# tokenizer <- function(x) {
#   NGramTokenizer(x, Weka_control(min = 2, max = 2))
# }
#   
# 
# bigram_dtm <- DocumentTermMatrix(corp1, control = list(tokenize = tokenizer))
# 
# bigram_dtm_m <- as.matrix(bigram_dtm)
# 
# freq <- colSums(bigram_dtm_m)
# 
# bi_words <- names(freq)
# 
# wordcloud(bi_words, freq, max.words = 15)


# Probable causes: 
# pilot: Time, weekday, first flight, travel distance, airline, weather
# aircraft: airframe time, first flight
# engine: brand, time, first flight